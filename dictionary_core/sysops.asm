;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> SYSOPS
;*      
;*      Operations for manipulating the forth runtime
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************


def_asm         "exec", 4, 0, exec 
        sbiw    SL, 0x02 
        movw    ZL, TOSL 
        cache_tos
        ijmp

; Retrieve next as num and put on P-stack
def_asm         "lit", 3, 0, literal  
        ld      TOSL, Y+         
        ld      TOSH, Y+
        push_tos
        rjmp    next 

; String literal
; 
def_asm         "strlit", 6, $0, strlit
        ld      r18, Y+                 ; load length 
        clr     r19

        _ppush  IL, IH                  ; instruction pt to p stack  
        movw    TOSL, r18               ; push length 
        push_tos        

        sbrs    TOSL, 0                 ; account for padding if length even (total odd)
        inc     TOSL 
        add     IL, TOSL                ; increment IP by length + padding
        adc     IH, zero

        jmp      next 

; direct to init vector
def_word        ":boot", 5, 0, boot
        .dw     init_v                 ; do init vector
        .dw     fetch 
        .dw     exec  

; Default system configuration
; Setup: clock, portmux, tx/rx, baud, pullup resistors
def_asm         "init0", 6, 0, init_zero 
        ldi     r17, 0x01               ; set clock prescalar to 2 (8MHz clk_per)
        ccp_ioreg_unlock 
        sts     CLKCTRL_MCLKCTRLB, r17

        .equ    baud_fr = (8000000*64)/(115200*16) ; default baud of 115200

        ldi         r16, Low(baud_fr)
        ldi         r17, High(baud_fr)
        sts         USART3_BAUDL, r16           
        sts         USART3_BAUDH, r17

        sts     USART3_CTRLA, zero      ; no interrupts
        ldi     r16, 0b11001000         ; enable tx / rx,  open drain, mode: normal, no multiprocessor
        sts     USART3_CTRLB, r16
        ldi     r16, 0b00100011         ; async, even parity, 1 stop bit, 8 bit char size
        sts     USART3_CTRLC, r16

        ldi     r16, 0x44               ; connect USART3 to the other uC, and USART1 to the pinout tx/rx
        sts     PORTMUX_USARTROUTEA, r16

        ldi     r16, 0x10               ; tx out
        sts     PORTB_DIRSET, r16

        ldi     r16, 0x20               ; rx in
        sts     PORTB_DIRCLR, r16

        ldi     r16, 0x08               ; engage pullup resistors 
        sts     PORTB_PIN4CTRL, r16 
        sts     PORTB_PIN5CTRL, r16 
        jmp     next
def_word         "sysinit", 7, 0, sys_init
        .dw     init_zero       ; hardware init

        .dw     core_v          ; set :lexicon to :core 
        .dw     fetch 
        .dw     lexicon_v
        .dw     store           

        .dw     sram_init       ; from
        .dw     literal         ; to
        .dw     SRAM_START + 2
        .dw     literal         ; 30 bytes
        .dw     0x001e
        .dw     move 
        .dw     quit 

def_word         "quit", 4, 0, quit
        .dw     r_clr 
        .dw     clear_parse_offset

        .dw     tib_start
        .dw     fetch
        .dw     dup 
        .dw     literal 
        .dw     0x000d
        .dw     tib_size
        .dw     fetch 
        .dw     accept 
        .dw     cr 
        .dw     print
        .dw     ok_msg 
        .dw     print
        .dw     cr 
        .dw     quit

def_asm         ":check", 8, 0, syscheck
        jmp     next 

def_asm         "rclr", 4, 0, r_clr
        ldi     ZL, Low(r_start)        ; get position in system ram vars               
        ldi     ZH, High(r_start)
        ld      r18, Z+
        ld      r19, Z+ 
        movw    ZL, r18                 ; fetch ^r
        ld      r18, Z+
        ld      r19, Z+ 
        out     CPU_SPL, r18            ; set stack pointer
        out     CPU_SPH, r19
        jmp     next

def_word         "pclr", 4, 0, p_clr
        .dw     p_start
        .dw     fetch
        .dw     p_pt_set
        .dw     done 

def_word        "0>in", 4, 0, clear_parse_offset
        .dw     _false 
        .dw     parse_offset
        .dw     store 
        .dw     done

def_word        "abort", 5, $0, abort ;(string[addr len])
        .dw     print
        .dw     p_clr 
        .dw     quit