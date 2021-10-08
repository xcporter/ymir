;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> INTERPILER (INTERPRETER/COMPILER)
;*      
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************

def_word        "interpret", 9, $0, interpret
        .dw     word                    ; (addr?, len)
        .dw     dup                     ; (addr?, len, len)
        .dw     branch_if               ; (addr?, len)
        .dw     0x0013                  ; finish interpreter loop
        .dw     dup_two                 ; (addr, len, addr, len)
        .dw     find                    ; (addr, len, word?)
        .dw     dup                     ; (addr, len, word?, word?)
        .dw     branch_if               ; (addr, len, word)
        .dw     0x0009                  ; to num
        .dw     inv_rot                 ; (word, addr, len)
        .dw     drop_two                ; (word)
        .dw     to_xt                   ; (xt)
        .dw     execute                 ; ()
        .dw     syscheck
        .dw     branch 
        .dw     0xfff2                  ; loop interpreter
        .dw     drop                    ; (addr, len)
        .dw     string_to_num           ; (num, error?)
        .dw     branch_if 
        .dw     0xffee                  ; loop if error is zero (num)
        .dw     syn_err                 ; else error
        .dw     drop
        .dw     ok
        .dw     exit



; def_asm         "[", 1, f_immediate, engage
; def_asm         "]", 1, $0, disengage
; def_word        ":", 1, $0, colon
; def_word        ";", 1, f_immediate, semicolon