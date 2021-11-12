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

; rx wait
def_asm        "rx~", 3, 0, rx_do_wait
        sbiw    SL, 0x02 
        movw    ZL, TOSL 
        cache_tos 
    rx_wait_loop:
        ld      r18, Z 
        sbrs    r18, 7
        rjmp    rx_wait_loop
        jmp     next 

; tx wait
def_asm         "tx~", 3, 0, tx_do_wait
        sbiw    SL, 0x02 
        movw    ZL, TOSL 
        cache_tos 
    tx_wait_loop:
        ld      r18, Z 
        sbrs    r18, 5
        rjmp    tx_wait_loop
        jmp     next 

def_word        "emit", 4, 0, emit
        .dw     tx_data_v
        .dw     fetch
        .dw     tx_wait_v 
        .dw     fetch
        .dw     tx_do_wait
        .dw     store_byte
        .dw     done
                        
def_word         "key", 3, 0, key       ; recieve single char 
        .dw     rx_data_v               ; wait for input
        .dw     fetch 
        .dw     rx_wait_v 
        .dw     fetch 
        .dw     rx_do_wait              
        .dw     fetch_byte
        .dw     done 
        
def_word        "accept", 6, 0, accept         ; (addr, end_delimiter, limit -- accepted_chars)
        .dw     to_r                           
        .dw     _false 
        .dw     to_r                           ; r[limit, 0]

        ; loop:
        .dw     r_equal                        ; Case: char limit reached
        .dw     branch_if                      
        .dw     0x0003                         
        .dw     bover_msg                      ;        buffer overflow exception
        .dw     abort                          ; _________
                                               
        .dw     key                            ; get next char

        .dw     dup_two                        ; Case: end_delimiter reached
        .dw     equal
        .dw     branch_if                      
        .dw     0x0006
        .dw     drop_two                       ;        cleanup
        .dw     drop 
        .dw     from_r                         ;        leave number of chars on stack
        .dw     r_drop
        .dw     done                           ; _________                 

        .dw     dup                            ; Case: char is delete
        .dw     literal 
        .dw     0x007f
        .dw     equal
        .dw     branch_if 
        .dw     0x0009
        .dw     r_decr
        .dw     drop                           ; drop current char
        .dw     swap                           ; decrement address in buffer 
        .dw     decr                    
        .dw     swap   
        .dw     del                            ; echo backspace                        
        .dw     branch                         ;        loop
        .dw     0xffe4                         ; _________ 

        .dw     dup                            ; echo input
        .dw     emit          
        .dw     rot                            ; store next char 
        .dw     store_byte_inc 
        .dw     swap 
        .dw     r_incr                         ; increment counter
        .dw     branch                         ; loop
        .dw     0xffdc

def_word         "print", 5, 0, print  ; (addr, len --)  
        .dw     _false                   ; put zero on tos
        .dw     to_r 
        .dw     to_r    

        ; loop:
        .dw     r_equal 
        .dw     branch_if               ; break if length == zero  
        .dw     0x0005 

        .dw     r_drop                  ; cleanup and exit
        .dw     r_drop
        .dw     drop
        .dw     done 

        .dw     r_decr                  ; decrement counter

        .dw     fetch_byte_inc 
        .dw     emit

        .dw     branch                  ; loop
        .dw     0xfff5                  ; -11

def_word        '.', 1, 0, dot
        ; .dw     num_to_string
        ; .dw     print
        ; .dw     exit

;; Special characters / terminal instructions ~~~~~~~~~~~~~~~~~~~~~~~~~~~~

def_word        "\n", 2, 0, cr 
        .dw     strlit
        .db     2, 0x0d, 0x0a
        .dw     print
        .dw     done 

def_word        "\s", 2, 0, sp
        .dw     literal 
        .dw     0x0020          ; \s
        .dw     emit 
        .dw     done

def_word        "\t", 2, 0, tab 
        .dw     literal 
        .dw     0x0009          ; \t
        .dw     emit 
        .dw     done

def_word        "\b", 2, 0, del 
        .dw     strlit
        .db     3, 0x08, 0x20, 0x08 ; \b \s \b 
        .dw     print
        .dw     done

def_word         "clear", 5, $0, clear
        .dw     strlit
        .db     0x0e, 0x1b, "[2J", 0x1b, "[20A", 0x1b, "[20D"
        .dw     print
        .dw     quit