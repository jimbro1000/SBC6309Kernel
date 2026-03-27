    include "noviewconst.inc"

; * init display () - general call all required routines with defaults
; * set mode (A) - 0 = badvga (no other modes supported yet)
; * set register (A,B) - assumes complex VDC
; * set base (D) - define base address of screen ram
; * set cursor (D) - set screen cursor position
; * write char (A) - write char A to cursor position (and advance position)
; * write string (D) - write null terminated string at D to screen at cursor position
; * blank screen (A) - set screen to character A
; * scroll (A) - scroll A lines
; * putcr () - newline

; *********************************************************************
; * Display driver for null display                                   *
; *     no actual display, just a sink for output                     *
; * maintains cursor and screen parameters in the absence of hardware *
; *********************************************************************

; *********************************************************************
; * Initialize display parameters for null display                    *
; * Assumes S stack pointer is correctly placed  		              *
; * INPUT : none                                                      *
; * OUTPUT : none                                                     *
; *********************************************************************
INIT_DISPLAY:
    PSHS    A,B
    LDD     #SCREEN_BASE_NULL           ; get screen base address for null display
    STD     SCREEN_TOP                  ; store in screen top
    LDD     #SCREEN_END_NULL            ; get screen end address for null display
    STD     SCREEN_END                  ; store in screen end
    LDD     #SCREEN_SIZE_NULL           ; get screen size for null display
    STD     SCREEN_SIZE                 ; store in screen size
    LDA     #SCREEN_COLS_NULL           ; get number of columns for null display
    STA     SCREEN_COLS                 ; store in screen cols
    LDA     #SCREEN_ROWS_NULL           ; get number of rows for null display
    STA     SCREEN_ROWS                 ; store in screen rows
    LDA     #NULL_CURSOR_CHAR           ; get cursor character for null display
    STA     CURSOR                      ; store in cursor
    LDA     #NULL_CURSOR_FLASH          ; get cursor blink rate for null display
    STA     SCREEN_BLINK                ; store in screen blink counter reset
    LDA     #NULL_BLANK_CHAR            ; get background character for null display
    STA     BACK_CHAR                   ; store in background character
    PULS    A,B,PC ;rts

SET_DISPLAY_BASE:
    STD     SCREEN_TOP                  ; set screen base address
    LDX     SCREEN_SIZE                 ; get screen size
    LEAX    D,X                         ; calculate screen end address
    STX     SCREEN_END                  ; store screen end address
    RTS

SET_CURSOR:
    PSHS    X
    LDX     CURSOR_POS                  ; get current cursor position
    STD     CURSOR_ROW                  ; set cursor position (row,col first)
    PSHS    B
    LDB     SCREEN_COLS
    MUL                                 ; multiply row by columns
    LEAX    D,X                         ; add offset to base address
    PULS    B
    ABX                                 ; add column offset
    STX     CURSOR_POS                  ; store new cursor position
    PULS    X,PC ;rts

; *********************************************************************
; * Handle cursor blink processing                                    *
; * INPUT : none                                                      *
; * OUTPUT : none                                                     *
; *********************************************************************
BLINK:
    RTS                                 ; no blinking for null display

WRITE_CHAR:
    PSHS    A,X
    LDX     CURSOR_POS                  ; get current cursor address
    LDA     CURSOR_COL                  ; get current cursor column
    CMPA    #SCREEN_COLS                ; compare to number of screen columns
    BNE     NO_SCROLL_CHAR              ; if not at end of line, skip scroll processing
    CLR     CURSOR_COL                  ; reset column to 0
    LDA     CURSOR_ROW                  ; get current cursor row  
    INCA                                ; move to next row
    CMPA    #SCREEN_ROWS                ; compare to number of screen rows
    BNE     NO_SCROLL_CHAR              ; if not at end of screen, skip scroll processing
    DECA                                ; move back to last row
    STA     CURSOR_ROW                  ; store new cursor row
    LDA     #SCREEN_COLS                ; get number of columns for screen
    NEGA                                ; negate to get negative offset 
    LEAX    A,X                         ; calculate offset to start of line
NO_SCROLL_CHAR:
    STX     CURSOR_POS                  ; store new cursor position
    PULS    A,X,PC ;rts

; *********************************************************************
; * Output carriage return - handle new line action                   *
; * INPUT : none                                                      *
; * OUTPUT : none                                                     *
; *********************************************************************
PUT_CR:
    PSHS    A,B,Y
    CLR     CURSOR_COL                  ; reset column to 0
    LDA     CURSOR_ROW                  ; get current cursor row
    INCA                                ; move to next row
    CMPA    #SCREEN_ROWS                ; compare to number of screen rows
    BNE     NO_SCROLL_CR                ; if not at end of screen, skip scroll processing
    DECA                                ; move back to last row
NO_SCROLL_CR:
    STA     CURSOR_ROW                  ; store new cursor row
    LDB     #SCREEN_COLS                ; get number of columns for screen
    MUL                                 ; calculate offset to start of line
    LDY     #SCREEN_TOP                 ; get screen top address
    LEAY    D,Y                         ; calculate new cursor position
    STY     CURSOR_POS                  ; store new cursor position
    PULS    A,B,Y,PC ;rts

; *********************************************************************
; * Scroll screen up by one row                                       *
; * INPUT : none                                                      *
; * OUTPUT : none                                                     *
; *********************************************************************
SCROLL_UP: ; scroll screen up by one row
    RTS                                 ; no scrolling for null display

; *********************************************************************
; * Copy null terminated string from address in X to screen at cursor *
; * INPUT : vector to string in X                                     *
; * OUTPUT : none                                                     *
; *********************************************************************
WRITE_STRING:               ; copy string from X to cursor
    PSHS    A,B,Y
    LDY     CURSOR_POS      ; get current cursor address
    LDB     CURSOR_COL      ; get current cursor column
COPY_LOOP_LN:
    LDA     ,X+             ; get next character from string
    BEQ     COPY_DONE       ; if null terminator, done
    INCB                    ; move to next column 
    CMPB    #SCREEN_COLS    ; compare to number of screen columns
    BNE     COPY_LOOP_LN    ; if not at end of line, continue copying
    CLRB                    ; reset column to 0
    LDA     CURSOR_ROW      ; get current cursor row
    INCA                    ; move to next row
    CMPA    #SCREEN_ROWS    ; compare to number of screen rows
    BNE     NO_SCROLL       ; if not at end of screen, skip scroll processing
    DECA                    ; move back to last row
NO_SCROLL:
    STA     CURSOR_ROW      ; store new cursor position
    BRA     COPY_LOOP_LN    ; continue copying next character
COPY_DONE:
    STY     CURSOR_POS      ; store new cursor position
    PULS    A,B,Y,PC ;rts

; *********************************************************************
; * Clear last line of screen                                         *
; * INPUT : none                                                      *
; * OUTPUT : none                                                     *
; *********************************************************************
BLANK_LINE:
    RTS                                 ; no blanking for null display

; *********************************************************************
; * Clear screen memory and reset cursor position                     *
; * Default version uses background character stored in BACK_CHAR     *
; * INPUT : background character in A (typically blank space)         *
; * OUTPUT : none                                                     *
; *********************************************************************
DEFAULT_CLS:
    RTS                                 ; no clearing for null display
CLS:
    RTS                                 ; no clearing for null display
