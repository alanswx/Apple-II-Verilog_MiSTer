;This is 6502 assembler code for a ProDOS compatible
;Clock Card
;

ZERO =        $00

; Slot 4 IO locations
YEAR_TENS =     $C082
YEAR_ONES =     $C083
MONTH_TENS =    $C084
MONTH_ONES =    $C085
DAY_WEEK=       $C086
DAY_TENS=       $C087
DAY_ONES=       $C088
HOUR_TENS  =    $C089
HOUR_ONES  =    $C08A
MIN_TENS   =    $C08B
MIN_ONES   =    $C08C
SEC_TENS   =    $C08D
SEC_ONES   =    $C08E


; Entry for the clock card
        *=        $C400  ; do we want this? the card shouldn't be anchored to C400
        PHP
        SEI
        PLP
        BIT $FF58
        BVS DOS
READ_ENTRY_4
        CLC
        BCC READ_TIME
WRITE_ENTRY_4
        BNE LBL3
DOS
LBL3
        rts

READ_TIME
        pha

        ; find slot number
        php 
        sei
        ;jsr                     RTS_ONLY
        jsr                     $FF58
        tsx
        lda                     $0100,X
        and                     #$07
        asl
        asl
        asl
        asl
        tax                                                     ;X will be $0S for memory locations
        plp
        ; restore

        lda  #','+$80
        sta  $0202
        sta  $0205
        sta  $0208
        sta  $020B
        sta  $020E
        lda  MONTH_TENS,X
        ora  #$80
        sta  $0200
        lda  MONTH_ONES,X
        ora  #$80
        sta  $0201
        lda  #'0'+$80		; Day of week tens is always 0
        sta  $0203
        lda  DAY_WEEK,X
        ora  #$80
        sta  $0204
        lda  DAY_TENS,X
        ora  #$80
        sta  $0206
        lda  DAY_ONES,X
        ora  #$80
        sta  $0207
        lda  HOUR_TENS,X
        ora  #$80
        sta  $0209
        lda  HOUR_ONES,X
        ora  #$80
        sta  $020A
        lda  MIN_TENS,X
        ora  #$80
        sta  $020C
        lda  MIN_ONES,X
        ora  #$80
        sta  $020D
        lda  SEC_TENS,X
        ora  #$80
        sta  $020F
        lda  SEC_ONES,X
        ora  #$80
        sta  $020D
        lda  #$8D			; carrage return
        sta  $020E
        ldx  #$0E
        pla
        rts

RTS_ONLY
        rts
