;******************************************************************************************
;*   
;*      USB serial library for arduino nano every
;*      uses UART3 at baud rate of 115200 (configurable)
;* 
;*      Add setup macro between initializing stack pointer and doing work:
;*              setup_usb
;*
;*      Must include these lines at the bottom (add wait subroutines):
;*              usb_rx_wait: usb_rx_wait
;*              usb_tx_wait: usb_tx_wait
;*
;*      main macros take subroutine to 
;*           a) before each read/write--check end condition for breq or $0 for loop
;*           b) do on each read/write--load next into r16 (can also be a.))
;*           c) do after all--cleanup task
;*
;*      Usage example:
;*          rx:     using_usb_rx       check_cr, write_mem, null_terminate_mem
;*          tx:     using_usb_tx       read_mem, $0, transmit_cr (read mem is loading next into r16, so b) isn't needed)
;* 
;*      Author: Alexander Porter (2021)
;* 
;******************************************************************************************

;;  USART settings
        .equ        usb_baud = 115200
        .equ        usb_ctlA = 0x00         ; no interrupts
        .equ        usb_ctlB = 0b11001000   ; enable tx / rx,  open drain, mode: normal, no multiprocessor
        .equ        usb_ctlC = 0b00100011   ; async, even parity, 1 stop bit, 8 bit char size

        .equ        usb_txdir = 0x10        ; set tx to out
        .equ        usb_txctl = 0x08        ; pullup resistor active

        .equ        usb_rxdir = 0x20

        .equ        usb_usart_mux = 0x44    ; connect USART3 to the other uC, and USART1 to the pinout tx/rx

.macro set_usb_baud                             
        .equ        baud_fractional = (8000000*64)/(@0*16)
        ldi         r16, Low(baud_fractional)
        ldi         r17, High(baud_fractional)
        sts         USART3_BAUDL, r16           
        sts         USART3_BAUDH, r17
.endmacro

.macro  setup_usb
    ;; Setup clock prescalar
        ldi     r17, 0x01                   ; clock prescalar of 2 (8MHz clk_per)
        ldi     r16, CPU_CCP_IOREG_gc       ; load io reg signature
        out     CPU_CCP, r16                ; Protected write engage! you have 4 cycles to do your thing   
        sts     CLKCTRL_MCLKCTRLB, r17      ; write prescalar
    ;; Setup usart
        set_usb_baud    usb_baud

        ldi     r16, usb_ctlA                   ; set control A
        sts     USART3_CTRLA, r16           

        ldi     r16, usb_ctlB                   ; set control B
        sts     USART3_CTRLB, r16           

        ldi     r16, usb_ctlC                   ; set control C
        sts     USART3_CTRLC, r16           

        ldi     r16, usb_usart_mux              ; route usart to proper ports 
        sts     PORTMUX_USARTROUTEA, r16

        ldi     r16, usb_txdir                  ; set tx pin direction
        sts     PORTB_DIRSET, r16

        ldi     r16, usb_rxdir                  ; set rx pin direction
        sts     PORTB_DIRCLR, r16

        ldi     r16, usb_txctl                  ; set pullup resistor
        sts     PORTB_PIN4CTRL, r16 
        sts     PORTB_PIN5CTRL, r16 
.endmacro

;;  ending condition (set zero flag), recieve callback, end callback or $0
.macro  using_usb_rx
    usb_rx_%:
        call    usb_rx_wait 
        .if @0!=$0
            call    @0
        .endif
        breq    usb_rx_end_%                    ; return if null

    usb_rx_do_%:
        .if @1!=$0
            call    @1
        .endif
        rjmp    usb_rx_%

    usb_rx_end_%:
        .if @2!=$0
            call    @2
        .endif
        ret
.endmacro


;;  ending condition (set zero flag), do callback (load next into r16), end callback
.macro using_usb_tx
    usb_tx_%:     
        call    usb_tx_wait
        .if @0!=$0
            call    @0
        .endif
        breq    usb_tx_end_%                    ; return if null

    usb_tx_do_%:
        .if @1!=$0
            call    @1
        .endif
        sts     USART3_TXDATAL, r16             ; send whatever is in r16
        rjmp    usb_tx_%

    usb_tx_end_%:
        .if @2!=$0
            call    @2
        .endif
        ret
.endmacro

.macro  usb_tx_wait
        lds     r17, USART3_STATUS              ; load uart status
        sbrs    r17, 5                          ; check if empty
        rjmp    usb_tx_wait                     ; loop if not
        ret
.endmacro

.macro  usb_rx_wait
        lds     r17, USART3_STATUS              ; load uart status
        sbrs    r17, 7                          ; check if empty
        rjmp    usb_rx_wait                     ; loop if not
        ret
.endmacro

.macro usb_tx_immediate
        rcall   usb_tx_wait
        sts     USART3_TXDATAL, @0
.endmacro


    