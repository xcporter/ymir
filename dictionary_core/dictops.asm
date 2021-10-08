;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> DICTOPS (DICTIONARY OPERATIONS)
;*      
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************

;| r[18:19] input string address 
;| r[20:21] length [current | input]
def_asm         "find", 4, $0, find

        push    YH                          ; put away instruction pointer for now
        push    YL  

        ; ldi     r18, Low(dict_start)        ; check if any dict in ram (ram_here == dict_start)
        ; ldi     r19, High(dict_start)
        ldi     YL, Low(SRAM_START + 0x06)
        ldi     YH, High(SRAM_START + 0x06)
        ld      ZL, Y+                      ; load ram latest into Z
        ld      ZH, Y+
                    

        ppop           r21                  ; load target length
        _ppop      r18, r19              ; load target address
        cp      ZL, r18
        cpc     ZH, r19
        breq    find_prog
        
    find_ram:
    ;todo
    find_prog:
        ldi     YL, Low(SRAM_START)
        ldi     YH, High(SRAM_START)
    find_next:
        ld      ZL, Y+          ; load next address
        ld      ZH, Y+
        movw    YL, ZL          ; copy to Y
        
        cp      YL, zero
        cpc     YH, zero
        breq    find_not_found
    find_loop:
        adiw    ZL, 0x02
        ld      r16, Z+                         ; get length / flags


        sbrc    r16, 6                          ; skip if hidden
        rjmp    find_next

        andi    r16, 0b00011111                 ; mask flags

        cp      r21, r16                         ; keep looking if different length
        brne    find_next       

   find_detail:
        mov     r20, r21
        push    YH              ; stash current address on return stack
        push    YL              
        movw    YL, r18          ; put target in Y
    detail_loop:
        cp      r20, zero                     
        breq    find_found                      ; all chars are the same; break!

        dec     r20
        ld      r16, Z+
        ld      r17, Y+

        cp      r16, r17                        ; do compare
        brne    detail_exit                     ; didn't match
        rjmp    detail_loop                     ; did match
    detail_exit:        
        pop     YL              ; put back current address
        pop     YH
        rjmp    find_next

    find_found:
        pop     YL                      ; put back current address
        pop     YH
        _ppush     YL, YH          ; put on p stack  
        rjmp    find_done
    find_not_found:
        ppush  zero
    find_done:
        pop     YL                      ; put back instruction pointer
        pop     YH 
        jmp     next

def_asm         ">xt", 3, $0, to_xt
        _ppop    ZL, ZH            ; get address from stack
        adiw    ZL, 0x02                ; skip past word link
        ld      r16, Z+                 ; get length
        andi    r16, 0b00011111         ; mask flags

        sbrs    r16, 0         ; deal with byte padding for things that take up odd numbers of space
        inc     r16

        add     ZL, r16        ; move pointer to start of definition
        adc     ZH, zero

        call    _global_to_flash
        _ppush     ZL, ZH
        jmp     next


; def_asm         "immediate", 9, f_immediate, immediate
def_asm         "hide", 4, $0, hide
        _ppop      ZL, ZH
        adiw    ZL, 0x02
        ld      r16, Z 
        ori     r16, 0b01000000
        st      Z, r16
        jmp     next 
def_asm         "unhide", 6, $0, unhide
        _ppop      ZL, ZH
        adiw    ZL, 0x02
        ld      r16, Z 
        andi     r16, 0b10111111
        st      Z, r16
        jmp     next 

def_word         "create", 6, $0, create
        .dw     word            ; (name?, len)
        .dw     dup             ; (name?, len, len)
        .dw     branch_if 
        .dw     0x0006          ; go to error if no word found

        .dw     r_latest_pt     ; write latest to here 
        .dw     fetch     
        .dw     r_here_pt       ; (latest, here)
        .dw     fetch 
        .dw     store 
        .dw     r_here_pt 
        .dw     fetch 
        .dw     dup            ; (here, here)           update latest to here
        .dw     r_latest_pt    ; (here, here, &latest)
        .dw     store          ; (here)

        .dw     incr 
        .dw     incr            ; (here+2)
        .dw     dup_two         ; (here+2, len, here+2)
        .dw     store           ; store length to here+2
        .dw     incr            ; (name, len, here+3)

        .dw     dup_two         ; (...len, here+3)
        .dw     addition        ; (...new here )
        .dw     to_r            ; stack new here on r stack

        ; .dw     move            ; write name to here+3

        .dw     from_r          ; update here pointer
        .dw     r_here_pt
        .dw     store           


        .dw     exit
        .dw     syn_err         ; to error

; def_asm         ",", 1, $0, comma