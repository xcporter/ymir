
# Primitives
## `execute`
( execution_address -- )
## `exit`
return from word
## `lit`
put literal on stack (compiled only)
## `reset`
Resets return stack, in buffer and s buffer
## `&r`
Put return stack pointer on stack
## `&p`
Put parameter stack pointer on stack
## `base@`
fetch current base (will always display as `10` without conversion to/from decimal)
## `hex`
hexidecimal
## `bin`
binary
## `dec`
decimal
## `base!`
Store base
## `digits`
set leading zero padding
## `sign`
toggle sign display
## `unsign`
toggle sign display
## `padclr`
## `&pad`
## `drop`
( a b -- a )
## `2drop`
( a b c d -- a b )
## `swap`
( a b -- b a )
## `2swap`
( a b c d -- c d a b )
## `dup`
( a -- a a )
## `2dup`
( a b -- a b a b )
## `over`
( a b -- a b a )
## `rot`
( a b c -- b c a )
## `-rot`
( a b c -- c a b )
## `>r`
pop to return stack
## `r>`
push from return stack
## `@r`
fetch from return stack
## `!r`
store to return stack
## `rdrop`
drop from return stack
## `++`
increment
## `--`
decrement
## `+`
add
## `-`
subtract
## `*`
multiply
## `**`
exponent ( base, power -- result )
## `/mod`
Division with remainder 
( dividend, divisor -- quotient, remainder )
## `sqrt`
( input -- root, remainder )
## `==`
is equal
## `!=`
is not equal
## `<`
    a b < // b is less than a
## `>`
    a b > // b is greater than a
## `<=`
less than or equal to
## `>=`
greater than or equal to
## `?0`
is zero
## `!0`
is not zero
## `-0`
is negative
## `||`
or 
## `&&`
and 
## `^`
xor
## `<<`
shift left 

( number, times to shift -- result )
## `>>`
shift right

( number, times to shift -- result )
## `!`
store 

( data, address -- )
## `!+`
store and increment

( data, address -- next_address )
## `@`
fetch 

( address -- value )
## `@+`
fetch and increment

( address -- next_address, value )
## `litstring`
string literal (compile only)
## `print`
( address, length -- )
## `branch`
unconditional branch
## `?branch`
condition branch (branch if zero)
## `key`
pull next char from buffer or accept 1 char
## `emit`
send top of stack 
## `word`
pull next word from buffer
## `>char`
to char
## `char>`
from char
## `$>#`
string to number (radix conversion)
## `#>$`
number to string (radix conversion)
## `find`
lookup word in dictionary
( address, length -- word_address or zero )
## `>xt`
( word_address -- execution_address )
## `create`
## `,`
## `[`
## `]`
## `immediate`
## `hidden`
## `accept`
Recieve and echo back input until cr 
## `\n`
send newline
## `\s`
send space
## `\t`
send tab
## `abort`
reset p-stack and quit
## `syscheck`
Internal to interpreter

check for over/underflows, pointer crossing, etc.

# Words

## `.s`
print stack nondestructively
## `pick`
( stack_position -- value )

0 = deepest item
## `:`
## `;`
## `quit`
Main loop
## `interpret`
Outer interpreter:

Loops through in buffer and either executes as word or puts number on the stack
## `clear`
Just like unix: clears the screen
## `ok`
system message success
## `synerr`
system message syntax error
## `undererr`
system message underflow error