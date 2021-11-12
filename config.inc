;******************************************************************************************
;*   
;*      YMIR
;*           A simple forth         
;*
;*      CONFIGURATION FILE
;* 
;*      Author: Alexander Porter (2021)
;*
;* 
;******************************************************************************************

;; Configuration ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;; Reserved Registers ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;       SP: Return stack pointer
;       Z:  Working Pointer: program memory read/write, indirect execution
        .def            IH = r29        ; Instruction Pointer
        .def            IL = r28
        .def            SH = r27        ; Stack Pointer
        .def            SL = r26 

        .def            ACAH = r25      ; Accumulator A
        .def            ACAL = r24 
        .def            ACBH = r23      ; Accumulator B
        .def            ACBL = r22

;       | compile-flag[7] | branch_offset[6:0] |
        .def            STAH = r21      ; state register
        .def            STAL = r20        

        .def            TOSH = r17      ; Top of Stack Cache
        .def            TOSL = r16 

;       |f_immediate[7] | f_hidden[6] | f_?[5] | Length[4:0] |
;   *** Notice that this means a max word-name-length of 31 chars. ***
        .def            WCH  = r13      ; current word cache (contains length/flag)
        .def            WCL  = r12

        .def            zero = r10      ; constant Zero
        .def            one  = r11      ; constant One

;; Constants ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;       Word header flags 
        .equ    f_immediate     = 0x80
        .equ    f_hidden        = 0x40
        .equ    f_data          = 0x20

;       defaults
        .equ        clock_freq  =  0x01     ; clock prescalar of 2 (8MHz clk_per)
        .equ        baud_def    =  115200   ; default baud rate 
        .equ        usart_mux   =  0x44     ; Map USART3 to USB and USART1 to TX/RX pins
        .equ        base_def    =  0xA      ; Decimal

;       default actor configuration
        .equ        op_p_size   = 0x0028    ; default stack size 40 b (20 items)
        .equ        op_r_size   = 0x0100
        .equ        op_tib_size = 0x0200    ; tib size (512 b)
        .equ        op_pad_size = 0x0100    ; pad size (256 b)
        .equ        op_rxd      = USART3_RXDATAL
        .equ        op_rxw      = USART3_STATUS
        .equ        op_txd      = USART3_TXDATAL
        .equ        op_txw      = USART3_STATUS

;;  IO Registers ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        .equ        reset_r         = GPIO_GPIOR0       ; reset debug info

        .equ        base_r          = GPIO_GPIOR1       ; current base

; memory detail: 
; 0b[7:3] | flash | eeprom | ram |
        .equ        mem_target      = GPIO_GPIOR2       

;      | signed[7] (default=true/set) | base-literal-flag[6] | 0b | padding [4:0] |
        .equ        num_format      = GPIO_GPIOR3       ; number fmt register

;; Ram layout ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; | sys vars 32b | word buffer 32b | pad | tib | p stack |
        .equ    sysram_end = SRAM_START + ram_link + 32
        .equ    def_tib_start = sysram_end + op_pad_size
        .equ    def_p_start  = def_tib_start + op_tib_size
