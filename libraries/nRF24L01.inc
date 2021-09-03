;******************************************************************************************
;*   
;*      Device library for nRF24L01 to be used with arduino nano every
;*      requires m4809def.inc to be available (preferably at highest level of project)
;*
;*      Must include these lines at the bottom (add wait subroutines):
;*              spi_rx_wait: spi_rx_wait
;*              spi_tx_wait: spi_tx_wait
;*
;*      set to pins PE[0:3]--can be adjusted in portmux.
;*      as it is currently set:
;*      PE0 (D11) -- MOSI
;*      PE1 (D12) -- MISO
;*      PE2 (D13) -- SCK 
;*      PE3 (D8) -- CSN 
;*      PB1 (D10) -- CE (Active high)
;*      PB0 (D9) -- IRQ (Active low)
;*
;*      Author: Alexander Porter (2021)
;*
;******************************************************************************************


;;  SPI settings
        .equ        rf_ctlA = 0b00100011       ; msb, master, prescalar 16 (500 kHz), enable
        .equ        rf_ctlB = 0b11000100       ; buffer, no wait, ss disable, mode 0

        .equ        rf_usart_mux = 0x44        ; connect USART3 to the other uC, and USART1 to the pinout tx/rx
        .equ        rf_spi_mux = 0x02          ; connect SPI to pins PE[0:3]

;;  commands
        .equ        R_REGISTER              = 0b00000000    ; [0:4] are for address
        .equ        W_REGISTER              = 0b00100000    ; [0:4] are for address
        .equ        R_RX_PAYLOAD            = 0b01100001
        .equ        W_TX_PAYLOAD            = 0b10100000
        .equ        FLUSH_TX                = 0b11100001
        .equ        FLUSH_RX                = 0b11100010
        .equ        REUSE_TX_PL             = 0b11100011
        .equ        R_RX_PL_WID             = 0b01100000
        .equ        W_ACK_PAYLOAD           = 0b10101000    ; [0:2] are for pipe
        .equ        W_TX_PAYLOAD_NO_ACK     = 0b10110000
        .equ        NOP                     = 0b11111111

.macro start_cmd                             ; set CSN low
        ldi     r17, 0x08
        sts     PORTE_OUTCLR, r17
.endmacro

.macro end_cmd                               ; set CSN high
        ldi     r17, 0x08
        sts     PORTE_OUTSET, r17
.endmacro

;;      put address in r16, include callback or $0
;;              for callback, result will be in r19
.macro rf_read_reg
        ldi     r18, R_REGISTER 
        or      r18, r16                     ; add address to command word
        start_cmd
                call    spi_tx_wait          ; send command word to spi bus when available for write
                sts     SPI0_DATA, r18
        
                call    spi_rx_wait
                lds     r19, SPI0_DATA
                call    spi_rx_wait
                lds     r19, SPI0_DATA
                .if @0!=$0
                        call    @0
                .endif
        end_cmd
.endmacro

.macro setup_rf_spi
;;      setup clock
        ldi     r17, 0x01                   ; clock prescalar of 2 (clk_per = 8MHz)
        ldi     r16, CPU_CCP_IOREG_gc       ; load io reg signature
        out     CPU_CCP, r16                ; Protected write engage! you have 4 cycles to do your thing   
        sts     CLKCTRL_MCLKCTRLB, r17      ; write prescalar

;;      setup serial bus
        ldi     r16, rf_usart_mux              ; route usart to proper ports 
        sts     PORTMUX_USARTROUTEA, r16

        ldi     r16, rf_spi_mux                ; route spi to port E
        sts     PORTMUX_TWISPIROUTEA, r16

        ldi     r16, rf_ctlA                   ; set control A
        sts     SPI0_CTRLA, r16           

        ldi     r16, rf_ctlB                   ; set control B
        sts     SPI0_CTRLB, r16                   

;*      PE0 (D11) -- MOSI
;*      PE1 (D12) -- MISO
;*      PE2 (D13) -- SCK 
;*      PE3 (D8) -- CSN 
;*      PB1 (D10) -- CE (Active high)
;*      PB0 (D9) -- IRQ (Active low)

        ldi     r16, 0x0D 
        sts     PORTE_DIRSET, r16           ; set pin direction port E
        ldi     r16, 0x02
        sts     PORTE_DIRCLR, r16           ; set pin direction port E
        sts     PORTB_DIRSET, r16           ; set pin direction port B

        ldi     r16, 0x08                   ; pullupctl                 
        
        sts     PORTE_PIN0CTRL, r16         ; set pullup resistor
        sts     PORTE_PIN1CTRL, r16
        sts     PORTE_PIN3CTRL, r16
        sts     PORTB_PIN1CTRL, r16

        sts     PORTE_OUTSET, r16           ; CSN set high


.endmacro

.macro  spi_tx_wait
        lds     r17, SPI0_INTFLAGS              ; load uart status
        sbrs    r17, 5                          ; return when available for write
        rjmp    spi_tx_wait                     ; loop if not
        ret
.endmacro

.macro  spi_rx_wait
        lds     r17, SPI0_INTFLAGS              ; load uart status
        sbrs    r17, 7                          ; return when available for write
        rjmp    spi_tx_wait                     ; loop if not
        ret
.endmacro

;;      include callback or $0
.macro  spi_rx_all
        call    spi_rx_wait                     ; wait for read available
spi_rx_all_do_%:
        lds     r17, SPI0_INTFLAGS              ; load uart status
        andi    r17, 0x80                       ; mask only read available
        cpi     r17, 0x80                       ; check read available
        brne    spi_rx_all_end_%                ; return when not available
        .if @0!=$0                              ; do call back
                call    @0
        .endif
        rjmp    spi_rx_all_do_%
        
spi_rx_all_end_%:
        ret
.endmacro



