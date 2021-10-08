;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> DEBUG
;*
;*
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************

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

def_word        "pick", 4, $0, pick   ; (stack index 0=bottom, n=top)
        .dw     literal 
        .dw     0x0001
        .dw     b_shl 
        .dw     p_start 
        .dw     addition
        .dw     fetch
        .dw     exit


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