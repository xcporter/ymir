;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> ACTOR
;*
;*      Storage and Retrieval Operaltions 
;*      
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************

def_asm         "!", 1, $0, store    ; ( val, addr --)
        _ppop  ZL, ZH              ; load address
        _ppop  r16, r17            ; load byte
        st      Z+, r16
        st      Z+, r17
        jmp     next

def_asm         "!+", 2, $0, store_inc       ; ( val, addr -- addr + 1)
        _ppop  ZL, ZH              ; load address
        _ppop  r16, r17
        st      Z+, r16
        st      Z+, r17
        _ppush  ZL, ZH
        jmp     next

def_asm         "@", 1, $0, fetch
        _ppop  ZL, ZH          ; load address
        ld      r16, Z+
        ld      r17, Z+
        _ppush  r16, r17       ; put value on p_stack
        jmp     next

def_asm         "@+", 2, $0, fetch_inc ; (addr -- next_addr, value)
        _ppop  ZL, ZH          ; load address
        ld      r16, Z+
        ld      r17, Z+
        _ppush  ZL, ZH     
        _ppush  r16, r17       ; put value on p_stack
        jmp     next