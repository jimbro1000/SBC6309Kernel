WARM           EQU  $0000 ; warm start indicator - 3 bytes
CURSOR         EQU  $0003 ; cursor character - byte
CURSOR_COUNTER EQU  $0004 ; blink counter - byte
CURSOR_POS     EQU  $0005 ; cursor address - word
CURSOR_COL     EQU  $0007 ; cursor column - byte
CURSOR_ROW     EQU  $0008 ; cursor row - byte
KEY_POLL_COUNT EQU  $0009 ; key poll counter - byte
KEY_POLL_TABLE EQU  $000A ; key matrix - 8 bytes
KEY_ROLLOVER   EQU  $0012 ; key rollover table - 64 bytes
SCREEN_TOP     EQU  $0052 ; screen address - 2 bytes
SCREEN_END     EQU  $0054 ; end of screen memory - 2 bytes
SCREEN_COLS    EQU  $0056 ; number of columns on screen - 1 byte
SCREEN_ROWS    EQU  $0057 ; number of rows on screen - 1 byte
SCREEN_BLINK   EQU  $0058 ; screen blink counter reset - 1 byte

SCREEN_COLS_BAD    EQU  40    ; number of columns on screen using BAD vga
SCREEN_ROWS_BAD    EQU  25    ; number of rows on screen using BAD vga
BAD_CURSOR_CHAR    EQU  $7F   ; cursor character for BAD vga
BAD_CURSOR_FLASH   EQU  $5C   ; cursor flash rate for BAD vga
SCREEN_BASE_BAD    EQU  $C000 ; base address of screen memory (bad)
SCREEN_END_BAD     EQU  $C800 ; end address of screen memory (bad)

    ORG $8000
RESET_HANDLER:
    LDX     #WARM_CODE
    LDY     #WARM
RESET_LOOP:
    LDA     ,X+
    BEQ     WARM_END
    CMPA    ,Y+
    BNE     COLD_START
    BRA     RESET_LOOP
WARM_END:
    CMPX    #$0002
    BNE     COLD_START
START:
    LDA     #$20
    JSR     CLS
    LDX     #WARM_CODE
    JSR     PRINT_STRING
    BRA     MAIN_LOOP
COLD_START:
    LDX     #$8000
    LDD     #$0000
COLD_CLEAR_LOOP:
    STD     ,--X
    BNE     COLD_CLEAR_LOOP
    LDS     #$8000  ; set system stack pointer (enables interrupts)
    LDU     #$7800  ; set user stack pointer
    JSR     INIT_DISPLAY
    LDX     #COLD_MESSAGE1
    JSR     PRINT_STRING
MAIN_LOOP:
    JSR     BLINK
    BRA     MAIN_LOOP

PRINT_STRING: ; copy string from X to cursor
    PSHS    A,B,Y
    LDY     CURSOR_POS
    LDB     CURSOR_COL
COPY_LOOP_LN:
    LDA     ,X+
    BEQ     COPY_DONE
    STA     ,Y+
    INCB
    CMPB    #SCREEN_COLS
    BNE     COPY_LOOP_LN
    CLRB
    LDA     CURSOR_ROW
    INCA
    CMPA    #SCREEN_ROWS
    BNE     NO_SCROLL
    DECA
    JSR     SCROLL_UP
NO_SCROLL:
    STA     CURSOR_ROW
    BRA     COPY_LOOP_LN
COPY_DONE:
    STY     CURSOR_POS 
    PULS    A,B,Y,PC ;rts
SCROLL_UP: ; scroll screen up by one row
    PSHS    A,X,Y
    LDX     SCREEN_TOP
    LDY     SCREEN_TOP
    LDA     #SCREEN_COLS
    LEAX    A,X ; offset X with one row
SCROLL_UP_LOOP:
    LDA     ,X+
    STA     ,Y+
    CMPY    SCREEN_END
    BNE     SCROLL_UP_LOOP
BLANK_LINE:
    LDA     #$20
    LDX     #SCREEN_COLS
BLANK_LINE_LOOP:
    STA     ,Y+
    LEAX    -1,X
    BNE     BLANK_LINE_LOOP
    PULS    A,X,Y,PC ;rts
ERROR_HANDLER:
    RTI
NMI_HANDLER:
    RTI
SWI_HANDLER:
    RTI
IRQ_HANDLER:
    RTI
FIRQ_HANDLER:
    RTI
SWI2_HANDLER:
    RTI
SWI3_HANDLER:
    RTI
CLS:
    PSHS    A,X
    LDX     SCREEN_TOP                  ; get screen top address
CLS_LOOP:
    STA     ,X+                         ; clear screen memory
    CMPX    SCREEN_END                  ; check for end of screen
    BNE     CLS_LOOP                    ; loop until done
    CLR     CURSOR_COL                  ; reset cursor column
    CLR     CURSOR_ROW                  ; reset cursor row
    LDX     SCREEN_TOP                  ; reset cursor position
    STX     CURSOR_POS                  ; store cursor position
    PULS    A,X,PC ;rts
INIT_DISPLAY:
    PSHS    A,X
    LDX     #SCREEN_BASE_BAD            ; get screen base address for BAD VGA
    STX     SCREEN_TOP                  ; store in screen top
    LDX     #SCREEN_END_BAD             ; get screen end address for BAD VGA
    STX     SCREEN_END                  ; store in screen end
    LDA     #SCREEN_COLS_BAD            ; get number of columns for BAD VGA
    STA     SCREEN_COLS                 ; store in screen cols
    LDA     #SCREEN_ROWS_BAD            ; get number of rows for BAD VGA
    STA     SCREEN_ROWS                 ; store in screen rows
    LDA     #BAD_CURSOR_CHAR            ; get cursor character for BAD VGA
    STA     CURSOR                      ; store in cursor
    LDA     #BAD_CURSOR_FLASH           ; get cursor blink rate for BAD VGA
    STA     SCREEN_BLINK                ; store in screen blink counter reset
    PULS    A,X,PC ;rts
BLINK:
    PSHS    A
    DEC     CURSOR_COUNTER              ; decrement blink counter
    BNE     NO_BLINK                    ; if not zero, skip blink processing
    LDA     SCREEN_BLINK                ; reload blink counter
    STA     CURSOR_COUNTER
    LDA     [CURSOR_POS]                ; get current cursor character
    CMPA    CURSOR                      ; compare to normal cursor char
    BNE     BLINK_ON                    ; if not equal, turn on blink
    LDA     CURSOR                      ; get normal cursor char
    STA     [CURSOR_POS]                ; restore normal cursor
    BRA     NO_BLINK                    ; done
BLINK_ON:
    LDA     #$20                        ; get space character
    STA     [CURSOR_POS]                ; turn on blink (hide cursor)
NO_BLINK:
    PULS    A,PC ;rts

WARM_CODE:
    FCN "OK"                          ; Placeholder for warm start code
COLD_MESSAGE1:
    FCN "6309 MODULAR ACCESS DEVICE"  ; Cold start message
COLD_MESSAGE2:
    FCN "2025 BUILD 00.00.01"         ; Version info
COLD_MESSAGE3:
    FCN "BOOTSTRAP ONLY"              ; Additional info

    ORG $FFF0
VECTOR_TABLE:
    FDB ERROR_HANDLER
    FDB SWI3_HANDLER
    FDB SWI2_HANDLER
    FDB FIRQ_HANDLER
    FDB IRQ_HANDLER
    FDB SWI_HANDLER
    FDB NMI_HANDLER
    FDB RESET_HANDLER
