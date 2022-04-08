
// Copyright (C) 2012 R. Diez
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the Affero GNU General Public License version 3
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// Affero GNU General Public License version 3 for more details.
//
// You should have received a copy of the Affero GNU General Public License version 3
// along with this program. If not, see http://www.gnu.org/licenses/ .


#include "UsbSupport.h"  // The include file for this module should come first.

#include <string.h>
#include <assert.h>
#include <inttypes.h>

#include <udc.h>
#include <udd.h>
#include <udi_cdc.h>

#include <BareMetalSupport/MainLoopSleep.h>
#include <BareMetalSupport/SerialPrint.h>
#include <Misc/AssertionUtils.h>

#include "my_usb_callbacks.h"

#include "Globals.h"


void InitUsb ( void )
{
  udc_start();
}

static const bool TRACE_USB_CONNECTION_NOTIFICATIONS = false;

static const uint8_t USB_CALLBACK_PORT_NUMBER = 0;


static volatile bool s_isUsbCableConnected   = false;
static volatile bool s_isCdcInterfaceEnabled = false;  // Note that this interface remains enabled even if the cable is pulled.
static volatile bool s_isChannelOpen         = false;


void MyUsbCallback_udc_resume ( void )
{
  // Sometimes, when you connect the cable, you get a first resume/suspend notification pair,
  // and then a second, stable resume notification.

  if ( TRACE_USB_CONNECTION_NOTIFICATIONS )
    SerialPrintStr( "MyUsbCallback_udc_resume()" EOL );

  assert( !s_isUsbCableConnected );
  s_isUsbCableConnected = true;
}


void MyUsbCallback_udc_suspend ( void )
{
  if ( TRACE_USB_CONNECTION_NOTIFICATIONS )
    SerialPrintStr( "MyUsbCallback_udc_suspend()" EOL );

  // This routine is always called once at the beginning, therefore we cannot assert this here:
  //   ASSERT( s_isUsbCableConnected );

  s_isUsbCableConnected = false;
  WakeFromMainLoopSleep();  // Notify the main loop if we loose the USB connection.
}


// The USB Host has enabled the CDC interface. Note that the interface remains logically enabled
// even if the user pulls the USB cable.

bool MyUsbCallback_cdc_enable ( const uint8_t port )
{
  if ( TRACE_USB_CONNECTION_NOTIFICATIONS )
    SerialPrintStr( "MyUsbCallback_cdc_enable()" EOL );

  assert( port == USB_CALLBACK_PORT_NUMBER );
  UNUSED_IN_RELEASE( port );

  assert( s_isUsbCableConnected );
  assert( !s_isCdcInterfaceEnabled );

  s_isCdcInterfaceEnabled = true;

  return true;  // Indicate success.
}

void MyUsbCallback_cdc_disable ( const uint8_t port )
{
  if ( TRACE_USB_CONNECTION_NOTIFICATIONS )
    SerialPrintStr( "MyUsbCallback_cdc_disable()" EOL );

  assert( port == USB_CALLBACK_PORT_NUMBER );
  UNUSED_IN_RELEASE( port );

  assert( s_isUsbCableConnected );
  assert( s_isCdcInterfaceEnabled );
  s_isCdcInterfaceEnabled = false;

  WakeFromMainLoopSleep();  // Notify the main loop if we loose the USB connection.
}


void MyUsbCallback_cdc_set_dtr ( const uint8_t port, const bool enable )
{
  if ( TRACE_USB_CONNECTION_NOTIFICATIONS )
  {
    SerialPrintf( "MyUsbCallback_cdc_set_dtr( %s )" EOL,
                  enable ? "enable" : "disable" );
  }

  assert( port == USB_CALLBACK_PORT_NUMBER );
  UNUSED_IN_RELEASE( port );

  assert( s_isUsbCableConnected );
  assert( s_isCdcInterfaceEnabled );


  // If the user pulls the USB cable, we don't get this notification. When the USB cable
  // is connected again, we'll get a first notification here that the channel is closed.
  //
  // Under Windows, if you connect with Cygwin socat, you get several notifications in a row
  // that the channel is open.

  s_isChannelOpen = enable;

  WakeFromMainLoopSleep();
}


void MyUsbCallback_cdc_rx_notify ( const uint8_t port )
{
  if ( false )
    SerialPrintStr( "MyUsbCallback_cdc_rx_notify()" EOL );

  // Print the received packet size (not quite reliable), for performance research purposes only:
  if ( false )
  {
    const uint32_t v = udi_cdc_get_nb_received_data();
    SerialPrintf( "%" PRIu32 EOL, v );
  }

  assert( port == USB_CALLBACK_PORT_NUMBER );
  UNUSED_IN_RELEASE( port );

  // This can trigger if the caller closes the connection quickly.
  //   ASSERT( IsUsbConnectionOpen() );

  WakeFromMainLoopSleep();
}


void MyUsbCallback_cdc_tx_empty_notify ( const uint8_t port )
{
  if ( false )
    SerialPrintStr( "MyUsbCallback_cdc_tx_empty_notify()" EOL );

  assert( port == USB_CALLBACK_PORT_NUMBER );
  UNUSED_IN_RELEASE( port );

  // This can trigger if the caller closes the connection quickly.
  //   ASSERT( IsUsbConnectionOpen() );

  WakeFromMainLoopSleep();
}


void MyUsbCallback_cdc_set_coding ( const uint8_t port, usb_cdc_line_coding_t * const cfg )
{
  if ( false )
    SerialPrintStr( "MyUsbCallback_cdc_set_coding()" EOL );

  assert( port == USB_CALLBACK_PORT_NUMBER );
  UNUSED_IN_RELEASE( port );

  assert( s_isUsbCableConnected );

  // cfg->bCharFormat can be CDC_STOP_BITS_2, US_MR_NBSTOP_1_5_BIT or US_MR_NBSTOP_1_BIT.
  // cfg->bParityType can be US_MR_PAR_EVEN, CDC_PAR_ODD, CDC_PAR_MARK, US_MR_PAR_SPACE or US_MR_PAR_NO.
  // cfg->bDataBits can be 5, 6, 7 or 8.

  // We don't actually need the encoding information here.
  UNUSED_ALWAYS( cfg );
}


bool IsUsbConnectionOpen ( void )
{
  return s_isUsbCableConnected &&
         s_isCdcInterfaceEnabled &&
         s_isChannelOpen;
}


static void UsbWriteLoop ( const void * const buf, const size_t byteCount )
{
  STATIC_ASSERT( sizeof( iram_size_t ) == sizeof( byteCount ), "Size mismatch." );

  const uint8_t * currPos = (const uint8_t *) buf;
  size_t byteCountLeft = byteCount;

  while ( byteCountLeft > 0 )
  {
    const size_t remainingCount = udi_cdc_write_buf( currPos, byteCountLeft );

    assert( remainingCount <= byteCountLeft );

    const size_t writtenCount = byteCountLeft - remainingCount;

    byteCountLeft -= writtenCount;
    currPos += writtenCount;
  }
}


void UsbWriteData ( const void * const data, const size_t dataLen )
{
  UsbWriteLoop( data, dataLen );
}

void UsbWriteStr ( const char * const str )
{
  // This assert triggers too easily when the user pulls the USB cable.
  //   ASSERT( IsUsbConnectionOpen() );

  UsbWriteLoop( str, strlen( str ) );
}


void DiscardAllUsbData ( void )
{
  // A possible optimisation would be to read the data in chunks here.
  while ( udi_cdc_is_rx_ready() )
  {
    udi_cdc_getc();
  }
}
