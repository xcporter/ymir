;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> SYSDEF
;*
;*      Words for accessing system addresses and constants
;*
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************

;; System State ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
def_asm         "?state", 6, 0, get_state
        movw    TOSL, STAL 
        push_tos
        jmp     next 

def_asm         ">state", 6, 0, set_state
        sbiw    SL, 0x02
        movw    STAL, TOSL
        cache_tos
        jmp     next 

def_asm         "?reset", 6, 0, get_reset
        in      TOSL, GPIO_GPIOR0
        clr     TOSH
        ppush   TOSL
        jmp     next 

def_asm         "&p", 2, 0, p_pt 
        movw    TOSL, SL
        push_tos
        jmp     next 

def_asm         "&p!", 3, 0, p_pt_set
        movw    SL, TOSL
        cache_tos
        jmp     next 

def_asm         "&r", 2, 0, r_pt 
        in      TOSL, CPU_SPL
        in      TOSH, CPU_SPH
        push_tos
        jmp     next

def_asm         "&r!", 3, 0, r_pt_set
        sbiw    SL, 0x02
        out     CPU_SPL, TOSL
        out     CPU_SPH, TOSH
        cache_tos
        jmp     next

; System vars (ram) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

def_ram         ":lexicon", 8, lexicon_v
def_ram         "&ram", 4, ram_here
def_ram         "^r", 2, r_start
def_ram         "$r", 2, r_max_size
def_ram         "^p", 2, p_start
def_ram         "$p", 2, p_max_size 
def_ram         "^pad", 4, pad_start
def_ram         "$pad", 4, pad_size
def_ram         "^tib", 4, tib_start
def_ram         "$tib", 4, tib_size
def_ram         ":rxw", 4, rx_wait_v
def_ram         ":rxd", 4, rx_data_v
def_ram         ":txw", 4, tx_wait_v
def_ram         ":txd", 4, tx_data_v

def_ram         ">in", 3, parse_offset

def_const       "^word", 5, word_buffer, sysram_end


;; default configuration/memory layout ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
def_var         "sram.init", 9, sram_init 
        .dw     def_p_start + op_p_size      ; ram$              
        .dw     RAMEND                       ; ^r
        .dw     op_r_size                    ; $r 
        .dw     def_p_start                  ; ^p
        .dw     op_p_size                    ; $p
        .dw     sysram_end                   ; ^pad
        .dw     op_pad_size                  ; $pad
        .dw     def_tib_start                ; ^tib
        .dw     op_tib_size                  ; $tib
        .dw     USART3_STATUS                ; :rxw
        .dw     USART3_RXDATAL               ; :rxd
        .dw     USART3_STATUS                ; :txw
        .dw     USART3_TXDATAL               ; :txd
        


; System vars (eeprom) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; value in eeprom is set at the end of the dictionary
; core/latest has to wait until all the words are added 
def_const       ":core", 5, core_v
        .dw     EEPROM_START


; Init vector-- defines word to boot from
def_eep         ":init", 5, init_v, sys_init

def_eep         "prg$", 4, prog_here_v, flash_here

def_eep         "eep$", 4, eep_here_v, eep_here 
def_eep         ":base", 5, base_default, 0x000a  ; default base 10

; Message constants ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

def_str         "$ok", 3, ok_msg, " ok", 3
def_str         "$unsyn", 6, unsyn_msg, " syntax error", 13
def_str         "$under", 6, under_msg, " stack underflow", 16
def_str         "$over", 5, over_msg, " stack overflow", 15
def_str         "$bover", 6, bover_msg, " buffer overflow", 16