// Include this header file only once.
#ifndef MY_USB_CALLBACKS_H_INCLUDED
#define MY_USB_CALLBACKS_H_INCLUDED

// This file is included from Atmel library C source, therefore all routines here must be extern "C".
// The "My" prefix is designed to avoid collisions with any Atmel-defined routines.

#ifdef __cplusplus
extern "C"
{
#endif

void MyUsbCallback_udc_resume  ( void );
void MyUsbCallback_udc_suspend ( void );

// 'sof' means "start of frame", one of them is received each 1 ms.
//   void MyUsbCallback_udc_sof ( void );

bool MyUsbCallback_cdc_enable  ( uint8_t port );
void MyUsbCallback_cdc_disable ( uint8_t port );
  
void MyUsbCallback_cdc_set_coding      ( uint8_t port, usb_cdc_line_coding_t * cfg );
void MyUsbCallback_cdc_set_dtr         ( uint8_t port, bool b_enable );
void MyUsbCallback_cdc_rx_notify       ( uint8_t port );
void MyUsbCallback_cdc_tx_empty_notify ( uint8_t port );


#ifdef __cplusplus
}
#endif

#endif  // Include this header file only once.
