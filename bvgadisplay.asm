    include "bvgaconst.inc"

; * init display () - general call all required routines with defaults
; * set mode (A) - 0 = badvga (no other modes supported yet)
; * set register (A,B) - assumes complex VDC
; * set base (D) - define base address of screen ram
; * set cursor (D) - set screen cursor position
; * blink () - handle cursor blink processing
; * write char (A) - write char A to cursor position (and advance position)
; * write string (D) - write null terminated string at D to screen at cursor position
; * blank screen (A) - set screen to character A
; * scroll (A) - scroll A lines
; * put cr () - newline

; *********************************************************************
; * Initialize display parameters for BAD VGA                         *
; * Assumes S stack pointer is correctly placed  		              *
; * INPUT : none                                                      *
; * OUTPUT : none                                                     *
; *********************************************************************
INIT_DISPLAY:
    PSHS    A,B
    LDD     #SCREEN_BASE_BAD            ; get screen base address for BAD VGA
    STD     SCREEN_TOP                  ; store in screen top
    LDD     #SCREEN_END_BAD             ; get screen end address for BAD VGA
    STD     SCREEN_END                  ; store in screen end
    LDD     #SCREEN_SIZE_BAD            ; get screen size for BAD VGA
    STD     SCREEN_SIZE                 ; store in screen size
    LDA     #SCREEN_COLS_BAD            ; get number of columns for BAD VGA
    STA     SCREEN_COLS                 ; store in screen cols
    LDA     #SCREEN_ROWS_BAD            ; get number of rows for BAD VGA
    STA     SCREEN_ROWS                 ; store in screen rows
    LDA     #BAD_CURSOR_CHAR            ; get cursor character for BAD VGA
    STA     CURSOR                      ; store in cursor
    LDA     #BAD_CURSOR_FLASH           ; get cursor blink rate for BAD VGA
    STA     SCREEN_BLINK                ; store in screen blink counter reset
    LDA     #BAD_BLANK_CHAR             ; get background character for BAD VGA
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

WRITE_CHAR:
    PSHS    A,X
    LDX     CURSOR_POS                  ; get current cursor address  
    STA     ,X+                         ; write character at cursor position
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
    JSR     SCROLL_UP                   ; scroll screen up by one line
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
    JSR     SCROLL_UP                   ; scroll screen up by one line
NO_SCROLL_CR:
    STA     CURSOR_ROW                  ; store new cursor row
    LDB     #SCREEN_COLS                ; get number of columns for screen
    MUL                                 ; calculate offset to start of line
    LDY     #SCREEN_TOP                 ; get screen top address
    LEAY    D,Y                         ; calculate new cursor position
    STY     CURSOR_POS                  ; store new cursor position
    PULS    A,B,Y,PC ;rts

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
    STA     ,Y+             ; write character to screen
    INCB                    ; move to next column 
    CMPB    #SCREEN_COLS    ; compare to number of screen columns
    BNE     COPY_LOOP_LN    ; if not at end of line, continue copying
    CLRB                    ; reset column to 0
    LDA     CURSOR_ROW      ; get current cursor row
    INCA                    ; move to next row
    CMPA    #SCREEN_ROWS    ; compare to number of screen rows
    BNE     NO_SCROLL       ; if not at end of screen, skip scroll processing
    DECA                    ; move back to last row
    JSR     SCROLL_UP       ; scroll screen up by one line
NO_SCROLL:
    STA     CURSOR_ROW      ; store new cursor position
    BRA     COPY_LOOP_LN    ; continue copying next character
COPY_DONE:
    STY     CURSOR_POS      ; store new cursor position
    PULS    A,B,Y,PC ;rts

; *********************************************************************
; * Scroll screen up by one row                                       *
; * INPUT : none                                                      *
; * OUTPUT : none                                                     *
; *********************************************************************
SCROLL_UP: ; scroll screen up by one row
    PSHS    A,X,Y
    LDX     SCREEN_TOP      ; get screen top address
    LDY     SCREEN_TOP      ; get screen top address for destination
    LDA     #SCREEN_COLS    ; get number of columns for screen
    LEAX    A,X             ; offset X with one row
SCROLL_UP_LOOP:
    LDA     ,X+             ; get character from next line
    STA     ,Y+             ; write character to current line
    CMPY    SCREEN_END      ; check if reached end of screen
    BNE     SCROLL_UP_LOOP  ; loop until end of screen
    BRA     BLANK_LINE_START    ; blank last line of screen

; *********************************************************************
; * Clear last line of screen                                         *
; * INPUT : none                                                      *
; * OUTPUT : none                                                     *
; *********************************************************************
BLANK_LINE:
    PSHS    A,X,Y
BLANK_LINE_START:
    LDA     BACK_CHAR               ; get background character for blanking
    LDB     #SCREEN_COLS            ; get number of columns for screen
BLANK_LINE_LOOP:
    STA     ,Y+                     ; write blank character to current position
    DECB                            ; decrement column count
    BNE     BLANK_LINE_LOOP         ; loop until end of line
    PULS    A,X,Y,PC ;rts

; *********************************************************************
; * Clear screen memory and reset cursor position                     *
; * Default version uses background character stored in BACK_CHAR     *
; * INPUT : background character in A (typically blank space)         *
; * OUTPUT : none                                                     *
; *********************************************************************
DEFAULT_CLS:
    PSHS    A
    LDA     BACK_CHAR
    JSR     CLS
    PULS    A,PC ;rts
CLS:
    PSHS    B,X
    LDX     SCREEN_TOP                  ; get screen top address
    TFR     A,B                         ; copy background char to B
CLS_LOOP:
    STD     ,X++                        ; clear screen memory
    CMPX    SCREEN_END                  ; check for end of screen
    BNE     CLS_LOOP                    ; loop until done
    CLR     CURSOR_COL                  ; reset cursor column
    CLR     CURSOR_ROW                  ; reset cursor row
    LDX     SCREEN_TOP                  ; reset cursor position
    STX     CURSOR_POS                  ; store cursor position
    PULS    B,X,PC ;rts
