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

SCREEN_COLS    EQU  40    ; number of columns on screen
SCREEN_ROWS    EQU  25    ; number of rows on screen

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
    RTS
INIT_DISPLAY:
    RTS

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
