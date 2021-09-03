;******************************************************************************************
;*   
;*      YMIR
;*           A simple forth         
;*
;*      MACROS: Mostly for defining forth data structures in asm, with some additional
;*               convienence functions                
;* 
;*      Author: Alexander Porter (2021)
;*
;* 
;******************************************************************************************

                    .set     word_link = 0x0000

                    .equ    f_immediate = 0x80
                    .equ    f_hidden = 0x40
                    .equ    f_in_ram = 0x20

;; Forth primative
;       name_string, name_length, flag, subroutine_name
.macro def_asm
        link_asm_%:
                    .dw     word_link
                    .db     @1, @0                      ; store length / name
                    .db     @2                          ; store flag
        .set            word_link = link_asm_%          ; update link
        .equ        @3 = PC
.endmacro

;; Forth word
;       name_string, name_length, flag, subroutine_name
.macro def_word
        link_word_%:
                    .dw     word_link
                    .db     @1, @0                      ; store length / name
                    .db     @2                          ; store flag
        .set            word_link = link_word_%         ; update link
        .equ        @3 = PC
                    jmp     do
.endmacro

;; Forth constant (retrieves word from mem and puts on stack)
;;      same args as word or primative + value
.macro def_const
        def_asm     @0, @1, @2, @3          ; setup header
        ldi      r16, Low(@4)           ; does: put address on stack
        ldi      r17, High(@4)
        p_push_word      r16, r17           ; puts on p stack
        jmp      next
.endmacro

;; constant byte rather than word
.macro def_const_b
        def_asm     @0, @1, @2, @3          ; setup header
        ldi      r16, @4            
        p_push   r16
        jmp      next          
.endmacro

;;      Parameter stack ops
;;      input: Rn
.macro  p_push 
        st      X+, zeroR
        st      X+, @0                                  ; store and increment pointer
.endmacro

.macro  p_pop
        ld      @0, -X                                  ; load and decrement pointer
        sbiw    XL, 0x01
.endmacro

;;      Parameter stack ops
;;      input: RL, RH
.macro p_pop_word                                       
        ld      @0, -X
        ld      @1, -X
.endmacro

.macro  p_push_word 
        st      X+, @1              ; store and increment pointer
        st      X+, @0
.endmacro

