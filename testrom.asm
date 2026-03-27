    include "config.inc"
    include "cpu.inc"
    include "acia.inc"
    include "constants.inc"

; *****************************************************************************
; * 6309 test ROM - intended to run on the SBC6309 with BAD VGA card          *
; * Author : Julian Brown                                                     *
; * Date : 2024-06-01                                                         *
; * This code leans heavily on prior work by Jeff Tranter                     *
; * This ROM performs the following functions:                                *
; * 1. On reset, check if CPU is a 6309 and halt if not                       *
; * 2. If 6309, check if warm start code is present and if so, do warm start  *
; *    else do cold start                                                     *
; * 3. On warm start, clear screen and print warm start message               *
; *    on cold, initialise system, clear screen, print cold start message     *
; * 4. Enter main loop to handle keyboard input and monitor commands          *
; * 5. Handle cursor blinking in main loop                                    *
; * 6. Handle serial input from ACIA in main loop                             *
; * 7. Monitor supports simple command parsing with support for setting       *
; *    display mode and loading hex files from serial input                   *
; * 8. Monitor commands are entered at the prompt and processed when the      *
; *    user presses enter                                                     *
; * 9. Monitor command format is loosely based on wozmon with support for hex *
; *    file loading, display mode setting, and command cancellation           *
; * 10. Monitor command parsing is incomplete and can be extended with        *
; *     additional commands as needed                                         *
; * 11. The ROM is intended for testing and demonstration purposes and is     *
; *     not a full implementation of a monitor or operating system            *
; *****************************************************************************

; zero page system variables
CURSOR         EQU  $0000 ; cursor character - byte
CURSOR_COUNTER EQU  $0001 ; blink counter - byte
CURSOR_POS     EQU  $0002 ; cursor address - word
CURSOR_ROW     EQU  $0004 ; cursor row - byte
CURSOR_COL     EQU  $0005 ; cursor column - byte
KEY_POLL_COUNT EQU  $0006 ; key poll counter - byte
KEY_POLL_TABLE EQU  $0008 ; key matrix - 8 bytes
KEY_BUFF_HEAD  EQU  $000E ; key buffer head - byte
KEY_BUFF_TAIL  EQU  $000F ; key buffer tail - byte
; *****************************************************************************
; * keyboard rollover can be reused as an input buffer for serial input
; *****************************************************************************
KEY_ROLLOVER   EQU  $0010 ; key rollover table - 64 bytes
KEY_ROLL_END   EQU  $004F ; end of key rollover table
SCREEN_TOP     EQU  $0050 ; screen address - 2 bytes
SCREEN_END     EQU  $0052 ; end of screen memory - 2 bytes
SCREEN_SIZE    EQU  $0054 ; size of screen memory - 2 bytes
SCREEN_COLS    EQU  $0056 ; number of columns on screen - 1 byte
SCREEN_ROWS    EQU  $0057 ; number of rows on screen - 1 byte
SCREEN_BLINK   EQU  $0058 ; screen blink counter reset - 1 byte
BACK_CHAR      EQU  $0059 ; background character - 1 byte
dMODE          EQU  $005A ; monitor mode - 1 byte
dTEMP          EQU  $005B ; monitor temp - 1 byte
dST            EQU  $005C ; monitor store index - 2 bytes
dXAM           EQU  $005E ; monitor XAM index - 2 bytes
MON_RAM        EQU  $0060 ; base of monitor RAM for command storage, etc.   
                          ; 128 bytes

; *****************************************************************************
; * interrupt vector definitions                                              *
; *****************************************************************************

ERROR_HANDLER  EQU  $0100 ; error handler vector
NMI_HANDLER    EQU  $0103 ; NMI handler vector
SWI_HANDLER    EQU  $0106 ; SWI handler vector
IRQ_HANDLER    EQU  $0109 ; IRQ handler vector
FIRQ_HANDLER   EQU  $010C ; FIRQ handler vector
SWI2_HANDLER   EQU  $010F ; SWI2 handler vector
SWI3_HANDLER   EQU  $0112 ; SWI3 handler vector

; default constants for BAD VGA operation
SCREEN_COLS_BAD    EQU  50    ; number of columns on screen using BAD vga
SCREEN_ROWS_BAD    EQU  18    ; number of rows on screen using BAD vga

    ORG     ROM_BASE
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
    LDA     #$0E            ; jmp opcode
    LDX     #ERROR_VECTOR   ; define interrupt vectors
    STA     ERROR_HANDLER
    STX     ERROR_HANDLER + 1
    LDX     #NMI_VECTOR
    STA     NMI_HANDLER
    STX     NMI_HANDLER + 1
    LDX     #SWI_VECTOR
    STA     SWI_HANDLER
    STX     SWI_HANDLER + 1
    LDX     #IRQ_VECTOR
    STA     IRQ_HANDLER
    STX     IRQ_HANDLER + 1
    LDX     #FIRQ_VECTOR
    STA     FIRQ_HANDLER
    STX     FIRQ_HANDLER + 1
    LDX     #SWI2_VECTOR
    STA     SWI2_HANDLER
    STX     SWI2_HANDLER + 1
    LDX     #SWI3_VECTOR
    STA     SWI3_HANDLER
    STX     SWI3_HANDLER + 1
    LDU     #$8000          ; set user stack pointer
    LDS     #$7F80          ; set system stack pointer (enables interrupts)
    JSR     INIT_DISPLAY    ; initialize display parameters
    LDX     #COLD_MESSAGE1  ; point to cold start message 1
    JSR     PRINT_STRING    ; print cold start message 1
    LDX     #COLD_MESSAGE2  ; point to cold start message 2
    JSR     PRINT_STRING    ; print cold start message 2
    LDX     #COLD_MESSAGE3  ; point to cold start message 3
    JSR     PRINT_STRING    ; print cold start message 3

; *********************************************************************
; * Main processing loop                                              *
; * 1. Blink cursor on "counter"                                      *
; * 2. Check for serial input                                         *
; * 3. If serial input, get data until stream empty or buffer full    *
; * 4. Pull a line of input from buffer or until empty                *
; * 5. Echo line to screen at cursor position                         *
; * 6. On end of line pass to monitor to parse command                * 
; * 7. Repeat                                                         * 
; *********************************************************************
MAIN_START:
    CLRB                        ; clear command char index   
MAIN_LOOP:
    JSR     BLINK               ; handle cursor blink
DRAIN_SERIAL:
    JSR     IS_KBD_BUFFER_FULL  ; check if keyboard buffer is full  
    BEQ     FORCE_MON           ; if full, skip forcing serial input
    JSR     CHECK_SERIAL_IN     ; check for serial input
    BEQ     FORCE_MON           ; if no data, skip
    JSR     DO_SERIAL_IN        ; get serial data
    JSR     PUSH_KEYBOARD_BUFFER ; push character into keyboard buffer
    BRA     DRAIN_SERIAL        ; repeat until no more data
FORCE_MON:
    JSR     MONITOR             ; monitor drain buffer and process commands if complete
    BRA     MAIN_LOOP

PUT_MSG:
    PSHS    X
    LDX     2,S
    BSR     PRINT_STRING
    STX     2,S
    PULS    X,PC ;rts
PUT_CONST:
    PSHS    A,X
    LDX     3,S
    LDA     ,X+
    BSR     PRINT_CHAR
    STX     3,S
    PULS    A,X,PC ;rts
PUT_BYTE:
    PSHS    A
    LSRA
    LSRA
    LSRA
    LSRA
    BSR     PUT_HEX
    PULS    A
; fall into PUT_HEX
PUT_HEX:
    PSHS    A
    ANDA    #$0F            ; remove upper half
    ADDA    #'0'            ; make prinable
    CMPA    #'9'            ; check if in digit range
    BLS     PH0             ;  yes - skip alpha adjustment
    ADDA    #7              ; convert to alpha (10=A, etc.)
PH0:
    BSR     PRINT_CHAR
    PULS    A,PC ;rts
PUT_SPACE:
    PSHS    A
    LDA     #$60
    BSR     PRINT_CHAR
    PULS    A,PC ;rts

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

PRINT_CHAR:
    PSHS    A,X
    LDX     CURSOR_POS
    STA     ,X+
    LDA     CURSOR_COL
    CMPA    #SCREEN_COLS
    BNE     NO_SCROLL_CHAR
    CLR     CURSOR_COL
    LDA     CURSOR_ROW
    INCA
    CMPA    #SCREEN_ROWS
    BNE     NO_SCROLL_CHAR
    DECA
    STA     CURSOR_ROW
    LDA     #SCREEN_COLS
    NEGA
    LEAX    A,X
    JSR     SCROLL_UP
NO_SCROLL_CHAR:
    STX     CURSOR_POS
    PULS    A,X,PC ;rts

BACKSPACE:
    PSHS    A,X
    LDX     CURSOR_POS
    CMPX    SCREEN_TOP
    BEQ     NO_BACKSPACE
    LDA     CURSOR_COL
    TSTA
    BNE     PRINT_BACKSPACE
    DEC     CURSOR_ROW
    LDA     SCREEN_COLS
PRINT_BACKSPACE:
    DECA
    STA     CURSOR_COL
    LDA     BACK_CHAR
    STA     ,-X
NO_BACKSPACE:
    PULS    A,X,PC ;rts

PUT_CR:
    PSHS    A,B,Y
    CLR     CURSOR_COL
    LDA     CURSOR_ROW
    INCA
    CMPA    #SCREEN_ROWS
    BNE     NO_SCROLL_CR
    DECA
    JSR     SCROLL_UP
NO_SCROLL_CR:
    STA     CURSOR_ROW
    LDB     #SCREEN_COLS
    MUL
    LDY     #SCREEN_TOP
    LEAY    D,Y
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
    LDA     #BAD_BACK_CHAR              ; get background character for BAD VGA
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

; *********************************************************************
; * Receive a byte from the serial port via ACIA                      *
; * INPUT : none                                                      *
; * OUTPUT : received byte in A                                       *
; *********************************************************************

DO_SERIAL_IN: 
	PSHS    CC,B			            ; save registers
    ORCC    #IntsDisable		        ; disable interrrupts
    LDA     #AciaSRxFull		        ; check for receiver register full (below)    
	LDB     AciaCmd			            ; get command register
    ORB     #AciaDTR		            ; set DTR low
    STB     AciaCmd			            ; send it
    ANDB    #~AciaDTR		            ; set DTR bit high again
	
GET_SERIAL_CHAR:
    BITA    AciaStat		            ; test status of ACIA
    BEQ     GET_SERIAL_CHAR	            ; no data, keep waiting
    STB     AciaCmd			            ; set DTR high again
    LDA     AciaData		            ; get the received data	from Acia Rx/Tx Register
    ANDCC   #IntsEnable		            ; re-enable interrupts
    PULS    CC,B,PC		                ; restore and return

; *********************************************************************
; * Check if data is available from serial port via ACIA              *
; * INPUT : none                                                      *
; * OUTPUT : if data available, Z clear                               *
; *          if no data, Z set                                        *
; *********************************************************************

CHECK_SERIAL_IN:
    BITA    AciaStat		            ; test status of ACIA
    RTS         		                ; restore and return

; *********************************************************************
; * Transmit a byte to the serial port via ACIA                       *
; * INPUT : byte to transmit in A                                     *
; * OUTPUT : none                                                     *
; *********************************************************************

DO_SERIAL_OUT:
	PSHS    CC,B			            ; save regs
    LDB     #AciaSTxEmpty		        ; check for space in transmit register
PUT_SERIAL_CHAR:
    BITB    AciaStat		            ; is there space?
    BEQ     PUT_SERIAL_CHAR			    ; nop, loop until current byte transmitted
    STA     AciaData		            ; write data to be transmitted	
    PULS    CC,B,PC			            ; restore and return
PUT_SERIAL_MSG:
    PSHS    X
    LDX     2,S
    BSR     PUT_SERIAL_STRING
    STX     2,S
    PULS    X,PC ;rts
;;
;; PUTCR - output CRLF to CONSOLE channel
;; return: all registers preserved
;;
PUT_SERIAL_CR:
        PSHS     A                                 ; save A value
PUTCR1  LDA      #CR                               ; output a carriage return
        BSR      PUT_SERIAL_CHAR                   ;
        LDA      #LF                               ; output a line feed
        BSR      PUT_SERIAL_CHAR                   
        PULS     A,PC                              ; restore A and PC and return
;;
;; PUT_SERIAL_STRING - output NULL/FF terminated string at X to CONSOLE channel
;; terminate with either 0, or $FF (CRLF before terminates)
;; inputs: X = address of string to output
;; return: X = terminator byte of string+1
;;
PUT_SERIAL_STRING:
        PSHS     A                                 ; preserve A
PSS1    LDA      ,X+                               ; get char from message
        BEQ      PSTRX                             ;  0 = end
        CMPA     #$FF                              ; FF = newline end?
        BEQ      PUTCR1                            ;  yes, new line, exit via PUTCR
        JSR      PUT_SERIAL_CHAR                   ; output character to term
        BRA      PSS1                              ; keep going
PSTRX   PULS     A,PC                              ; restore A and return
PUT_SERIAL_CONST:
    PSHS    A,X
    LDX     3,S
    LDA     ,X+
    BSR     PUT_SERIAL_CHAR
    STX     3,S
    PULS    A,X,PC ;rts
PUT_SERIAL_BYTE:
    PSHS    A
    LSRA
    LSRA
    LSRA
    LSRA
    BSR     PUT_SERIAL_HEX
    PULS    A
; fall into PUT_HEX
PUT_SERIAL_HEX:
    PSHS    A
    ANDA    #$0F            ; remove upper half
    ADDA    #'0'            ; make prinable
    CMPA    #'9'            ; check if in digit range
    BLS     PH1             ;  yes - skip alpha adjustment
    ADDA    #7              ; convert to alpha (10=A, etc.)
PH1:
    BSR     PUT_SERIAL_CHAR
    PULS    A,PC ;rts
PUT_SERIAL_SPACE:
    PSHS    A
    LDA     #$60
    BSR     PUT_SERIAL_CHAR
    PULS    A,PC ;rts

DO_SET_BAUD:
	CMPB    #$07			            ; check for a valid board rate number
    BCC     SET_BAUD_ERR			    ; error, exit
	
    LDX     #BAUD_RATE_TABLE		    ; point to base of baud rate table
    ABX				                    ; move to correct entry
    LDB     TextSerBaudRate 	        ; get the baud rate to set
    ANDB    #~AciaBrdMask		        ; mask out baud rate bits
    ORB     ,X			                ; merge with rate from table
    STB     TextSerBaudRate 	        ; set the baud rate	
    ANDCC   #~FlagCarry		            ; clear carry
    BRA     SET_BAUD_END		        ; return
	
SET_BAUD_ERR:
    COMB				                ; flag error
SET_BAUD_END:
    RTS

; baud rate table, see 6551 datasheet for details.
;
; Note the 6551 is capable of other baud rates if programmed 
; directly
;
BAUD_RATE_TABLE:   
    FCB     AciaCBrd300	    ; 300 baud
    FCB     AciaCBrd600	    ; 600 baud
    FCB     AciaCBrd1200	; 1200 baud
    FCB     AciaCBrd2400	; 2400 baud
    FCB     AciaCBrd4800	; 4800 baud
    FCB     AciaCBrd9600	; 9600 baud
    FCB     AciaCBrd19200	; 19200 baud

; *********************************************************************
; * Check if keyboard buffer is full                                  *
; * INPUT : none                                                      *
; * OUTPUT : if full, Z set                                           *
; *          if not full, Z clear                                     *
; *********************************************************************
IS_KBD_BUFFER_FULL:
    PSHS    A
    LDA     KEY_BUFF_TAIL               ; get tail of buffer
    CMPA    #KEY_ROLL_END               ; compare to end of buffer
    BEQ     KBD_BUFFER_WRAP             ; if at end, wrap to start
    SUBA    KEY_BUFF_HEAD               ; tail - head
    CMPA    #$FF                        ; compare to -1
    BEQ     KBD_BUFFER_FULL             ; if equal, buffer is full
KBD_BUFFER_WRAP
    LDA     KEY_BUFF_HEAD               ; get head of buffer
    CMPA    #KEY_ROLLOVER               ; compare to start of buffer
KBD_BUFFER_FULL:
    PULS    A,PC ;rts

; *********************************************************************
; * Check if keyboard buffer is empty                                 *
; * INPUT : none                                                      *
; * OUTPUT : if empty, Z set                                         *
; *          if not empty, Z clear                                   *
; *********************************************************************

IS_KBD_BUFFER_EMPTY:
    PSHS    A
    LDA     KEY_BUFF_HEAD               ; get head of buffer
    CMPA    KEY_BUFF_TAIL               ; compare to end of buffer
    PULS    A,PC ;rts

; *********************************************************************
; * Push a character into the keyboard buffer                         *
; * INPUT : character in A                                            *
; * OUTPUT : none                                                     * 
; *********************************************************************

PUSH_KEYBOARD_BUFFER:
    PSHS    X
    LDX     KEY_BUFF_HEAD               ; get head of buffer
    STA     ,X+                         ; store character in buffer
    CMPX    #KEY_ROLL_END               ; check for end of buffer
    BNE     PUSH_KBD_BUFF_END           ; if not end, done
    LDX     #KEY_ROLLOVER               ; wrap to start of buffer
PUSH_KBD_BUFF_END:
    STX     KEY_BUFF_HEAD               ; store updated head pointer
    PULS    X,PC ;rts

; *********************************************************************
; * Pop a character from the keyboard buffer                          *
; * INPUT : none                                                      *
; * OUTPUT : character in A                                           *
; *********************************************************************

POP_KEYBOARD_BUFFER:
    PSHS    X
    CLRA
    JSR     IS_KBD_BUFFER_EMPTY
    BEQ     POP_KBD_BUFF_END            ; if not empty, proceed
    LDX     KEY_BUFF_TAIL               ; get tail of buffer
    LDA     ,X+                         ; get character from buffer
    CMPX    #KEY_ROLL_END               ; check for end of buffer
    BNE     POP_KBD_BUFF_END            ; if not end, done
    LDX     #KEY_ROLLOVER               ; wrap to start of buffer   
POP_KBD_BUFF_END:
    STX     KEY_BUFF_TAIL               ; store updated tail pointer
    PULS    X,PC ;rts    

; **************************************************************
; * Monitor loosly based on wozmon translated to 6809 assembly *
; * Implementation is incomplete....                           *
; **************************************************************

MONITOR:
; drain keyboard buffer or until CR found
    JSR     POP_KEYBOARD_BUFFER
    CMPA    #$0D            ; check for carriage return
    BEQ     MONITOR_LINE_COMPLETE
    CMPA    #CTL_H          ; check for backspace
    BEQ     MONITOR_BACKSPACE
    CMPA    #DEL            ; delete
    BEQ     MONITOR_BACKSPACE
    CMPA    #CTL_X          ; check for cancel
    BEQ     MONITOR_CANCEL
    CMPA    #ESC            ; check for escape
    BEQ     MONITOR_CANCEL
    JSR     PRINT_CHAR      ; echo character to screen
    STA     B,U             ; increment cursor column
    INCB
    JSR     IS_KBD_BUFFER_EMPTY
    BEQ     MONITOR_PAUSE   ; if empty, return to main loop
    BRA     MONITOR         ; else keep draining
MONITOR_CANCEL:
    LDA     #'\'
    JSR     PRINT_CHAR      ; print '\' for cancel
    JSR     PUT_CR          ; print carriage return
    BRA     MONITOR
MONITOR_BACKSPACE:
    TSTB                    ; check command length
    BEQ     MONITOR_SOL     ; if at char 0, ignore backspace
    JSR     BACKSPACE       ; do backspace on screen
    DECB
MONITOR_SOL:
    BRA     MONITOR         ; continue draining
MONITOR_PAUSE:
    RTS
MONITOR_LINE_COMPLETE:
    STA     B,U             ; store command length
    JSR     PUT_CR          ; print carriage return
    ; Y points to command buffer 
    CLRD
    DECB
MON_SETMODE:
    STA     dMODE           ; $00=XAM (0), $BA=STORE (-), $2E=BLOK XAM (+)
MON_BLSKIP:
    INCB                    ; advance command index
MON_NEXT_ITEM:
    LDA     B,U             ; get next command character
    CMPA    #CR             ; check for end of command
    BEQ     MON_XRET        ; if end, execute command
    CMPA    #DOT            ; check for period
    BEQ     MON_SETMODE     ; if period, set block mode
    BLS     MON_BLSKIP      ; delimiters
    ORA     #$80            ; convert high-bit set
    CMPA    #HI_COL         ; check for colon
    BEQ     MON_SETMODE     ; set store mode
    CMPA    #HI_X           ; check for X
    BEQ     MON_XLOAD       ; load hexfile from console
MON_NEWHEX:
    CLRW
    STB     dTEMP
MON_NEXTHEX:
    LDA     B,U             ; get next command character
    EORA    #$30            ; convert digits to value
    CMPA    #$09            ; check for non-digit
    BLS     MON_ADDDIGIT    ; if digit, add to value
    ORA     #$20            ; neutralize case
    ADDA    #$89            ; convert A-F to $FA-$FF
    CMPA    #$F9            ; check for non-hex
    BLS     MON_NOTHEX      ; if hex, continue
MON_ADDDIGIT:
    ANDA    #$0F            ; mask to 4 bits
    EXG     D,W             ; digit in 4lsb of E, WORD in D, buffer ptr in F
    ASLD                    ; shift left 4 bits
    ASLD
    ASLD
    ASLD
    ORR     E,B             ; OR the new digit in WORD
    EXG     D,W             ; restore registers
    INCB                    ; advance command index
    BRA     MON_NEXTHEX     ; get next hex digit
    RTS
MON_RUN:
    LEAS   2,S              ; drop return address from stack
    JMP    [MON_XAM,U]      ; RUN command, jump to address in XAM index
MON_XLOAD:
    LDX    #HEX_DOWNLOAD_MSG
    JSR    PRINT_STRING
    JSR    DL_START         ; download hex file from host
MON_XRET:
    RTS

; A non-hex, non-command character has been encountered. We may have a new
; hex argument in WORD (if MON_TEMP = B, we do NOT) and if so, we need to figure
; out what to do with depending on MODE. If we are already in STOR mode, then
; we simply store the LSB of the WORD at address in ST, then increment ST.
; If we are in XAM mode (which includes the address entered prior to the ':' in
; the command line) then WORD argument is copied to XAM and ST addresses, and we
; fall into the NXTPRT loop. If we're already in BLOCK XAM mode, then we take the
; WORD argument as the end of the block, and fall in the NXTPRT loop.
;
; U is pointer to line buffer and work variables
; X is work pointer
; W is the WORD parsed from input line (A2 in new monitor)
; B is the index into the line buffer
; A is work register
; MON_TEMP is copy of line buffer index upon entry, but after this is
;          complete, it is the flow-control byte for XAM/BLOCK XAM output

MON_NOTHEX:
    CMPB     <dTEMP                             ; Check if W empty (no hex digits parsed).
    BEQ      MON_XERR                           ;  yes, bad input so return via ERROR
    CLR      <dTEMP                             ; clear the 'flow control' byte
    TST      <dMODE                             ; Test MODE byte.
    BPL      MON_NOTSTOR                        ; B7=1 for STOR, 0 for XAM and BLOCK XAM
; STOR mode
    LDX      <dST                               ; use X to hold 'store index'
    STF      ,X+                                ; store LSB of WORD at 'store index'
    STX      <dST                               ; save the incremented 'store index'
    BRA      MON_NEXT_ITEM                      ; Get next command item.
MON_NOTSTOR:
    BNE      MON_XAMNEXT                        ; mode = $00 for XAM, $56 for BLOCK XAM.
; non BLOCK XAM
    STW      <dST                               ; copy word parsed into 'store index'
    STW      <dXAM                              ; copy word parsed into 'XAM index'
    CLRA                                        ; set Z=1 to cause address display to occur
; fall into NXTPRNT loop...
MON_NXTPRNT:
    BNE      MON_PRDATA                         ; Z=0 means skip displaying address
    LDA      <dTEMP                             ; check flow control byte
    BEQ      MON_NXT1                           ;  if zero, skip waiting for character
    JSR      GETCHT                             ; yes, flow control in effect, wait for character
    CMPA     #CTL_X                             ; did we get a ^X?
    BEQ      MON_XRET                           ;  yes, exit and get new input line
    CMPA     #SPACE                             ; did we get a SPACE
    BEQ      MON_NXT1                           ;  yes, set flow control to $20
    CLRA                                        ; any other character, clear flow control
MON_NXT1:
    STA      <dTEMP                             ; update flow control byte
    JSR      GETCH1                             ; attempt to read a character (A=0 if none)
    CMPA     #SPACE                             ; is it a SPACE?
    BEQ      MON_NXT2                           ;   yes, set flow control to $20
    CMPA     #CTL_X                             ; is it a ^X?
    BEQ      MON_XRET                           ;  yes, exit and get new input line
    LDA      <dTEMP                             ; flow unaffected by other characters
MON_NXT2:
    STA      <dTEMP                             ; update flow control byte
MON_NXT3:
    JSR      PUT_CR                              ; CR for a new line
    LDA      <dXAM                              ; 'XAM index' high-order byte.
    JSR      PUT_BYTE
    LDA      <dXAM+1                            ; Low-order 'Examine index' byte.
    JSR      PUT_BYTE
    LDA      #':'                               ; ":".
    JSR      PRINT_CHAR                              ; Output it.
MON_PRDATA:
    JSR      PUT_SPACE                           ; output a space
    LDA      [MON_XAM,U]                        ; Get data byte at 'examine index'.
    JSR      PUT_BYTE                            ; display it
MON_XAMNEXT:
    LDX      <dXAM                              ; use X to hold XAM index
    CMPR     W,X                                ; compare XAM index to parsed address WORD
    LBEQ     MON_NEXT_ITEM                      ;  same, done examining memory
    LEAX     1,X                                ; increment XAM index
    STX      <dXAM                              ;  and save it
    LDA      <(dXAM+1)                          ; Check low-order 'examine index' byte
    ANDA     #$07                               ; set Z when 'examine index' MOD 8 = 0
    BRA      MON_NXTPRNT                        ; always taken
MON_XERR:
    LDA      #'?'                               ; parse ERROR
    JMP      PRINT_CHAR                              ; output a ? and return

;;======================================================================
;; S-RECORD AND INTEL HEX CONSOLE DOWNLOAD FUNCTION
;;======================================================================

;;
;; DL_START - try to download a HEX file (either S9 or IHEX) from console
;; inputs: none
;; return: V=0 : successful load (A=0)
;;         V=1 : error during load (A=$FF)
;;
DL_START:
        BSR      DL_REC                            ; DOWNLOAD RECORD (A=00 ready for more)
        BNE      DLO2                              ;  if Z=0 then stop reading records
        JSR      PUT_CONST                         ; OUTPUT ONE DOT PER RECORD
        FCC      '.'
        BRA      DL_START                          ; CONTINUE
DLO2    BPL      DLO3                              ;  if N=0, no error occurred (A=01 means EOF)
        JSR      PUT_MSG
        FCN      "ERR"
        ORCC     #FlagOverflow                     ; set V (error)         
        RTS
DLO3    JSR      PUT_MSG
        FCN      "OK"
        RTS
; Download a record in either MOTOROLA or INTEL hex format
DL_REC  JSR      GETCH                             ; Get a character
        CMPA     #CTL_X                            ; Check for ^X (CANCEL)
        BEQ      DL_ERR                            ; yes, abort with error
        CMPA     #':'                              ; Start of INTEL record?
        LBEQ     DL_INT                            ; Yes, download INTEL
        CMPA     #'S'                              ; Start of MOTOROLA record?
        BNE      DL_REC                            ; No, keep looking
; Download a record in MOTOROLA hex format
DL_MOT  JSR      GETCH                              ; get record type
        CMPA     #'0'                              ; S0 header record?
        BEQ      DL_REC                            ;    skip it
        CMPA     #'5'                              ; S5 count record?
        BEQ      DL_REC                            ;    skip it
        CMPA     #'9'                              ; S9 end of file?
        BEQ      DL_MOT9                           ;    end of file
        CMPA     #'1'                              ; should be a data record (S1) then!
        BNE      DL_ERR                            ;  none of these = load error
        JSR      GETBYTE                           ; get length
        BVS      DL_ERR                            ; report error
        TFR      A,E                               ; start checksum in E
        SUBA     #3                                ; adjust length (omit address and checksum)
        TFR      A,F                               ; set length in F
; Get address         
        JSR      GETBYTE                           ; get first byte of address
        BVS      DL_ERR                            ; report error
        TFR      A,B                               ; save for later
        ADDR     A,E                               ; include in checksum
        JSR      GETBYTE                           ; get next byte of address
        BVS      DL_ERR                            ; report error
        EXG      A,B                               ; swap address halves (endian stuff)
        TFR      D,X                               ; set pointer
        ADDR     B,E                               ; include in checksum
; Get data bytes         
        BSR      DL_BYTES
        BVS      DL_ERR
; get checksum byte
        JSR      GETBYTE                           
        BVS      DL_ERR                            ; report error
        ADDR     A,E                               ; add to computed checksum
        INCE                                       ; test for success
        BEQ      DL_RTS                            ; download ok

; Error occurred on loading
DL_ERR  LDA      #$FF                              ; A=$FF if an error occurred (N is set, Z is clear)
        RTS

; properly handle S9 end record (just eat it)
DL_MOT9 JSR      GETBYTE                           ; get length byte
        BVS      DL_ERR                            ; report error
        TFR      A,F                               ; save length
DL_MOT10:
        JSR      GETBYTE                           ; get next byte (ignore it)
        DECF                                       ; reduce length
        BNE      DL_MOT10                          ; get all the bytes
; fall into DLEOF...

; Record download successful, EOF marker encountered
DL_EOF  LDA      #$01                              ; A=$01 if EOF is reached (N and Z both clear)
        RTS

; Record download successful, expecting another record
DL_RTS  CLRA                                       ; A=$00 if another record is needed (Z set, N clear)
        RTS

; Download F number of bytes from console, storing in memory at X, and 
; maintaining running checksum in E. Exit with V=1 on error.
DL_BYTES:
        TSTF                                       ; examine # of bytes to get
        BEQ      DLBX                             ;   zero, nothing to do!
        JSR      GETBYTE                           ; get data byte
        BVS      DLBX                             ; exit with V=1 on error
        STA      ,X+                               ; Write to memory
        ADDR     A,E                               ; include in checksum
        DECF                                       ; reduce length
        BNE      DL_BYTES                          ; Do them all
DLBX    RTS

; Download record in INTEL format
DL_INT  JSR      GETBYTE                           ; get count
        BVS      DL_ERR                            ; report error
        TFR      A,E                               ; start checksum in E
        TFR      A,F                               ; set length in F
; Get address
        JSR      GETBYTE                           ; get first byte of address
        BVS      DL_ERR                            ; report error
        TFR      A,B                               ; Save for later
        ADDR     A,E                               ; include in checksum
        JSR      GETBYTE                           ; get next byte of address
        BVS      DL_ERR                            ; report error
        EXG      A,B                               ; Swap
        TFR      D,X                               ; Set pointer
        ADDR     B,E                               ; include in checksum
; Get record type
        INCF                                       ; temporarily increment length (EOF 0->1)
        JSR      GETBYTE                           ; get type value
        BVS      DL_ERR                            ; report error
        CMPA     #1                                ; EOF record?
        BEQ      DL_MOT10                          ;   yes, eat 1 byte and return with EOF status
        ADDR     A,E                               ; include type in checksum
        DECF                                       ; back to correct length 
; Get data bytes
        BSR      DL_BYTES                          ; get F# of data bytes (return with zero length)
        BVS      DL_ERR                            ; report error
; Get checksum
        JSR      GETBYTE                           ; Read checksum byte
        BVS      DL_ERR                            ; Report error
        ADDR     A,E                               ; add to computed checksum
        BEQ      DL_RTS                            ; Report success
        BRA      DL_ERR                            ; Report failure

ERROR_VECTOR:
    RTI
NMI_VECTOR:
    RTI
SWI_VECTOR:
    RTI
IRQ_VECTOR:
    RTI
FIRQ_VECTOR:
    RTI
SWI2_VECTOR:
    RTI
SWI3_VECTOR:
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
HEX_DOWNLOAD_MSG:
    FCB    CR,LF
    FCN    "Hex Download "

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

; ANDCC with IntsEnable to enable IRQ + FIRQ
; ORCC with IntsDisable to disable IRQ + FIRQ

IntsEnable		EQU		$FF-(FlagFIRQ+FlagIRQ)
IntsDisable		EQU		(FlagFIRQ+FlagIRQ)		

AciaData	    EQU		RegAciaData+ACIA_BASE	; Acia Rx/Tx Register
AciaStat	    EQU		RegAciaStat+ACIA_BASE	; Acia status register
AciaCmd		    EQU		RegAciaCmd+ACIA_BASE	; Acia command register
AciaCtrl	    EQU		RegAciaCtrl+ACIA_BASE	; Acia control register