# YMIR  
##  A simple forth for the atmega 4809
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
prog_latest | ram_latest | prog_here | ram_here | 0x00


# RAM layout:
| System | Buffer | P stack >|< Ram Dictionary |< R stack |
|--------|--------|----------|-----------------|----------|
| 256 B  | 2kB    | 512 B    |  3.2kB          | 512 B    |

| Buffer ||
|--------|-|
| s_buffer>  | <in_buffer |

# Code samples, basic Forth intro: 
Everything that happens is an operation on the stack. Input consists of ascii words separated by whitespace. Numbers are simply added to the top, and words can manipulate the stack in other ways. Everything is interpreted sequentially from left to right resulting in a postfix style syntax. eg: `2 2 +` instead of `2 + 2`.

to print the stack non-destructively, use `.s`
```forth
1 2 3  ok
.s <3> 1 2 3  ok     
```
The three in the angle brackets tells us how many items are on the parameter stack.

To remove and print the top element of the stack, use `.` (period) Now that we know that 1, 2, and 3 are on the stack, we can print each item. `\t`, `\s`, `\n` (tab, space, and newline) are also available for formatting results.
```forth
\n . \n \s . \s \s .
3
 2  1 ok    
```
Notice that the items are printed in the reverse of the order in which they were placed on the stack. This is an inherent property of our stack-based environment. 

The "ok" tells us that everything happened without any system compromising incidents. 

If you try to take more items off the stack than you initially put there, you'll get a stack underflow
```forth
1 2 . . .213100 stack underflow  
```
Notice that it still executed the dots--it's just reading into memory that is **not** a part of the parameter stack (In this case the input buffer). 

There is a single integrity check at the end of each interpreter cycle, which will reset things on a deeper level if you've done something plainly wrong.

Basic math works as you'd expect:
```forth
2 3 + .5 ok
2 3 - .-1 ok
2 3 * .6 ok
```
The word `/mod` returns two values, the quotient and remainder:
```forth
5 2 /mod swap \n . \s .
2 1 ok
```
Notice that I've added the word `swap` (switch the top two items) to make sure it prints the quotient first.

The number system can be configured with the words `base!`, `sign`, `unsign`, and `digits`. Shortcuts `hex`, `dec`, and `bin` provide for switching between the most common radixes. 

Keep in mind that this isn't a type conversion, you're changing how the entire forth system handles numbers.
```forth
-12 unsign .ffee ok         
```
After the above example, all numbers will continue to be unsigned until `sign` is called. 
```forth
dec 30 hex .1e ok
ff ok
bin .11111111 ok
ff syntax error
```
The number 0xff produces a syntax error the second time because the base is no longer hexadecimal, but rather binary. 

`digits` pads numbers smaller than what it's set to with zeros. 
```forth
4 digits ok
ff .00ff ok
```

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
