; *********************** kernel
CR      EQU     $0D                             ; carriage return
LF      EQU     $0A                             ; line feed
SPACE   EQU     $20
; *********************** monitor
DOT     EQU     $6E                             ; period
HI_COL  EQU     $7A                             ; colon
HI_X    EQU     $58                             ; X

CTL_C   EQU     'C'-$40                         ; control-C
CTL_S   EQU     'S'-$40                         ; control-S
CTL_H   EQU     'H'-$40                         ; control-H
CTL_X   EQU     'X'-$40                         ; control-X
DEL     EQU     127                             ; "Delete"
ESC     EQU     '['-$40                         ; ESCape

MON_OFFSET  EQU     MON_RAM % 256
MON_INLEN   EQU     120                         ; line input buffer length
MON_XAM     EQU     MON_INLEN
