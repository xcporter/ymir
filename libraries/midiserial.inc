;******************************************************************************************
;*   
;*      MIDI serial library for arduino nano every
;*      uses UART1 (PC[4:5]) at baud rate of 31250
;* 
;*      Add setup macro between initializing stack pointer and doing work:
;*              setup_midi
;*
;*      Must include these lines at the bottom (add wait subroutines):
;*              midi_rx_wait: midi_rx_wait
;*              midi_tx_wait: midi_tx_wait
;*
;*      main macros take subroutine to 
;*           a) before each read/write--check end condition for breq or $0 for loop
;*           b) do on each read/write--load next into r16 (can also be a.))
;*           c) do after all--cleanup task
;*
;*      Usage example:
;*          rx:     using_midi_rx       check_cr, write_mem, null_terminate_mem
;*          tx:     using_midi_tx       read_mem, $0, transmit_cr (read mem is loading next into r16, so b) isn't needed)
;* 
;*      Author: Alexander Porter (2021)
;* 
;******************************************************************************************

;;  USART settings
        .equ        baud = 128          ; fractional value for register
        .equ        ctlA = 0x00         ; no interrupts
        .equ        ctlB = 0b11001000   ; enable tx / rx,  open drain, mode: normal, no multiprocessor
        .equ        ctlC = 0b00000011   ; async, no parity, 1 stop bit, 8 bit char size

        .equ        txdir = 0x10        ; set tx to out
        .equ        txctl = 0x08        ; pullup resistor active

        .equ        rxdir = 0x20

        .equ        usart_mux = 0x44    ; connect USART3 to the other uC, and USART1 to the pinout tx/rx


.macro  setup_midi
    ;; Setup clock prescalar
        ldi     r17, 0x07                   ; clock prescalar of 16 (clk_per = 1mhz)
        ldi     r16, CPU_CCP_IOREG_gc       ; load io reg signature
        out     CPU_CCP, r16                ; Protected write engage! you have 4 cycles to do your thing   
        sts     CLKCTRL_MCLKCTRLB, r17      ; write prescalar
    ;; Setup usart
        ldi     r16, Low(baud)              ; set baud rate 
        ldi     r17, High(baud)
        sts     USART1_BAUDL, r16           
        sts     USART1_BAUDH, r17

        ldi     r16, ctlA                   ; set control A
        sts     USART1_CTRLA, r16           

        ldi     r16, ctlB                   ; set control B
        sts     USART1_CTRLB, r16           

        ldi     r16, ctlC                   ; set control C
        sts     USART1_CTRLC, r16           

        ldi     r16, usart_mux              ; route usart to proper ports 
        sts     PORTMUX_USARTROUTEA, r16

        ldi     r16, txdir                  ; set tx pin direction
        sts     PORTB_DIRSET, r16

        ldi     r16, rxdir                  ; set rx pin direction
        sts     PORTB_DIRCLR, r16

        ldi     r16, txctl                  ; set pullup resistor
        sts     PORTC_PIN4CTRL, r16 
        sts     PORTC_PIN5CTRL, r16 
.endmacro

;;  ending condition (set zero flag), recieve callback, end callback or $0
.macro  using_midi_rx
    midi_rx_%:
        call    midi_rx_wait 
        .if @0!=$0
            call    @0
        .endif
        breq    midi_rx_end_%                    ; return if null

    midi_rx_do_%:
        .if @1!=$0
            call    @1
        .endif
        rjmp    midi_rx_%

    midi_rx_end_%:
        .if @2!=$0
            call @2
        .endif
        ret
.endmacro


;;  ending condition (set zero flag), do callback (load next into r16), end callback
.macro using_midi_tx
    midi_tx_%:     
        call    midi_tx_wait
        .if @0!=$0
            call    @0
        .endif
        breq    midi_tx_end_%                    ; return if null

    midi_tx_do_%:
        .if @1!=$0
            call    @1
        .endif
        sts     USART1_TXDATAL, r16             ; send whatever is in r16
        rjmp    midi_tx_%

    midi_tx_end_%:
        .if @2!=$0
            call    @2
        .endif
        ret
.endmacro

.macro  midi_tx_wait
        lds     r17, USART1_STATUS              ; load uart status
        sbrs    r17, 5                          ; check if empty
        rjmp    midi_tx_wait                     ; loop if not
        ret
.endmacro

.macro  midi_rx_wait
        lds     r17, USART1_STATUS              ; load uart status
        sbrs    r17, 7                          ; check if empty
        rjmp    midi_rx_wait                     ; loop if not
        ret
.endmacro