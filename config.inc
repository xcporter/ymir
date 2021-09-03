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


;       defaults
        .equ        clock_freq  =  0x01     ; clock prescalar of 2 (8MHz clk_per)
        .equ        baud        =  115200   ; default baud rate 
        .equ        usart_mux   =  0x44     ; Map USART3 to USB and USART1 to TX/RX pins
        .equ        base        =  0xA      ; Decimal


;       RAM layout:
;       :| System | Buffer | P stack >|< Ram Dictionary |< R stack |:

        .equ        buffer_start = INTERNAL_SRAM_START + 0xFF   ; 256 bytes for System (same as eeprom)
        .equ        buffer_size = 0x7D0                         ; 2K bytes for buffer
        .equ        r_stack_max = 0x200                         ; 512 bytes; 128 addrs
        .equ        p_stack_max = 0x200                         ; 512 bytes; 128 params
;       Remaining space goes to Ram Dictionary                  2720 bytes

;       System memory:
;       Defaults stored in eeprom, loaded into ram at runtime
;

;       ...
;       TODO: Timer registers, SPI, 2 wire, tasks, interrupts

;       Addresses for Latest pointers. v (volitile) = sram, p (persistent) = eeprom
        .equ        latest_sram_v = INTERNAL_SRAM_START
        .equ        latest_sram_p = EEPROM_START
        .equ        latest_prog_v = INTERNAL_SRAM_START + 0x4
        ; .equ        latest_prog_p = prog_end + 0x4

        .equ        spl = CPU_SPL
        .equ        sph = CPU_SPH