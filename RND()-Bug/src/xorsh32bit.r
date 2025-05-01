
; ******** Source: xorsh32bit.asm
     1                          !to "xorsh32bit.o",cbm	
     2                          ;
     3                          ;  **** Func RND ****
     4                          
     5                          ; Main Floating point Accumulator
     6                          v2	 = $61	; FAC Mantissa
     7                          v2e		= v2
     8                          v2d		= v2+1
     9                          v2c		= v2+2
    10                          v2b		= v2+3
    11                          v2a		= v2+4
    12                          
    13                          ; Floating RND Function Seed
    14                          v1	= $8B	; rndseedvalue
    15                          v1e		= v1
    16                          v1d		= v1+1
    17                          v1c		= v1+2
    18                          v1b		= v1+3
    19                          v1a		= v1+4
    20                          
    21                          

; ******** Source: loader.asm
     1                          ;
     2                          ; *********** Loader
     3                          ;
     4                          ;       2013 11 10 johann e. klasek, johann at klasek at
     5                          ;
     6                          
     7                          ; --- Temporäre Variablen:
     8                          
     9                          ptr		= $22		; Zeropage, frei
    10                          ptr_l		= ptr
    11                          ptr_h		= ptr+1
    12                          
    13                          len		= $4f		; Zeropage, temp. frei
    14                          len_l		= len
    15                          len_h		= len+1
    16                          
    17                          dest		= $51		; Zeropage, temp. frei
    18                          dest_l		= dest
    19                          dest_h		= dest+1
    20                          
    21                          
    22                          ; --- Konstanten:
    23                          
    24                          basicrom	= $a000		; Startadresse
    25                          kernalrom	= $e000		; Startadresse
    26                          
    27                          ; --- Ein-/Ausgabe:
    28                          
    29                          prozport 	= $01		; Prozessorport
    30                          
    31                          memrom		= %00110111	; Basic+Kernal ROM
    32                          memram		= %00110101	; Basic+Kernal ROM
    33                          
    34                          
    35                          *= $0801
    36                          basic_start
    37                          ;       2013 sys2061
    38  0801 0b08dd079e         	!by <EOP,>EOP,<(2013),>(2013),$9E
    39  0806 32303631           	!tx "2061"
    40  080a 00                 	!by 0 			; End of Line
    41  080b 0000               EOP	!by 0, 0		; Basic-Programmende
    42                          
    43                          loader
    44                          !if loader != 2061 {
    45                          	!error "Loader-Adresse stimmt nicht mit SYS-Adresse überein!"
    46                          }
    47  080d a000               	ldy #0
    48  080f a937               	lda #memrom
    49  0811 8501               	sta prozport		; ROM einblenden
    50  0813 8422               	sty ptr_l
    51                          
    52                          	; Basic und Kernal ins RAM kopieren
    53                          
    54  0815 a9a0               	lda #>basicrom		; Basic ROM Start
    55  0817 207408             	jsr copyram
    56  081a a9e0               	lda #>kernalrom		; Kernal ROM Start
    57  081c 207408             	jsr copyram
    58                          
    59                          	; Patchliste abarbeiten (Basic und Kernal betreffend)
    60                          
    61  081f a200               	ldx #0
    62  0821 bd8508             nextp	lda patchlist,x
    63  0824 8522               	sta ptr
    64  0826 a8                        	tay
    65                          
    66  0827 bd8608             	lda patchlist+1,x
    67  082a 8523               	sta ptr_h
    68  082c d003               	bne patch
    69  082e 98                 	tya
    70  082f f034               	beq pend
    71                          
    72                          patch	
    73  0831 bd8808             	lda patchlist+3,x
    74  0834 8550               	sta len_h
    75  0836 bd8708             	lda patchlist+2,x
    76  0839 854f               	sta len_l
    77  083b f002               	beq nohighcorr		; dec 0/0 Korrektur
    78  083d e650               	inc len_h
    79                          nohighcorr
    80                          
    81  083f bd8908             	lda patchlist+4,x
    82  0842 8551               	sta dest_l
    83                          
    84  0844 bd8a08             	lda patchlist+5,x
    85  0847 8552               	sta dest_h
    86                          
    87  0849 a000               	ldy #0
    88  084b b122               ploop	lda (ptr),y		; Patch an richtige Adresse
    89  084d 9151               	sta (dest),y		; übertragen
    90  084f c8                 	iny
    91  0850 d004               	bne nohigh
    92  0852 e623               	inc ptr_h		; High Byte bei Überlauf
    93  0854 e652               	inc dest_h
    94                          nohigh
    95  0856 c64f               	dec len_l		; Länge herunter
    96  0858 d0f1               	bne ploop		; zählen nach
    97  085a c650               	dec len_h		; dec 0/0 Methode
    98  085c d0ed               	bne ploop
    99  085e 8a                 	txa			; Index auf nächsten Patch
   100  085f 18                 	clc			; positionieren ...
   101  0860 6906               	adc #6
   102  0862 aa                 	tax
   103  0863 d0bc               	bne nextp		; immer
   104                          
   105                          pend
   106  0865 a935               	lda #memram		; BASIC, KERNAL RAM aktivieren
   107  0867 8501               	sta prozport
   108                          
   109  0869 a204               	ldx #$04		; copy init rnd default seed
   110  086b bdbae3             -	lda $e3ba,x
   111  086e 958b               	sta $8B,x
   112  0870 ca                 	dex
   113  0871 10f8               	bpl -
   114  0873 60                 	rts
   115                          
   116                          
   117                          ; 8kByte Block an geleiche Stelle kopieren
   118                          
   119                          copyram
   120  0874 8523               	sta ptr_h		; Startadresse
   121  0876 a220               	ldx #$20		; Pages: 8K
   122  0878 b122               toram	lda (ptr),y		; ROM lesen
   123  087a 9122               	sta (ptr),y		; RAM schreiben
   124  087c c8                 	iny
   125  087d d0f9               	bne toram
   126  087f e623               	inc ptr_h		; nächste "Page"
   127  0881 ca                 	dex
   128  0882 d0f4               	bne toram
   129  0884 60                 	rts
   130                          

; ******** Source: xorsh32bit.asm
    22                          
    23                          
    24                          ;
    25                          ; Patch-Liste für "loader"
    26                          ;
    27                          
    28                          patchlist:
    29                          
    30  0885 9308400097e0       !wo part1_real,part1_real_end-part1_real,part1
    31  088b d3080500bae3       !wo part2_real,part2_real_end-part2_real,part2
    32  0891 0000               !wo 0  ; Endemarkierung
    33                          
    34                          
    35                          
    36                          ;====================
    37                          ; (1.) v1 ^= v1 << 13
    38                          ; (2.) v1 ^= v1 >> 17
    39                          ; (3.) v1 ^= v1 << 5
    40                          ;====================
    41                          
    42                          part1_real:
    43                          
    44                          !pseudopc $e097 {
    45                          part1: 
    46                          ; (1.): [v1 ^= v1 << 13]
    47  0893 a203               	ldx #$03	
    48  0895 b58c               -	lda v1d,x	; v2 = v1 << 8
    49  0897 9561               	sta v2e,x
    50  0899 ca                 	dex
    51  089a d0f9               	bne -
    52  089c 8665               	stx v2a
    53  089e 20bce0             	jsr lsh; v2 = v2 << 5; v1 ^= v2		; (14b)
    54                          ;-------------------------------------------------
    55                          ; (2.): v1 ^= v1 >> 17
    56  08a1 8662               	stx v2d
    57  08a3 8663               	stx v2c
    58  08a5 a58c               	lda v1d	
    59  08a7 4a                 	lsr 	; 0 >> 1	v2 = v1 >> (1 + 16) [part 1]
    60  08a8 8564               	sta v2b	; 0 >> 16
    61  08aa a58d               	lda v1c
    62  08ac 6a                 	ror		; c >> 1	v2 = v1 >> (1 + 16) [part 2]
    63  08ad 8565               	sta v2a	; c >> 16
    64  08af 20c9e0             	jsr dxo								; (17b)
    65                          ;-----------------------------------------------------
    66                          ; (3.): v1 ^= v2 << 5
    67                          ;	ldx #$04		; Daten bereits kopiert in dxo !
    68                          ;-	lda v1e,x ; v2 = v1
    69                          ;	sta v2e,x
    70                          ;	dex
    71                          ;	bne -
    72  08b2 20bce0             	jsr lsh								; (12b)
    73                          ;-----------------------------------------------
    74                          ; copy v1 to v2 - and - finish
    75  08b5 4ce3e0             	jmp $e0e3							; (6b)
    76                          ;-----------------------------------------------
    77  08b8 a205               lsh	ldx #$05
    78  08ba 0665               -	asl v2a	; v2 = v2 << 5
    79  08bc 2664               	rol v2b
    80  08be 2663               	rol v2c
    81  08c0 2662               	rol v2d
    82  08c2 ca                 	dex
    83  08c3 d0f5               	bne -								; (13b)
    84                          ;-----------------------------------------------
    85                          ; xor v1 ^= v2	; eor for all 4 byte
    86  08c5 a204               dxo	ldx #$04
    87  08c7 b58b               -	lda v1e,x	; read v1
    88  08c9 5561               	eor v2e,x	; v1 xor v2
    89  08cb 958b               	sta v1e,x 	; write v1
    90  08cd 9561               	sta v2e,x 	; write v2 
    91  08cf ca                 	dex
    92  08d0 d0f5               	bne -
    93  08d2 60                 	rts									; (14b)
    94                          ;-----------------------------------------------		
    95                          }
    96                          part1_real_end
    97                          
    98                          ; Codebereich 1: darf den zur Verfügung stehenden Bereich nicht überschreiten!
    99                          
   100                          !set part1_end = (part1_real_end-part1_real)+part1-1
   101                          !if ( part1_end > $e0e2 ) {
   102                          	!error "Code-Teil 1 ist zu lang! ",part1,"-",part1_end-1
   103                          }
   104                          
   105                          part2_real:
   106                          
   107                          !pseudopc $e3ba {
   108                          part2:
   109                          ;***** copy result from v => v2 (alias basic fac1)
   110  08d3 0000000001         	!byte	$00, $00, $00, $00, $01
   111                          }
   112                          part2_real_end
