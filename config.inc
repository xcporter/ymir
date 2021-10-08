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

; memory detail: 
; 0b01 = sram
; 0b10 = eeprom
; 0b11 = flash
;       | sign-flag[7] | memory-flag[6:5] | 0b | 0b | 0b | 0b | compile-flag[0] |
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
        .equ    f_immediate = 0x80
        .equ    f_hidden = 0x40
        ; .equ    f_in_ram = 0x20

;       defaults
        .equ        clock_freq  =  0x01     ; clock prescalar of 2 (8MHz clk_per)
        .equ        baud_def    =  115200   ; default baud rate 
        .equ        usart_mux   =  0x44     ; Map USART3 to USB and USART1 to TX/RX pins
        .equ        base_def    =  0xA      ; Decimal

;       default actor configuration
        .equ        op_p_size   = 0x0028    ; default stack size 40 b (20 items)
        .equ        op_tib_size = 0x0100    ; tib size (256 b)
        .equ        op_pad_size = 0x0100    ; pad size (256 b)
        .equ        op_rxd      = USART3_RXDATAL
        .equ        op_rxw      = USART3_STATUS
        .equ        op_txd      = USART3_TXDATAL
        .equ        op_txw      = USART3_STATUS


;; RAM layout: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;| &active block | active block | word buffer  | actor workspace | return stack |
;|       2 b     |    1024 b    |     32 b     |     <4430 b     |    ~(512 b)  |
;| SRAM_START----->

        .equ        active_block_start = SRAM_START + 0x02
        .equ        word_buffer_start = active_block_start + 0x400
        .equ        actor_ws_start = word_buffer_start + 0x20

;;  IO Registers ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        .equ        reset_r         = GPIO_GPIOR0       ; reset debug info

        .equ        base_r          = GPIO_GPIOR1       ; current base

        .equ        coroutine_pt    = GPIO_GPIOR2       ; current actor

;      | signed[7] (default=true/set) | base-literal-flag[6] | 0b | padding [4:0] |
        .equ        num_format      = GPIO_GPIOR3       ; number fmt register

