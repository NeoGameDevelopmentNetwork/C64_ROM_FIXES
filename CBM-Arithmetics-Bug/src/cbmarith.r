
; ******** Source: cbmarith.asm
     1                          !to "cbmarith.o",cbm	
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
    17                          fl_akku2= $70		; Flieﬂkomma-Akku #2: Runden
    18                          fl_res_1= $26		; Flieﬂkommaergebnis 1
    19                          fl_res_2= $27		; Flieﬂkommaergebnis 2
    20                          fl_res_3= $28		; Flieﬂkommaergebnis 3
    21                          fl_res_4= $29		; Flieﬂkommaergebnis 4
    22                          
    23                          

; ******** Source: loader.asm
     1                          ;
     2                          ; *********** Loader
     3                          ;
     4                          ;       2013 11 10 johann e. klasek, johann at klasek at
     5                          ;
     6                          
     7                          ; --- Tempor‰re Variablen:
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
    25                          
    26                          ; --- Ein-/Ausgabe:
    27                          
    28                          prozport 	= $01		; Prozessorport
    29                          
    30                          memrom		= %00110111	; Basic+Kernal ROM
    31                          membas		= %00110110	; Basic ram+Kernal ROM
    32                          memram		= %00110110	; Basic+Kernal ROM
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
    45                          	!error "Loader-Adresse stimmt nicht mit SYS-Adresse ¸berein!"
    46                          }
    47  080d a000               	ldy #0
    48  080f a937               	lda #memrom
    49  0811 8501               	sta prozport		; ROM einblenden
    50  0813 8422               	sty ptr_l
    51                          
    52                          	; Basic und ins RAM kopieren
    53                          
    54  0815 a9a0               	lda #>basicrom		; Basic ROM Start
    55  0817 206508             	jsr copyram
    56                          
    57                          	; Patchliste abarbeiten (Basic betreffend)
    58                          
    59  081a a200               	ldx #0
    60  081c bd7608             nextp	lda patchlist,x
    61  081f 8522               	sta ptr
    62  0821 a8                        	tay
    63                          
    64  0822 bd7708             	lda patchlist+1,x
    65  0825 8523               	sta ptr_h
    66  0827 d003               	bne patch
    67  0829 98                 	tya
    68  082a f034               	beq pend
    69                          
    70                          patch	
    71  082c bd7908             	lda patchlist+3,x
    72  082f 8550               	sta len_h
    73  0831 bd7808             	lda patchlist+2,x
    74  0834 854f               	sta len_l
    75  0836 f002               	beq nohighcorr		; dec 0/0 Korrektur
    76  0838 e650               	inc len_h
    77                          nohighcorr
    78                          
    79  083a bd7a08             	lda patchlist+4,x
    80  083d 8551               	sta dest_l
    81                          
    82  083f bd7b08             	lda patchlist+5,x
    83  0842 8552               	sta dest_h
    84                          
    85  0844 a000               	ldy #0
    86  0846 b122               ploop	lda (ptr),y		; Patch an richtige Adresse
    87  0848 9151               	sta (dest),y		; ¸bertragen
    88  084a c8                 	iny
    89  084b d004               	bne nohigh
    90  084d e623               	inc ptr_h		; High Byte bei ‹berlauf
    91  084f e652               	inc dest_h
    92                          nohigh
    93  0851 c64f               	dec len_l		; L‰nge herunter
    94  0853 d0f1               	bne ploop		; z‰hlen nach
    95  0855 c650               	dec len_h		; dec 0/0 Methode
    96  0857 d0ed               	bne ploop
    97  0859 8a                 	txa			; Index auf n‰chsten Patch
    98  085a 18                 	clc			; positionieren ...
    99  085b 6906               	adc #6
   100  085d aa                 	tax
   101  085e d0bc               	bne nextp		; immer
   102                          
   103                          pend
   104  0860 a936               	lda #memram		; BASIC, KERNAL RAM aktivieren
   105  0862 8501               	sta prozport
   106  0864 60                 	rts
   107                          
   108                          
   109                          ; 8kByte Block an geleiche Stelle kopieren
   110                          
   111                          copyram
   112  0865 8523               	sta ptr_h		; Startadresse
   113  0867 a220               	ldx #$20		; Pages: 8K
   114  0869 b122               toram	lda (ptr),y		; ROM lesen
   115  086b 9122               	sta (ptr),y		; RAM schreiben
   116  086d c8                 	iny
   117  086e d0f9               	bne toram
   118  0870 e623               	inc ptr_h		; n‰chste "Page"
   119  0872 ca                 	dex
   120  0873 d0f4               	bne toram
   121  0875 60                 	rts
   122                          

; ******** Source: cbmarith.asm
    24                          
    25                          
    26                          ;
    27                          ; Patch-Liste f¸r "loader"
    28                          ;
    29                          
    30                          patchlist:
    31                          
    32  0876 8408140053bf       !wo part1_real,part1_real_end-part1_real,part1
    33  087c 980803005bba       !wo part2_real,part2_real_end-part2_real,part2
    34  0882 0000               !wo 0  ; Endemarkierung
    35                          
    36                          
    37                          ; ******************************* part 2 *************************************
    38                          
    39                          part1_real:
    40                          
    41                          !pseudopc $bf53 {
    42                          
    43                          part1:
    44                          
    45                          ;***** Neue Pre-Shift Funktion
    46  0884 a529               	lda fl_res_4
    47  0886 8570               	sta fl_akku2
    48  0888 a203               	ldx #$03
    49  088a b525               l1	lda fl_res_1-1,x
    50  088c 9526               	sta fl_res_1,x
    51  088e ca                 	dex
    52  088f d0f9               	bne l1
    53  0891 a001               	ldy #$01
    54  0893 98                 	tya
    55  0894 4a                 	lsr
    56  0895 8526               	sta fl_res_1
    57  0897 60                 	rts
    58                          }
    59                          part1_real_end
    60                          
    61                          ; Codebereich 2: darf den zur Verf¸gung stehenden Bereich nicht ¸berschreiten!
    62                          
    63                          !set part1_end = (part1_real_end-part1_real)+part1
    64                          !if ( part1_end > $bf67 ) {
    65                          	!error "Code-Teil 1 ist zu lang! ",part1,"-",part1_end
    66                          }
    67                          
    68                          ; ******************************* part 1 *************************************
    69                          
    70                          part2_real:
    71                          
    72                          !pseudopc $ba5b {
    73                          
    74                          part2:
    75  0898 4c53bf             	jmp part1
    76                          ;***** Sprung auf neue Pre-Shift Funktion
    77                          
    78                          }
    79                          part2_real_end
    80                          
    81                          ; Codebereich 1: darf den zur Verf¸gung stehenden Bereich nicht ¸berschreiten!
    82                          
    83                          !set part2_end = (part2_real_end-part2_real)+part2
    84                          !if ( part2_end > $ba5e ) {
    85                          	!error "Code-Teil 2 ist zu lang! ",part2,"-",part2_end
    86                          }
    87                          
    88                          
