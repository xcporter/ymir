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
;   | Link Address | Flags/Length | Definition |
;   | 2 B          | n B          | n B        |
;                 /                \
;    ____________/                  \__________________
;   |f_immediate | f_hidden | f_no_flash | Length[4:0] |

;;  IO Registers ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;       State: | neg | 0b | 0b | 0b | 0b | 0b | 0b | compile |
        .equ        state           = GPIO_GPIOR0

        .equ        base_r          = GPIO_GPIOR1

        .equ        coroutine_pt    = GPIO_GPIOR2

;       Number format: | sign [default true] | base literal | 0b | padding [5:0] |
        .equ        num_format      = GPIO_GPIOR3 


;;  System Memory ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;   0x00 : prog_latest | ram_latest | prog_here | ram_here | 0x00

;; RAM layout: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;  start:| System | Buffer | P stack >| Ram Dictionary> |< R stack  |:end
;        | 256 B  | 2kB    | 1024 B   |  2.6kB          | min 512 B |
;                /          \________________________
;               | pad 256B | w_buffer >|< in_buffer  |

        .equ        p_stack_start = buffer_start + buffer_size
        .equ        w_buffer_start = buffer_start + 0x100
        .equ        dict_start = p_stack_start + p_stack_max

;; Setup ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        .cseg
        .org    0x0000

        ldi     ZL, Low(RSTCTRL_RSTFR)  ; get reset reason
        ldi     ZH, High(RSTCTRL_RSTFR)
        ld      r5, Z

        ldi     r16, Low(RAMEND)        ; init stack pointer
        ldi     r17, High(RAMEND)
        out     CPU_SPL, r16
        out     CPU_SPH, r17

        clr     zero                   ; set up constant registers (0 and 1)
        clr     one 
        inc     one 
        setup_usb

        call    reset_reason 
        call    load_data_seg
        call    reset_p
        call    reset_sysreg
        

;;  Start ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        ldi     ZL, Low(main)           ; perhaps add another layer of deflection for user configurable init
        ldi     ZH, High(main)
        ijmp

;; Terminal Core ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;       Kernel and execution flow
do:
        push    YH
        push    YL
        
        adiw    ZL, 0x02  ; opcode is 4 bytes

        movw    YL, ZL
        lsl     YL        ; Instruction pointer is in global address space
        rol     YH
        ldi     r16, 0x40
        add     YH, r16
        rjmp    next
done:
        pop     YL
        pop     YH
next:
        ld      ZL, Y+
        ld      ZH, Y+
        ijmp


;; Dictionary ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
def_asm         "execute", 7, $0, execute
        p_pop_word      ZL, ZH
        ijmp
          
def_asm         "exit", 4, $0, exit
        rjmp    done

def_asm         "lit", 3, $0, literal           ; Retrieve next as num and put on P-stack
        ld      r16, Y+
        ld      r17, Y+
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
    
;; System Constants and Ops ------
def_const       "r0", 2, $0, r_stack_zero, RAMEND

def_asm         "&r", 2, $0, r_stack_pt
        in      r16, CPU_SPL
        in      r17, CPU_SPL
        p_push_word     r16, r17
        jmp     next

def_const       "p0", 2, $0, p_start, p_stack_start

def_asm         "base@", 5, $0, get_base      
        in      r16, base_r
        p_push  r16
        jmp     next

def_asm         "base!", 5, $0, set_base 
        p_pop   r16
        out     base_r, r16
        jmp     next
def_asm         "&p", 2, $0, p_stack_pt
        p_push_word     XL, XH
        jmp     next

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
        p_pop   r17
        in      r16, num_format
        andi    r16, 0b11100000         ; clear last fmt
        or      r17, r16                ; add mask to new digit value
        out     num_format, r17
        jmp     next

; Access pointers ----------------

def_const       "&prog.latest", 12, $0, p_latest_pt, SRAM_START
def_const       "&ram.latest", 11, $0, r_latest_pt, SRAM_START + 0x02

def_const       "&prog.here", 10, $0, p_here_pt, SRAM_START + 0x04
def_const       "&ram.here", 9, $0, r_here_pt, SRAM_START + 0x06

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
        pop     r16
        pop     r17 
        push    r17 
        push    r16
        p_push_word  r16, r17       ; put it onto the param stack
        jmp     next

def_asm         "!r", 2, $0, store_r
        p_pop_word   r16, r17       ; get top of p stack
        adiw    XL, 0x02            ; offset p stack pointer
        push    r17
        push    r16 
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

        ; .dw     p_stack_pt 
        ; .dw     p_start
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
        ; .dw     p_start 
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
    mul_push:
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

def_asm         "**", 2, $0, exponent
        p_pop_word      r18, r19        ; power from stack
        p_pop_word      r16, r17        ; base from stack
        rcall           _exponent
        rjmp            mul_push

;| r[22:23]     result high  
;| r[20:21]     result low
;| r[18:19]     power
;| r[16:17]     base
_exponent:
        clr     r22
        clr     r23     
        movw    r4, r18         ; power as counter
        cp      r18, zeroR
        cpc     r19, zeroR
        breq    _exp_zero
        cp      r18, oneR
        cpc     r19, zeroR
        breq    _exp_one
        movw    r18, r16
        sub     r4, oneR        ; decrement
        sbc     r5, zeroR 

    _exp_loop:
        cp      r4, zeroR
        cpc     r5, zeroR
        breq    _exp_done

        sub     r4, oneR        ; decrement
        sbc     r5, zeroR        

        rcall   _multiplication
        movw    r18, r20        ; put result (low) for next multiply

        rjmp    _exp_loop

    _exp_zero:
        clr     r21
        mov     r20, oneR 
        ret
        
    _exp_one:
        movw     r20, r16 
        ret
    _exp_done:
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

def_asm         "sqrt", 4, $0, square_root ; (input -- root, remainder)
        p_pop_word      r16, r17
        rcall           _square_root
        p_push_word     r0, r1
        p_push_word     r2, r3
        jmp     next

;| r20 counter
;| r[16:17] in
;| r[2:3] Remainder
;| r[0:1] Root 
_square_root:
        clr     r2 
        clr     r3
        movw    r0, r2
        ldi     r20, 0x08
_sqrt_loop:
        lsl     r0      ; root * 2
        rol     r1

        lsl     r16     ; shift 2 bits from input into rem
        rol     r17
        rol     r2
        rol     r3

        lsl     r16     
        rol     r17
        rol     r2
        rol     r3

        cp      r0, r2
        cpc     r1, r3
        brcc    _sqrt_end
        inc     r0
        sub     r2, r0
        sbc     r3, r1
        inc     r0
_sqrt_end:
        dec     r20
        brne    _sqrt_loop
        lsr     r1
        ror     r0
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
        st      Z+, r16
        st      Z+, r17
        jmp     next

def_asm         "!+", 2, $0, store_inc       ; ( val, addr -- addr + 1)
        p_pop_word  ZL, ZH              ; load address
        p_pop_word  r16, r17
        st      Z+, r16
        st      Z+, r17
        p_push_word  ZL, ZH
        jmp     next

def_asm         "@", 1, $0, fetch
        p_pop_word  ZL, ZH          ; load address
        ld      r16, Z+
        ld      r17, Z+
        p_push_word  r16, r17       ; put value on p_stack
        jmp     next

def_asm         "@+", 2, $0, fetch_inc ; (addr -- next_addr, value)
        p_pop_word  ZL, ZH          ; load address
        ld      r16, Z+
        ld      r17, Z+
        p_push_word  ZL, ZH     
        p_push_word  r16, r17       ; put value on p_stack
        jmp     next

def_asm         "<move<", 5, $0, double_reverse_move
        push     YH
        push     YL

        p_pop_word      YL, YH  ; destination
        p_pop   r18             ; length
        p_pop_word      ZL, ZH

    _rr_move_loop:
        cp      r18, zeroR
        breq    _move_done
        dec     r18 
        ld      r16, Z
        sbiw    ZL, 0x01
        st      Y, r16
        sbiw    YL, 0x01
        rjmp    _rr_move_loop

def_asm         "move<", 5, $0, reverse_move
        push     YH
        push     YL

        p_pop_word      YL, YH  ; destination
        p_pop   r18             ; length
        p_pop_word      ZL, ZH

    _r_move_loop:
        cp      r18, zeroR
        breq    _move_done
        dec     r18 
        ld      r16, Z+
        st      Y, r16
        sbiw    YL, 0x01
        rjmp    _r_move_loop
def_asm        "move", 4, $0, move     ; ( from_addr, length, to_addr -- )
        push     YH
        push     YL

        p_pop_word      YL, YH  ; destination
        p_pop   r18             ; length
        p_pop_word      ZL, ZH

    _move_loop:
        cp      r18, zeroR
        breq    _move_done
        dec     r18 
        ld      r16, Z+
        st      Y+, r16
        rjmp    _move_loop
    _move_done:
        pop      YL
        pop      YH
        jmp     next 

;; String Ops --------------------
def_asm         "litstring", 9, $0, litstring
        ld      r16, Y+                 ; load length

        p_push_word      YL, YH
        p_push           r16      ; push length

        sbrs    r16, 0          ; account for padding if length even (total odd)
        inc     r16

        add     YL, r16                 ; add length to instruction pointer
        adc     YH, zeroR

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

def_word        "dump", 4, $0, dump
        .dw     cr 

        .dw     to_r        ; put length on return stack

        .dw     literal 
        .dw     0x0000

        .dw     dup 
        .dw     fetch_r
        .dw     not_equal
        .dw     branch_if
        .dw     0x0012          ; end if count == length

        .dw     incr             

        .dw     dup 
        .dw     literal 
        .dw     0x0008
        .dw     div_mod    
        .dw     swap 
        .dw     drop 
        .dw     branch_if
        .dw     0x000d          ; wrap text?     

        .dw     to_r 

        .dw     fetch_inc
        .dw     dot 
        .dw     sp 

        .dw     from_r 
        .dw     branch 
        .dw     0xffed 

        .dw     from_r
        .dw     drop_two   
        .dw     drop        
        
        .dw     exit

        .dw     cr                      ; do wrap
        .dw     branch 
        .dw     0xfff4                  ; return                          

;; Branching ---------------------
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
        p_pop   r16
        cpse    r16, zeroR
        rjmp    branch_if_skip
        rjmp    branch
    branch_if_skip:
        adiw    YL, 0x02        ; advance Y past number if skip
        jmp     next

;; I/O ---------------------------
def_asm         "key", 3, $0, key       ; pop next char off in buffer
        ; mov     ZL, BRL 
        ; mov     ZH, BRH
        ; cp      ZL, BWL                ; check if buffer consumed (read=write)
        ; cpc     ZH, BWH
        ; breq    key_empty
        ; ld      r16, Z
        ; sbiw    ZL, 0x01
        ; mov     BRL, ZL
        ; mov     BRH, ZH
        ; ppush  r16
        jmp     next
key_empty:
        call    usb_rx_wait             ; if buffer empty accept one char
        lds     r16, USART3_RXDATAL
        ppush  r16
        jmp     next

def_asm         "emit", 4, $0, emit
        ppop   r16                 ; load char from stack
        call    usb_tx_wait
        sts     USART3_TXDATAL, r16 
        jmp     next

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


;| r[8:9] current char, base
;| r[6:7] accumulator
;| r5   error
;| r[2:3] length count, length

def_asm         ">num", 4, $0, string_to_num            ; (addr, length -- num, error)
        cbi     state, 7 
        clr     r5
        clr     r6
        clr     r7
        p_pop           r2              ; length
        mov     r3, r2
        p_pop_word      ZL, ZH          ; address

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
        push    zeroR                   ; otherwise push unchared num to r stack
        push    r16

        cp      r2, zeroR
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
        p_push_word     r6, r7          ; push result
        p_push          r5              ; push error
        jmp     next

;|      r0 length counter
def_asm         "num>", 4, $0, num_to_string
        clr     r0                              ; length counter [r0]
        ; ldi     ZL, Low(buffer_start)           ; load pad address into Z
        ; ldi     ZH, High(buffer_start)
        sbic    num_format, 7                   ; if using signed numbers, do sign
        rjmp    _nts_sign
    _nts_start:
        in      r16, base_r                     ; load divisor (base)
        clr     r17

     _nts_loop:
        call    _division

        cp      r20, zeroR      ; is quotient zero?
        cpc     r21, zeroR
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
        cp      r0, zeroR
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
        cp      r0, zeroR
        breq    _nts_skip_format
        dec     r0
        push    zeroR
        push    zeroR
        rjmp    _nts_format_loop

    _nts_skip_format:
        mov     r0, r1                  ; put back counter for write
        rjmp    _nts_write_cont
    _nts_done:   
        ; ldi     ZL, Low(buffer_start)           ; put string addr / length on stack
        ; ldi     ZH, High(buffer_start)
        jmp     next
        

;; Dictionary Ops ----------------


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
                    

        p_pop           r21                  ; load target length
        p_pop_word      r18, r19              ; load target address
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
        
        cp      YL, zeroR
        cpc     YH, zeroR
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
        cp      r20, zeroR                     
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
        p_push_word     YL, YH          ; put on p stack  
        rjmp    find_done
    find_not_found:
        p_push  zeroR
    find_done:
        pop     YL                      ; put back instruction pointer
        pop     YH 
        jmp     next

def_asm         ">xt", 3, $0, to_xt
        p_pop_word    ZL, ZH            ; get address from stack
        adiw    ZL, 0x02                ; skip past word link
        ld      r16, Z+                 ; get length
        andi    r16, 0b00011111         ; mask flags

        sbrs    r16, 0         ; deal with byte padding for things that take up odd numbers of space
        inc     r16

        add     ZL, r16        ; move pointer to start of definition
        adc     ZH, zeroR

        call    _global_to_flash
        p_push_word     ZL, ZH
        jmp     next

;; Compiling ---------------------
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
; def_asm         "[", 1, f_immediate, engage
; def_asm         "]", 1, $0, disengage
; def_word        ":", 1, $0, colon
; def_word        ";", 1, f_immediate, semicolon
; def_asm         "immediate", 9, f_immediate, immediate
def_asm         "hide", 4, $0, hide
        p_pop_word      ZL, ZH
        adiw    ZL, 0x02
        ld      r16, Z 
        ori     r16, 0b01000000
        st      Z, r16
        jmp     next 
def_asm         "unhide", 6, $0, unhide
        p_pop_word      ZL, ZH
        adiw    ZL, 0x02
        ld      r16, Z 
        andi     r16, 0b10111111
        st      Z, r16
        jmp     next 
;; Interpreting ------------------
def_word        "quit", 4, $0, main              ; Main system loop
        .dw     reset                            ;  
        .dw     accept                           ;   
        .dw     interpret                        ;   
        .dw     branch                           ;  
        .dw     0xfffd                           ; -3

; def_asm       "test", 4, $0, test 
;         call    pagebuf_clear
;         ldi     r16, 0xbb
;         ldi     r18, 0x00
;         ldi     r19, 0x14

;         ldi     ZL, Low(NVMCTRL_ADDRL)
;         ldi     ZH, High(NVMCTRL_ADDRL)
;         st      Z+, r18
;         st      Z+, r19

;         movw    ZL, r18

;         st      Z+, r16 
;         st      Z+, r16 
;         st      Z+, r16 
;         st      Z+, r16 
;         st      Z+, r16 
;         st      Z+, r16 
;         st      Z+, r16 
;         st      Z+, r16 
;         st      Z+, r16 
;         st      Z+, r16 
;         st      Z+, r16 
;         st      Z+, r16 

;         ldi     ZL, Low(NVMCTRL_CTRLA)
;         ldi     ZH, High(NVMCTRL_CTRLA)

;         call    nvm_wait

        

;         ldi     r16, 0x01
;         ccp_spm_unlock
;         st      Z, r16

;         jmp     next

def_asm         "accept", 6, $0, accept         ; read from tty into buffer until cr
;         mov     ZL, BWL
;         mov     ZH, BWH
;         rcall   tty_rx
;         jmp     next
;     before_each_rx:
;         lds     r16, USART3_RXDATAL         ; load next char from serial
;         cpi     r16, $0D                    ; check if cr
;         ret
;     on_each_rx:
;         st      Z, r16                      ; store and increment recieved char
;         sbiw    ZL, 0x01                    ; decrement Z (in buffer grows down!)
;         cpi     r16, 0x7F                    ; check if backspace
;         breq    do_backspace
;         rcall   usb_tx_wait                 ; echo back each character typed in tty
;         sts     USART3_TXDATAL, r16   
;     on_each_rx_skip:
;         ret  
;     rx_end:
;         mov     BWL, ZL
;         mov     BWH, ZH
;         ret
;     tty_rx:     using_usb_rx    before_each_rx, on_each_rx, rx_end

;     do_backspace:
;         adiw    ZL, 0x02                     ; drop one from in buffer
;         ldi     r16, $08                     ; send backspace
;         call    usb_tx_wait
;         sts     USART3_TXDATAL, r16 
;         ldi     r16, $20                    ; send space
;         call    usb_tx_wait
;         sts     USART3_TXDATAL, r16 
;         ldi     r16, $08                    ; send backspace
;         call    usb_tx_wait
;         sts     USART3_TXDATAL, r16
;         ret

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
        jmp     main 

def_asm         "syscheck", 8, $0, syscheck
        ; ldi     r16, Low(p_stack_start)
        ; ldi     r17, High(p_stack_start)
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
load_data_seg: 
        ldi     ZL, Low(EEPROM_START)          
        ldi     ZH, High(EEPROM_START)

        push    YH
        push    YL

        ldi     YL, Low(SRAM_START)
        ldi     YH, High(SRAM_START)

    load_ds_loop:
        ld      r17, Z+         ; load next from eeprom
        ld      r16, Z+

        cp      r16, zeroR      ; break if zero word found
        cpc     r17, zeroR
        breq    load_ds_end

        st      Y+, r17
        st      Y+, r16
        
        rjmp    load_ds_loop

    load_ds_end:
        pop     YL
        pop     YH

        ret

        
reset_sysreg:
        out     state, zeroR
        out     coroutine_pt, zeroR
        ldi     ZL, Low(EEPROM_START + 0x08)        ; load base into GPIOR
        ldi     ZH, High(EEPROM_START + 0x08)
        ld      r16, Z+
        ld      r17, Z+
        out     base_r, r16
        out     num_format, r17                   ; clear number fmt
        ret 
reset_w_buffer:
        ; ldi     WL, Low(buffer_start + 0x100)
        ; ldi     WH, High(buffer_start + 0x100)
        ; ret
reset_in_buffer:
        ; ldi     r16, Low(p_stack_start - 0x02)
        ; ldi     r17, High(p_stack_start - 0x02)
        ; mov     BRL, r16
        ; mov     BRH, r17
        ; mov     BWL, r16
        ; mov     BWH, r17

        ret

push_w_start:
        ; ldi     r16, Low(w_buffer_start)
        ; ldi     r17, High(w_buffer_start)
        ; _ppush     r16, r17
        ; ret

reset_p:
        ; ldi     XL, Low(p_stack_start)      ; reset parameter stack
        ; ldi     XH, High(p_stack_start)

        ; ret

_flash_to_global:                ; multiply by 2 and add 0x4000 for flash mem (using ld)
        lsl     ZL
        rol     ZH
        ldi     r16, 0x40
        add     ZH, r16
        ret

_global_to_flash:
        ldi     r18, 0x40
        sub     ZH, r18         ; addr back to flash space
        lsr     ZH
        ror     ZL
        ret

do_const:
        p_push_word      r16, r17           ; puts on p stack
        jmp      next

do_const_b:
        p_push     r16                     ; puts on p stack
        jmp      next


nvm_wait:
        ldi     ZL, Low(NVMCTRL_STATUS)
        ldi     ZH, High(NVMCTRL_STATUS)

        ld      r16, Z
        sbrc    r16, 1
        rjmp    nvm_wait

        sbrc    r16, 0
        rjmp    nvm_wait
        ret 
pagebuf_clear:
        rcall   nvm_wait

        ldi     ZL, Low(NVMCTRL_CTRLA)
        ldi     ZH, High(NVMCTRL_CTRLA)
        ldi     r17, 0x04
        ccp_spm_unlock

        st      Z, r17
        ret

;;  rx/tx ------------------------



;;  End of Core ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
prog_here:

;;  System Memory ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;               Default system values in eeprom
        .eseg
        .org    0x0000

    prog_latest:
        .dw     (word_link << 1) + 0x4000              
    ram_latest:
        .dw     (word_link << 1) + 0x4000             
    prog_here_e:
        .dw     (prog_here << 1) + 0x4000              
    ram_here:
        ; .dw     dict_start              
    default_base:
        .dw     0x000A   

        .dw     0x0000