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
        ld      r18, Y+        ; load number from IP
        ld      r19, Y+
        lsl     r18            ; multiply branch by 2 (word address)
        rol     r19
        sbiw    YL, 0x02       ; IP counts from between branch and distance
        add     YL, r18
        adc     YH, r19
        jmp     next

def_asm         "?branch", 7, $0, branch_if
        sbiw    SL, 0x02
        movw    r18, TOSL 
        cache_tos
        cp      r18, zero 
        cpc     r19, zero 
        brne    branch_skip
        rjmp    branch 
    branch_skip:
        adiw    YL, 0x02        ; advance Y past number if skip
        jmp     next

; def_word        "repeat", 6, 0, repeat

; def_word        "end", 3, 0, end