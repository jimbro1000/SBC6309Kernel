; 6309 ROM Monitor
; Features: Intel HEX loader, memory inspect/modify, fill, execute
;
;***************************************************************
;* Memory model
;* $0000 - $7FFF = default ram page
;* $8000 - $9FFF = rom page 1 8K
;* $A000 - $BFFF = rom page 2 8K
;* $C000 - $DFFF = reserved 4K
;* $E000 - $EFFF = video 4K
;* $F000 - $FDFF = monitor (3.5K)
;* $FE00 - $FFEF = IO
;* $FFF0 - $FFFF = CPU vectors
;***************************************************************

; Memory Map Definitions
ZERO_PAGE       EQU     $0000   ; system variables
ROM_BASE        EQU     $F000   ; rom base address
ACIA_BASE       EQU     $FE00   ; base address for ACIA
SYS_STACK       EQU     $7FFF   ; initial stack pointer
USR_STACK       EQU     $6FFF   ; initial user stack pointer

; ACIA Register Definitions
ACIA_CTRL       EQU     ACIA_BASE       ; Control/Status register
ACIA_DATA       EQU     ACIA_BASE+1     ; Data register

; ACIA Status bits
RDRF            EQU     $01     ; Receive Data Register Full
TDRE            EQU     $02     ; Transmit Data Register Empty

; Monitor workspace (Zero Page RAM)
HEXBUF          EQU     $0080   ; Buffer for hex input line (80 bytes)
HEXLEN          EQU     $00C0   ; Byte count from hex record
HEXADDR         EQU     $00C1   ; Load address (2 bytes)
HEXTYPE         EQU     $00C3   ; Record type
HEXCKSUM        EQU     $00C4   ; Running checksum
TMPBYTE         EQU     $00C5   ; Temporary storage

; ROM Monitor starts at $F000
                ORG     ROM_BASE

;==============================================================================
; COLD START - Initialize and display banner
;==============================================================================
COLDSTART:
                LDS     #SYS_STACK      ; Initialize system stack
                
                ; Initialize ACIA (8N1, /64, no interrupts)
                LDA     #$03            ; Master reset
                STA     ACIA_CTRL
                LDA     #$11            ; 8N1, /64, RTS low
                STA     ACIA_CTRL
                
                ; Display banner
                LDX     #BANNER
                JSR     PRINT_STR
                
                ; Fall through to command loop

;==============================================================================
; COMMAND LOOP - Main monitor loop
;==============================================================================
CMDLOOP:
                LDX     #PROMPT
                JSR     PRINT_STR
                
                JSR     GETCHR          ; Get command character
                JSR     PUTCHR          ; Echo it
                JSR     CRLF
                
                ; Convert to uppercase
                CMPA    #'a'
                BLT     CMD_CHECK
                CMPA    #'z'
                BGT     CMD_CHECK
                SUBA    #$20            ; Convert to uppercase
                
CMD_CHECK:
                CMPA    #'L'            ; Load Intel HEX
                LBEQ     CMD_LOAD
                CMPA    #'D'            ; Dump memory
                LBEQ     CMD_DUMP
                CMPA    #'M'            ; Modify memory
                LBEQ     CMD_MODIFY
                CMPA    #'F'            ; Fill memory
                LBEQ     CMD_FILL
                CMPA    #'G'            ; Go (execute)
                LBEQ     CMD_GO
                CMPA    #'H'            ; Help
                LBEQ     CMD_HELP
                CMPA    #'?'
                LBEQ     CMD_HELP
                
                LDX     #MSG_UNKNOWN
                JSR     PRINT_STR
                BRA     CMDLOOP

;==============================================================================
; HELP COMMAND - Display available commands
;==============================================================================
CMD_HELP:
                LDX     #HELP_TEXT
                JSR     PRINT_STR
                BRA     CMDLOOP

HELP_TEXT:
                FCC     "Commands:"
                FCB     13,10
                FCC     "L - Load Intel HEX file"
                FCB     13,10
                FCC     "D - Dump memory (D AAAA LLLL)"
                FCB     13,10
                FCC     "M - Modify memory (M AAAA)"
                FCB     13,10
                FCC     "F - Fill memory (F AAAA LLLL DD)"
                FCB     13,10
                FCC     "G - Go/Execute (G AAAA)"
                FCB     13,10
                FCC     "H - This help"
                FCB     13,10,0

;==============================================================================
; LOAD INTEL HEX COMMAND
;==============================================================================
CMD_LOAD:
                LDX     #MSG_LOAD
                JSR     PRINT_STR
                
LOAD_LOOP:
                ; Wait for ':' to start record
WAIT_COLON:
                JSR     GETCHR
                CMPA    #':'
                BNE     WAIT_COLON
                
                ; Read byte count
                JSR     GET_HEX_BYTE
                BCS     LOAD_ERROR
                STA     HEXLEN
                STA     HEXCKSUM        ; Start checksum
                
                ; Read address (high byte)
                JSR     GET_HEX_BYTE
                BCS     LOAD_ERROR
                STA     HEXADDR
                ADDA    HEXCKSUM
                STA     HEXCKSUM
                
                ; Read address (low byte)
                JSR     GET_HEX_BYTE
                BCS     LOAD_ERROR
                STA     HEXADDR+1
                ADDA    HEXCKSUM
                STA     HEXCKSUM
                
                ; Read record type
                JSR     GET_HEX_BYTE
                BCS     LOAD_ERROR
                STA     HEXTYPE
                ADDA    HEXCKSUM
                STA     HEXCKSUM
                
                ; Check record type
                LDA     HEXTYPE
                CMPA    #$01            ; End of file record?
                BEQ     LOAD_DONE
                CMPA    #$00            ; Data record?
                BNE     LOAD_NEXT       ; Ignore other types
                
                ; Load data bytes
                LDX     HEXADDR
                LDB     HEXLEN
                BEQ     LOAD_CKSUM      ; No data bytes
                
LOAD_DATA:
                JSR     GET_HEX_BYTE
                BCS     LOAD_ERROR
                STA     ,X+             ; Store to memory
                ADDA    HEXCKSUM
                STA     HEXCKSUM
                DECB
                BNE     LOAD_DATA
                
LOAD_CKSUM:
                ; Read and verify checksum
                JSR     GET_HEX_BYTE
                BCS     LOAD_ERROR
                ADDA    HEXCKSUM
                BNE     LOAD_CKERR
                
                LDA     #'.'            ; Progress indicator
                JSR     PUTCHR
                
LOAD_NEXT:
                BRA     LOAD_LOOP
                
LOAD_DONE:
                ; Verify final checksum
                JSR     GET_HEX_BYTE
                ADDA    HEXCKSUM
                BNE     LOAD_CKERR
                
                LDX     #MSG_LOADED
                JSR     PRINT_STR
                JMP     CMDLOOP
                
LOAD_CKERR:
                LDX     #MSG_CKERR
                JSR     PRINT_STR
                JMP     CMDLOOP
                
LOAD_ERROR:
                LDX     #MSG_HEXERR
                JSR     PRINT_STR
                JMP     CMDLOOP

;==============================================================================
; DUMP MEMORY COMMAND - D AAAA LLLL
;==============================================================================
CMD_DUMP:
                JSR     GET_ADDRESS     ; Get start address in X
                BCS     DUMP_ERR
                TFR     X,Y             ; Save start in Y
                
                JSR     SKIP_SPACES
                JSR     GET_HEX_WORD    ; Get length in X
                BCS     DUMP_ERR
                
                TFR     X,D             ; Length in D
                BEQ     DUMP_ERR
                
                ; Dump loop
DUMP_LOOP:
                TFR     Y,X             ; Current address
                JSR     PRINT_ADDR      ; Print address
                LDA     #':'
                JSR     PUTCHR
                JSR     SPACE
                
                ; Print 16 bytes in hex
                LDB     #16
DUMP_HEX:
                LDA     ,Y+             ; Get byte
                JSR     PRINT_BYTE
                JSR     SPACE
                DECD                    ; Decrement length
                BEQ     DUMP_ASCII      ; Done if length = 0
                DECB
                BNE     DUMP_HEX
                
                ; Print ASCII representation
DUMP_ASCII:
                PSHS    D               ; Save remaining length
                LDA     #' '
                JSR     PUTCHR
                JSR     PUTCHR
                
                TFR     Y,X
                LEAX    -16,X           ; Back to start of line
                LDB     #16
DUMP_ASC2:
                LDA     ,X+
                CMPA    #$20
                BLT     DUMP_DOT
                CMPA    #$7E
                BGT     DUMP_DOT
                JSR     PUTCHR
                BRA     DUMP_ASCNXT
DUMP_DOT:
                LDA     #'.'
                JSR     PUTCHR
DUMP_ASCNXT:
                DECB
                BNE     DUMP_ASC2
                
                JSR     CRLF
                PULS    D               ; Restore length
                BNE     DUMP_LOOP
                
                JMP     CMDLOOP
                
DUMP_ERR:
                LDX     #MSG_SYNTAX
                JSR     PRINT_STR
                JMP     CMDLOOP

;==============================================================================
; MODIFY MEMORY COMMAND - M AAAA
;==============================================================================
CMD_MODIFY:
                JSR     GET_ADDRESS     ; Get address in X
                BCS     MOD_ERR
                
MOD_LOOP:
                JSR     PRINT_ADDR      ; Show address
                LDA     #':'
                JSR     PUTCHR
                JSR     SPACE
                
                LDA     ,X              ; Show current value
                JSR     PRINT_BYTE
                JSR     SPACE
                
                ; Get new value or command
                JSR     GETCHR
                JSR     PUTCHR
                
                CMPA    #13             ; CR = quit
                BEQ     MOD_DONE
                CMPA    #'.'            ; Period = quit
                BEQ     MOD_DONE
                CMPA    #'-'            ; Minus = previous
                BEQ     MOD_PREV
                CMPA    #' '            ; Space = next (no change)
                BEQ     MOD_NEXT
                CMPA    #'='            ; Equals = next (no change)
                BEQ     MOD_NEXT
                
                ; Must be hex digit - get byte value
                PSHS    X
                JSR     UNGETC          ; Put char back
                JSR     GET_HEX_BYTE
                PULS    X
                BCS     MOD_ERR
                
                STA     ,X              ; Store new value
                
MOD_NEXT:
                JSR     CRLF
                LEAX    1,X
                BRA     MOD_LOOP
                
MOD_PREV:
                JSR     CRLF
                LEAX    -1,X
                BRA     MOD_LOOP
                
MOD_DONE:
                JSR     CRLF
                JMP     CMDLOOP
                
MOD_ERR:
                LDX     #MSG_SYNTAX
                JSR     PRINT_STR
                JMP     CMDLOOP

;==============================================================================
; FILL MEMORY COMMAND - F AAAA LLLL DD
;==============================================================================
CMD_FILL:
                JSR     GET_ADDRESS     ; Get start address in X
                BCS     FILL_ERR
                TFR     X,Y             ; Save in Y
                
                JSR     SKIP_SPACES
                JSR     GET_HEX_WORD    ; Get length in X
                BCS     FILL_ERR
                TFR     X,D             ; Length in D
                BEQ     FILL_ERR
                
                JSR     SKIP_SPACES
                JSR     GET_HEX_BYTE    ; Get fill byte
                BCS     FILL_ERR
                
                ; Fill loop
                TFR     Y,X             ; Start address
FILL_LOOP:
                STA     ,X+
                DECD
                BNE     FILL_LOOP
                
                LDX     #MSG_FILLED
                JSR     PRINT_STR
                JMP     CMDLOOP
                
FILL_ERR:
                LDX     #MSG_SYNTAX
                JSR     PRINT_STR
                JMP     CMDLOOP

;==============================================================================
; GO COMMAND - G AAAA
;==============================================================================
CMD_GO:
                JSR     GET_ADDRESS     ; Get address in X
                BCS     GO_ERR
                
                ; Set up user stack and jump to address
                LDU     #USR_STACK      ; Initialize user stack
                JMP     ,X
                
GO_ERR:
                LDX     #MSG_SYNTAX
                JSR     PRINT_STR
                JMP     CMDLOOP

;==============================================================================
; UTILITY ROUTINES
;==============================================================================

; Get address from input (4 hex digits) - Result in X, Carry set on error
GET_ADDRESS:
                JSR     SKIP_SPACES
                JSR     GET_HEX_WORD
                RTS

; Get 16-bit hex word - Result in X, Carry set on error
GET_HEX_WORD:
                JSR     GET_HEX_BYTE
                BCS     GHW_ERR
                TFR     A,B             ; High byte in B
                JSR     GET_HEX_BYTE
                BCS     GHW_ERR
                EXG     A,B             ; Swap to get correct order
                TFR     D,X
                ANDCC   #$FE            ; Clear carry
                RTS
GHW_ERR:
                ORCC    #$01            ; Set carry
                RTS

; Get 8-bit hex byte - Result in A, Carry set on error
GET_HEX_BYTE:
                JSR     GET_HEX_DIGIT
                BCS     GHB_ERR
                LSLA
                LSLA
                LSLA
                LSLA
                TFR     A,B
                JSR     GET_HEX_DIGIT
                BCS     GHB_ERR
                PSHS    B
                ADDA    ,S+
                ANDCC   #$FE            ; Clear carry
                RTS
GHB_ERR:
                ORCC    #$01            ; Set carry
                RTS

; Get hex digit - Result in A (0-15), Carry set on error
GET_HEX_DIGIT:
                JSR     GETCHR
                CMPA    #'0'
                BLT     GHD_ERR
                CMPA    #'9'
                BLE     GHD_NUM
                CMPA    #'A'
                BLT     GHD_ERR
                CMPA    #'F'
                BLE     GHD_ALPHA
                CMPA    #'a'
                BLT     GHD_ERR
                CMPA    #'f'
                BGT     GHD_ERR
                SUBA    #'a'-10
                ANDCC   #$FE            ; Clear carry
                RTS
GHD_ALPHA:
                SUBA    #'A'-10
                ANDCC   #$FE
                RTS
GHD_NUM:
                SUBA    #'0'
                ANDCC   #$FE
                RTS
GHD_ERR:
                ORCC    #$01            ; Set carry
                RTS

; Skip whitespace characters
SKIP_SPACES:
SS_LOOP:
                JSR     GETCHR
                CMPA    #' '
                BEQ     SS_LOOP
                CMPA    #9              ; Tab
                BEQ     SS_LOOP
                ; Put non-space back
                
; Unget character (put A back in input buffer)
UNGETC:
                ; Simple implementation - just decrement would work with buffering
                RTS

; Print 16-bit address in X as 4 hex digits
PRINT_ADDR:
                TFR     X,D
                TFR     A,B
                TFR     B,A
                JSR     PRINT_BYTE
                TFR     D,X
                TFR     X,D
                ; Fall through to PRINT_BYTE

; Print byte in A as 2 hex digits
PRINT_BYTE:
                PSHS    A
                LSRA
                LSRA
                LSRA
                LSRA
                JSR     PRINT_DIGIT
                PULS    A
                ANDA    #$0F
                ; Fall through to PRINT_DIGIT

; Print hex digit in A (0-F)
PRINT_DIGIT:
                CMPA    #10
                BLT     PD_NUM
                ADDA    #'A'-10
                BRA     PUTCHR
PD_NUM:
                ADDA    #'0'
                BRA     PUTCHR

; Print string pointed to by X (null-terminated)
PRINT_STR:
                LDA     ,X+
                BEQ     PS_DONE
                JSR     PUTCHR
                BRA     PRINT_STR
PS_DONE:
                RTS

; Print CR/LF
CRLF:
                LDA     #13
                JSR     PUTCHR
                LDA     #10
                JSR     PUTCHR
                RTS

; Print space
SPACE:
                LDA     #' '
                ; Fall through to PUTCHR

; Output character in A to ACIA
PUTCHR:
                PSHS    A
PC_WAIT:
                LDA     ACIA_CTRL
                ANDA    #TDRE
                BEQ     PC_WAIT
                PULS    A
                STA     ACIA_DATA
                RTS

; Get character from ACIA into A
GETCHR:
                LDA     ACIA_CTRL
                ANDA    #RDRF
                BEQ     GETCHR
                LDA     ACIA_DATA
                RTS

;==============================================================================
; MESSAGES
;==============================================================================
BANNER:
                FCB     13,10
                FCC     "6309 ROM Monitor v1.0"
                FCB     13,10
                FCC     "Type H for help"
                FCB     13,10,0

PROMPT:
                FCC     "> "
                FCB     0

MSG_UNKNOWN:
                FCC     "Unknown command. Type H for help."
                FCB     13,10,0

MSG_LOAD:
                FCC     "Send Intel HEX file now..."
                FCB     13,10,0

MSG_LOADED:
                FCC     " OK"
                FCB     13,10,0

MSG_HEXERR:
                FCC     " HEX format error"
                FCB     13,10,0

MSG_CKERR:
                FCC     " Checksum error"
                FCB     13,10,0

MSG_SYNTAX:
                FCC     "Syntax error"
                FCB     13,10,0

MSG_FILLED:
                FCC     "Memory filled"
                FCB     13,10,0

;==============================================================================
; CPU VECTORS (at $FFF0-$FFFF)
;==============================================================================
                ORG     $FFF0
VEC_RSVD0       FDB     COLDSTART       ; Reserved
VEC_SWI3        FDB     COLDSTART       ; SWI3
VEC_SWI2        FDB     COLDSTART       ; SWI2
VEC_FIRQ        FDB     COLDSTART       ; FIRQ
VEC_IRQ         FDB     COLDSTART       ; IRQ
VEC_SWI         FDB     COLDSTART       ; SWI
VEC_NMI         FDB     COLDSTART       ; NMI
VEC_RESET       FDB     COLDSTART       ; Reset vector

                END
