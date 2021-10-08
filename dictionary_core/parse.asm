;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> PARSE
;*
;*      Words for accessing system addresses related to the forth kernel
;*
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************



def_asm         "word", 4, $0, word
;         call    reset_w_buffer
;         clr     r18                    ; r18: length counter 
;         mov     ZL, BRL                ; load in read pointer
;         mov     ZH, BRH
;         ldi     r17, 0x20              ; load space for compare
;     word_1:
;         cp      ZL, BWL                 ; check if buffer consumed or space (read=write)
;         cpc     ZH, BWH
;         breq    word_empty
;         ld      r16, Z
;         sbiw    ZL, 0x01
;         cp      r16, r17
;         breq    word_1                  ; loop if space
;     word_2:
;         inc     r18                     ; store next char in s buffer
;         mov     BRL, ZL                
;         mov     BRH, ZH
;         movw    ZL, WL 
;         st      Z+, r16
;         movw    WL, ZL
;         mov     ZL, BRL                
;         mov     ZH, BRH

;         cp      ZL, BWL                 ; check if buffer consumed
;         cpc     ZH, BWH
;         breq    word_result
;         ld      r16, Z                  ; load next char and check if space
;         sbiw    ZL, 0x01
;         cp      r16, r17
;         breq    word_result

;         rjmp    word_2
;     word_result:
;         call    push_w_start
;         ppush  r18
;         jmp     next
;     word_empty:
;         ldi     r16, 0x00
;         ppush  r16
        jmp     next


def_asm         ">char", 5, $0, to_char
        ppop   r16
        rcall   _to_char
        ppush  r16
        jmp     next
    _to_char:   ; (r16 -- r16)
        ldi     r17, 0x30           ; '0'
        add     r16, r17
        cpi     r16, 0x3a           ; if >9, add letter offset 
        brge    to_char_1
        ret
    to_char_1:
        ldi     r17, 0x27
        add     r16, r17
        ret
def_asm         "char>", 5, $0, from_char
        ppop   r16
        rcall   _from_char
        ppush  r16
        jmp     next

    _from_char: ; (r16 -- r16)
        ldi     r17, 0x30           ; subtract '0'
        sub     r16, r17
        cpi     r16, 0x10           ; if >9, subtract letter offset 
        brge    _char_to_num_1
        ret
    _char_to_num_1:
        ldi     r17, 0x27
        sub     r16, r17
        ret  


;| r[8:9] current char, base
;| r[6:7] accumulator
;| r5   error
;| r[2:3] length count, length

def_asm         ">num", 4, $0, string_to_num            ; (addr, length -- num, error)
        cbi     state, 7 
        clr     r5
        clr     r6
        clr     r7
        ppop           r2              ; length
        mov     r3, r2
        _ppop      ZL, ZH          ; address

        in      r9, base_r

        ld      r8, Z+                  ; load first char
        dec     r2

        ldi     r16, 0x2D               ; check if '-'
        cp      r8, r16
        breq    _stn_sign_1

    _stn_base_literal:
        mov     r16, r8
        ldi     r17, '$'
        cp      r16, r17
        breq    _stn_base_override

        ldi     r17, '#'
        cp      r16, r17
        breq    _stn_base_override

        ldi     r17, '%'
        cp      r16, r17
        breq    _stn_base_override

        rjmp    _stn_start

   _stn_sign_1:
        sbi     state, 7 

        ld      r8, Z+                  ; load next char
        dec     r2 
        dec     r3                      ; dec backup count 
        rjmp    _stn_base_literal
    _stn_base_override:
        ldi     r18, 0x0a
        ldi     r17, 0x23
        sub     r16, r17

        sbrc    r16, 0
        ldi     r18, 0x10

        sbrc    r16, 1
        ldi     r18, 0x02

        mov     r9, r18

        ld      r8, Z+                  ; load next
        dec     r2
        dec     r3

    _stn_start:
        mov     r16, r8
        ldi     r17, '0'
        cp      r16, r17                ; accept only 0-9, a-z
        brlt    _stn_err

        ldi     r17, ':'  
        cp      r16, r17              ; 
        brlt    _stn_cont

        ldi     r17, '{'
        cp      r16, r17
        brge    _stn_err

        ldi     r17, 'a'
        cp      r16, r17
        brlt    _stn_err 
    _stn_cont:
        cp      r16, r17
        call    _from_char
        cp      r16, r9                 ; compare with base
        brge    _stn_err                ; error if greater
        push    zero                   ; otherwise push unchared num to r stack
        push    r16

        cp      r2, zero
        breq    _stn_finish

        ld      r8, Z+                  ; load next char
        dec     r2 

        rjmp    _stn_start              ; loop
    _stn_err:   
        inc     r5
        rjmp    _stn_end

    _stn_finish:
        cp      r2, r3
        breq    _stn_return

        mov     r16, r9                 ; get place
        clr     r17
        mov     r18, r2
        clr     r19
        call    _exponent      

        movw    r16, r20                ; multiply by term
        pop     r18
        pop     r19
        call    _multiplication

        add     r6, r20                 ; add to accumulator
        adc     r7, r21         

        inc     r2
        rjmp    _stn_finish             ; loop

    _stn_sign_2:
        com     r7                      ; do two's compliment
        neg     r6
        cbi     state, 7

        rjmp    _stn_end
        
    _stn_return:
        sbic    $1c, 7                 ; check sign in state register
        rjmp    _stn_sign_2
    _stn_end:
        _ppush     r6, r7          ; push result
        ppush          r5              ; push error
        jmp     next

;|      r0 length counter
def_asm         "num>", 4, $0, num_to_string
        clr     r0                              ; length counter [r0]
        ; ldi     ZL, Low(buffer_start)           ; load pad address into Z
        ; ldi     ZH, High(buffer_start)
        _ppop   r22, r23                   ; load num from stack
        sbic    num_format, 7                   ; if using signed numbers, do sign
        rjmp    _nts_sign
    _nts_start:
        in      r16, base_r                     ; load divisor (base)
        clr     r17

     _nts_loop:
        call    _division

        cp      r20, zero      ; is quotient zero?
        cpc     r21, zero
        breq    _nts_write      ; break to write

        inc     r0
        push    r19             ; temporarily keep remainders on return stack
        push    r18
        mov     r22, r20        ; do next with quotient
        mov     r23, r21
        rjmp    _nts_loop

     _nts_write:
        inc     r0                              ; push last remainder
        push    r19           
        push    r18
        mov     r1, r0                          ; copy length
        rjmp    _nts_format
    _nts_write_cont:
        sbic    $1c, 7                          ; check sign in state register
        rjmp    _nts_write_sign

     _nts_write_loop:
        cp      r0, zero
        breq    _nts_done                       ; break when length counter zero
        dec     r0

        pop     r16                             ; load next rem
        pop     r2                              ; discard high byte
        call    _to_char
        st      Z+, r16
        rjmp    _nts_write_loop

    _nts_sign:
        sbrc    r23, 7
        rjmp    _do_nts_sign
        rjmp    _nts_start
    _do_nts_sign:
        com     r23 
        neg     r22 
        sbi     state, 7 
        rjmp    _nts_start

    _nts_write_sign:
        ldi     r16, 0x2d
        st      Z+, r16
        inc     r1
        cbi     state, 7 
        rjmp    _nts_write_loop

    _nts_format:
        in      r16, num_format 
        andi    r16, 0b00011111         ; clear flags
        cp      r16, r1                 ; break if number larger than fmt
        brlt    _nts_skip_format 
        mov     r0, r16
        sub     r0, r1                  ; get amount to pad
        add     r1, r0                  ; adjust length
    _nts_format_loop:
        cp      r0, zero
        breq    _nts_skip_format
        dec     r0
        push    zero
        push    zero
        rjmp    _nts_format_loop

    _nts_skip_format:
        mov     r0, r1                  ; put back counter for write
        rjmp    _nts_write_cont
    _nts_done:   
        ; ldi     ZL, Low(buffer_start)           ; put string addr / length on stack
        ; ldi     ZH, High(buffer_start)
        _ppush     ZL, ZH
        ppush          r1
        jmp     next