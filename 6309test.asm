TEST_6309:
    PSHS    B
    FDB     $1043
    CMPB    1,S
    BNE     IS_6309
    LDA     #0
    PULS    B,PC
IS_6309:
    LDA     #255
    PULS    B,PC