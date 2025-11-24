; zero page system variables
CURSOR         EQU  $0000 ; cursor character - byte
CURSOR_COUNTER EQU  $0001 ; blink counter - byte
CURSOR_POS     EQU  $0002 ; cursor address - word
CURSOR_COL     EQU  $0004 ; cursor column - byte
CURSOR_ROW     EQU  $0005 ; cursor row - byte
KEY_POLL_COUNT EQU  $0006 ; key poll counter - byte
KEY_POLL_TABLE EQU  $0008 ; key matrix - 8 bytes
KEY_ROLLOVER   EQU  $0010 ; key rollover table - 64 bytes
SCREEN_TOP     EQU  $0050 ; screen address - 2 bytes
SCREEN_END     EQU  $0052 ; end of screen memory - 2 bytes
SCREEN_COLS    EQU  $0054 ; number of columns on screen - 1 byte
SCREEN_ROWS    EQU  $0055 ; number of rows on screen - 1 byte
SCREEN_BLINK   EQU  $0056 ; screen blink counter reset - 1 byte
; defaut constants for BAD VGA operation
SCREEN_COLS_BAD    EQU  40    ; number of columns on screen using BAD vga
SCREEN_ROWS_BAD    EQU  25    ; number of rows on screen using BAD vga
BAD_CURSOR_CHAR    EQU  $7F   ; cursor character for BAD vga
BAD_CURSOR_FLASH   EQU  $5C   ; cursor flash rate for BAD vga
SCREEN_BASE_BAD    EQU  $C000 ; base address of screen memory (bad)
SCREEN_END_BAD     EQU  $C800 ; end address of screen memory (bad)

    ORG $8000
RESET_HANDLER:
    JSR     TEST_6309       ; check the host is a 6309
    LDMD    #$01            ; enable 6309 native mode
    TFR     V,X             ; expose V register for comparison
    CMPX    #$FFFF          ; compare to default V
    BNE     START           ; if not default, do warm start
    LDX     $WARM_CODE      ; load warm start code
    TFR     X,V             ; copy to V for storage
    BRA     COLD_START      ; do cold start

; *********************************************************************
; * Warm start routine                                                *
; * INPUT : none                                                      *
; * OUTPUT : none                                                     *
; *********************************************************************
START:
    LDA     #$20            ; space character
    JSR     CLS             ; clear screen to space
    LDX     #WARM_CODE      ; point to warm start message
    JSR     PRINT_STRING    ; print warm start message
    BRA     MAIN_LOOP       ; enter main loop

; *********************************************************************
; * Cold start routine                                                *
; * INPUT : none                                                      *
; * OUTPUT : none                                                     *
; *********************************************************************
COLD_START:
    LDX     #$8000          ; point to end of RAM
    LDD     #$0000          ; clear D register
COLD_CLEAR_LOOP:
    STD     ,--X            ; clear memory to zero
    BNE     COLD_CLEAR_LOOP
    LDS     #$8000          ; set system stack pointer (enables interrupts)
    LDU     #$7800          ; set user stack pointer
    JSR     INIT_DISPLAY    ; initialize display parameters
    LDX     #COLD_MESSAGE1  ; point to cold start message 1
    JSR     PRINT_STRING    ; print cold start message 1
    LDX     #COLD_MESSAGE2  ; point to cold start message 2
    JSR     PRINT_STRING    ; print cold start message 2
    LDX     #COLD_MESSAGE3  ; point to cold start message 3
    JSR     PRINT_STRING    ; print cold start message 3
MAIN_LOOP:
    JSR     BLINK           ; handle cursor blink  
    BRA     MAIN_LOOP

; *********************************************************************
; * Copy null terminated string from address in X to screen at cursor *
; * INPUT : vector to string in X                                     *
; * OUTPUT : none                                                     *
; *********************************************************************
PRINT_STRING:               ; copy string from X to cursor
    PSHS    A,B,Y
    LDY     CURSOR_POS      ; get current cursor address
    LDB     CURSOR_COL      ; get current cursor column
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

; *********************************************************************
; * Scroll screen up by one row                                       *
; * INPUT : none                                                      *
; * OUTPUT : none                                                     *
; *********************************************************************
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

; *********************************************************************
; * Clear last line of screen                                         *
; * INPUT : none                                                      *
; * OUTPUT : none                                                     *
; *********************************************************************
BLANK_LINE:
    LDA     #$20
    LDX     #SCREEN_COLS
BLANK_LINE_LOOP:
    STA     ,Y+
    LEAX    -1,X
    BNE     BLANK_LINE_LOOP
    PULS    A,X,Y,PC ;rts

; *********************************************************************
; * Test if CPU is a 6309                                             *
; * INPUT : none                                                      *
; * OUTPUT : if 6309, return; if not, halt system                     *
; *********************************************************************
TEST_6309:
    PSHS    D
    FDB     $1043
    CMPB    1,S
    BNE     IS_6309
    LDX     #$0200
    LDD     #$2020
FAIL_6309_LOOP:
    STD     ,X++
    CMPX    #$0400
    BNE     FAIL_6309_LOOP
    LDX     #$0400
    STX     CURSOR_POS
    CLR     CURSOR_COL
    LDX     #MSG_6309
    JSR     PRINT_STRING
HALT_6809:
    BRA     HALT_6809
IS_6309:
    PULS    D,PC

; *********************************************************************
; * Clear screen memory and reset cursor position                     *
; * INPUT : background character in A (typically blank space)         *
; * OUTPUT : none                                                     *
; *********************************************************************
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

; *********************************************************************
; * Initialize display parameters for BAD VGA                         *
; * INPUT : none                                                      *
; * OUTPUT : none                                                     *
; *********************************************************************
INIT_DISPLAY:
    PSHS    A,B
    LDD     #SCREEN_BASE_BAD            ; get screen base address for BAD VGA
    STD     SCREEN_TOP                  ; store in screen top
    LDD     #SCREEN_END_BAD             ; get screen end address for BAD VGA
    STD     SCREEN_END                  ; store in screen end
    LDA     #SCREEN_COLS_BAD            ; get number of columns for BAD VGA
    STA     SCREEN_COLS                 ; store in screen cols
    LDA     #SCREEN_ROWS_BAD            ; get number of rows for BAD VGA
    STA     SCREEN_ROWS                 ; store in screen rows
    LDA     #BAD_CURSOR_CHAR            ; get cursor character for BAD VGA
    STA     CURSOR                      ; store in cursor
    LDA     #BAD_CURSOR_FLASH           ; get cursor blink rate for BAD VGA
    STA     SCREEN_BLINK                ; store in screen blink counter reset
    PULS    A,B,PC ;rts

; *********************************************************************
; * Handle cursor blink processing                                    *
; * INPUT : none                                                      *
; * OUTPUT : none                                                     *
; *********************************************************************
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

WARM_CODE:
    FCN "OK"                          ; Placeholder for warm start code
COLD_MESSAGE1:
    FCN "6309 MODULAR ACCESS DEVICE"  ; Cold start message
COLD_MESSAGE2:
    FCN "2025 BUILD 00.00.01"         ; Version info
COLD_MESSAGE3:
    FCN "BOOTSTRAP ONLY"              ; Additional info
MSG_6309:
    FCN "6309 NOT DETECTED - HALTING" ; 6309 not detected message

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
