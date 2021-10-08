;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> STACK
;*      
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************

def_asm         "drop", 4, $0, drop
        sbiw    SL, 0x02
        cache_tos
        jmp     next

def_asm         "2drop", 5, $0, drop_two
        sbiw    SL, 0x04
        cache_tos 
        jmp     next

def_asm         "swap", 4, $0, swap
        _ppop      r0, r1
        _ppop      TOSL, TOSH 
        _ppush     r0, r1
        push_tos
        jmp     next

def_asm         "dup", 3, $0, dup
        push_tos
        jmp     next

def_asm         "over", 4, $0, over
        sbiw    SL, 0x02
        _ppop   TOSL, TOSH
        adiw    SL, 0x04 
        push_tos
        jmp     next

def_word         "2dup", 4, $0, dup_two
        .dw     over 
        .dw     over 
        .dw     done 

def_asm         "2swap", 5, $0, swap_two ; (a, b, c, d -- c, d, a, b)
        _ppop      r0, r1 
        _ppop      r2, r3 
        _ppop      TOSL, TOSH 
        _ppop      r4, r5 
        _ppush     r2, r3 
        _ppush     r0, r1 
        _ppush     r4, r5
        push_tos
        jmp     next
def_asm         "rot", 3, $0, rot ; ( a b c -- b c a )
        _ppop      r0, r1
        _ppop      r2, r3
        _ppop      TOSL, TOSH
        _ppush     r2, r3
        _ppush     r0, r1
        push_tos
        jmp     next

def_asm         "-rot", 4, $0, inv_rot ; ( a b c -- c a b )
        _ppop      r0, r1
        _ppop      TOSL, TOSH
        _ppop      r2, r3
        _ppush     r0, r1
        _ppush     r2, r3
        push_tos
        jmp     next
 
; Return Stack ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
def_asm         ">r", 2, $0, to_r
        _ppop   r16, r17
        _push   r16, r17
        jmp     next

def_asm         "r>", 2, $0, from_r
        _pop    r16, r17
        _ppush  r16, r17
        jmp     next

def_asm         "@r", 2, $0, fetch_r
        _pop    r16, r17
        _push   r16, r17
        _ppush  r16, r17       ; put it onto the param stack
        jmp     next

def_asm         "!r", 2, $0, store_r
        sbiw    SL, 0x02
        _push   TOSL, TOSH
        jmp     next

def_asm         "rdrop", 5, $0, r_drop
        _pop    r0, r1
        jmp     next