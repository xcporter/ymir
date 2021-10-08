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
        _ppop  r16, r17
        _ppop  r18, r19
        cp      r16, r18
        cpc     r17, r19
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
        _ppop  r16, r17
        _ppop  r18, r19
        ldi     r20, 0x01
        add     r18, r20
        cp      r16, r18
        cpc     r17, r19
        brge    _true
        rjmp    _false

def_asm         "<=", 2, $0, less_eq
        _ppop  r16, r17
        _ppop  r18, r19
        ldi     r20, 0x01
        add     r18, r20
        cp      r16, r18
        cpc     r17, r19
        brlt    _true
        rjmp    _false

def_asm         ">=", 2, $0, greater_eq
        rcall   _do_compare
        brge    _true
        rjmp    _false

def_asm         "?0", 2, $0, is_zero
        _ppop  r16, r17
        clr     r18
        cp      r16, r18
        cpc     r17, r18
        breq    _true
        rjmp    _false

;; Booleans ----------------------
;       These aren't words, but rather subroutines which 
;       put either true or false onto the stack,
;       put away the P pointer and jump to next
_true:                    
        ppush  one
        jmp     next
_false:
        ppush  zero
        jmp     next

def_asm         "!0", 2, $0, is_not_zero
        _ppop  r16, r17
        cp      r16, zero
        cpc     r17, zero
        brne    _true
        rjmp    _false

def_asm         "-0", 2, $0, less_zero
        _ppop  r16, r17
        cp      r16, zero
        cpc     r17, zero
        brlt    _true
        rjmp    _false

;; Logic -------------------------
def_asm         "||", 2, $0, b_or
        _ppop  r16, r17
        _ppop  r18, r19
        or          r16, r18
        or          r17, r19
        _ppush r16, r17
        jmp     next

def_asm         "&&", 2, $0, b_and
        _ppop  r16, r17
        _ppop  r18, r19
        and         r16, r18
        and         r17, r19
        _ppush r16, r17
        jmp     next

def_asm         "^", 1, $0, b_xor
        _ppop  r16, r17
        _ppop  r18, r19
        eor         r16, r18
        eor         r17, r19
        _ppush r16, r17
        jmp     next

def_asm         "<<", 2, $0, b_shl
    _ppop  r18, r19
    _ppop  r16, r17
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
        _ppush r16, r17
        jmp     next

def_asm         ">>", 2, $0, b_shr  ;(num to shift, shift x times)
        _ppop  r18, r19    
        _ppop  r16, r17
    
    b_shr_loop:
        cp      r18, zero
        cpc     r19, zero
        breq    shift_end
        sub     r18, one
        sbc     r19, zero
        lsr     r17
        ror     r16
        rjmp    b_shr_loop
