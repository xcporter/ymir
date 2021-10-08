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

def_asm         "*exec", 5, 0, indirect_exec 
        _push   IL, IH 
        movw    IL, TOSL 
        cache_tos
        rjmp     next 

; direct to init vector
def_word        ":boot", 5, 0, boot
        .dw     init_vector             ; do init vector
        .dw     fetch 
        .dw     exec
        .dw     start_vector            ; do start vector
        .dw     fetch 
        .dw     exec    

; prepares system and IO for shell
def_asm         ":sysinit", 5, 0, sysinit 
        ldi     r17, 0x01               ; set clock prescalar to 2 (8MHz clk_per)
        ccp_ioreg_unlock 
        sts     CLKCTRL_MCLKCTRLB, r17

        ; default baud of 115200
        .equ    baud_fr = (8000000*64)/(115200*16) 

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


def_word         ":init", 5, 0, init
        .dw     sysinit
        .dw     done

; start word -- operator shell loop
def_asm         ":start", 6, 0, start
        jmp     next 

def_asm         ":check", 8, 0, syscheck
        jmp     next 

def_asm         ":rstack", 5, 0, init_r
        ldi     r16, Low(RAMEND)        ; init stack pointer
        ldi     r17, High(RAMEND)
        out     CPU_SPL, r16
        out     CPU_SPH, r17
        jmp     next

def_asm        "abort", 5, $0, abort
        ; call    reset_p
        jmp     main



