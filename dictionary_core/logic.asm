;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> LOGIC
;*      
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************

_do_compare:
        sbiw     SL, 0x02
        _ppop    r18, r19
        cp       r18, r16
        cpc      r19, r17
        ret

def_asm         "==", 2, $0, equal
        rcall   _do_compare
        breq    _true
        rjmp    _false

def_asm         "!=", 2, $0, not_equal
        rcall   _do_compare
        brne    _true
        rjmp    _false

def_asm         "<", 1, $0, less
        rcall   _do_compare
        brlt    _true
        rjmp    _false

def_asm         ">", 1, $0, greater
        sbiw    SL, 0x02
        _ppop   r18, r19
        inc     r18
        cp      r18, r16
        cpc     r19, r17
        brge    _true
        rjmp    _false

def_asm         "<=", 2, $0, less_eq
        sbiw    SL, 0x02
        _ppop   r18, r19
        inc     r16
        cp      r18, r16
        cpc     r19, r17
        brlt    _true
        rjmp    _false

def_asm         ">=", 2, $0, greater_eq
        rcall   _do_compare
        brge    _true
        rjmp    _false

def_asm         "0?", 2, $0, is_zero
        sbiw    SL, 0x02
        cp      TOSL, zero
        cpc     TOSH, zero
        breq    _true
        rjmp    _false

;; Booleans ----------------------
def_asm         "true", 4, 0, _true                 
        ppush   one
        mov     TOSL, one 
        clr     TOSH 
        jmp     next
def_asm         "false", 5, 0, _false
        ppush   zero
        clr     TOSH 
        clr     TOSL 
        jmp     next

def_asm         "^0", 2, $0, is_not_zero
        sbiw    SL, 0x02
        cp      TOSL, zero
        cpc     TOSH, zero
        brne    _true
        rjmp    _false

def_asm         "<0", 2, $0, less_zero
        sbiw    SL, 0x02
        cp      TOSL, zero
        cpc     TOSH, zero
        brlt    _true
        rjmp    _false

;; used for loop primatives 
;; checks top two elements on r stack, 
;; then does == check 
def_asm         "r==", 4, 0, r_equal
        _pop    r0, r1          
        _pop    r2, r3 
        _push   r2, r3 
        _push   r0, r1 
        cp      r0, r2 
        cpc     r1, r3  
        breq    _true
        rjmp    _false

def_asm         "pr==", 4, 0, pr_equal
        _pop    r18, r19 
        _push   r18, r19 
        cp      TOSL, r18 
        cpc     TOSH, r19  
        breq    _true
        rjmp    _false

;; Logic -------------------------
def_asm         "||", 2, $0, b_or
        sbiw    SL, 0x02
        _ppop   r18, r19
        or          r16, r18
        or          r17, r19
        push_tos
        jmp     next

def_asm         "&&", 2, $0, b_and
        sbiw    SL, 0x02
        _ppop  r18, r19
        and         r16, r18
        and         r17, r19
        push_tos
        jmp     next

def_asm         "^", 1, $0, b_xor
        sbiw    SL, 0x02
        _ppop  r18, r19
        eor         r16, r18
        eor         r17, r19
        push_tos
        jmp     next

def_asm         "<<", 2, $0, b_shl
    movw        r18, TOSL
    _ppop       TOSL, TOSH
    b_shl_loop:
        cp      r18, zero
        cpc     r19, zero
        breq    shift_end
        sub     r18, one
        sbc     r19, zero
        lsl     r16
        rol     r17
        rjmp    b_shl_loop
    shift_end:
        push_tos
        jmp     next

def_asm         ">>", 2, $0, b_shr  ;(num to shift, shift x times)
    movw        r18, TOSL
    _ppop       TOSL, TOSH
    
    b_shr_loop:
        cp      r18, zero
        cpc     r19, zero
        breq    shift_end
        sub     r18, one
        sbc     r19, zero
        lsr     r17
        ror     r16
        rjmp    b_shr_loop
