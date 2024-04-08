
#include "CommandProcessor.h"  // The include file for this module should come first.

#include <assert.h>
#include <errno.h>
#include <ctype.h>
#include <stdexcept>
#include <stdarg.h>
#include <malloc.h>
#include <inttypes.h>

#include <BareMetalSupport/Uptime.h>
#include <BareMetalSupport/MainLoopSleep.h>
#include <BareMetalSupport/StackCheck.h>
#include <BareMetalSupport/TextParsingUtils.h>
#include <BareMetalSupport/BusyWait.h>
#include <BareMetalSupport/DebugConsoleSerialSync.h>
#include <BareMetalSupport/IntegerPrintUtils.h>
#include <BareMetalSupport/DebugConsoleEol.h>
#include <BareMetalSupport/LinkScriptSymbols.h>

#include <Misc/AssertionUtils.h>

#include <BoardSupport-ArduinoDue/DebugConsoleSupport.h>

#include "Globals.h"
#include "BusPirateOpenOcdMode.h"
#include "JtagPins.h"

#include <rstc.h>


static const char SPACE_AND_TAB[] = " \t";


uint8_t g_usbSpeedTestBuffer[ 1000 ];
uint64_t g_usbSpeedTestEndTime;
UsbSpeedTestEnum g_usbSpeedTestType;


static bool DoesStrMatch ( const char * const strBegin,
                           const char * const strEnd,
                           const char * const match,
                           const bool isCaseSensitive )
{
  assert( strEnd >= strBegin );

  const size_t len = size_t( strEnd - strBegin );

  size_t i;
  for ( i = 0; i < len; ++i )
  {
    const char m = match[ i ];

    if ( m == 0 )
      return false;

    const char c = strBegin[ i ];

    assert( c != 0 );

    // Otherwise, toupper() may not be reliable.
    assert( IsPrintableAscii( m ) );

    if ( c == m )
    {
      continue;
    }

    if ( !isCaseSensitive && toupper( c ) == toupper( m ) )
    {
      continue;
    }

    return false;
  }

  if ( match[ i ] != 0 )
    return false;

  return true;
}


static bool IsCmd ( const char * const cmdBegin,
                    const char * const cmdEnd,   // One character beyond the end, like the STL does.
                    const char * const cmdName,  // Must be printable ASCII and NULL-character terminated.
                    const bool isCaseSensitive,
                    const bool allowExtraParams,
                    bool * const extraParamsFound )
{
  if ( !DoesStrMatch( cmdBegin, cmdEnd, cmdName, isCaseSensitive ) )
    return false;

  if ( !allowExtraParams )
  {
    const char * const paramBegin = SkipCharsInSet( cmdEnd, SPACE_AND_TAB );

    if ( *paramBegin != 0 )
    {
      *extraParamsFound = true;
      return false;
    }
  }

  return true;
}



// This routine could be improved in many ways:
// - Make it faster by building a complete line and sending it at once.
// - Provide memory addresses and/or offsets on the left.
// - Provide an ASCII dump on the right.
// - Use different data sizes (8 bits, 16 bits, 32 bits).
//
//  There is a similar routine in this project called SerialHexDump().

void CCommandProcessor::HexDump ( const void * const ptr,
                                  const size_t byteCount,
                                  const char * const endOfLineChars )
{
  assert( byteCount > 0 );

  const unsigned LINE_BYTE_COUNT = 32;
  const size_t eolLen = strlen( endOfLineChars );
  const size_t lineCount = ( byteCount + LINE_BYTE_COUNT - 1 ) / LINE_BYTE_COUNT;
  const size_t expectedOutputLen = byteCount * 3 + lineCount * eolLen;

  // Example on how to use expectedOutputLen beforehand:
  // if ( expectedOutputLen > txBuffer->GetFreeCount() )
  //   throw std::runtime_error( "Not enough room in the Tx buffer for the hex dump." );
  UNUSED_IN_RELEASE( expectedOutputLen );

  const uint8_t * const bytePtr = static_cast< const uint8_t * >( ptr );

  unsigned lineElemCount = 0;
  size_t actualOutputLen = 0;

  for ( size_t i = 0; i < byteCount; ++i )
  {
    if ( lineElemCount == LINE_BYTE_COUNT )
    {
      lineElemCount = 0;
      Printf( "%s", endOfLineChars );
      actualOutputLen += eolLen;
    }
    const uint8_t b = bytePtr[ i ];

    Printf( "%02X ", b );
    actualOutputLen += 3;

    ++lineElemCount;
  }

  Printf( "%s", endOfLineChars );
  actualOutputLen += eolLen;

  assert( actualOutputLen == expectedOutputLen );
}


static unsigned int ParseUnsignedIntArg ( const char * const begin )
{
  const char ERR_MSG[] = "Invalid unsigned integer value.";

  int base = 10;
  const char * p = begin;

  // Prefix "0x" means that the number is in hexadecimal.

  if ( *p == '0' && *(p+1) == 'x' )
  {
    p += 2;
    base = 16;
  }

  // strtoul() interprets a leading '-', but we always want an unsigned positive value
  // and the user should not be allowed to enter a negative value.
  if ( *p == '-' )
    throw std::runtime_error( ERR_MSG );

  char * end2;
  errno = 0;
  const unsigned long val = strtoul( p, &end2, base );

  if ( errno != 0 || ( *end2 != 0 && !IsCharInSet( *end2, SPACE_AND_TAB ) ) )
  {
    throw std::runtime_error( ERR_MSG );
  }

  STATIC_ASSERT( sizeof(unsigned int) == sizeof(unsigned long), "You may want to rethink this routine's data types." );
  return (unsigned int) val;
}


void CCommandProcessor::PrintMemory ( const char * const paramBegin )
{
  const char * const addrEnd       = SkipCharsNotInSet( paramBegin, SPACE_AND_TAB );
  const char * const countBegin    = SkipCharsInSet   ( addrEnd,    SPACE_AND_TAB );
  const char * const countEnd      = SkipCharsNotInSet( countBegin, SPACE_AND_TAB );
  const char * const extraArgBegin = SkipCharsInSet   ( countEnd,   SPACE_AND_TAB );

  if ( *paramBegin == 0 || *countBegin == 0 || *extraArgBegin != 0 )
  {
    PrintStr( "Invalid arguments." EOL );
    return;
  }

  assert( countBegin > paramBegin );

  const unsigned addr  = ParseUnsignedIntArg( paramBegin );
  const unsigned count = ParseUnsignedIntArg( countBegin );

  // SerialPrint( "Addr : %u" EOL, unsigned(addr ) );
  // SerialPrint( "Count: %u" EOL, unsigned(count) );

  if ( count == 0 )
  {
    PrintStr( "Invalid arguments." EOL );
    return;
  }

  // We could calculate the maximum byte count more accurately using the USB buffer sizes.
  // Routine HexDump() has also logic to calculate the number of characters needed in advance.
  if ( count > 1024 )
  {
    PrintStr( "Due to the USB buffer size limit and the watchdog period, the byte count cannot exceed 1024 bytes with the current implementation." EOL );
    return;
  }

  HexDump( (const void *) addr, size_t( count ), EOL );
}


void CCommandProcessor::BusyWait ( const char * const paramBegin )
{
  const char * const delayEnd      = SkipCharsNotInSet( paramBegin, SPACE_AND_TAB );
  const char * const extraArgBegin = SkipCharsInSet   ( delayEnd,   SPACE_AND_TAB );

  if ( *paramBegin == 0 || *extraArgBegin != 0 )
  {
    PrintStr( "Invalid arguments." EOL );
    return;
  }

  const unsigned delayMs = ParseUnsignedIntArg( paramBegin );

  if ( delayMs == 0 || delayMs > 60 * 1000 )
  {
    PrintStr( "Invalid arguments." EOL );
    return;
  }

  const uint32_t oneMsIterationCount = GetBusyWaitLoopIterationCountFromUs( 1000 );

  for ( unsigned i = 0; i < delayMs; ++i )
  {
    BusyWaitLoop( oneMsIterationCount );
  }

  Printf( "Waited %u ms." EOL, delayMs );
}


void CCommandProcessor::ProcessUsbSpeedTestCmd ( const char * const paramBegin,
                                                 const uint64_t currentTime )
{
  // Examples about how to automate the speed test from the bash command line:
  //   Tests where the Arduino Due is sending:
  //     echo "UsbSpeedTest TxFastLoopRawUsb" | socat - /dev/debugdue1,b115200,raw,echo=0,crnl | pv -pertb >/dev/null
  //   Tests where the Arduino Due is receiving:
  //     (echo "UsbSpeedTest RxWithCircularBuffer" && yes ".") | pv -pertb - | socat - /dev/debugdue1,b115200,raw,echo=0,crnl >/dev/null

  const uint32_t TEST_TIME_IN_MS = 5000;  // We could make a user parameter out of this value.

  if ( *paramBegin == 0 )
  {
    PrintStr( "Please specify the test type as an argument:" EOL );
    PrintStr( "  TxSimpleWithTimestamps" EOL );
    PrintStr( "  TxSimpleLoop" EOL );
    PrintStr( "  TxFastLoopCircularBuffer" EOL );
    PrintStr( "  TxFastLoopRawUsb" EOL );
    PrintStr( "  RxWithCircularBuffer" EOL );

    return;
  }

  const char * const paramEnd = SkipCharsNotInSet( paramBegin, SPACE_AND_TAB );

  assert( g_usbSpeedTestType == stNone );
  UsbSpeedTestEnum testType = stNone;

  bool extraParamsFound = false;

  if ( IsCmd( paramBegin, paramEnd, "TxSimpleWithTimestamps", false, false, &extraParamsFound ) )
    testType = stTxSimpleWithTimestamps;
  else if ( IsCmd( paramBegin, paramEnd, "TxSimpleLoop", false, false, &extraParamsFound ) )
    testType = stTxSimpleLoop;
  else if ( IsCmd( paramBegin, paramEnd, "TxFastLoopCircularBuffer", false, false, &extraParamsFound ) )
    testType = stTxFastLoopCircularBuffer;
  else if ( IsCmd( paramBegin, paramEnd, "TxFastLoopRawUsb", false, false, &extraParamsFound ) )
    testType = stTxFastLoopRawUsb;
  else if ( IsCmd( paramBegin, paramEnd, "RxWithCircularBuffer", false, false, &extraParamsFound ) )
    testType = stRxWithCircularBuffer;

  if ( testType != stNone )
  {
    for ( size_t i = 0; i < sizeof( g_usbSpeedTestBuffer ); ++i )
      g_usbSpeedTestBuffer[ i ] = '.';

    g_usbSpeedTestEndTime = currentTime + TEST_TIME_IN_MS;
    g_usbSpeedTestType = testType;

    // This message may not make it to the console, depending on the test type.
    PrintStr( "Starting USB speed test..." EOL );

    WakeFromMainLoopSleep();

    return;
  }

  if ( extraParamsFound )
    Printf( "No parameters are allowed after test type \"%.*s\"." EOL, paramEnd - paramBegin, paramBegin );
  else
    Printf( "Unknown test type \"%.*s\"." EOL, paramEnd - paramBegin, paramBegin );
}


void CCommandProcessor::DisplayResetCause ( void )
{
  PrintStr( "Reset cause: " );

  const uint32_t resetCause = rstc_get_reset_cause( RSTC );

  switch ( resetCause )
  {
  case RSTC_GENERAL_RESET:
    PrintStr( "General" );
    break;

  case RSTC_BACKUP_RESET:
    PrintStr( "Backup" );
    break;

  case RSTC_WATCHDOG_RESET:
    PrintStr( "Watchdog" );
    break;

  case RSTC_SOFTWARE_RESET:
    PrintStr( "Software" );
    break;

  case RSTC_USER_RESET:
    PrintStr( "User" );
    break;

  default:
    PrintStr( "<unknown>" );
    assert( false );
    break;
  }

  PrintStr( EOL );
}


void CCommandProcessor::DisplayCpuLoad ( void )
{
  const uint8_t * lastMinute;
        uint8_t   lastMinuteIndex;

  const uint8_t * lastSecond;
        uint8_t   lastSecondIndex;

  GetCpuLoadStats( &lastMinute, &lastMinuteIndex,
                   &lastSecond, &lastSecondIndex );

  uint32_t minuteAverage = 0;

  for ( unsigned j = 0; j < CPU_LOAD_LONG_PERIOD_SLOT_COUNT; ++j )
  {
    const unsigned index = ( lastMinuteIndex + j ) % CPU_LOAD_LONG_PERIOD_SLOT_COUNT;

    minuteAverage += lastMinute[ index ];
  }

  minuteAverage = minuteAverage * 100 / ( CPU_LOAD_LONG_PERIOD_SLOT_COUNT * 255 );
  assert( minuteAverage <= 100 );

  PrintStr( "CPU load in the last 60 seconds (1 second intervals, oldest to newest):" EOL );

  for ( unsigned j = 0; j < CPU_LOAD_LONG_PERIOD_SLOT_COUNT; ++j )
  {
    const unsigned index = ( lastMinuteIndex + j ) % CPU_LOAD_LONG_PERIOD_SLOT_COUNT;

    const uint32_t val = uint32_t( lastMinute[ index ] * 100 / 255 );

    assert( val <= 100 );

    Printf( "%3" PRIu32 " %%" EOL, val );
  }


  uint32_t secondAverage = 0;

  for ( unsigned j = 0; j < CPU_LOAD_SHORT_PERIOD_SLOT_COUNT; ++j )
  {
    const unsigned index = ( lastSecondIndex + j ) % CPU_LOAD_SHORT_PERIOD_SLOT_COUNT;

    secondAverage += lastSecond[ index ];
  }

  secondAverage = secondAverage * 100 / ( CPU_LOAD_SHORT_PERIOD_SLOT_COUNT * 255 );
  assert( secondAverage <= 100 );


  PrintStr( "CPU load in the last second (50 ms intervals, oldest to newest):" EOL );

  for ( unsigned j = 0; j < CPU_LOAD_SHORT_PERIOD_SLOT_COUNT; ++j )
  {
    const unsigned index = ( lastSecondIndex + j ) % CPU_LOAD_SHORT_PERIOD_SLOT_COUNT;

    const uint32_t val = uint32_t( lastSecond[ index ] * 100 / 255 );

    assert( val <= 100 );

    Printf( "%2" PRIu32 " %%" EOL, val );
  }

  Printf( "Average CPU load in the last 60 seconds: %2" PRIu32 " %%" EOL, minuteAverage );
  Printf( "Average CPU load in the last    second : %2" PRIu32 " %%" EOL, secondAverage );
}


void CCommandProcessor::SimulateError ( const char * const paramBegin )
{
  if ( *paramBegin == 0 )
  {
    PrintStr( "Please specify the error type as an argument: 'command' or 'protocol'" EOL );
    return;
  }

  const char * const paramEnd      = SkipCharsNotInSet( paramBegin, SPACE_AND_TAB );
  const char * const extraArgBegin = SkipCharsInSet   ( paramEnd,   SPACE_AND_TAB );

  if ( *extraArgBegin != 0 )
  {
    PrintStr( "Invalid arguments." EOL );
    return;
  }

  if ( DoesStrMatch( paramBegin, paramEnd, "command", false ) )
  {
    throw std::runtime_error( "Simulated command error." );
  }

  if ( DoesStrMatch( paramBegin, paramEnd, "protocol", false ) )
  {
    m_simulateProcolError = true;
    return;
  }

  Printf( "Unknown error type \"%.*s\"." EOL, paramEnd - paramBegin, paramBegin );
}


static const char * const CMDNAME_QUESTION_MARK = "?";
static const char * const CMDNAME_HELP = "help";
static const char * const CMDNAME_I = "i";
static const char * const CMDNAME_USBSPEEDTEST = "UsbSpeedTest";
static const char * const CMDNAME_JTAGPINS = "JtagPins";
static const char * const CMDNAME_JTAGSHIFTSPEEDTEST = "JtagShiftSpeedTest";
static const char * const CMDNAME_MALLOCTEST = "MallocTest";
static const char * const CMDNAME_CPP_EXCEPTION_TEST = "ExceptionTest";
#ifndef NDEBUG
  static const char * const CMDNAME_ASSERT_TEST = "Assert";
#endif
static const char * const CMDNAME_MEMORY_USAGE = "MemoryUsage";
static const char * const CMDNAME_SIMULATE_ERROR = "SimulateError";
static const char * const CMDNAME_RESET = "Reset";
static const char * const CMDNAME_CPU_LOAD = "CpuLoad";
static const char * const CMDNAME_RESET_CAUSE = "ResetCause";
static const char * const CMDNAME_PRINT_MEMORY = "PrintMemory";
static const char * const CMDNAME_BUSY_WAIT = "BusyWait";
static const char * const CMDNAME_UPTIME = "Uptime";


void CCommandProcessor::ParseCommand ( const char * const cmdBegin,
                                       const uint64_t currentTime )
{
  const char * const cmdEnd = SkipCharsNotInSet( cmdBegin, SPACE_AND_TAB );
  assert( cmdBegin != cmdEnd );

  const char * const paramBegin = SkipCharsInSet( cmdEnd, SPACE_AND_TAB );

  bool extraParamsFound = false;

  if ( IsCmd( cmdBegin, cmdEnd, CMDNAME_QUESTION_MARK, true, false, &extraParamsFound ) ||
       IsCmd( cmdBegin, cmdEnd, CMDNAME_HELP, false, false, &extraParamsFound ) )
  {
    PrintStr( "This console is similar to the Bus Pirate console." EOL );
    PrintStr( "Commands longer than 1 character are case insensitive." EOL );
    PrintStr( "WARNING: If a command takes too long to run, the watchdog may reset the board." EOL );
    PrintStr( "Commands are:" EOL );

    Printf( "  %s, %s: Show this help text." EOL, CMDNAME_QUESTION_MARK, CMDNAME_HELP );
    Printf( "  %s: Show version information." EOL, CMDNAME_I );
    Printf( "  %s: Test USB transfer speed." EOL, CMDNAME_USBSPEEDTEST );
    Printf( "  %s: Show JTAG pin status (read as inputs)." EOL, CMDNAME_JTAGPINS );
    Printf( "  %s: Test JTAG shift speed. WARNING: Do NOT connect any JTAG device." EOL, CMDNAME_JTAGSHIFTSPEEDTEST );
    Printf( "  %s: Exercises malloc()." EOL, CMDNAME_MALLOCTEST );
    Printf( "  %s: Exercises C++ exceptions." EOL, CMDNAME_CPP_EXCEPTION_TEST );

    #ifndef NDEBUG
      Printf( "  %s: Triggers an assertion." EOL, CMDNAME_ASSERT_TEST );
    #endif

    Printf( "  %s: Shows memory usage." EOL, CMDNAME_MEMORY_USAGE );
    Printf( "  %s" EOL, CMDNAME_CPU_LOAD );
    Printf( "  %s" EOL, CMDNAME_UPTIME );
    Printf( "  %s" EOL, CMDNAME_RESET );
    Printf( "  %s" EOL, CMDNAME_RESET_CAUSE );
    Printf( "  %s <addr> <byte count>" EOL, CMDNAME_PRINT_MEMORY );
    Printf( "  %s <milliseconds>" EOL, CMDNAME_BUSY_WAIT );
    Printf( "  %s <command|protocol>" EOL, CMDNAME_SIMULATE_ERROR );

    return;
  }

  if ( IsCmd( cmdBegin, cmdEnd, CMDNAME_I, true, false, &extraParamsFound ) )
  {
    #ifndef NDEBUG
      const char buildType[] = "Debug build";
    #else
      const char buildType[] = "Release build";
    #endif

    Printf( "DebugDue %s" EOL, PACKAGE_VERSION );
    Printf( "%s, compiler version %s" EOL, buildType, __VERSION__ );
    Printf( "Watchdog %s" EOL, ENABLE_WDT ? "enabled" : "disabled" );

    return;
  }


  if ( IsCmd( cmdBegin, cmdEnd, CMDNAME_RESET, false, false, &extraParamsFound ) )
  {
    // This message does not reach the other side, we would need to add some delay.
    //   UsbPrint( txBuffer, "Resetting the board..." EOL );
    __disable_irq();
    // Note that this message always goes to the serial port console,
    // even if the user is connected over USB. It might be possible to send
    // it over USB and then wait for the outgoing buffer to be empty.
    SerialSyncWriteStr( "Resetting the board..." EOL );
    SerialWaitForDataSent();
    ResetBoard( ENABLE_WDT );
    assert( false );  // We should never reach this point.
    return;
  }


  if ( IsCmd( cmdBegin, cmdEnd, CMDNAME_CPU_LOAD, false, false, &extraParamsFound ) )
  {
    if ( ENABLE_CPU_SLEEP )
      PrintStr( "CPU load statistics not available." EOL );
    else
      DisplayCpuLoad();

    return;
  }


  if ( IsCmd( cmdBegin, cmdEnd, CMDNAME_UPTIME, false, false, &extraParamsFound ) )
  {
    char buffer[ CONVERT_TO_DEC_BUF_SIZE ];
    Printf( "Uptime: %s seconds." EOL, convert_unsigned_to_dec_th( GetUptime() / 1000, buffer, ',' ) );
    return;
  }


  if ( IsCmd( cmdBegin, cmdEnd, CMDNAME_RESET_CAUSE, false, false, &extraParamsFound ) )
  {
    DisplayResetCause();
    return;
  }


  if ( IsCmd( cmdBegin, cmdEnd, CMDNAME_PRINT_MEMORY, false, true, &extraParamsFound ) )
  {
    PrintMemory( paramBegin );
    return;
  }


  if ( IsCmd( cmdBegin, cmdEnd, CMDNAME_BUSY_WAIT, false, true, &extraParamsFound ) )
  {
    BusyWait( paramBegin );
    return;
  }


  if ( IsCmd( cmdBegin, cmdEnd, CMDNAME_USBSPEEDTEST, false, true, &extraParamsFound ) )
  {
    ProcessUsbSpeedTestCmd( paramBegin, currentTime );
    return;
  }


  if ( IsCmd( cmdBegin, cmdEnd, CMDNAME_JTAGPINS, false, false, &extraParamsFound ) )
  {
    PrintJtagPinStatus();
    return;
  }

  if ( IsCmd( cmdBegin, cmdEnd, CMDNAME_JTAGSHIFTSPEEDTEST, false, false, &extraParamsFound ) )
  {
    if ( !IsNativeUsbPort() )
      throw std::runtime_error( "This command is only available on the 'Native' USB port." );


    // Fill the Rx buffer with some test data.
    assert( m_rxBuffer != nullptr );

    m_rxBuffer->Reset();
    for ( uint32_t i = 0; !m_rxBuffer->IsFull(); ++i )
    {
      m_rxBuffer->WriteElem( CUsbRxBuffer::ElemType( i ) );
    }


    // If the mode is set to MODE_HIZ, you cannot see the generated signal with the oscilloscope.
    // Note also that the built-in pull-ups on the Atmel ATSAM3X8 are too weak (between 50 and 100 KOhm,
    // yields too slow a rising time) to be of any use.

    const bool oldPullUps = GetJtagPullups();
    SetJtagPullups( false );

    const JtagPinModeEnum oldMode = GetJtagPinMode();
    SetJtagPinMode ( MODE_JTAG );


    // Each JTAG transfer needs 2 bits in the Rx buffer, TMS and TDI,
    // but produces only 1 bit, TDO.
    const uint32_t jtagByteCount = m_rxBuffer->GetElemCount() / 2;

    assert( jtagByteCount * 8 < UINT16_MAX * 2 / 3 );  // Early warning against overflow.

    const uint16_t bitCount = uint16_t( jtagByteCount * 8 );

    // Shift all JTAG data through several times.

    const uint64_t startTime = GetUptime();
    const uint32_t iterCount = 50;

    for ( uint32_t i = 0; i < iterCount; ++i )
    {
      // We hope that this will not clear the buffer contents.
      assert( m_rxBuffer != nullptr );
      assert( m_txBuffer != nullptr );

      m_rxBuffer->Reset();
      m_rxBuffer->CommitWrittenElements( jtagByteCount * 2 );

      m_txBuffer->Reset();

      ShiftJtagData( m_rxBuffer,
                     m_txBuffer,
                     bitCount );

      assert( m_txBuffer->GetElemCount() == jtagByteCount );
    }

    const uint64_t finishTime = GetUptime();
    const uint32_t elapsedTime = uint32_t( finishTime - startTime );

    m_rxBuffer->Reset();
    m_txBuffer->Reset();
    const unsigned kBitsPerSec = unsigned( uint64_t(bitCount) * iterCount * 1000 / elapsedTime / 1024 );

    SetJtagPinMode( oldMode );
    SetJtagPullups( oldPullUps );

    // I am getting 221 KiB/s with GCC 4.7.3 and optimisation level "-O3".
    Printf( EOL "Finished JTAG shift speed test, throughput %u Kbits/s (%u KiB/s)." EOL,
            kBitsPerSec, kBitsPerSec / 8 );

    return;
  }


  if ( IsCmd( cmdBegin, cmdEnd, CMDNAME_MALLOCTEST, false, false, &extraParamsFound ) )
  {
    PrintStr( "Allocalling memory..." EOL );

    volatile uint32_t * const volatile mallocTest = (volatile uint32_t *) malloc(123);
    *mallocTest = 123;

    PrintStr( "Releasing memory..." EOL );

    free( const_cast< uint32_t * >( mallocTest ) );

    PrintStr( "Test finished." EOL );

    return;
  }


  if ( IsCmd( cmdBegin, cmdEnd, CMDNAME_CPP_EXCEPTION_TEST, false, false, &extraParamsFound ) )
  {
    try
    {
      PrintStr( "Throwing integer exception..." EOL );
      throw 123;
      PrintStr( "Throw did not work." EOL );
      assert( false );
    }
    catch ( ... )
    {
      PrintStr( "Caught integer exception." EOL );
    }
    PrintStr( "Test finished." EOL );

    return;
  }

  #ifndef NDEBUG
  if ( IsCmd( cmdBegin, cmdEnd, CMDNAME_ASSERT_TEST, false, false, &extraParamsFound ) )
  {
    PrintStr( "Asserting..." EOL );
    assert( false );
    PrintStr( "Assertion finished." EOL );
    return;
  }
  #endif

  if ( IsCmd( cmdBegin, cmdEnd, CMDNAME_SIMULATE_ERROR, false, true, &extraParamsFound ) )
  {
    SimulateError( paramBegin );
    return;
  }


  if ( IsCmd( cmdBegin, cmdEnd, CMDNAME_MEMORY_USAGE, false, false, &extraParamsFound ) )
  {
    const unsigned stackAreaSize = uintptr_t( &__StackTop  ) - uintptr_t( &__StackLimit );
    const unsigned heapAreaSize  = uintptr_t( &__HeapLimit ) - uintptr_t( &__end__      );

    Printf( "Used stack (estimated): %zu from %u bytes." EOL,
             GetStackSizeUsageEstimate(),
             stackAreaSize );

    const struct mallinfo mi = mallinfo();
    const unsigned usedFromArea = unsigned( mi.arena );
    assert ( usedFromArea <= heapAreaSize );

    Printf( "Heap: %zu allocated bytes, %u area size, %u area limit." EOL,
            mi.uordblks,
            usedFromArea,
            heapAreaSize );

    return;
  }

  if ( extraParamsFound )
    Printf( "Command \"%.*s\" does not take any parameters." EOL, cmdEnd - cmdBegin, cmdBegin );
  else
    Printf( "Unknown command \"%.*s\"." EOL, cmdEnd - cmdBegin, cmdBegin );
}


void CCommandProcessor::ProcessCommand ( const char * const cmdStr,
                                         const uint64_t currentTime )
{
  m_simulateProcolError = false;

  try
  {
    const char * const s = SkipCharsInSet( cmdStr, SPACE_AND_TAB );

    if ( *s != 0 )
    {
      ParseCommand( s, currentTime );
    }
  }
  catch ( const std::exception & e )
  {
    Printf( "Error processing command: %s" EOL, e.what() );
  }

  if ( m_simulateProcolError )
  {
    throw std::runtime_error( "Simulated protocol error." );
  }
}


// The Arduino Due has 2 USB ports: the "Native" one and the "Programming" one.

bool CCommandProcessor::IsNativeUsbPort ( void ) const
{
  if ( m_txBuffer == nullptr )
  {
    assert( m_rxBuffer == nullptr );
    return false;
  }
  else
  {
    assert( m_rxBuffer != nullptr );
    return true;
  }
}


void CCommandProcessor::PrintPinStatus ( const char * const pinName,
                                         const Pio * const pioPtr,
                                         const uint8_t pinNumber  // 0-31
                                       )
{
  const char * const status = IsInputPinHigh( pioPtr, pinNumber ) ? "high" : "low ";

  const uint8_t arduinoDuePinNumber = GetArduinoDuePinNumberFromPio( pioPtr, pinNumber );

  Printf( "%s (pin %02u): %s", pinName, unsigned(arduinoDuePinNumber), status );
}


void CCommandProcessor::PrintJtagPinStatus ( void )
{
  PrintStr( "Input status of all JTAG pins:" EOL );

  PrintPinStatus( "TDI  ", JTAG_TDI_PIO, JTAG_TDI_PIN );
  PrintStr( "  |  " );
  PrintPinStatus( "GND2 ", JTAG_GND2_PIO, JTAG_GND2_PIN );

  PrintStr( EOL );

  Printf( "%s (pin %02u): %s", " -   ", unsigned( GetArduinoDuePinNumberFromPio( PIOC, 19 ) ), " -  " );
  PrintStr( "  |  " );
  PrintPinStatus( "nTRST", JTAG_TRST_PIO, JTAG_TRST_PIN );

  PrintStr( EOL );

  PrintPinStatus( "TMS  ", JTAG_TMS_PIO, JTAG_TMS_PIN );
  PrintStr( "  |  " );
  PrintPinStatus( "nSRST", JTAG_SRST_PIO, JTAG_SRST_PIN );

  PrintStr( EOL );

  PrintPinStatus( "TDO  ", JTAG_TDO_PIO, JTAG_TDO_PIN );
  PrintStr( "  |  " );
  PrintPinStatus( "VCC  ", JTAG_VCC_PIO, JTAG_VCC_PIN );

  PrintStr( EOL );

  PrintPinStatus( "TCK  ", JTAG_TCK_PIO, JTAG_TCK_PIN );
  PrintStr( "  |  " );
  PrintPinStatus( "GND1 ", JTAG_GND1_PIO, JTAG_GND1_PIN );

  PrintStr( EOL );
}
