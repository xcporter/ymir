;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> STRING
;*      
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************

def_asm         "litstring", 9, $0, litstring
        ld      r16, Y+                 ; load length

        _ppush      YL, YH
        ppush       r16                 ; push length

        sbrs    r16, 0                  ; account for padding if length even (total odd)
        inc     r16

        add     YL, r16                 ; add length to instruction pointer
        adc     YH, zero

        jmp    next 


def_asm         "strcmp"