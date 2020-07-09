8080-CPU emulator for the VIC with Ultimem expansion + SD2IEC drive
===================================================================

This is just a sketch of it to see how it could work
out.  So far it amounts to 2.8K compiled code and it
looks like the emulated code would run at least 5 to
10 times slower.

Requires GNU Make and CC65 to build.


# Why!?

The number of applications for CP/M-80 is overwhelming.


# How it is supposed to work

## 8080-CPU emulation

The emulator is basically a loop that fetches an opcode that is used as
an index into a jump table to call the procedure that emulates that
particular opcode.  Two blocks are being used to access the emulated memory.
One for optimized, sequential code reads with less overhead for banking
and one for slower random data access.  BIOS/BDOS calls are caught via
an 'illegal' opcode.

This implementation is a hand-compiled version of the C version of
https://github.com/superzazu/8080

## Terminal

The terminal is a VT52 emulation with 40x24 grid of 4x8 pixel chars.
WordStar and Turbo Pascal can be patched to work with this, for example.
(Thanks to Polluks for pointing that out.)

Let's see how high the fun level of keyboard mapping will turn out…

## BDOS

This is based on xcpm by Gábór Lénart, using the standard C library
of cc65.  And here is the catch; devices have to support random-access
on sequential files, like the SD2IEC does.

## BIOS

No support planned unless required or for disk images.


# Possible improvements

* Faster CPU emulation (a bit)
* Z80 emulation
* Disk image support
* Higher CP/M versions
* GIOS
