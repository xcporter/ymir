;******************************************************************************************
;*   
;*      YMIR
;*           A simple forth         
;*
;*      MACROS: Shortcuts for defining forth data structures in asm, with some additional
;*               convienence functions                
;* 
;*      Author: Alexander Porter (2021)
;*
;* 
;******************************************************************************************

        .set     word_link = 0x0000     ; macro variable for word link

;; Word Structure ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;   | Link Address | 0xff | Flags/Length | Definition |
;   | 2 B                 | n B          | n B        |
;                        /                \
;           ____________/                  \_____________
;           |f_immediate | f_hidden | f_? | Length[4:0] |



; Define Forth primative
;       must end in jump to next (or jump to word that ends in next/done)

;;      name_string, name_length, flag, subroutine_name
.macro def_asm
        link_asm_%:
                .if     word_link != 0x0000                             ; build word header
                        .dw     (word_link << 1) + 0x4000
                .else
                        .dw     word_link
                .endif
                    .dw     0xff00 + ((@1 & 0b00011111)+(@2 & 0b11100000))                               ; store marker/length/flag
                    .db     @0   ; store name
        .set            word_link = link_asm_%                          ; update link
        .equ        @3 = PC                                             ; set routine name to address
.endmacro

; Define Forth word
;       each address must be .dw not .db
;       must end in 'done' or loop or kernel will crash

;;      name_string, name_length, flag, subroutine_name
.macro def_word
        link_word_%:
                .if     word_link != 0x0000                             ; build word header
                        .dw     (word_link << 1) + 0x4000
                .else
                        .dw     word_link
                .endif
                        .dw     0xff00 + ((@1 & 0b00011111)+(@2 & 0b11100000))                               ; store marker/length/flag
                        .db    @0   ; store string
        .set            word_link = link_word_%                         ; update link
        .equ        @3 = PC                                             ; set routine name to address
                    jmp     do                                          ; thread 
.endmacro

;; puts data after xt on stack
.macro def_const
        def_asm         @0, @1, 0, @2
                jmp     do_const
.endmacro 

        

;; puts address after xt on stack
.macro def_var
        def_asm         @0, @1, 0, @2
                jmp     do_var
.endmacro 

;; allocate space in ram and add constant word with address
        .set    ram_link = 0x0000
.macro def_ram
        def_asm         @0, @1, 0, @2
                jmp     do_const
                .dw     SRAM_START + ram_link
        .set    ram_link = ram_link + 2
.endmacro 

        .set    eep_link = 0x0000
.macro def_eep 
        .set    eep_link = eep_link + 2 ; preincrement bc core is defined manually in ymir.asm
        def_asm         @0, @1, 0, @2
                jmp     do_const
        .dw     EEPROM_START + eep_link
        
        .eseg 
        .org    eep_link
        .dw     @3
        
        .cseg 
.endmacro

;; name_string, name_length, subroutine_name, content, content_length 
.macro def_str 
        def_word         @0, @1, 0, @2
                .dw     strlit
                .db     @4, @3 
                .dw     done
.endmacro 

; Stack op shortcuts ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; underscore before means word (takes two args)

.macro cache_tos 
        _ppop   TOSL, TOSH
        adiw    SL, 0x02 
.endmacro    

.macro push_tos     
        _ppush   TOSL, TOSH
.endmacro 

;; push word to return stack (for consistency)
.macro _push
        push    @1                  
        push    @0
.endmacro 
.macro _pop
        pop     @0                  
        pop     @1
.endmacro 

;;      Parameter stack ops
;;      input: Rn
.macro  ppush 
        st      X+, zero                ; store and increment pointer
        st      X+, @0                  
.endmacro

.macro  ppop
        ld      @0, -X                  ; load and decrement pointer
        sbiw    XL, 0x01                
.endmacro

;;      Parameter stack ops
;;      input: RL, RH
.macro _ppop 
        ld      @0, -X                                    
        ld      @1, -X
.endmacro

.macro  _ppush  
        st      X+, @1                  ; store and increment pointer
        st      X+, @0              
.endmacro


;; CPU op shortcuts ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.macro ccp_spm_unlock               ; write spm signature to config change protection register
        ldi     r16, CPU_CCP_SPM_gc
        out     CPU_CCP, r16 
.endmacro

.macro ccp_ioreg_unlock              ; write spm signature to config change protection register
        ldi     r16, CPU_CCP_IOREG_gc
        out     CPU_CCP, r16 
.endmacro