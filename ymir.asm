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
        .include    "config.inc"
        .include    "macros.inc"


;; Setup ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        .cseg
        .org    0x0000

        ldi     ZL, Low(RSTCTRL_RSTFR)  ; get reset debug info
        ldi     ZH, High(RSTCTRL_RSTFR)
        ld      r16, Z
        out     GPIO_GPIOR0, r16

        clr     zero                    ; set up registers
        clr     one 
        movw    STAL, zero 
        movw    TOSL, zero 
        movw    ACAL, zero 
        movw    ACBL, zero
        inc     one 

        ldi     r16, Low(RAMEND)        ; init stack pointer
        ldi     r17, High(RAMEND)
        out     CPU_SPL, r16
        out     CPU_SPH, r17
 
        ldi     ZL, Low(sysinit)           ; boot kernel (directs to whatever word is set to init vector)
        ldi     ZH, High(sysinit)
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
def_asm         "exit", 4, $0, done
        _pop    YL, YH
next:
        ld      ZL, Y+
        ld      ZH, Y+
        ijmp


;; Dictionary ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        .include        "dictionary_core/sysops.asm"
        .include        "dictionary_core/sysdef.asm"
        .include        "dictionary_core/stack.asm"
        .include        "dictionary_core/math.asm"
        .include        "dictionary_core/memory.asm"
        
def_word        "quit", 4, $0, main              ; Main system loop
        ; .dw     reset                            ;  
        ; .dw     accept                           ;   
        ; .dw     interpret                        ;   
        ; .dw     branch                           ;  
        ; .dw     0xfffd                           ; -3

;; End Dictionary ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;; Utilities ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

_flash_to_global:                ; multiply by 2 and add 0x4000 for flash mem (using ld)
        lsl     ZL
        rol     ZH
        ldi     r16, 0x40
        add     ZH, r16
        ret

_global_to_flash:
        ldi     r18, 0x40
        sub     ZH, r18         ; addr back to flash space
        lsr     ZH
        ror     ZL
        ret

do_const:
        push_tos
        jmp      next
;;  End of Core ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
flash_here:
        .eseg 
eep_here_pt:
        .org    0x0000
        .dw     word_link


