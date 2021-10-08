;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> MATH
;*      
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************

def_asm         "++", 2, $0, incr
        sbiw    SL, 0x02 
        add     TOSL, one
        adc     TOSH, zero
        push_tos
        jmp     next

def_asm         "--", 2, $0, decr
        sbiw    SL, 0x02 
        sub     TOSL, one
        sbc     TOSH, zero
        push_tos
        jmp     next

def_asm         "+", 1, $0, addition
        sbiw    SL, 0x02
        _ppop   r0, r1
        add     TOSL, r0
        adc     TOSH, r1
        push_tos
        jmp     next

def_asm         "-", 1, $0, subtraction
        sbiw    SL, 0x02
        _ppop   r0, r1
        sub     r0, TOSL
        sbc     r1, TOSH 
        movw    TOSL, r0
        push_tos
        jmp     next

def_asm         "*", 1, $0, multiplication
        sbiw    SL, 0x02
        _ppop    r18, r19
        rcall         _multiplication
    mul_push:
        cp      ACBL, zero
        cpc     ACBH, zero
        breq    mul_skip_upper
        _ppush     ACBL, ACBH
    mul_skip_upper:
        _ppush  ACAL, ACAH
        movw    TOSL, ACAL      ; cache tos
        jmp     next

;| 16 x 16 -> 16 or 32 bit
;| ACA          result low  
;| ACB          result high
;| r[18:19]     multiplicand
;| TOS          multiplier
_multiplication: 
        mul     r17, r19        ; multiply high
        movw    ACBL, r0

        mul     r16, r18
        movw    ACAL, r0         ; multiply low

        mul     r17, r18        ; cross multiply       
        add     ACAH, r0
        adc     ACBL, r1
        adc     r23, zero

        mul     r16, r19        
        add     ACAH, r0
        adc     ACBL, r1
        adc     r23, zero

        ret

def_asm         "**", 2, $0, exponent ; (base, power -- result)
        sbiw    SL, 0x02
        movw    r18, TOSL          ; power from stack
        _ppop   TOSL, TOSH
        rcall   _exponent
        rjmp    mul_push

;| ACA       result low
;| ACB       result high  
;| r[18:19]  power
;| TOS       base
_exponent:
        clr     ACAL            ; clear accumulators
        clr     ACAH
        movw    ACBL, ACAL    
        movw    r4, r18         ; power as counter in r4
        cp      r18, zero
        cpc     r19, zero
        breq    _exp_zero
        cp      r18, one
        cpc     r19, zero
        breq    _exp_one
        movw    r18, r16        ; copy base for self multiply

    _exp_loop:
        cp      r4, zero
        cpc     r5, zero
        breq    _exp_done

        sub     r4, one        ; decrement
        sbc     r5, zero        

        rcall   _multiplication
        movw    r18, ACAL      ; put result (low) for next multiply

        rjmp    _exp_loop

    _exp_zero:
        inc     ACAL
        ret
        
    _exp_one:
        movw    ACAL, TOSL 
    _exp_done:
        ret
    


def_asm         "/mod", 4, $0, div_mod  ; (dividend, divisor -- quotient, remainder)
        sbiw    SL, 0x02           ; divisor (factor) on tos
        _ppop   ACBL, ACBH         ; dividend (num being divided)
        rcall   _division
        _ppush  ACAL, ACBL         ; push quotient
        _ppush  r18, r19           ; push remainder
        movw    TOSL, r18          ; cache tos
        jmp     next

; 16 bit division ----------------
;| ACA          quotient
;| ACB          dividend in
;| r[18:19]     dividend workspace / remainder out
;| TOS          divisor (factor)
;| r[2:3]       bitmask / counter
_division:
        clr     r2                      ; clear counter and accumulators
        clr     r3
        movw    ACAL, r2
        movw    ACBL, r2
        ldi     r16, 0x80               ; set up counter / bitmask
        mov     r3, r16
    mod_loop:
        cp      r2, zero                ; end if bitmask is zero
        cpc     r3, zero
        breq    mod_end

        lsl     ACBL                    ; left shift dividend into workspace
        rol     ACBH
        rol     r18
        rol     r19
        cp      r18, TOSL               ; don't set if doesn't divide
        cpc     r19, TOSH
        brmi    mod_skip
        
        or      ACAL, r2                ; set bit if it divides
        or      ACAH, r3
        sub     r18, TOSL               ; then subtract divisor from workspace
        sbc     r19, TOSH
    mod_skip:
        lsr     r3                      ; shift counter / bitmask right 
        ror     r2      
        rjmp    mod_loop

    mod_end:
        ret

def_asm         "sqrt", 4, $0, square_root ; (input -- root, remainder)
        sbiw    SL, 0x02
        rcall   _square_root
        _ppush  r0, r1
        _ppush  r2, r3
        movw    TOSL, r2        ; cache tos
        jmp     next

;| ACAL counter
;| TOS in
;| r[2:3] Remainder
;| r[0:1] Root 
_square_root:
        clr     r2              ; clear result registers
        clr     r3
        movw    r0, r2
        ldi     ACAL, 0x08      ; setup counter
_sqrt_loop:
        lsl     r0              ; root * 2
        rol     r1

        lsl     TOSL            ; shift 2 bits from input into rem
        rol     TOSH
        rol     r2
        rol     r3

        lsl     TOSL     
        rol     TOSH
        rol     r2
        rol     r3

        cp      r0, r2          
        cpc     r1, r3
        brcc    _sqrt_end       ; finish if Root > Remainder
        add     r0, one 
        adc     r1, zero
        sub     r2, r0
        sbc     r3, r1
        add     r0, one 
        adc     r1, zero
_sqrt_end:
        dec     ACAL
        brne    _sqrt_loop
        lsr     r1
        ror     r0
        ret