;*************************************************************************
;*   
;*      YMIR
;*           A simple forth              
;* 
;*      Author: Alexander Porter (2021)
;*
;*
;*
;* 
;*************************************************************************

;; Device definitions ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        .include    "m4809def.inc"
        .include    "libraries/usbserial.inc"
        .include    "macros.inc"
        .include    "config.inc"


;; Setup ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        .cseg
        .org    0x0000

        ldi     ZL, Low(RSTCTRL_RSTFR)  ; get reset debug info
        ldi     ZH, High(RSTCTRL_RSTFR)
        ld      r16, Z
        out     GPIO_GPIOR0, r16

        clr     zero                    ; setup registers
        clr     one 
        movw    STAL, zero 
        movw    TOSL, zero 
        movw    ACAL, zero 
        movw    ACBL, zero
        inc     one 

        ldi     r16, Low(RAMEND)        ; setup r stack pointer
        ldi     r17, High(RAMEND)
        out     CPU_SPL, r16
        out     CPU_SPH, r17

        ldi     SL, Low(def_p_start)    ; setup p stack pointer 
        ldi     SH, High(def_p_start)
 
        ldi     ZL, Low(sys_init)           ; boot forth kernel
        ldi     ZH, High(sys_init)
        ijmp

;; Terminal Core ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;       Kernel and execution
do:
        push    YH
        push    YL
        
        adiw    ZL, 0x02  ; opcode is 4 bytes

        movw    YL, ZL
        lsl     YL        ; Instruction pointer is in global address space
        rol     YH
        ldi     r16, 0x40
        add     YH, r16
        rjmp    next
def_asm         "exit", 4, 0, done
        _pop    YL, YH
next:
        ld      ZL, Y+
        ld      ZH, Y+
        ijmp


;; Dictionary ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        .include        "dictionary_core/sysops.asm"
        .include        "dictionary_core/sysdef.asm"
        .include        "dictionary_core/memory.asm"
        .include        "dictionary_core/stack.asm"
        .include        "dictionary_core/control.asm"
        .include        "dictionary_core/math.asm"
        .include        "dictionary_core/logic.asm"
        .include        "dictionary_core/io.asm"
        ; .include        "dictionary_core/number.asm"

;; End of Dictionary ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

do_const:
        adiw    ZL, 0x02
        call    _flash_to_global 
        ld      TOSL, Z+
        ld      TOSH, Z+
        push_tos
        jmp     next

do_var:
        adiw    ZL, 0x02
        call    _flash_to_global
        movw    TOSL, ZL
        push_tos
        jmp     next 

;;  End of Core ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
flash_here:

        .eseg 

eep_here:
        .org    0x0000
        .dw     word_link

