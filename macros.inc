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
;   | Link Address | Flags/Length | Definition |
;   | 2 B          | n B          | n B        |
;                 /                \
;    ____________/                  \__________________
;   |f_immediate | f_hidden | f_? | Length[4:0] |

;; Forth primative
;       name_string, name_length, flag, subroutine_name
.macro def_asm
        link_asm_%:
                .if     word_link != 0x0000 
                        .dw     (word_link << 1) + 0x4000
                .else
                        .dw     word_link
                .endif
                    
                    .db     ((@1 & 0b00011111)+(@2 & 0b11100000)), @0   ; store length / flag
        .set            word_link = link_asm_%          ; update link
        .equ        @3 = PC
.endmacro

;; Forth word
;       name_string, name_length, flag, subroutine_name
.macro def_word
        link_word_%:
                .if     word_link != 0x0000 
                        .dw     (word_link << 1) + 0x4000
                .else
                        .dw     word_link
                .endif
                    .db     ((@1 & 0b00011111)+(@2 & 0b11100000)), @0   ; store length / flag
        .set            word_link = link_word_%         ; update link
        .equ        @3 = PC
                    jmp     do
.endmacro

;; Forth constant (retrieves word from mem and puts on stack)
;;      same args as word or primative + value
.macro const 
        def_asm     @0, @1, 0, @2          ; setup header
        ldi      TOSL, Low(@3)              ; does: put word on stack
        ldi      TOSH, High(@3)
        jmp      do_const
.endmacro

.macro const_data 
        def_asm     @0, @1, 0, @2          ; setup header
    _const_data_%:
        ldi      TOSL, Low((_const_data_% << 1) + 0x4000)   ; put start of new data seg on stack
        ldi      TOSH, High((_const_data_% << 1) + 0x4000)
        jmp      do_const
.endmacro

        .set     eep_link = 0x0000      ; latest is first 0x0000
;       name, name length, routine name, eep content
.macro eep_const 
        def_asm     @0, @1, 0, @2          ; setup header
        ldi      TOSL, Low(EEPROM_START + eep_link)
        ldi      TOSH, High(EEPROM_START + eep_link)        
        jmp      do_const       
        .set     eep_link = eep_link + 0x02

        .eseg 
        .org    eep_link
        .dw     @3
        .cseg 
.endmacro

        .set     ram_link = 0x0000
.macro ram_const 
        def_asm     @0, @1, 0, @2          ; setup header
        ldi      TOSL, Low(SRAM_START + ram_link)
        ldi      TOSH, High(SRAM_START + ram_link)        
        jmp      do_const       
        .set     eep_link = ram_link + 0x02
.endmacro


.macro cache_tos 
        _ppop   TOSL, TOSH
        adiw    SL, 0x02 
.endmacro    

.macro push_tos     ; push TOS
        _ppush   TOSL, TOSH
.endmacro 

;; push word to return stack (for consistency)
.macro _push
        push    @0                  
        push    @1
.endmacro 
.macro _pop
        pop     @1                  
        pop     @0
.endmacro 

;;      Parameter stack ops
;;      input: Rn
.macro  ppush 
        st      X+, @0                  ; store and increment pointer
        st      X+, zero
.endmacro

.macro  ppop
        sbiw    XL, 0x01                ; load and decrement pointer
        ld      @0, -X
.endmacro

;;      Parameter stack ops
;;      input: RL, RH
.macro _ppop                                     
        ld      @1, -X
        ld      @0, -X
.endmacro

.macro  _ppush
        st      X+, @0              ; store and increment pointer
        st      X+, @1
.endmacro

.macro ccp_spm_unlock               ; write spm signature to config change protection register
        ldi     r16, CPU_CCP_SPM_gc
        out     CPU_CCP, r16 
.endmacro

.macro ccp_ioreg_unlock              ; write spm signature to config change protection register
        ldi     r16, CPU_CCP_IOREG_gc
        out     CPU_CCP, r16 
.endmacro