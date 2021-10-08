;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> CONTROLFLOW
;*      
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************

def_asm         "branch", 6, $0, branch
        ld      r16, Y+
        ld      r17, Y+
        lsl     r16
        rol     r17
        sbiw    YL, 0x04        ; counts from pointer to branch
        add     YL, r16
        adc     YH, r17
        jmp     next

def_asm         "?branch", 7, $0, branch_if
        ppop   r16
        cpse    r16, zero
        rjmp    branch_if_skip
        rjmp    branch
    branch_if_skip:
        adiw    YL, 0x02        ; advance Y past number if skip
        jmp     next