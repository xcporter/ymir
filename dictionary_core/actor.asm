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

def_word        "actor.init", 10, 0, init_actor  ; (address of config word--)
        .dw     actor_zero
        .dw     fetch_incr          ; (ac+1, p size)

        .dw     done

def_asm         "actor.load"
def_asm         "actor.new", 9, 0, new_actor