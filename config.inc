; ***************************************************************
; * Memory model
; * $0000 - $7FFF = default ram page
; * $8000 - $9FFF = rom page 1 8K
; * $A000 - $BFFF = rom page 2 8K
; * $C000 - $DFFF = reserved 4K
; * $E000 - $EFFF = video 4K
; * $F000 - $FDFF = monitor
; * $FE00 - $FFEF = IO
; * $FFF0 - $FFFF = CPU vectors
; ***************************************************************

ZERO_PAGE           EQU     $0000       ; system variables
ROM_BASE            EQU     $F000       ; rom base address
ACIA_BASE	        EQU		$FE00		; base address for ACIA
SYS_STACK           EQU     $7FFF       ; initial stack pointer
USR_STACK           EQU     $6FFF       ; initial user stack pointer

BAD_BACK_CHAR       EQU     $20         ; background character for BAD vga
BAD_CURSOR_CHAR     EQU     $7F         ; cursor character for BAD vga
BAD_CURSOR_FLASH    EQU     $5C         ; cursor flash rate for BAD vga
SCREEN_BASE_BAD     EQU     $E000       ; base address of screen memory (bad)
SCREEN_END_BAD      EQU     $E800       ; end address of screen memory (bad)
SCREEN_SIZE_BAD     EQU     $0800       ; size of screen memory (bad)
; BAD VGA needs 2K of memory for screen but has a 4K window
; video could be upraded to 16 byte characters or to add colour support