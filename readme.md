# YMIR  
##  A simple forth for the atmega 4809
----

 > Ymir was a primordial being who was born from venom that dripped from the icy rivers called the Élivágar, and lived in the grassless void of Ginnungagap. Ymir was both male and female, and gave birth to a male and female from his armpits, and his legs together begat a six-headed being. The grandsons of Búri, the gods Odin, Vili and Vé, fashioned the Earth (elsewhere personified as a goddess, Jörð) from his flesh, from his blood the ocean, from his bones the mountains, from his hair the trees, from his brains the clouds, from his skull the heavens, and from his eyebrows the middle realm in which mankind lives.
 ----
It seems that the best way to know forth is to write one yourself. To that end this project is primarily educational, but may perhaps be practical as well, given that most forths which run on avr have yet to be ported to the 4809.

##  Compiling
I use the avra toolchain, and avrdude to flash. For avrdude, be sure to use the version included with the arduino environment. Also, to trigger the programmer (if you're using the arduino nano every) you'll have to make a connection at 1200 baud, then immediately disconnect and engage avrdude. 

## General Structures
Though this forth is for an 8 bit processor, the default number type in this system is a signed 16 bit integer. 
Each space on the parameter stack is a single 16 bit word. This avoids having to manage all manner of possible address alignment mishaps that could occur if items of mixed size were kept on the stack. (At the cost of some memory space)

Memory that decrements generally belongs to "system" concerns like the in-buffer, dictionary and return stack. 
All other memory segments grows toward higher addresses. 

In some cases I've opted for more unix/c like syntax instead of classical forth syntax, for example:

`!=` instead of `<>`, `/n` instead of `cr`, etc.

# Reserved Registers 
       SP: Return stack pointer
       Z:  Working Pointer: program memory read/write, indirect execution
       Y:  Instruction Pointer
       X:  Parameter stack pointer
       W:  pointer to s buffer (r[24:25])
       BR: r[14:15] in buffer read pointer
       BW: r[12:13]  in buffer write pointer
       constant zero: r10
       constant one: r11

# Word Structure 
| Link Address | Name Length | Name | Flag | Definition | 0xPadding |
|--------------|-------------|------|------|------------|-----------|
| 2 b | 1 b | n b | 1 b  | n b        | n b

| Flag Detail|          |          |    |    |    |    |           |
|------------|----------|----------|----|----|----|----|-----------|
|f_immediate | f_hidden | f_in_ram | 0b | 0b | 0b | 0b | 0b |

# IO Registers
| State: | | | | | | | |
|---------|-----------------|----|----|----|----|----|---------|
| reverse | in_buffer_reset | 0b | 0b | 0b | 0b | 0b | compile |


# System Memory
First 256 bytes of sram (can be persisted in eeprom)
| 0x0000: | | | | | | 
|---------|-----------------|----|----|----|----|
base | prog_latest | ram_latest | prog_here | ram_here | 0x00


# RAM layout:
| System | Buffer | P stack >|< Ram Dictionary |< R stack |
|--------|--------|----------|-----------------|----------|
| 256 B  | 2kB    | 512 B    |  3.2kB          | 512 B    |

| Buffer ||
|--------|-|
| s_buffer>  | <in_buffer |

# todo 
- compiler / interpreter state
- flash to program memory
- assembler? 
- persistent string buffer
- arrow keys

- multitasking
- eeprom configuration
 - system for configuring / switching uart tty and pinout
 - system for configuring clock / tty baud
