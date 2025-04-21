
; ******** Source: xorsh2x.asm
     1                          !to "xorsh2x.o",cbm	
     2                          ;
     3                          ;  **** Func RND ****
     4                          
     5                          ;!set opt_no_copy=1
     6                          
     7                          !ifdef opt_no_copy {
     8                          !set no_opt_3=1
     9                          }
    10                          
    11                          
    12                          ; Basic-Zeiger und -konstanten
    13                          
    14                          ; Hilfsvariablen
    15                          
    16                          ptr	 	= $22		; Arbeitszeiger, alter Heap
    17                          xorsh1_l= $fb		; xor-shift 1 low variable
    18                          xorsh1_h= $fc		; xor-shift 1 high variable
    19                          xorsh2_l= $fd		; xor-shift 2 low variable
    20                          xorsh2_h= $fe		; xor-shift 2 high variable
    21                          
    22                          
    23                          ; Vorbelegung der Speicherplätze
    24                          
    25                          romsize  = $2000	; ROM Länge 8K
    26                          
    27                          prozport = $01		; Prozessorport
    28                          memrom = %00110111	; Basic+Kernal ROM
    29                          membas = %00110110	; Basic RAM+kernal ROM
    30                          memram = %00110101	; Basic+Kernal RAM
    31                          
    32                          
    33                          

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
    32                          membas		= %00110110	; Basic ram+Kernal ROM
    33                          memram		= %00110101	; Basic+Kernal ROM
    34                          
    35                          
    36                          *= $0801
    37                          basic_start
    38                          ;       2013 sys2061
    39  0801 0b08dd079e         	!by <EOP,>EOP,<(2013),>(2013),$9E
    40  0806 32303631           	!tx "2061"
    41  080a 00                 	!by 0 			; End of Line
    42  080b 0000               EOP	!by 0, 0		; Basic-Programmende
    43                          
    44                          loader
    45                          !if loader != 2061 {
    46                          	!error "Loader-Adresse stimmt nicht mit SYS-Adresse überein!"
    47                          }
    48  080d a000               	ldy #0
    49  080f a937               	lda #memrom
    50  0811 8501               	sta prozport		; ROM einblenden
    51  0813 8422               	sty ptr_l
    52                          
    53                          	; Basic und Kernal ins RAM kopieren
    54                          
    55  0815 a9a0               	lda #>basicrom		; Basic ROM Start
    56  0817 206a08             	jsr copyram
    57  081a a9e0               	lda #>kernalrom		; Kernal ROM Start
    58  081c 206a08             	jsr copyram
    59                          
    60                          	; Patchliste abarbeiten (Basic und Kernal betreffend)
    61                          
    62  081f a200               	ldx #0
    63  0821 bd7b08             nextp	lda patchlist,x
    64  0824 8522               	sta ptr
    65  0826 a8                        	tay
    66                          
    67  0827 bd7c08             	lda patchlist+1,x
    68  082a 8523               	sta ptr_h
    69  082c d003               	bne patch
    70  082e 98                 	tya
    71  082f f034               	beq pend
    72                          
    73                          patch	
    74  0831 bd7e08             	lda patchlist+3,x
    75  0834 8550               	sta len_h
    76  0836 bd7d08             	lda patchlist+2,x
    77  0839 854f               	sta len_l
    78  083b f002               	beq nohighcorr		; dec 0/0 Korrektur
    79  083d e650               	inc len_h
    80                          nohighcorr
    81                          
    82  083f bd7f08             	lda patchlist+4,x
    83  0842 8551               	sta dest_l
    84                          
    85  0844 bd8008             	lda patchlist+5,x
    86  0847 8552               	sta dest_h
    87                          
    88  0849 a000               	ldy #0
    89  084b b122               ploop	lda (ptr),y		; Patch an richtige Adresse
    90  084d 9151               	sta (dest),y		; übertragen
    91  084f c8                 	iny
    92  0850 d004               	bne nohigh
    93  0852 e623               	inc ptr_h		; High Byte bei Überlauf
    94  0854 e652               	inc dest_h
    95                          nohigh
    96  0856 c64f               	dec len_l		; Länge herunter
    97  0858 d0f1               	bne ploop		; zählen nach
    98  085a c650               	dec len_h		; dec 0/0 Methode
    99  085c d0ed               	bne ploop
   100  085e 8a                 	txa			; Index auf nächsten Patch
   101  085f 18                 	clc			; positionieren ...
   102  0860 6906               	adc #6
   103  0862 aa                 	tax
   104  0863 d0bc               	bne nextp		; immer
   105                          
   106                          pend
   107  0865 a935               	lda #memram		; BASIC, KERNAL RAM aktivieren
   108  0867 8501               	sta prozport
   109  0869 60                 	rts
   110                          
   111                          
   112                          ; 8kByte Block an geleiche Stelle kopieren
   113                          
   114                          copyram
   115  086a 8523               	sta ptr_h		; Startadresse
   116  086c a220               	ldx #$20		; Pages: 8K
   117  086e b122               toram	lda (ptr),y		; ROM lesen
   118  0870 9122               	sta (ptr),y		; RAM schreiben
   119  0872 c8                 	iny
   120  0873 d0f9               	bne toram
   121  0875 e623               	inc ptr_h		; nächste "Page"
   122  0877 ca                 	dex
   123  0878 d0f4               	bne toram
   124  087a 60                 	rts
   125                          

; ******** Source: xorsh2x.asm
    34                          
    35                          
    36                          ;
    37                          ; Patch-Liste für "loader"
    38                          ;
    39                          
    40                          patchlist:
    41                          
    42  087b 8308420097e0       !wo part1_real,part1_real_end-part1_real,part1
    43  0881 0000               !wo 0  ; Endemarkierung
    44                          
    45                          
    46                          ; ******************************* part 1 *************************************
    47                          
    48                          part1_real:
    49                          
    50                          !pseudopc $e097 {
    51                          
    52                          part1:
    53                          
    54                          ;***** Neue RND Funktion
    55                          ; 1st 16-bit xor-shift random generator
    56  0883 a5fb               	lda xorsh1_l
    57  0885 d004               	bne l1
    58  0887 a901               	lda #01 ; seed, can be anything except 0
    59  0889 85fb               	sta xorsh1_l
    60  088b a5fc               l1	lda xorsh1_h
    61  088d 4a                 	lsr
    62  088e a5fb               	lda xorsh1_l
    63  0890 6a                 	ror
    64  0891 45fc               	eor xorsh1_h
    65  0893 85fc               	sta xorsh1_h ; high part of x ^= x << 7 done
    66  0895 6a                 	ror             ; a has now x >> 9 and high bit comes from low byte
    67  0896 45fb               	eor xorsh1_l
    68  0898 85fb               	sta xorsh1_l  ; x ^= x >> 9 and the low part of x ^= x << 7 done
    69  089a 45fc               	eor xorsh1_h 
    70  089c 85fc               	sta xorsh1_h ; x ^= x << 8 done
    71                          	
    72                          ; 2nd 16-bit xor-shift random generator
    73  089e a5fb               	lda xorsh1_l
    74  08a0 d004               	bne l2
    75  08a2 a9ff               	lda #$ff ; seed, can be anything except 0
    76  08a4 85fd               	sta xorsh2_l
    77  08a6 a5fe               l2	lda xorsh2_h
    78  08a8 6a                 	ror
    79  08a9 a5fb               	lda xorsh1_l
    80  08ab 4a                 	lsr
    81  08ac 45fe               	eor xorsh2_h
    82  08ae 85fe               	sta xorsh2_h ; high part of x ^= x >> 7 done
    83  08b0 4a                 	lsr             ; a has now x << 9 and high bit comes from low byte
    84  08b1 45fd               	eor xorsh2_l
    85  08b3 85fd               	sta xorsh2_l  ; x ^= x << 9 and the low part of x ^= x >> 7 done
    86  08b5 45fe               	eor xorsh2_h 
    87  08b7 85fe               	sta xorsh2_h ; x ^= x >> 8 done
    88                          
    89                          ; copy resultats
    90  08b9 a204               	ldx #$04
    91  08bb b5fa               l3	lda $fa,x
    92  08bd 9561               	sta $61,x
    93  08bf ca                 	dex 
    94  08c0 d0f9               	bne l3
    95                          
    96  08c2 4ce3e0             	jmp $e0e3
    97                          }
    98                          part1_real_end
    99                          
   100                          ; Codebereich 1: darf den zur Verfügung stehenden Bereich nicht überschreiten!
   101                          
   102                          !set part1_end = (part1_real_end-part1_real)+part1
   103                          !if ( part1_end > $e0e2 ) {
   104                          	!error "Code-Teil 1 ist zu lang! ",part1,"-",part1_end
   105                          }
   106                          
