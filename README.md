# Kernel (ROM) for SBC6309 Homebrew

To operate in any meaningful way the board needs something 
to bootstrap it into a usable state. The kernel provides a
set of low level routines to initialise the device and
abstract how other software should interact with it

## Target State ##

The kernel is being developed on the basis of highest need
first - so display and use input to start with, and then
build out. It isn't completely organic, there is a plan...

[The Plan](./plan.md)

Ultimately this should form a small(ish) layer of code that
a more complex OS can sit on, preferably loaded into RAM
rather than sitting on a ROM. That said part of the design
brief is to include ROM paging using 8K or 16K pages which
would allow the kernel to become much larger without impinging
substantially on the memory model

Given the ability to page RAM and ROM the bootstrap kernel can 
even be paged out once suitable software is loaded if required
by a substitute OS (such as OS9)

## Software Used ##

The kernel is written in 6309 assembly language using Ciaran
Anscomb's asm6809, it does almost all it is asked for (except
run on MacOS by default)

The code will (in theory) compile under pretty much any 6x09
assembler. Initially LWTOOLS was used (because it does run
on MacOS - just saying) but required more effort (and I'm
lazy)

If I get organised a build container will be created so that I
can run the build process on any hardware...

## Borrowing a Monitor ##

A comparable 6309 SBC homebrew project by tomcircuit contains
a translation of wozmon to 6309 assembler. The hardware
implementation may be different but the fundamental code is
transferable, so rather than re-invent the wheel I have borrowed
it with some artistic licence

[tomcircuit/hd6309sbc](https://github.com/tomcircuit/hd6309sbc)

