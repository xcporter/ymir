;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> TX-RX 
;*
;*      Words for transmitting and recieving, as well as 
;*      shell and formatting behavoir
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************


def_asm         "io.wait", 7, 0, io_wait
        ldi     ZL, Low(io_wait_vector)
        ldi     ZH, Low(io_wait_vector)

        ld      r19, Z+                 ; get io_wait registers
        ld      r18, Z+ 

        movw    ZL, r18

        ld      r17, Z                  ; load uart status
        sbrs    r17, 7                  ; check if empty
        rjmp    io_wait                 ; loop if not
        jmp     next

def_word        "emit", 4, $0, emit
        .dw     io_wait
        .dw     tx_d_vect
        .dw     fetch 
        .dw     store 
        .dw     done
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
def_asm         "print", 5, $0, print
        ppop   r18                 ; load length from stack
        _ppop  ZL, ZH          ; load address word from stack
        rcall   print_tx
        jmp    next 
    print_before:
        cp     r18, zero          ; is char count exhausted?
        ret
    print_during:
        dec     r18                 ; decrement size and load next for send
        ld      r16, Z+
        ret
    print_tx:  using_usb_tx     print_before, print_during, $0

                        
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

def_word         "clear", 5, $0, clear
        .dw     litstring
        .db     0x0e, 0x1b, "[2J", 0x1b, "[20A", 0x1b, "[20D"
        .dw     print
        .dw     main  