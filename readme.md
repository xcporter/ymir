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
Everything that happens in Forth is operation on the stack. Input consists of ascii words separated by whitespace. 

When you type return or enter the forth system engages the interpreter. The Interpreter reads from the `in_buffer` until empty, parsing each whitespace separated token in turn according to the following logic:
-   Is it in the Dictionary? 
       - Execute Word
- Is it a valid number?     
  - place number on the stack
- syntax error

This results in the characteristic postfix style of forth. Eg. `4 4 +` instead of `4 + 4`

## The Interpreter

`clear` will clear the screen without affecting the stacks, much like a unix shell. Backspace should work to edit each line. 

## Numbers and the Stack
to print the stack non-destructively, type `.s`
```forth
1 2 3  ok
.s <3> 1 2 3  ok     
```
The number in the angle brackets tells us how many items are on the parameter stack.

To pop the top element from the stack and print to screen as a number, use `.` (dot)


Now that we know that 1, 2, and 3 are on the stack, we can print each item. 

## Formatting Results

By default, `.` prints a number immediately, on the same line. Results can be formatted with `\s`, `\t`, and `\n` (space, tab, and newline).
```forth
\n . \n \s . \t .
3
 2      1 ok    
```
Notice that the items are printed in the reverse of the order in which they were placed on the stack. This is an inherent property of our stack-based environment. 

## System Status

The "ok" tells us that everything happened without any system compromising incidents. 

If you try to take more items off the stack than you initially put there, you'll get a stack underflow
```forth
1 2 . . .213100 stack underflow  
```
Notice that it still executed the dots--it's just reading from memory that is **not** a part of the parameter stack (In this case the input buffer). 

There is a single integrity check at the end of each interpreter cycle which will reset things on a deeper level if something doesn't line up on the system level.

In this case, the return stack and the parameter stack are cleared, and the main (quit) loop is reengaged. 

## Basic Math
Basic math works as you'd expect:
```forth
2 3 + .5 ok
2 3 - .-1 ok
2 3 * .6 ok
2 3 ** .8 ok  // exponent

3 ++ .4 ok    // increment
3 -- .2 ok    // decrement

```
The arithmetic words `/mod` (division / modulo) and `sqrt` (square root) return two values, the answer and remainder:
```forth
5 2 /mod swap \n . \s .
2 1 ok

25 sqrt swap \n . \s .
5 0 ok
```
Notice that I've added the word `swap` (switch the top two items) to make sure it prints the quotient first.

## Configuring the Number system
The number system can be configured with the words `base!`, `sign`, `unsign`, and `digits`. Shortcuts `hex`, `dec`, and `bin` provide for switching between the most common radixes. 

Keep in mind that this isn't a type conversion, but rather, you're changing how the forth system displays numbers.

### Signed/unsigned
Any time you enter a number with a negative sign, that will always be interpreted as 16 bit two's compliment.
```forth
-12 .-12 ok
unsign ok
-12 .65524 ok        
```
After the above example, all numbers will continue to be displayed as unsigned until either `sign` is called or a system reset occurs. 

### Radix
To non-destructively check what base the system is currently using, enter:
```forth
base@ dup dec . base!
```
This line first fetches the current base and places it on the stack, then duplicates it, sets the base to decimal, displays the previous base, then resets the base to the previous value. 

The current base is one factor in determining whether or not a number input is valid.

```forth
ff bin .11111111 ok   // convert 0xff to binary

ff syntax error  // 'f' is greater than base '2'

hex ok
ff ok         // 0xff is now acceptable
.s <1> ff  ok
```

To set an arbitrary base up to 36, use this line
```forth
dec [your radix] base! 
```
for example:
```forth
dec 36 base! ok
xyz ok        // now 'xyz' is a valid number
.s <1> -glh  ok   
unsign \n .  // display top of stack as unsigned
xyz ok
```

### Leading Zeros

`digits` sets the minimum size (in digits) when numbers are displayed. If a number has more digits, nothing is altered, but if it has fewer, leading zers are added. 
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
