;*************************************************************************
;*   
;*      YMIR
;*           A simple forth              
;* 
;*      Author: Alexander Porter (2021)
;*
;*
;*
;* 
;*************************************************************************

;; Device definitions ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        .include    "m4809def.inc"
        .include    "libraries/usbserial.inc"
        .include    "config.inc"
        .include    "macros.inc"

;; Reserved Registers ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;       SP: Return stack pointer
;       Z:  Working Pointer: program memory read/write, indirect execution
;       Y:  Instruction Pointer
;       X:  Parameter stack pointer
;       W:  pointer to s buffer (r[24:25])
;       BR: r[14:15]
;       BW: r[12:13]
        .def        WL = r24
        .def        WH = r25
        .def        BRL = r14
        .def        BRH = r15
        .def        BWL = r12
        .def        BWH = r13
        .def        zeroR = r10, 
        .def        oneR = r11

;; Word Structure ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;   | Link Address | Name Length | Name | Flag | Definition | 0xPadding
;   | 2 B          | 1 B         | n B  | 1 B  | n B        | n B
;                                      /       \
;    _________________________________/         \_______________
;   |f_immediate | f_hidden | f_in_ram | 0b | 0b | 0b | 0b | 0b |

;;  IO Registers ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;       State: | reverse | in_buffer_reset | 0b | 0b | 0b | 0b | 0b | compile |
        .equ        state           = GPIO_GPIOR0
        .equ        base_r          = GPIO_GPIOR1

;;  System Memory ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;   0x00 : prog_latest | ram_latest | prog_here | ram_here | 0x00
        .equ        prog_latest_pt  = SRAM_START 
        .equ        ram_latest_pt   = SRAM_START + 0x2  
        .equ        prog_here_pt  = SRAM_START + 0x4
        .equ        ram_here_pt   = SRAM_START + 0x6

;; RAM layout: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;  start:| System | Buffer | P stack >|< Ram Dictionary |< R stack |:end
;        | 256 B  | 2kB    | 512 B    |  3.2kB          | 512 B    |
;                /          \________________________
;               | pad 256B | w_buffer >|< in_buffer  |

        .equ        p_stack_start = buffer_start + buffer_size
        .equ        w_buffer_start = buffer_start + 0x100
        .equ        dict_start = RAMEND - r_stack_max

;; Setup ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        .cseg
        .org    0x0000

        ldi     r16, Low(RAMEND)        ; init stack pointer
        ldi     r17, High(RAMEND)
        out     CPU_SPL, r16
        out     CPU_SPH, r17

        clr     zeroR                   ; set up constant registers (0 and 1)
        ldi     r16, 0x01
        mov     oneR, r16

        setup_usb
        call    setup_data_seg
        call    reset_p

;;  Start ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        ldi     YL, Low(main)
        ldi     YH, High(main)
        rjmp    next

;; Terminal Core ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
do:
        push    YL
        push    YH
        adiw    ZL, 0x02  ; opcode is 3 bytes
        movw    YL, ZL
        rjmp    next
done:
        pop     YH
        pop     YL
next:
        ldi     r18, 0x40
        lsl     YL
        rol     YH
        add     YH, r18
        ld      ZL, Y+
        ld      ZH, Y+
        sub     YH, r18
        lsr     YH
        ror     YL
        ijmp


;; Dictionary ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
def_asm         "execute", 7, $0, execute
        p_pop_word      ZL, ZH
        ijmp
          
def_asm         "exit", 4, $0, exit
        rjmp    done

def_asm         "lit", 3, $0, literal           ; Retrieve next as num and put on P-stack
        ldi     r18, 0x40
        lsl     YL
        rol     YH
        add     YH, r18
        ld      r16, Y+
        ld      r17, Y+
        sub     YH, r18
        lsr     YH
        ror     YL
        p_push_word  r16, r17
        rjmp    next 

def_asm         "reset", 5, $0, reset
        ldi     r16, Low(RAMEND)        ; init stack pointer
        ldi     r17, High(RAMEND)
        out     CPU_SPL, r16
        out     CPU_SPH, r17
        call    reset_in_buffer
        call    reset_w_buffer
        rjmp    next
    
;; System Constants --------------
def_const       "r0", 2, $0, r_stack_zero, RAMEND

def_asm         "&r", 2, $0, r_stack_pt
        in      r16, CPU_SPL
        in      r17, CPU_SPL
        p_push_word     r16, r17
        jmp     next

def_const       "p0", 2, $0, p_start, p_stack_start

def_asm         "&p", 2, $0, p_stack_pt
        p_push_word     XL, XH
        jmp     next

def_asm         "@base", 5, $0, get_base      ; put base on stack
        in      r16, base_r
        p_push  r16
        jmp     next

def_asm         "base", 4, $0, set_base      
        p_pop   r16
        out     base_r, r16
        jmp     next

def_const       "pad", 4, $0, pad_start, buffer_start

def_const       "buffer", 6, $0, buffer, w_buffer_start

;; Stack Ops ---------------------
;       Parameter
def_asm         "drop", 4, $0, drop
        sbiw    XL, 0x02
        jmp     next

def_asm         "2drop", 5, $0, drop_two
        sbiw    XL, 0x04
        jmp     next

def_asm         "swap", 4, $0, swap
        p_pop_word      r16, r17
        p_pop_word      r18, r19 
        p_push_word     r16, r17
        p_push_word     r18, r19
        jmp     next

def_asm         "2swap", 5, $0, swap_two
        p_pop_word      r0, r1
        p_pop_word      r2, r3 
        p_pop_word      r4, r5
        p_pop_word      r6, r7 
        p_push_word     r0, r1
        p_push_word     r2, r3 
        p_push_word     r4, r5
        p_push_word     r6, r7 
        jmp     next

def_asm         "dup", 3, $0, dup
        p_pop_word      r16, r17
        p_push_word     r16, r17
        p_push_word     r16, r17
        jmp     next

def_asm         "2dup", 4, $0, dup_two
        p_pop_word      r16, r17
        p_pop_word      r18, r19
        p_push_word     r18, r19
        p_push_word     r16, r17
        p_push_word     r18, r19
        p_push_word     r16, r17
        jmp     next

def_asm         "over", 4, $0, over
        sbiw    XL, 0x02
        p_pop_word      r16, r17
        adiw    XL, 0x04 
        p_push_word      r16, r17
        jmp     next

def_asm         "rot", 3, $0, rot
        p_pop_word      r16, r17
        p_pop_word      r18, r19
        p_pop_word      r20, r21
        p_push_word     r18, r19
        p_push_word     r16, r17
        p_push_word     r20, r21
        jmp     next

def_asm         "-rot", 4, $0, inv_rot
        p_pop_word      r16, r17
        p_pop_word      r18, r19
        p_pop_word      r20, r21
        p_push_word     r16, r17
        p_push_word     r20, r21
        p_push_word     r18, r19
        jmp     next
 
;       Return
def_asm         ">r", 2, $0, to_r
        p_pop_word   r16, r17
        push    r17
        push    r16
        jmp     next

def_asm         "r>", 2, $0, from_r
        pop     r16
        pop     r17
        p_push_word  r16, r17
        jmp     next

def_asm         "@r", 2, $0, fetch_r
        in      ZL, SPL             ; load stack pointer into Z
        in      ZH, SPH
        ld      r17, Z+             ; get word from return stack
        ld      r16, Z+
        p_push_word  r16, r17       ; put it onto the param stack
        jmp     next

def_asm         "!r", 2, $0, store_r
        p_pop_word   r16, r17       ; get top of p stack
        in      ZL, SPL             ; load stack pointer into Z
        in      ZH, SPH
        st      Z, r17              ; write to stack
        sbiw    ZL, 0x01
        st      Z, r16              ; write to stack
        sbiw    ZL, 0x01
        out     SPL, ZL             ; put back the pointer
        out     SPH, ZH
        jmp     next

def_asm         "rdrop", 5, $0, r_drop
        pop     r16
        pop     r16
        jmp     next

def_word         ".s", 2, $0, print_p_stack
        .dw     sp 
        .dw     literal         ; " <"
        .dw     0x003c
        .dw     emit 

        .dw     p_stack_pt 
        .dw     p_start
        .dw     subtraction
        .dw     literal 
        .dw     0x0001 
        .dw     b_shr
        .dw     dup
        .dw     dot             ; ( size )

        .dw     literal         ; ">"
        .dw     0x003e
        .dw     emit 

        .dw     literal         ; prep loop
        .dw     0x0000          ; ( size, 0 )

        .dw     sp
        .dw     dup_two         ; ( size, 0, size, 0 )
        .dw     not_equal       ; ( size, 0, ? )

        .dw     branch_if       ; end if equal
        .dw     0x0008          

        .dw     dup 
        .dw     pick 
        .dw     dot 
        .dw     incr

        .dw     branch          ;loop
        .dw     0xfff7

        .dw     drop_two
        .dw     exit

def_word        "pick", 4, $0, pick   ; (stack index 0=bottom, n=top)
        .dw     literal 
        .dw     0x0001
        .dw     b_shl 
        .dw     p_start 
        .dw     addition
        .dw     fetch
        .dw     exit

;; Arithmetic --------------------
def_asm         "++", 2, $0, incr
        p_pop_word    r16, r17
        add     r16, oneR
        adc     r17, zeroR
        p_push_word   r16, r17
        jmp     next

def_asm         "--", 2, $0, decr
        p_pop_word    r16, r17
        sub     r16, oneR
        sbc     r17, zeroR
        p_push_word   r16, r17
        jmp     next

def_asm         "+", 1, $0, addition
        p_pop_word    r16, r17
        p_pop_word    r18, r19
        add     r16, r18
        adc     r17, r19
        p_push_word   r16, r17
        jmp     next

def_asm         "-", 1, $0, subtraction
        p_pop_word    r18, r19
        p_pop_word    r16, r17
        sub     r16, r18
        sbc     r17, r19
        p_push_word   r16, r17
        jmp     next

def_asm         "*", 1, $0, multiplication
        p_pop_word    r16, r17
        p_pop_word    r18, r19
        rcall         _multiplication
        cp      r22, zeroR
        cpc     r23, zeroR
        breq    mul_skip_upper
        p_push_word     r22, r23
mul_skip_upper:
        p_push_word     r20, r21
        jmp     next

;| r[22:23]     result high  
;| r[20:21]     result low
;| r[18:19]     multiplicand
;| r[16:17]     multiplier
;t
_multiplication: 
        mul     r17, r19        ; multiply high
        movw    r22, r0

        mul     r16, r18
        movw    r20, r0         ; multiply low

        mul     r17, r18        ; cross multiply       
        add     r21, r0
        adc     r22, r1
        adc     r23, zeroR

        mul     r16, r19        
        add     r21, r0
        adc     r22, r1
        adc     r23, zeroR

        ret

def_asm         "/mod", 4, $0, div_mod  ; (dividend, divisor -- quotient, remainder)
        p_pop_word   r16, r17           ; divisor (factor)
        p_pop_word   r22, r23           ; dividend (num being divided)
        rcall   _division
        p_push_word  r20, r21           ; push quotient
        p_push_word  r18, r19           ; push remainder
        jmp     next

; 16 bit division ----------------
;| r[22:23]     dividend in
;| r[20:21]     quotient
;| r[18:19]     dividend workspace / remainder out
;| r[16:17]     divisor (factor)
;| r[2:3]       bitmask / counter
_division:
        ldi     r20, 0x80               ; setup mask / counter
        mov     r3, r20
        clr     r2
        clr     r20                     ; clear accumulator 
        clr     r21
        clr     r18
        clr     r19
    mod_loop:
        cp      r2, zeroR               ; end if bitmask reaches zero
        cpc     r3, zeroR
        breq    mod_end

        lsl     r22                     ; left shift dividend workspace
        rol     r23
        rol     r18
        rol     r19
        cp      r19, r17                ; don't set if doesn't divide
        cpc     r18, r16
        brmi    mod_skip
        
        or      r20, r2                 ; set bit if it divides
        or      r21, r3
        sub     r18, r16                ; subtract if it divides
        sbc     r19, r17
    mod_skip:
        lsr     r3                     ; shift accumulator right 
        ror     r2      
        rjmp    mod_loop

    mod_end:
        ret

;; Comparison --------------------
_do_compare:
        p_pop_word  r16, r17
        p_pop_word  r18, r19
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
        p_pop_word  r16, r17
        p_pop_word  r18, r19
        ldi     r20, 0x01
        add     r18, r20
        cp      r16, r18
        cpc     r17, r19
        brge    _true
        rjmp    _false

def_asm         "<=", 2, $0, less_eq
        p_pop_word  r16, r17
        p_pop_word  r18, r19
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
        p_pop_word  r16, r17
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
        p_push  oneR
        jmp     next
_false:
        p_push  zeroR
        jmp     next

def_asm         "!0", 2, $0, is_not_zero
        p_pop_word  r16, r17
        cp      r16, zeroR
        cpc     r17, zeroR
        brne    _true
        rjmp    _false

def_asm         "-0", 2, $0, less_zero
        p_pop_word  r16, r17
        cp      r16, zeroR
        cpc     r17, zeroR
        brlt    _true
        rjmp    _false

;; Logic -------------------------
def_asm         "||", 2, $0, b_or
        p_pop_word  r16, r17
        p_pop_word  r18, r19
        or          r16, r18
        or          r17, r19
        p_push_word r16, r17
        jmp     next

def_asm         "&&", 2, $0, b_and
        p_pop_word  r16, r17
        p_pop_word  r18, r19
        and         r16, r18
        and         r17, r19
        p_push_word r16, r17
        jmp     next

def_asm         "^", 1, $0, b_xor
        p_pop_word  r16, r17
        p_pop_word  r18, r19
        eor         r16, r18
        eor         r17, r19
        p_push_word r16, r17
        jmp     next

def_asm         "<<", 2, $0, b_shl
    p_pop_word  r18, r19
    p_pop_word  r16, r17
    b_shl_loop:
        cp      r18, zeroR
        cpc     r19, zeroR
        breq    shift_end
        sub     r18, oneR
        sbc     r19, zeroR
        lsl     r16
        rol     r17
        rjmp    b_shl_loop
    shift_end:
        p_push_word r16, r17
        jmp     next

def_asm         ">>", 2, $0, b_shr  ;(num to shift, shift x times)
        p_pop_word  r18, r19    
        p_pop_word  r16, r17
    
    b_shr_loop:
        cp      r18, zeroR
        cpc     r19, zeroR
        breq    shift_end
        sub     r18, oneR
        sbc     r19, zeroR
        lsr     r17
        ror     r16
        rjmp    b_shr_loop

;; Memory Ops --------------------
def_asm         "!", 1, $0, store    ; ( val, addr --)
        p_pop_word  ZL, ZH              ; load address
        p_pop_word  r16, r17            ; load byte
        st      Z+, r17
        st      Z+, r16
        jmp     next

def_asm         "!+", 2, $0, store_inc       ; ( val, addr -- addr + 1)
        p_pop_word  ZL, ZH              ; load address
        p_pop_word  r16, r17
        st      Z+, r17
        st      Z+, r16
        p_push_word  ZL, ZH
        jmp     next

def_asm         "@", 1, $0, fetch
        p_pop_word  ZL, ZH          ; load address
        ld      r17, Z+
        ld      r16, Z+
        p_push_word  r16, r17       ; put value on p_stack
        jmp     next

def_asm         "@+", 2, $0, fetch_inc ; (addr -- next_addr, value)
        p_pop_word  ZL, ZH          ; load address
        ld      r17, Z+
        ld      r16, Z+
        p_push_word  ZL, ZH     
        p_push_word  r16, r17       ; put value on p_stack
        jmp     next

def_word        "move", 4, $0, move     ; ( from_addr, to_addr, length -- )
        .dw     dup 
        .dw     branch_if 
        .dw     0x0000          ; end if zero
        
        .dw     exit

;; String Ops --------------------
def_asm         "litstring", 9, $0, litstring
        ldi     r18, 0x40       ; addr to global space
        lsl     YL
        rol     YH
        add     YH, r18
        ld      r16, Y+         ; load length
        p_push_word      YL, YH
        adiw    YL, 0x01        ; finish length offset
        sub     YH, r18         ; addr back to flash space
        lsr     YH
        ror     YL

        mov     r17, r16        ; divide by two (word addressed)
        lsr     r17

        p_push  r16
        add     YL, r17         ; add length to instruction pointer
        ldi     r17, 0x00
        adc     YH, r17

        jmp    next 

def_asm         "print", 5, $0, print
        p_pop   r18                 ; load length from stack
        p_pop_word  ZL, ZH          ; load address word from stack
        rcall   print_tx
        jmp    next 
    print_before:
        cp     r18, zeroR          ; is char count exhausted?
        ret
    print_during:
        dec     r18                 ; decrement size and load next for send
        ld      r16, Z+
        ret
    print_tx:  using_usb_tx     print_before, print_during, $0


;; Branching ---------------------
def_asm         "branch", 6, $0, branch
        ldi     r18, 0x40
        lsl     YL              ; load jump offset into r[16:17]
        rol     YH
        add     YH, r18
        ld      r16, Y+
        ld      r17, Y+
        sub     YH, r18
        lsr     YH
        ror     YL
        sbiw    YL, 0x02
        add     YL, r16
        adc     YH, r17
        jmp     next

def_asm         "?branch", 7, $0, branch_if
        p_pop   r16
        ldi     r17, 0x00
        cpse    r16, r17
        rjmp    branch_if_skip
        rjmp    branch
    branch_if_skip:
        adiw    YL, 0x01        ; advance Y past number if skip
        jmp     next

;; I/O ---------------------------
def_asm         "key", 3, $0, key       ; pop next char off in buffer
        mov     ZL, BRL 
        mov     ZH, BRH
        cp      ZL, BWL                ; check if buffer consumed (read=write)
        cpc     ZH, BWH
        breq    key_empty
        ld      r16, Z
        sbiw    ZL, 0x01
        mov     BRL, ZL
        mov     BRH, ZH
        p_push  r16
        jmp     next
key_empty:
        call    usb_rx_wait             ; if buffer empty accept one char
        lds     r16, USART3_RXDATAL
        p_push  r16
        jmp     next

def_asm         "emit", 4, $0, emit
        p_pop   r16                 ; load char from stack
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16 
        jmp     next

def_asm         "word", 4, $0, word
        call    reset_w_buffer
        clr     r18                    ; r18: length counter 
        mov     ZL, BRL                ; load in read pointer
        mov     ZH, BRH
        ldi     r17, 0x20              ; load space for compare
    word_1:
        cp      ZL, BWL                 ; check if buffer consumed or space (read=write)
        cpc     ZH, BWH
        breq    word_empty
        ld      r16, Z
        sbiw    ZL, 0x01
        cp      r16, r17
        breq    word_1                  ; loop if space
    word_2:
        inc     r18                     ; store next char in s buffer
        mov     BRL, ZL                
        mov     BRH, ZH
        movw    ZL, WL 
        st      Z+, r16
        movw    WL, ZL
        mov     ZL, BRL                
        mov     ZH, BRH

        cp      ZL, BWL                 ; check if buffer consumed
        cpc     ZH, BWH
        breq    word_result
        ld      r16, Z                  ; load next char and check if space
        sbiw    ZL, 0x01
        cp      r16, r17
        breq    word_result

        rjmp    word_2
    word_result:
        call    push_w_start
        p_push  r18
        jmp     next
    word_empty:
        ldi     r16, 0x00
        p_push  r16
        jmp     next


def_asm         ">char", 5, $0, to_char
        p_pop   r16
        rcall   _to_char
        p_push  r16
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
        p_pop   r16
        rcall   _from_char
        p_push  r16
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
        
;| r[8:9]          accumulator
;| r2              error 
;| r3              sign 
;| r4              length
;| r6              main counter
;| r5              exponent
;| r7              exp counter

def_asm         "$>#", 3, $0, string_to_num
        p_pop           r4              ; length
        p_pop_word      r16, r17        ; address
        clr             r3              ; sign    
        clr             r2              ; error
        clr             r5              ; subcounter  
        clr             r7
        clr             r9     
        mov     ZL, r16
        mov     ZH, r17
        mov     r6, r4
        in      r18, base_r
        ld      r16, Z+              ; load next char
        cp      r4, zeroR            ; is zero length?
        breq    _stn_end
        cpi     r16, 0x2d            ; is minus sign?
        breq    _stn_minus
    _stn_1:                          ; validate, unchar, put on r stack
        call    _from_char
        dec     r6
        push    r16                  ; keep temp values on r stack
        cp      r16, r18             ; greater than base?
        brge    _stn_error
    _stn_1_cont:
        ld      r16, Z+              ; load next
        cp      r6, zeroR            ; go to next loop if end of string
        breq    _stn_2          
        rjmp    _stn_1

    _stn_2:
        cp      r6, r4               ; is length?
        breq    _stn_done
        inc     r6                   ; increment main ct
        
        pop     r16                  ; get next 
        cp      r5, zeroR            ; just add if b^0
        breq    _stn_do_first     

        clr     r17
        clr     r19
        clr     r21
        in      r18, base_r
        mov     r7, r5                  ; move exp to counter
    _stn_2_mul:
        cp      r7, zeroR
        breq    _stn_2_mul_done
        call    _multiplication  
        movw    r16, r20             ; move mul result to next multiplicand 
        dec     r7
        rjmp    _stn_2_mul
    _stn_2_mul_done:
        inc     r5                   ; inc sub counter (exponent)
        add     r8, r20
        adc     r9, r21
        cp      r22, zeroR
        cpc     r23, zeroR
        brne    _stn_overflow
        rjmp    _stn_2
        
    _stn_do_first:
        mov     r8, r16
        inc     r5
        rjmp    _stn_2
    _stn_minus:                        ; mark negative
        inc     r3
        dec     r6                     ; dec length
        dec     r4
        ld      r16, Z+                ; load next
        rjmp    _stn_1
    _stn_error:
        inc     r2
        ld      r16, Z+
        rjmp    _stn_1_cont
    _stn_done:
        cp      r3, zeroR
        brne    _stn_do_sign
    _stn_done_1:
        p_push_word     r8, r9
    _stn_end:
        p_push   r2              ; push error if any
        jmp     next
    _stn_do_sign:
        com     r8
        com     r9
        add     r8, oneR
        adc     r9, zeroR     
        rjmp    _stn_done_1
    _stn_overflow:              ; overflow error
        inc     r2
        rjmp    _stn_2

def_asm         "#>$", 3, $0, num_to_string
        clr     r0              ; length counter
        clr     r4              ; sign 
        p_pop_word   r22, r23   ; load dividend from stack
        sbrc    r23, 7
        rcall   _nts_sign       ; add negative sign if msb set
        in      r16, base_r     ; load divisor (base)
        clr     r17
    _nts_loop:
        call    _division

        cp      r20, zeroR      ; is quotient zero?
        cpc     r21, zeroR
        breq    _nts_write
        
        inc     r0
        push    r19             ; temporarily keep remainders on return stack
        push    r18
        mov     r22, r20        ; do next with quotient
        mov     r23, r21
        rjmp    _nts_loop

    _nts_done:
        ldi     ZL, Low(buffer_start)           ; put string addr / length on stack
        ldi     ZH, High(buffer_start)
        p_push_word     ZL, ZH
        p_push          r0
        jmp     next
    _nts_write:
        inc     r0                              ; push last remainder
        push    r19           
        push    r18
        mov     r18, r0
        ldi     ZL, Low(buffer_start)
        ldi     ZH, High(buffer_start)
        cpse    r4, zeroR
        rcall   _nts_do_sign
    _nts_write_loop:                            ; pop results and write (to reverse)
        cp      r18, zeroR
        breq    _nts_done
        dec     r18
        pop     r16
        pop     r1
        call    _to_char
        st      Z+, r16
        rjmp    _nts_write_loop  

    _nts_sign:
        com     r22
        com     r23
        add     r22, oneR 
        adc     r23, zeroR
        inc     r4
        inc     r0
        ret
    _nts_do_sign:
        ldi     r16, '-'
        st      Z+, r16
        ret

;; Dictionary Ops ----------------
_skip_word_name:
        push    r3
        sbrs    r3, 0         ; deal with byte padding for things that take up odd numbers of space
        inc     r3
        add     ZL, r3
        adc     ZH, zeroR
        pop     r3
        ret

_back_to_name:
        push    r3
        sbrs    r3, 0         ; deal with byte padding for things that take up odd numbers of space
        inc     r3
        sub     ZL, r3
        sbc     ZH, zeroR
        sbiw    ZL, 0x01        ; back up past flag
        pop     r3
        ret

;| r[22:23]     accumulator
;| r[20:21]     next address
;| r[18:19]     target address

;| r[6:7]       target safekeeping
;| r2           target length
;| r3           this length

;| r4           detail counter
def_asm         "find", 4, $0, find
        clr     r22                         ; setup acc
        clr     r23
        clr     r4
        ldi     r18, Low(dict_start)        ; check if any dict in ram (ram_latest == dict_start)
        ldi     r19, High(dict_start)
        ldi     ZL, Low(ram_latest_pt)
        ldi     ZH, High(ram_latest_pt)
        ld      r16, Z+
        ld      r17, Z+
        cp      r16, r18
        cpc     r17, r19
        breq    find_prog
    find_ram:
    ;todo
    find_prog:
        p_pop   r2                              ; load target length r2 
        p_pop_word  r18, r19                    ; load target addr r[18:19]
        mov     r6, r18
        mov     r7, r19
        ldi     ZL, Low(prog_latest_pt)         ; move prog_latest into Z
        ldi     ZH, High(prog_latest_pt)
        ld      r16, Z+
        ld      r17, Z+
        movw    ZL, r16
        call    _flash_to_global
        ld      r20, Z+                         ; load next address
        ld      r21, Z+

    find_loop:
        mov     r8, r20
        mov     r9, r21
        ld      r3, Z+                          ; get length
        cp      r2, r3                          ; go to next if word different
        brne    find_next
        rcall   _skip_word_name                 ; advance Z to compile flag
        ld      r16, Z+
        sbrc    r16, 6                          ; skip if hidden
        rjmp    find_next

        cp      r2, r3                          ; compare detail if length same
        breq    find_detail
    find_next:
        movw    ZL, r20
        call    _flash_to_global
        ld      r20, Z+                         ; load next address
        ld      r21, Z+
        cp      r20, zeroR
        cpc     r21, zeroR
        breq    find_not_found
        rjmp    find_loop
    find_detail:
        rcall    _back_to_name
        mov     r4, r3
    detail_loop:
        cp      r4, zeroR                     
        breq    find_found                      ; all chars are same    
        dec     r4                              ; else decrement length
        ld      r16, Z+                         ; compare next
        push    ZL                              ; get chars to compare
        push    ZH   
        movw    ZL, r18
        ld      r17, Z+
        movw    r18, ZL
        pop     ZH
        pop     ZL
        cp      r16, r17                        ; do compare
        brne    detail_exit                     ; didn't match
        rjmp    detail_loop                     ; did match
    detail_exit:        
        mov     r18, r6                         ; restore target address
        mov     r19, r7
        rjmp    find_next
    find_found:
        call    _back_to_name
        sbrs    r3, 0                   ; increment if word has even number of letters
        adiw    ZL, 0x01
        sbiw    ZL, 0x02                  ; back up to word link
        p_push_word     ZL, ZH                 
        jmp     next
    find_not_found:
        p_push  zeroR
        jmp     next

def_asm         ">xt", 3, $0, to_xt
        p_pop_word    r16, r17          ; get address from stack
        mov     ZL, r16                 ; load into Z                                                          
        mov     ZH, r17
        adiw    ZL, 0x02                ; skip past word link
        ld      r3, Z+                  ; get length
        call    _skip_word_name
        adiw    ZL, 0x02                ; skip past flag
        ldi     r16, 0x40               ; convert to flash address
        sub     ZH, r16
        lsr     ZH
        ror     ZL
        p_push_word     ZL, ZH
        jmp     next
;; Compiling ---------------------
; def_asm         "create", 6, $0, create
; def_asm         ",", 1, $0, comma
; def_asm         "[", 1, f_immediate, engage
; def_asm         "]", 1, $0, disengage
; def_word        ":", 1, $0, colon
; def_word        ";", 1, f_immediate, semicolon
; def_asm         "immediate", 9, f_immediate, immediate
; def_asm         "hidden", 6, $0, hidden
; def_asm         0x27, 1, $0, get_xt 
;; Interpreting ------------------
def_asm        "quit", 4, $0, main               ; Main system loop
        .dw     reset                            ;   Notice that it's defined as asm despite being a 
        .dw     accept                           ;   forth word. There is no call to 'do' included, 
        .dw     interpret                        ;   since as the outer loop it doesn't really need 
        .dw     branch                           ;   to put anything on the return stack
        .dw     0xfffd                           ; -3

def_asm         "accept", 6, $0, accept         ; read from tty into buffer until cr
        mov     ZL, BWL
        mov     ZH, BWH
        rcall   tty_rx
        jmp     next
    before_each_rx:
        lds     r16, USART3_RXDATAL         ; load next char from serial
        cpi     r16, $0D                    ; check if cr
        ret
    on_each_rx:
        st      Z, r16                      ; store and increment recieved char
        sbiw    ZL, 0x01                    ; decrement Z (in buffer grows down!)
        cpi     r16, 0x7F                    ; check if backspace
        breq    do_backspace
        rcall   usb_tx_wait                 ; echo back each character typed in tty
        sts     USART3_TXDATAL, r16   
    on_each_rx_skip:
        ret  
    rx_end:
        mov     BWL, ZL
        mov     BWH, ZH
        ret
    tty_rx:     using_usb_rx    before_each_rx, on_each_rx, rx_end

    do_backspace:
        adiw    ZL, 0x02                     ; drop one from in buffer
        ldi     r16, $08                     ; send backspace
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16 
        ldi     r16, $20                    ; send space
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16 
        ldi     r16, $08                    ; send backspace
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16
        ret

def_word        '.', 1, $0, dot
        .dw     num_to_string
        .dw     print
        .dw     exit

def_asm         "\n", 2, $0, cr
        rcall   _cr      
        jmp     next
_cr: 
        ldi     r16, $0d                    ; send \r
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16             
        ldi     r16, $0a                    ; send \n
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16   
        ret

def_asm         "\s", 2, $0, sp
        rcall   _sp      
        jmp     next
_sp: 
        ldi     r16, $20                    ; send space
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16             
        ret

def_asm         "\t", 2, $0, tab 
        rcall   _tab      
        jmp     next
_tab: 
        ldi     r16, $09                    ; send tab
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16             
        ret

;;      The Outer Interpreter
def_word        "interpret", 9, $0, interpret
        .dw     word                    ; (addr?, len)
        .dw     dup                     ; (addr?, len, len)
        .dw     branch_if               ; (addr?, len)
        .dw     0x0013                  ; finish interpreter loop
        .dw     dup_two                 ; (addr, len, addr, len)
        .dw     find                    ; (addr, len, word?)
        .dw     dup                     ; (addr, len, word?, word?)
        .dw     branch_if               ; (addr, len, word)
        .dw     0x0009                  ; to num
        .dw     inv_rot                 ; (word, addr, len)
        .dw     drop_two                ; (word)
        .dw     to_xt                   ; (xt)
        .dw     execute                 ; ()
        .dw     syscheck
        .dw     branch 
        .dw     0xfff2                  ; loop interpreter
        .dw     drop                    ; (addr, len)
        .dw     string_to_num           ; (num, error?)
        .dw     branch_if 
        .dw     0xffee                  ; loop if error is zero (num)
        .dw     syn_err                 ; else error
        .dw     drop
        .dw     ok
        .dw     exit

def_word         "clear", 5, $0, clear
        .dw     litstring
        .db     0x0e, 0x1b, "[2J", 0x1b, "[20A", 0x1b, "[20D"
        .dw     print
        .dw     main

def_word        "ok", 2, $0, ok
        .dw     litstring
        .db     3," ok"
        .dw     print
        .dw     cr 
        .dw     exit

def_word        "synerr", 6, $0, syn_err
        .dw     litstring
        .db     13," syntax error"
        .dw     print
        .dw     cr 
        .dw     abort

def_word        "undererr", 8, $0, under_err
        .dw     litstring
        .db     16," stack underflow"
        .dw     print
        .dw     cr 
        .dw     abort

def_asm        "abort", 5, $0, abort
        call    reset_p
        jmp     next

def_asm         "syscheck", 8, $0, syscheck
        ldi     r16, Low(p_stack_start)
        ldi     r17, High(p_stack_start)
        cp      XL, r16
        cpc     XH, r17
        brlt    syscheck_under
        jmp     next
    syscheck_under:
        ldi     ZL, Low(under_err) 
        ldi     ZH, High(under_err)
        ijmp

;; End Dictionary ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;; Transmission wait ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
usb_rx_wait: usb_rx_wait
usb_tx_wait: usb_tx_wait

;; Utilities ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

; todo: eeprom for config, clock/timer/usart/spi/port defaults etc.
setup_data_seg: 
        ldi     ZL, Low(SRAM_START)         ; init working pointer to sram start
        ldi     ZH, High(SRAM_START)
        ldi     r16, Low(word_link)         ; move prog_latest pointer into ram
        ldi     r17, High(word_link)
        st      Z+, r16
        st      Z+, r17
        ldi     r16, Low(dict_start)        ; move ram_latest pointer into ram
        ldi     r17, High(dict_start)
        st      Z+, r16
        st      Z+, r17
        ldi     r16, Low(prog_here)         ; move prog_here pointer into ram
        ldi     r17, High(prog_here)
        st      Z+, r16
        st      Z+, r17
        ldi     r16, Low(dict_start)        ; move ram_here pointer into ram
        ldi     r17, High(dict_start)
        st      Z+, r16
        st      Z+, r17
        ldi     r16, 0x00                   ; padding
        st      Z+, r16
        ldi     r16, 0x00
        out     state, r16
        ldi     r16, 0x10                   ; set default base 
        out     base_r, r16
        
        
        ret

reset_w_buffer:
        ldi     WL, Low(buffer_start + 0x100)
        ldi     WH, High(buffer_start + 0x100)
        ret
reset_in_buffer:
        ldi     r16, Low(p_stack_start - 0x02)
        ldi     r17, High(p_stack_start - 0x02)
        mov     BRL, r16
        mov     BRH, r17
        mov     BWL, r16
        mov     BWH, r17

        ret

push_w_start:
        ldi     r16, Low(w_buffer_start)
        ldi     r17, High(w_buffer_start)
        p_push_word     r16, r17
        ret

reset_p:
        ldi     XL, Low(p_stack_start)      ; reset parameter stack
        ldi     XH, High(p_stack_start)

        ret

_flash_to_global:                ; multiply by 2 and add 0x4000 for flash mem (using ld)
        lsl     ZL
        rol     ZH
        ldi     r16, 0x40
        add     ZH, r16
        ret

;;  rx/tx ------------------------


;;  End of Core ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
prog_here: