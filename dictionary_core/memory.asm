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

;; Checks address on TOS and sets mem in kernel state register
; TOS[L:H] address in 
; r16, accumulator
_check_mem:
        clr     r16 
        cpi     TOSH, High(MAPPED_PROGMEM_START)
        brge    _mem_is_flash
        cpi     TOSH, High(SRAM_START)
        brge    _mem_is_ram
        cpi     TOSH, High(EEPROM_START)
        brge    _mem_is_eep
        rjmp    _check_mem_done
    _mem_is_flash:
        sbr     STAH, 6
        sbr     STAH, 5
        rjmp    _check_mem_done
    _mem_is_ram:
        sbr     STAH, 5
        rjmp    _check_mem_done
    _mem_is_eep:
        cpi     TOSH, High(EEPROM_START + EEPROM_SIZE)
        brge    _check_mem_done
        sbr     STAH, 6
    _check_mem_done:
        ret

def_asm         "@", 1, 0, fetch
        movw    ZL, TOSL                 ; load address
        sbiw    SL, 0x02
        ld      TOSH, Z+
        ld      TOSL, Z+
        push_tos
        jmp     next


def_asm         "!", 1, 0, store         ; ( val, addr --)
        rcall   _check_mem
        movw    ZL, TOSL                 ; load address
        sbiw    SL, 0x02 
        _ppop   TOSL, TOSH               ; load val
        sbrc    STAH, 6
        rcall   _nvm_pb_clear
        st      Z+, TOSL
        st      Z+, TOSH
        sbrc    STAH, 6
        rcall   _nvm_write
        cache_tos
        jmp     next

def_word        "!+", 2, 0, store_inc     ; ( val, addr -- addr + 1)
        .dw     dup 
        .dw     inv_rot
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
        rcall   _check_mem
        movw    ZL, TOSL                
        sbiw    SL, 0x02 
        ppop    TOSL
        sbrc    STAH, 6
        rcall   _nvm_pb_clear
        st      Z, TOSL
        sbrc    STAH, 6
        rcall   _nvm_write
        cache_tos
        jmp     next
        
def_asm         "c@", 2, 0, fetch_byte
        movw    ZL, TOSL       
        sbiw    SL, 0x02
        ld      TOSL, Z+
        clr     TOSH 
        ppush   TOSL
        jmp     next

def_asm         "move", 4, 0, move              ;(from, to, bytes--)
        _push   IL, IH 
        movw    ACAL, TOSL
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