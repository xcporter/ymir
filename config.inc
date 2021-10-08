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
;       State: | negative | memory[6:5] | 0b | 0b | 0b | 0b | compile |
;       Memory detail: 0b01 = sram, 0b10 = eeprom, 0b11 = flash
        .def            STAH = r21      ; state register
        .def            STAL = r20        
        
  

        .def            TOSH = r17      ; Top of Stack Cache
        .def            TOSL = r16 
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

;;  IO Registers ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        .equ        reset_r         = GPIO_GPIOR0

        .equ        base_r          = GPIO_GPIOR1

        .equ        coroutine_pt    = GPIO_GPIOR2

;       Number format: | sign [default true] | base literal | 0b | padding [5:0] |
        .equ        num_format      = GPIO_GPIOR3 


;; RAM layout: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;       | &active block | active block | word buffer  | actor workspace | return stack |
;       |       2 b     |    1024 b    |     32 b     |     <4430 b     |    ~(512 b)  |
;       | SRAM_START----->

        .equ        active_block_start = SRAM_START + 0x02
        .equ        word_buffer_start = active_block_start + 0x400
        .equ        actor_ws_start = word_buffer_start + 0x20

