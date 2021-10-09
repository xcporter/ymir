;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> SYSDEF
;*
;*      Words for accessing system addresses related to the forth kernel
;*
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************

eep_const       "#latest", 7, latest, EEPROM_START
eep_const       "#init", 5, init_vector, init
eep_const       "#start", 6, start_vector, start
eep_const       "base.default", 12, base_default, base_def
const           "base", 4, base, base_r
eep_const       "here.pg", 7, here_pg, flash_here 
eep_const       "here.eep", 8, eep_here, eep_here_pt
const           "word.buffer", 11, word_buffer, word_buffer_start
eep_const       "#rx.data", 8, rx_d_vect, USART3_RXDATAL
eep_const       "#rx.wait", 8, rx_wait_vect, USART3_STATUS  
eep_const       "#tx.data", 8, tx_d_vect, USART3_TXDATAL
eep_const       "#tx.wait", 8, tx_wait_vect, USART3_STATUS

; default operator is actor0
const_data       "actor0", 6, actor_zero        
        .dw     op_p_size
        .dw     op_tib_size
        .dw     op_pad_size
        .dw     op_rxd
        .dw     op_rxw
        .dw     op_txd
        .dw     op_txw

; start of actor area (contains link to next actor if present)
eep_const       "#operator", 8, operator_vect, actor_ws_start

eep_const       "#p0", 3, p_zero_vect, actor_ws_start + 0x06 ; skip actor link, task addr, and stack pointer storage

eep_const       "#tib", 4, tib_vector, 0x0000
eep_const       "#pad", 4, pad_vector, 0x0000

;   (#active-block)
const           "block", 5, block_start, SRAM_START + 0x02
const           "&block", 6, block_pt, SRAM_START
const           "r0", 2, r_zero, SRAM_START + SRAM_SIZE

def_word        "p0", 2, 0, p_zero
        .dw     p_zero_vect
        .dw     fetch 
        .dw     done

def_asm         "&r", 2, 0, r_stack_pt
        in      TOSL, CPU_SPL
        in      TOSH, CPU_SPL
        push_tos
        jmp     next

def_asm         "&p", 2, 0, p_stack_pt
        movw    TOSL, SL
        push_tos
        jmp     next

def_asm         ":state", 6, 0, get_state
        movw    TOSL, STAL 
        push_tos
        jmp     next 

def_asm         "reset?", 6, 0, get_reset
        in      TOSL, GPIO_GPIOR0
        clr     TOSH
        ppush   TOSL
        jmp     next 