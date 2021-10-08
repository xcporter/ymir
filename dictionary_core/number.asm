;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> NUMBER
;*      
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************

def_asm         "lit", 3, $0, literal           ; Retrieve next as num and put on P-stack
        ld      r16, Y+
        ld      r17, Y+
        _ppush  r16, r17
        rjmp    next 


def_word        "hex", 3, $0, to_hex
        .dw     literal
        .dw     0x0010
        .dw     set_base
        .dw     exit

def_word        "dec", 3, $0, to_dec
        .dw     literal
        .dw     0x000A
        .dw     set_base
        .dw     exit

def_word        "bin", 3, $0, to_bin
        .dw     literal
        .dw     0x0002
        .dw     set_base
        .dw     exit

def_asm         "sign", 4, $0, sign
        sbi     num_format, 7
        jmp     next
def_asm         "unsign", 6, $0, unsign
        cbi     num_format, 7
        jmp     next


; (digits --) set length constant for how nums are displayed
; numbers that exceed the digit size are unaffected
; smaller numbers are padded with zeros
def_asm         "digits", 6, $0, digits 
        ppop   r17
        in      r16, num_format
        andi    r16, 0b11100000         ; clear last fmt
        or      r17, r16                ; add mask to new digit value
        out     num_format, r17
        jmp     next