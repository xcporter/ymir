;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> ACTOR
;*
;*      Words for creating and managing Actors for concurrent tasks. 
;*      
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************

const_data       "actor0", 6, actor_zero
        .dw     0x0028          ; stack size (20 items)
        .dw     0x0100          ; tib size (256 b)
        .dw     0x0100          ; pad size (256 b)
        .dw     USART3_RXDATAL  ; rx
        .dw     USART3_TXDATAL  ; tx
        .dw     USART3_STATUS   ; wait vect 

def_word        "actor.init", 10, 0, init_actor  ; (address of config word--)
        .dw     actor_zero
        .dw     fetch_incr          ; (ac+1, p size)

        .dw     done

def_asm         "actor.load"
def_asm         "actor.new", 9, 0, new_actor