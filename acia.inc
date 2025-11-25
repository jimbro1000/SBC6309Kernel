; constants for the ACIA status register

AciaSParityErr	EQU		$01		; parity error
AciaSFrameErr	EQU		$02		; framing error
AciaSOverrun	EQU		$04		; data overrun
AciaSRxFull	EQU		$08		; receiver register full
AciaSTxEmpty	EQU		$10		; transmit register empty
AciaSDCD	EQU		$20		; data carrier detect =0detect, 1=not detect
AciaSDSR	EQU		$40		; data set ready 0=ready, 1=not ready
AciaSIRQ	EQU		$80		; interrupt, 0=no int, 1=int

; constants for ACIA command register
AciaPMCMask	EQU		$C0		; mask for PMC bits
AciaTICMask	EQU		$0C		; transmitter interrupt control mask

AciaPMCPOdd	EQU		$00		; odd parity tx/rx
AciaPMCPEven	EQU		$40		; even parity tx/rx
AciaPMCPMark	EQU		$80		; mark parity tx, rx parity disabled
AciaPMCPSpace	EQU		$C0		; space parity tx, rx parity disabled
AciaPME		EQU		$20		; parity mode enable = 1, disable = 0
AciaREM		EQU		$10		; receiver echo mode, 0=no echo, 1=echo
AcidTICRHDis	EQU		$00		; RTS high, interrupt disabled
AcidTICRLEna	EQU		$04		; RTS low, interrupt enabled
AcidTICRLDis	EQU		$08		; RTS low, interrupt disabled
AcidTICRLBrk	EQU		$0C		; RTS low, interrupt disabled, break on txd
AciaIRD		EQU		$02		; receiver interrupt disable, 0=int enabled, 1=int disabled
AciaDTR		EQU		$01		; data terminal ready 0=DTR high, 1=DTR low

; constants for the ACIA control register 
; bits 0..3 specify the baud rate

AciaBrdMask	EQU		$0F		; baud rate mask
AciaCBrdExt	EQU		$00		; 1/16th external clock
AciaCBrd50	EQU		$01		; 50 baud
AciaCBrd75	EQU		$02		; 75 baud
AciaCBrd110	EQU		$03		; 110 baud
AciaCBrd135	EQU		$04		; 135 baud
AciaCBrd150	EQU		$05		; 150 baud
AciaCBrd300	EQU		$06		; 300 baud
AciaCBrd600	EQU		$07		; 600 baud
AciaCBrd1200	EQU		$08		; 1200 baud
AciaCBrd1800	EQU		$09		; 1800 baud
AciaCBrd2400	EQU		$0A		; 2400 baud
AciaCBrd3600	EQU		$0B		; 3600 baud
AciaCBrd4800	EQU		$0C		; 4800 baud
AciaCBrd7200	EQU		$0D		; 7200 baud
AciaCBrd9600	EQU		$0E		; 9600 baud
AciaCBrd19200	EQU		$0E		; 19200 baud

AciaCRxClk	EQU		$10		; receiver clock source, 0= external, 1=baud rate
AciaWrdMask	EQU		$60		; word length bits mask
AciaCWrd8	EQU		$00		; 8 bit word
AciaCWrd7	EQU		$20		; 7 bit word
AciaCWrd6	EQU		$40		; 6 bit word
AciaCWrd5	EQU		$60		; 5 bit word3
AciaCSBN	EQU		$80		; stop bit number, 0=1 bit, 1=2 bits

TextSerBaudRate	EQU	AciaCtrl	; Serial baud rate

RegAciaData	    EQU		$04		; Acia Rx/Tx Register
RegAciaStat	    EQU		$05		; Acia status register
RegAciaCmd	    EQU		$06		; Acia command register
RegAciaCtrl	    EQU		$07		; Acia control register
