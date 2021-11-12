;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> MEMORY
;*
;*      Storage and Retrieval Operations 
;*      
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************

def_asm         "@", 1, 0, fetch
        movw    ZL, TOSL                 ; load address
        sbiw    SL, 0x02
        ld      TOSH, Z+
        ld      TOSL, Z+
        push_tos
        jmp     next

def_asm         "!", 1, 0, store         ; ( val, addr --)
        sbiw    SL, 0x02 
        _ppop   r18, r19 
        movw    ZL, TOSL 
        st      Z+, r19
        st      Z+, r18
        cache_tos
        jmp     next

def_word        "!+", 2, 0, store_inc     ; ( val, addr -- addr + 1)
        .dw     dup 
        .dw     inv_rot
        .dw     store 
        .dw     store 
        .dw     incr 
        .dw     incr 
        .dw     done

def_word        "@+", 2, 0, fetch_inc   ; (addr -- next_addr, value)
        .dw      dup
        .dw      fetch 
        .dw      swap    
        .dw      incr 
        .dw      incr 
        .dw      swap
        .dw      done

def_asm         "c!", 2, 0, store_byte
        sbiw    SL, 0x02
        _ppop   r18, r19
        movw    ZL, TOSL
        st      Z, r18
        cache_tos
        jmp     next

def_asm         "c!+", 3, 0, store_byte_inc
        sbiw    SL, 0x02
        _ppop   r18, r19
        movw    ZL, TOSL
        st      Z+, r18
        movw    TOSL, ZL
        push_tos
        jmp     next

def_asm         "c@", 2, 0, fetch_byte
        movw    ZL, TOSL       
        sbiw    SL, 0x02
        ld      TOSL, Z
        clr     TOSH 
        push_tos
        jmp     next
        
def_asm         "c@+", 3, 0, fetch_byte_inc
        movw    ZL, TOSL       
        sbiw    SL, 0x02
        ld      r18, Z+
        clr     r19 
        movw    TOSL, ZL
        push_tos 
        movw    TOSL, r18
        push_tos
        jmp     next

def_asm         "move", 4, 0, move              ;(from, to, bytes--)
        _push   IL, IH  
        movw    ACAL, TOSL                      ; get bytes (counter)
        sbiw    SL, 0x02 
        _ppop   YL, YH                          ; Y = TO
        _ppop   ZL, ZH                          ; Z = FROM
    _move:
        cp      ACAL, zero 
        cpc     ACAH, zero 
        breq    _move_done
        ld      r17, Z+
        ld      r16, Z+
        st      Y+, r16
        st      Y+, r17

        sbiw    ACAL, 0x01
        rjmp    _move
    _move_done:
        _pop    IL, IH
        jmp     next 


; Utilities ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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
_nvm_pb_clear:
        ldi     r17, 0x04
        rjmp    _nvm_exec

_nvm_write:
        ldi     r17, 0x01
; command word r17
_nvm_exec:
        ldi     ZL, Low(NVMCTRL_STATUS)
        ldi     ZH, High(NVMCTRL_STATUS)
        ld      r16, Z     ; wait for NVM available
        cpse    r16, zero
        rjmp    _nvm_exec
        ldi     ZL, Low(NVMCTRL_CTRLA)
        ldi     ZH, High(NVMCTRL_CTRLA)
        ccp_spm_unlock
        st      Z, r17
        ret


; set mem_target register depending on address range
_mem_map:
        ldi     r18, 0x40
        ldi     r19, 0b00000100
        cp      TOSL, r18 
        brlo    _not_flash
        out     mem_target, r19
        ret
    _not_flash:
        ldi     r18, 0x14
        ldi     r19, 0b00000010
        cp      TOSL, r18 
        brlo    _is_ram
        inc     r18 
        cp      TOSL, r18 
        brsh    _is_ram
        out     mem_target, r19
        ret
    _is_ram:
        ldi     r19, 0b00000001
        out     mem_target, r19
        ret