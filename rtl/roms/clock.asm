;This is 6502 assembler code for a ProDOS compatible
;Apple II bootable serial drive.
;


;Calculate I/O addresses for this slot
sdrive_7 =     $70

;Hardware addresses
UART =        $C0F0     ; Slot 5 UART base address
;#define SCREEN      $0400

ROM_WP = $C060
OPT_ROM= $C006
INT_ROM = $C007

INTC3ROM= $C00A
SLOT3ROM= $C00B

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



; Slot 5 RAM locations
; We can use these if we want to
sram0_5 =   $47D                   ; scratch
sram1_5 =   $4FD
sram2_5 =   $57D
sram3_5  =  $5FD
sram4_5   =  $67D
sram5_5     = $6FD
sram6_5   =   $77D
sram7_5 =     $7FD

; Slot 7 RAM locations
sram0_7 =   $47F
CHECKSUM=   $47F	; Storage for calculating checksums
sram1_7 =   $4FF
BLOCK_HI=   $4FF	; Storage for the calculated high block address
sram2_7 =   $57F
sram3_7 =   $5FF
sram4_7 =   $67F
sram5_7 =   $6FF
sram6_7 =   $77F
sram7_7 =     $7FF

;ProDOS defines
command    =$42       ;ProDOS command
unit       =$43       ;7=drive 6-4=slot 3-0=not used
buflo      =$44       ;low address of buffer
bufhi      =$45       ;hi address of buffer
blklo      =$46       ;low block
blkhi      =$47       ;hi block
ioerr      =$27       ;I/O error code
nodev      =$28       ;no device connected
wperr      =$2B       ;write protect error
monitor   = $FF69

        *=        $C400
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
        jsr                     MYLABEL
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

MYLABEL
        rts
