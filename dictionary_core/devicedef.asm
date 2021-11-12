;*************************************************************************
;*   
;*      YMIR
;*
;*      DICTIONARY CORE -> DEVICEDEF
;*
;*      Words for accessing device constants like IO register locations
;*
;*
;*      Author: Alexander Porter (2021)
;* 
;*************************************************************************

def_const       "ramstart", 8, 0, c_ramend
        .dw     SRAM_START

def_const       "ramsize", 7, 0, c_ramsize
        .dw     SRAM_SIZE

def_const       "eepstart", 8, 0, c_eepstart
        .dw     EEPROM_START

def_const       "eepsize", 7, 0, c_eepsize
        .dw     EEPROM_SIZE

def_const       "progstart", 9, 0, c_progstart
        .dw     MAPPED_PROGMEM_START

def_const       "progsize", 8, 0, c_progsize
        .dw     MAPPED_PROGMEM_SIZE