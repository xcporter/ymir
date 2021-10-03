# YMIR  
##  A simple forth for the atmega 4809
It seems that the best way to know forth is to write one yourself. To that end this project is primarily educational, but may perhaps be practical as well, given that most forths which run on avr have yet to be ported to the 4809.

##  Compiling
I use the avra toolchain, and avrdude to flash. For avrdude, be sure to use the version included with the arduino environment. Also, to trigger the programmer (if you're using the arduino nano every) you'll have to make a connection at 1200 baud, then immediately disconnect and engage avrdude. 

## Connecting
Find likely IO devices with `ls /dev/cu*` the one most similar to `/dev/cu.usbmodem141401` is the correct port.

To connect with the `screen` utility, enter the following into bash:
```
screen /dev/cu.usbmodem141401 115200
```
where the last number is the baud rate. 

## General Structures
Though this forth is for an 8 bit processor, the default number type in this system is a signed 16 bit integer. 
Each space on the parameter stack is a single 16 bit word.

Memory that decrements generally belongs to "system" concerns like the in-buffer,and return stack. 
All other memory segments grows toward higher addresses. 

In some cases I've opted for more unix/c like syntax instead of classical forth syntax, for example:

`!=` instead of `<>`, `/n` instead of `cr`, etc.

# Reserved Registers 
`SP` - Return stack pointer

`Z` - Working Pointer
- memory read/write,indirect execution

`Y` -  Instruction Pointer

`X` -  Parameter stack pointer

`W` -  pointer to s buffer (r[24:25])

`BR` - r[14:15] in buffer read pointer

`BW` - r[12:13]  in buffer write pointer

`zeroR` - r10 constant zero

`oneR` - r11 constant one

# Word Structure 
| Link Address | Name Length / Flag | Name  | Definition | 
|-|-|-|-|
| 2 b | flags[7:5] length[4:0] | max 31 chars | code or data  | n b        | n b

| Flag Detail|          |          |    |    |    |    |           |
|------------|----------|----------|----|----|----|----|-----------|
|f_immediate | f_hidden | f_no_flash | length[4:0] |

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
| System | Buffer | P stack >| Ram Dictionary > |< R stack |
|--------|--------|----------|-----------------|----------|
| 256 B  | 2kB    | 512 B    |  3.2kB          | 512 B    |

| Buffer ||
|--------|-|
| s_buffer>  | <in_buffer |

# Code samples, basic Forth intro: 
Everything that happens in Forth is an operation on the stack. Input consists of ascii words separated by whitespace. 

When you type return/enter the forth system engages the interpreter. The Interpreter reads what you've typed so far from the `in_buffer` until empty, parsing each whitespace separated token in turn according to the following logic:
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

To pop the top element from the stack and display as a number, use `.` (dot)


Now that we know that 1, 2, and 3 are on the stack, we can return each item. 

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
Notice that I've added the word `swap` (switch the top two items on the stack) to make sure it displays the quotient first.

## The Number System
The number system can be configured with the words `base!`,`base@`, `sign`, `unsign`, and `digits`. 

Shortcuts `hex`, `dec`, and `bin` provide for switching between the most common radixes. 

Keep in mind that this isn't a type conversion. At the end of the day, everything is binary. Rather, these words affect how numbers are accepted and displayed by the system. You could think of it like shifting gears in a manual transmission.

for example:
```forth
hex ok        // shift to hexadecimal
ff ok         // enter ff
bin ok        // shift to binary
.11111111 ok  // display (binary)
```
This also changes what numbers are considered acceptable. 
```forth
ff syntax error    // system still set to binary
0100 ok
```
To query the current base and display in decimal:
```forth
base@ dup dec \n . base!
2 ok   // it's binary
```
Here I'm also making a copy of the previous base before switching to decimal, then replacing it using `base!` (set base), and displaying the result on a new line with `\n`.

### Constant Radix sigils:

| `$` | `#` | `%` |
|-|-|-|
|hexadecimal|decimal| binary|

For convienence, numbers beginning with `$`, `#`, or `%` are interpreted with a constant base regardless of how the number system is curently configured. 

```forth
$ff bin .11111111 ok       
#16 hex .10 ok
%0100 dec .4 ok

$g syntax error  // 'g' out of range for base 16
```

To set an arbitrary base up to 36, use this line
```forth
[your radix] base! 
```
for example:
```forth
#36 base! ok
xyz ok        // now 'xyz' is a valid number
.s <1> -glh  ok
unsign \n .  
xyz ok        // (display unsigned to get original)
```

### Signed/unsigned
Any time you enter a number with a negative sign, it will always be interpreted as 16 bit two's compliment.
```forth
-12 .-12 ok
unsign ok
-12 .65524 ok        
```
After the above example, all numbers will continue to be displayed as unsigned until either `sign` is called or a system reset occurs. 


### Leading Zeros

`digits` sets the minimum size (in digits) when numbers are displayed. If a number has more digits, nothing is altered, but if it has fewer, it's padded with leading zeros. 
```forth
4 digits ok
ff .00ff ok
```

### Memory Ops

`@` and `!` are used to read and write to memory respectively

```forth
42 $30e3 ! ok        // save 42 to memory at 30e3
$30e3 @ ok           // fetch from 30e3
.42 ok               
```

### Debugging

Often it's necessary to probe larger streches of memory. For this, `dump` and `print` are helpful tools. 

`dump` takes (address, length) on the stack, and displays that area as numbers. 

`print` takes the same arguments and tries to display that data as text.

```forth
hex #4 digits  ok     // configure format


// dump first 20 words at 0x4000

$4000 #40 dump       
ef0f e31f bf0d bf1e 24aa e001 2eb0 
e011 ed08 bf04 9310 0061 e105 e011 9300 
0868 9310 0869 e000 9300 0865 ec08 9300 
0866 e203 9300 0867 e404 9300 05e2 e100 
9300 0421 e200 9300 0422 e008 9300 0434 
9300  ok


// dump first 4 words at 0x2800, this time in binary

bin #16 digits  ok

$2800 #4 dump
0100110101001110 0100110101001110 0100111000011110 0011010011001111  ok
```
To read back 40 chars of the last dictionary entry as text
```
\n &prog.latest @ #40 print
>syscheck�����=����     ����� ok
```
Here we see the most recent word is `syscheck`, and the rest is machine code


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
