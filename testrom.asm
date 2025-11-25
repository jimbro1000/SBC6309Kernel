    include "config.inc"
    include "cpu.inc"
    include "acia.inc"
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
    JSR     CHECK_SERIAL_IN ; check for serial input
    BEQ     NO_SERIAL_IN    ; if no data, skip
    JSR     DO_SERIAL_IN    ; get serial data
    JSR     PUSH_KEYBOARD_BUFFER ; push character into keyboard buffer
NO_SERIAL_IN:
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
    LDA     AciaData		            ; get the received data	
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
    FCB     AciaCBrd300	    ; 300
    FCB     AciaCBrd600	    ; 600
    FCB     AciaCBrd1200	; 1200
    FCB     AciaCBrd2400	; 2400
    FCB     AciaCBrd4800	; 4800
    FCB     AciaCBrd9600	; 9600
    FCB     AciaCBrd19200	; 19200

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
    CMPA    #KEY_ROLLOVER            ; compare to start of buffer
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
    JSR     IS_KBD_BUFFER_FULL
    LDX     KEY_BUFF_HEAD               ; get head of buffer
    BEQ     PUSH_KBD_BUFF_END           ; if not full, proceed
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

MONITOR:
    RTS
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

IntsEnable		EQU		~(FlagFIRQ+FlagIRQ)
IntsDisable		EQU		(FlagFIRQ+FlagIRQ)		

AciaData	    EQU		RegAciaData+ACIA_BASE	; Acia Rx/Tx Register
AciaStat	    EQU		RegAciaStat+ACIA_BASE	; Acia status register
AciaCmd		    EQU		RegAciaCmd+ACIA_BASE	; Acia command register
AciaCtrl	    EQU		RegAciaCtrl+ACIA_BASE	; Acia control register
