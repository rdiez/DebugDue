
#pragma once


bool IsJtagTdoPullUpActive ( void ) throw();

void InitDebugConsoleUart ( bool enableRxInterrupt ) throw();

void PrintPanicMsg ( const char * const msg ) throw();

void StartUpChecks ( void ) throw();
