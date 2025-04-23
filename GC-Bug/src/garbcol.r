
; ******** Source: garbcol.asm
     1                          !to "garbcol.o",cbm	
     2                          ;
     3                          ;  **** Garbage Collection ****
     4                          ;
     5                          ; 64'er, Oct. 1988
     6                          ;
     7                          ; In zwei Schritten wird der String-Speicher kompaktiert:
     8                          ;   1) Alle Strings im String-Descriptor-Stack (SDS),
     9                          ;      in Variablen und Arrays erhalten im
    10                          ;      Backlink den Verweis auf den Descriptor.
    11                          ;      Nicht mehr referenzierte Strings bleiben als
    12                          ;      ungenutzt markiert und verweisen auf den
    13                          ;      nächsten String Richtung niedriger Adressen.
    14                          ;   2) Nun wird der String-Speicher absteigend durchgegangen,
    15                          ;      wobei nur die aktiven Strings nach "oben" über
    16                          ;      etwaige Lücken hinweg kopiert werden. Die ungenutzten
    17                          ;      Lücken werden dabei übergangen.
    18                          ;      Beim Kopieren wird der Backlink wieder entfernt
    19                          ;      (als ungenutzt markiert), da ja bis zur nächsten
    20                          ;      Kompaktierung der Speicher aufgegeben werden könnte.
    21                          ;
    22                          ; Im Vergleich zu der von CBM eingesetzten Routine, wird
    23                          ; hier auf eine platzraubende Optimierung verzichtet,
    24                          ; wenn ein Teil oder der gesamt String-Speicher schon
    25                          ; kompaktiert sein sollte. Es werden dann die Strings
    26                          ; im schlimmsten Fall wieder über sich selbst kopiert.
    27                          ;
    28                          ; Ein gleichwertiger Ansatz wäre eine einfache Abfrage
    29                          ; bei opt_no_copy, ob ptr (Arbeitszeiger auf den alten
    30                          ; Heap) gleich newptr (neuer Heap) ist. Solange diese
    31                          ; der Fall ist, ist keine Kopieraktion (und auch
    32                          ; keine Descriptor-Korrektur) notwendig.
    33                          ; In diesem Fall kann allerdings die Optimierung #3 nicht
    34                          ; verwendet werden, da sonst die Backlink-Markierung
    35                          ; nicht in allen Fällen passieren würde!
    36                          ;
    37                          ; Überarbeitetet und korrigiert:
    38                          ;	2013-11-15 Johann E. Klasek, johann at klasek at
    39                          ; Optimiert:
    40                          ;	2019-03-20 Johann E. Klasek, johann at klasek at
    41                          ;
    42                          ; Bugfixes:
    43                          ;
    44                          ;	1) in backlinkarr:
    45                          ;	   das C-Flag ist beim Errechnen des Folge-Arrays
    46                          ;	   definiert zu löschen, sonst werden ev. nicht 
    47                          ;	   alle Elemente aller Arrays mit einem korrekten
    48                          ;	   Backlink versehen und der String-Heap wird 
    49                          ;	   durch die GC korrumpiert!
    50                          ;
    51                          ;	2) in backlinkarr bei blanext:
    52                          ;	   Muss zum Aufrufer immer mit Z=0 rückkehren,
    53                          ;	   und erkennt sonst immer nur das 1. Array!
    54                          ;	   Damit liegen die anderen Strings dann im 
    55                          ;	   freien Bereich und werden nach und nach 
    56                          ;	   überschrieben!
    57                          ;
    58                          ; Optimierungen:
    59                          ;    
    60                          ;    #1 Schnellere Kopierroutine (+5 Byte Code, -2 T/Zeichen):
    61                          ;	Wegen des längeren Codes und und einem deswegen länger werdenden
    62                          ;	Branch-Offset, wurde der Code ab cfinish zurückversetzt.
    63                          ;	Da im Teilbereich 1 nur noch 3 Bytes frei sind, muss auch
    64                          ;	noch an anderer Stelle eingespart werden.
    65                          ;	Dabei wird unmittelbar vor dem Kopieren des Strings nicht
    66                          ;	mehr explizit der Fall eines Strings mit Länge 0 betrachtet,
    67                          ;	der an dieser Stelle auch nicht auftreten kann, da
    68                          ;	der erste Durchgang durch alle Strings am SDS, bei den
    69                          ;	Variablen und den Arrays Strings der Länge 0 übergeht. 
    70                          ;	Selbst, wenn jemand böswilligerweise via allocate-Routine
    71                          ;	0-Längen-Speicher anfordert (was immer 2 Link-Bytes kostet),
    72                          ;	können diese Leerstring nicht referenziert werden. Im Zuge
    73                          ;	des zweiten Durchlaufs (Collection) würden diese degenerieren
    74                          ;	0-Längen-Strings auch wieder verschwinden.
    75                          ;
    76                          ;	Aktivierbar via use_fast_copy-Variable.
    77                          ;
    78                          ;    #2 allocate etwas kompakter/schneller (-2 Byte Code, -3 T)
    79                          ;       Der Backlink wird via strptr/strptr+1 gesetzt, wobei
    80                          ;       bei einem String länger 253 Bytes das High-Byte in strptr+1
    81                          ;	erhöht wird, statt dies mit fretop+1 zu machen, welches
    82                          ;	dann restauriert werden muss.
    83                          ;       
    84                          ;	Aktivierbar via alternate_stralloc-Variable.
    85                          ;
    86                          ;    #3 Die Lückenmarkierung (Low-Byte mit der Länge) wird beim
    87                          ;	Kopieren des Strings mitgemacht. (-4 Byte Code, -5 T/String)
    88                          ;	Siehe no_opt_3-Abfrage bei Label cw3.
    89                          ;
    90                          ;    #4 Kein String-Kopieren durchführen, solange der String-Heap
    91                          ;	geordnet ist (also solange ptr = newptr ist). Sobald
    92                          ;	eine Lücke eliminiert wurde, laufen ptr und newptr auseinander.
    93                          ;
    94                          
    95                          ; Optimierung #1: Die optimierte Kopierroutine verwenden
    96                          ; aktiv
    97                          !set use_fast_copy=1
    98                          
    99                          ; Optimierung #2: etwas kürzere und schnellere stralloc-Routine
   100                          ; inaktiv
   101                          !set alternate_stralloc=1
   102                          
   103                          ; Optimierung #3: Lückmarkierung teilweise mit String-Kopieren mitmachen.
   104                          ; ist immer aktiv
   105                          
   106                          ; Optimierung #4: Kein String-Kopieren, solange Heap geordnet ist.
   107                          ; Wenn aktiv (passt aber nicht ins ROM!), dann darf nicht Optimierung #3
   108                          ; aktiv sein!
   109                          ; inaktiv
   110                          ;!set opt_no_copy=1
   111                          
   112                          !ifdef opt_no_copy {
   113                          !set no_opt_3=1
   114                          }
   115                          
   116                          
   117                          ; Basic-Zeiger und -konstanten
   118                          
   119                          collected = $0f
   120                          
   121                          sdsbase  = $0019	; 1. Element String-Descriptor-Stacks (SDS)
   122                          			; wächst nach oben, max. 3 Elemente
   123                          			; zu je 3 Bytes.
   124                          sdsptr   = $16		; Zeiger auf nächstes freie Element
   125                          			; des String-Descriptor-Stacks (SDS)
   126                          
   127                          vartab   = $2d		; Basicprogrammende = Variablenanfang
   128                          arytab   = $2f		; Variablenende = Array-Bereichanfang
   129                          strend   = $31		; Array-Bereichende = unterste String-Heap-Adresse 
   130                          fretop   = $33		; aktuelle String-Heap-Adresse
   131                          strptr	 = $35		; temporärer Stringzeiger
   132                          memsiz   = $37		; höchste RAM-Adresse für Basic, Start
   133                          			; des nach unten wachsenden String-Heaps
   134                          ; Hilfsvariablen
   135                          
   136                          ptr	 = $22		; Arbeitszeiger, alter Heap
   137                          newptr	 = $4e		; Neuer Stringzeiger, neuer Heap
   138                          desclen	 = $53		; akt. Länge eines Stringdescriptors
   139                          aryptr	 = $58		; Array-Zeiger
   140                          descptr	 = $5f		; Descriptor-Zeiger
   141                          
   142                          garcoll  = $b526
   143                          
   144                          ; Vorbelegung der Speicherplätze
   145                          
   146                          romsize  = $2000	; ROM Länge 8K
   147                          
   148                          prozport = $01		; Prozessorport
   149                          memrom = %00110111	; Basic+Kernal ROM
   150                          membas = %00110110	; Basic RAM+kernal ROM
   151                          memram = %00110101	; Basic+Kernal RAM
   152                          
   153                          
   154                          ; Datenstrukturen
   155                          ;
   156                          ; String am Heap:
   157                          ;
   158                          ;   +--------------------------------------+
   159                          ;   |       +--------------+               |
   160                          ;   V       |              V               |
   161                          ;   +---+---+---+          +-----------+---+---+
   162                          ;   |LEN|LO |HI |          |STRINGDATEN|LO |HI |
   163                          ;   +---+---+---+          +-----------+---+---+
   164                          ;   ^    *******           ^            *******
   165                          ;   |       String.-Adr.   |               Descriptor-Adr.
   166                          ;   +-Descriptor-Adresse   +-String-Adresse
   167                          ;
   168                          ; Lücken am Heap:
   169                          ;                      
   170                          ;   +-------------+   +--------------+
   171                          ;   V             |   V              |
   172                          ;    +-----------+---+---+---------+---+---+
   173                          ;    |LÜCKE 2    |LEN|$FF|LÜCKE 1  |LEN|$FF|
   174                          ;    +-----------+---+---+---------+---+---+
   175                          ;                  ^  ***            ^  ***
   176                          ;                  |   Lückenmark.   |   Lückenmarkierung
   177                          ;                  Backlink-Adresse  Backlink-Adresse
   178                          
   179                          
   180                          

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

; ******** Source: garbcol.asm
   181                          
   182                          
   183                          ;
   184                          ; Patch-Liste für "loader"
   185                          ;
   186                          
   187                          patchlist:
   188                          
   189  087b 9b084501f4b4       !wo part1_real,part1_real_end-part1_real,part1
   190  0881 2e0a1700bae4       !wo part2_real,part2_real_end-part2_real,part2
   191  0887 f5090a0067bf       !wo part3_real,part3_real_end-part3_real,part3
   192  088d ff092f007be4       !wo part4_real,part4_real_end-part4_real,part4
   193  0893 e0091500c1b6       !wo part5_real,part5_real_end-part5_real,part5
   194  0899 0000               !wo 0  ; Endemarkierung
   195                          
   196                          
   197                          ; ******************************* part 1 *************************************
   198                          
   199                          part1_real:
   200                          
   201                          !pseudopc $b4f4 {
   202                          
   203                          part1:
   204                          
   205                          ;***** Speicher von String-Heap anfordern
   206                          ;
   207                          ;	in:	A		; Länge anforderung
   208                          ;		fretop
   209                          ;	mod:	collected	; "GC aufgerufen"-Flag
   210                          ;		strptr		; temp. Zeiger
   211                          ;	out:	fretop		; Adresse auf String
   212                          ;		X,Y		; Adresse auf String
   213                          ;
   214                          ; Der String wird im Backlink stets als ungebrauchte Lücke
   215                          ; markiert! Dann muss die GC nur noch die Backlinks
   216                          ; der aktiven Strings setzen und kann die ungebrauchten
   217                          ; Strings überspringen.
   218                          
   219                          
   220                          basicerror = $b4d2		; Basic-Fehlermeldung
   221                          
   222                          allocate:
   223  089b 460f               	lsr collected		; Flag löschen
   224  089d 48                 retry	pha			; Länge der Anforderung,
   225                          				; für 2. Teil
   226                          				; Länge 0 möglich, verbraucht aber 2 Bytes
   227  089e 49ff               	eor #$ff		; negieren
   228  08a0 38                 	sec
   229  08a1 6533               	adc fretop		; A/X = fretop; A/X -= Länge
   230  08a3 a634               	ldx fretop+1
   231  08a5 b002               	bcs l1
   232  08a7 ca                 	dex
   233  08a8 38                 	sec
   234  08a9 e902               l1	sbc #2			; A/X -= 2 Platz für Backlink einrechnen
   235  08ab b001               	bcs l2
   236  08ad ca                 	dex
   237  08ae e432               l2	cpx strend+1		; String-Heap voll (Array-Bereichende)?
   238  08b0 9006               	bcc checkcollect
   239  08b2 d013               	bne alloc		; nein, Bereich anfordern
   240  08b4 c531               	cmp strend 
   241  08b6 b00f               	bcs alloc		; nein, Bereich anfordern
   242                          checkcollect
   243  08b8 a210               	ldx #16			; Basic-Fehler 16: "OUT OF MEMORY"
   244  08ba a50f               	lda collected
   245  08bc 30bb               	bmi basicerror		; Collection schon gelaufen?
   246  08be 2026b5             	jsr docollect		; nein, dann Garbage Collection, C=1 (immer!)
   247  08c1 660f               	ror collected		; Flag setzen (Bit 7) setzen
   248  08c3 68                 	pla			; Länge angeforderter Bereich
   249  08c4 4cf6b4             	jmp retry		; nochmal versuchen (ob durch GC Platz frei wurde)
   250                          
   251  08c7 2067b5             alloc	jsr setfretop		; FRETOP = A/X
   252  08ca 4cbae4             	jmp stralloc		; zum 2. Teil: Allokation abschließen
   253                          
   254                          
   255                          ;***** garbage collection
   256                          
   257                          ;	in:	-
   258                          ;	mod:	ptr		; Zeiger auf alten String-Heap
   259                          ;		newptr		; Zeiger auf neuen String-Heap
   260                          ;		descptr		; Zeiger auf Descriptor
   261                          ;		desclen		; Descriptor-Schrittweite
   262                          ;	out:	fretop		; Neue String-Heap-Position
   263                          ;		C=1
   264                          
   265                          docollect
   266                          
   267                          
   268                          ; Backlink aller temporären Strings am String-Descriptor-Stack setzen
   269                          
   270  08cd a919               sds:	lda #<sdsbase		; Startadr. String-Descriptor-Stack
   271  08cf a200               	ldx #>sdsbase		; da in 0-Page, immer 0
   272  08d1 20a5e4             	jsr setptr		; damit ptr setzen
   273                          
   274  08d4 c516               sdsnext	cmp sdsptr		; am 1. freien SDS-Element? (nur Low-Byte!)
   275  08d6 f005               	beq vars		; Ja, SDS durch, weiter mit Variablen
   276  08d8 20e6b5             	jsr backlink		; sonst Backlink setzen
   277  08db f0f7               	beq sdsnext		; immer, weil High-Byte 0; nächsten SDS-Descriptor
   278                          
   279                          ; Backlink aller String-Variablen setzen
   280                          
   281  08dd a905               vars:	lda #5			; Descriptor-Schritt für Variablen
   282  08df 8553               	sta desclen
   283  08e1 a52d               	lda vartab		; Variablenbeginn
   284  08e3 a62e               	ldx vartab+1
   285  08e5 20a5e4             	jsr setptr		; ptr = A/X
   286                          
   287  08e8 e430               varnext	cpx arytab+1		; Variablenende?
   288  08ea d004               	bne varbl
   289  08ec c52f               	cmp arytab
   290  08ee f005               	beq arrays		; ja, weiter mit Arrays
   291  08f0 201db6             varbl	jsr backlinkvar		; Backlink für nächste String-Variable setzen
   292  08f3 d0f3               	bne varnext		; immer; nächsten Var.-Descriptor
   293                          
   294                          ; Backlink bei allen String-Arrays setzen
   295                          
   296                          arrays:
   297  08f5 8558               	sta aryptr		; Variablenbereichende = Array-Bereichanfang
   298  08f7 8659               	stx aryptr+1 
   299  08f9 a003               	ldy #3			; Descriptor-Schritt bei String-Arrays
   300  08fb 8453               	sty desclen
   301                          
   302  08fd e432               arrnext	cpx strend+1		; Array-Bereichende?
   303  08ff d004               	bne arrbl
   304  0901 c531               	cmp strend
   305  0903 f00e               	beq cleanwalk
   306  0905 20c4b6             arrbl	jsr backlinkarr		; Backlinks für nächstes String-Array setzen -> Z=0!
   307  0908 d0f3               	bne arrnext		; immer; nächstes Array-Element
   308                          
   309                          
   310                          ; Ende, Zeiger zum neuen String-Heap übernehmen
   311                          
   312                          cfinish
   313  090a a54e               	lda newptr		; Aufgeräumtzeiger ist ..
   314  090c a64f               	ldx newptr+1
   315                          setfretop
   316  090e 8533               	sta fretop		; neues FRETOP
   317  0910 8634               	stx fretop+1 
   318  0912 60                 	rts			; fertig!
   319                          
   320                          ; Nachdem nun alle Backlinks gesetzt sind
   321                          ; den String-Heap von oben nach unten durchgehen
   322                          ; und zusammenschieben ...
   323                          
   324                          cleanwalk:
   325  0913 a537               	lda memsiz		; beim Basic-Speicherende
   326  0915 a638               	ldx memsiz+1
   327  0917 854e               	sta newptr		; ... beginnen
   328  0919 864f               	stx newptr+1 
   329                          
   330                          ; Aufräumschleife
   331                          
   332  091b e434               cwnext	cpx fretop+1		; A/X: altes FRETOP erreicht,
   333  091d d004               	bne cwclean		; dann Heap durch und fertig.
   334  091f c533               	cmp fretop		; andernfalls aufräumen ...
   335  0921 f0e7               	beq cfinish		; fertig, weil A/X = FRETOP
   336                          
   337                          ; nächsten String "aufräumen" ...
   338                          
   339  0923 38                 cwclean	sec			; Aufgeräumtzeiger auf Backlink
   340  0924 e902               	sbc #2
   341  0926 b001               	bcs cw1
   342  0928 ca                 	dex			; A/X -> Backlink
   343                          
   344  0929 20a5e4             cw1	jsr setptr		; A/X -> ptr (Alt-String-Zeiger)
   345                          
   346  092c a000               	ldy #0
   347  092e b122               	lda (ptr),y		; Backlink low oder Lückenlänge
   348  0930 c8                 	iny			; Y=1
   349  0931 aa                 	tax			; -> X
   350  0932 b122               	lda (ptr),y		; Backlink high
   351  0934 c9ff               	cmp #$ff		; "String-nicht gebraucht"-Markierung
   352  0936 900c               	bcc cwactive		; aktiver String
   353                          
   354  0938 8a                 	txa			; Lückenlänge
   355  0939 49ff               	eor #$ff		; negieren, C=1 (Komplement, +1)
   356  093b 6522               	adc ptr			; (ptr - Lückenlänge)
   357  093d a623               	ldx ptr+1 
   358  093f b0da               	bcs cwnext		; weiter mit nächstem/r String/Lücke
   359  0941 ca                 	dex			; High Byte
   360                          
   361  0942 d0d7               cw2	bne cwnext		; immer (Heap ist nie in Page 1)
   362                          				; weiter mit nächstem/r String/Lücke
   363                          
   364                          ; einen aktiven String nach oben schieben
   365                          
   366                          cwactive			; immer mit Y=1 angesprungen
   367  0944 8560               	sta descptr+1		; Descriptor-Adresse
   368  0946 865f               	stx descptr 
   369                          
   370  0948 a54e               	lda newptr		; Aufgeräumtzeiger -= 2
   371  094a e901               	sbc #1			; weil bereits C=0!
   372  094c 854e               	sta newptr		; newptr -= 2
   373  094e b003               	bcs cw3
   374  0950 c64f               	dec newptr+1
   375  0952 38                 	sec			; für SBC unten
   376                          
   377  0953 a9ff               cw3	lda #$ff		; Backlink h: als Lücke markieren
   378  0955 914e               	sta (newptr),y		; Y=1
   379  0957 88                 	dey			; Y=0
   380                          !ifdef no_opt_3 {
   381                          	lda (descptr),y		; Descriptor: String-Länge
   382                          	sta (newptr),y		; Backlink l: Lückenlänge
   383                          } else {
   384                          				; Backlink l: Lückenlänge später beim
   385                          				; Kopieren ...
   386                          }
   387  0958 a54e               	lda newptr		; Aufgeräumtzeiger -= String-Länge
   388  095a f15f               	sbc (descptr),y		; minus String-Länge, immer C=1, Y=0
   389  095c 854e               	sta newptr
   390  095e b003               	bcs cw4
   391  0960 c64f               	dec newptr+1
   392  0962 38                 	sec			; für SBC unten
   393                          
   394  0963 a522               cw4	lda ptr			; Alt-String-Zeiger -= String-Länge
   395  0965 f15f               	sbc (descptr),y		; immer C=1
   396  0967 8522               	sta ptr			; Arbeitszeiger = alte String-Adresse
   397  0969 b002               	bcs cw5
   398  096b c623               	dec ptr+1
   399                          cw5
   400                          	; An dieser Stelle wäre eine Optimierung möglich, um das
   401                          	; Kopieren zu verhindern, wenn der String an der gleichen
   402                          	; Stelle bleibt - dabei darf die Optimierung #3 nicht
   403                          	; in Verwendung sein und es würden zusätzlich 10 Bytes gebraucht!
   404                          !ifdef opt_no_copy {
   405                          	cmp newptr		; ptr bereits in A
   406                          	bne cw6			; ptr != newptr, also kopieren
   407                          	lda ptr+1		; High Byte ...
   408                          	cmp newptr+1
   409                          	beq cwheapordered	; ptr = newptr, nicht kopieren
   410                          cw6
   411                          }
   412                          
   413  096d b15f               	lda (descptr),y		; String-Länge
   414                          !ifndef use_fast_copy {
   415                          
   416                          				; immer, da Länge >0
   417                          !ifdef no_opt_3 {
   418                          	beq cwnocopy		; falls doch Länge 0, kein Kopieren,
   419                          				; Descriptor trotzdem anpassen ...
   420                          	tay			; als Index, mit Dekrementieren beginnen
   421                          } else { ; mit Optimierung #3
   422                          	tay			; Länge als Index
   423                          	bne cwbllen		; immer, zuerst Backlink-Low-Markierung
   424                          				; mit Lückenlänge belegen
   425                          }
   426                          cwloop	dey			; -> Startindex fürs Kopieren
   427                          	lda (ptr),y		; Arbeitszeiger mit altem String
   428                          cwbllen sta (newptr),y		; Aufgeräumtzeiger mit neuem String-Ort
   429                          	tya			; Test auf Z-Flag!
   430                          	bne cwloop		; Index = 0 -> fertig kopiert
   431                          
   432                          } else { ; use_fast_copy!
   433                          
   434                          				; + 3 Byte, -2 T/Zeichen 
   435  096f a8                 	tay			; Länge als Index
   436                          !ifdef no_opt_3 {
   437                          	bne cwentry		; immer, da Länge in Y>0, bei
   438                          				; Dekrementieren beginnen!
   439                          } else { ; mit Optimierung #3
   440  0970 d002               	bne cwbllen		; immer, zuerst Backlink-Low-Markierung
   441                          				; mit Lückenlänge belegen
   442                          }
   443                          				; -> Startindex fürs Kopieren
   444  0972 b122               cwloop	lda (ptr),y		; Arbeitszeiger mit altem String
   445  0974 914e               cwbllen	sta (newptr),y		; Aufgeräumtzeiger mit neuem String-Ort
   446  0976 88                 cwentry	dey			; Test auf Z-Flag!
   447  0977 d0f9               	bne cwloop		; Index = 0 -> fertig kopiert
   448  0979 b122               cwone	lda (ptr),y		; Arbeitszeiger mit altem String
   449  097b 914e               	sta (newptr),y		; Aufgeräumtzeiger mit neuem String-Ort
   450                          }
   451                          
   452                          cwnocopy:
   453                          				; Y=0
   454  097d c8                 	iny			; Y=1
   455  097e a54e               	lda newptr		; im Descriptor:
   456  0980 915f               	sta (descptr),y		; String-Adresse L: neue Adresse
   457  0982 c8                 	iny			; Y=2
   458  0983 a54f               	lda newptr+1
   459  0985 915f               	sta (descptr),y		; String-Adresse H: neue Adresse
   460                          
   461                          cwheapordered:
   462  0987 a522               	lda ptr
   463  0989 a623               	ldx ptr+1		; High-Byte immer !=0
   464  098b d08e               	bne cwnext		; immer; weiter in Schleife
   465                          
   466                          
   467                          ;**** Backlink setzen
   468                          ;
   469                          ; 	in:		ptr	Descriptor-Adresse
   470                          ; 	out:		ptr	Descriptor-Adresse
   471                          ;			A/X
   472                          ;			Z=0	wenn nicht am SDS
   473                          ;			Z=1	wenn am SDS
   474                          ;	destroy:	newptr
   475                          ;	called:		blaset, backlinkvar
   476                          
   477                          backlink:
   478  098d a000               	ldy #0
   479  098f b122               	lda (ptr),y		; String-Länge
   480  0991 f023               	beq blnext		; fertig, wenn =0
   481  0993 c8                 	iny
   482  0994 18                 	clc
   483  0995 7122               	adc (ptr),y		; Backlink-Position (am String-Ende)
   484  0997 854e               	sta newptr		; Backlink-Zeiger L
   485  0999 aa                 	tax
   486  099a c8                 	iny
   487  099b b122               	lda (ptr),y
   488  099d 6900               	adc #0
   489  099f 854f               	sta newptr+1		; Backlink-Zeiger H
   490  09a1 c532               	cmp strend+1		; < Array-Bereichende (außerhalb Heap)?
   491  09a3 9011               	bcc blnext		; ja, denn nächsten String
   492  09a5 d004               	bne blsetdesc
   493  09a7 e431               	cpx strend 
   494  09a9 900b               	bcc blnext		; < Array-Bereichende (außerhalb Heap)?
   495                          
   496                          blsetdesc:
   497  09ab a001               	ldy #1
   498  09ad a523               	lda ptr+1
   499  09af 914e               	sta (newptr),y		; Descriptor-Adresse ...
   500  09b1 88                 	dey
   501  09b2 a522               	lda ptr
   502  09b4 914e               	sta (newptr),y		; in den Backlink übertragen
   503                          
   504  09b6 a553               blnext	lda desclen		; nächster String/nächste Variable
   505  09b8 18                 	clc			; Schrittweite zum nächsten Descriptor
   506  09b9 6522               	adc ptr			; ptr += desclen
   507  09bb 8522               	sta ptr
   508  09bd 9002               	bcc +
   509  09bf e623               	inc ptr+1
   510  09c1 a623               +	ldx ptr+1		; immer != 0 -> Z=0 (außer bei SDS, Z=1)
   511  09c3 60                 	rts
   512                          
   513                          ;**** Nächste String-Variable und Backlink setzen
   514                          ;
   515                          ; 	in:		ptr	Variablenadresse
   516                          ; 	out:		ptr	Variablenadresse
   517                          ;			A/X
   518                          ;			Z=0
   519                          ;	destroy:	newptr
   520                          ;	called:		varbl (vars)
   521                          
   522                          backlinkvar:
   523  09c4 a000               	ldy #0			;							
   524  09c6 b122               	lda (ptr),y		; Variablenname 1. Zeichen
   525  09c8 aa                 	tax			; Typstatus merken
   526  09c9 c8                 	iny
   527  09ca b122               	lda (ptr),y		; Variablenname 2. Zeichen
   528  09cc a8                 	tay			; Typstatus merken
   529                          
   530  09cd a902               	lda #2			; Descriptor-Adresse (in Variable)
   531  09cf 18                 	clc
   532  09d0 6522               	adc ptr			; ptr += 2
   533  09d2 8522               	sta ptr
   534  09d4 9002               	bcc +
   535  09d6 e623               	inc ptr+1
   536                          +
   537  09d8 8a                 	txa			; Variablentyp prüfen
   538  09d9 30db               	bmi blnext		; keine String, nächste Variable
   539  09db 98                 	tya
   540  09dc 30af               	bmi backlink		; Backlink setzen
   541  09de 10d6               	bpl blnext		; keine String-Var., nächste Variable
   542                          
   543                          }
   544                          part1_real_end
   545                          
   546                          ; Codebereich 1: darf den zur Verfügung stehenden Bereich nicht überschreiten!
   547                          
   548                          !set part1_end = (part1_real_end-part1_real)+part1
   549                          !if ( part1_end > $B63D ) {
   550                          	!error "Code-Teil 1 ist zu lang! ",part1,"-",part1_end
   551                          }
   552                          
   553                          
   554                          ; ******************************* part 4 *************************************
   555                          
   556                          part5_real
   557                          !pseudopc $b6c1 {
   558                          
   559                          part5:
   560                          
   561                          part5_continue = $b6d6
   562  09e0 4cd6b6             	jmp part5_continue
   563                          
   564                          ;**** Nächste Array-Variable und Backlink setzen
   565                          ;
   566                          ; 	in: 		ptr	Arrayadresse
   567                          ; 	out:		ptr	Adresse Folge-array
   568                          ;			aryptr	Adresse Folge-array
   569                          ;			A/X	Adresse Folge-array
   570                          ;			Z=0
   571                          ;	destroy:	newptr
   572                          ;	called:		arrbl (arrays)
   573                          
   574                          backlinkarr:
   575  09e3 a000               	ldy #0
   576  09e5 b122               	lda (ptr),y		; Variablenname 1. Zeichen
   577  09e7 08                 	php			; für später
   578  09e8 c8                 	iny
   579  09e9 b122               	lda (ptr),y		; Variablenname 2. Zeichen
   580  09eb aa                 	tax			; für später
   581                          
   582  09ec c8                 	iny
   583  09ed b122               	lda (ptr),y		; Offset nächstes Array
   584  09ef 18                 	clc			; Bugfix 1: C=0 definiert setzen
   585  09f0 6558               	adc aryptr
   586  09f2 4c67bf             	jmp part3
   587                          				; weiter an anderer Stelle!
   588                          blapast
   589                          !if blapast > part5_continue {
   590                          	!error "part5 ist zu lang!"
   591                          }
   592                          }
   593                          part5_real_end
   594                          
   595                          
   596                          ; ******************************* part 3 - pre *************************************
   597                          
   598                          part3_real
   599                          !pseudopc $bf67 {
   600                          
   601                          part3:
   602  09f5 8558               	sta aryptr		; Folge-Array L
   603  09f7 c8                 	iny
   604  09f8 b122               	lda (ptr),y
   605  09fa 6559               	adc aryptr+1 
   606  09fc 4c7ce4             	jmp backlinkarr2
   607                          }
   608                          part3_real_end
   609                          
   610                          ; ******************************* part 3 *************************************
   611                          
   612                          part4_real
   613                          !pseudopc $e47b { ; +7 bytes wegen part4pre
   614                          
   615                          part4:
   616                          
   617  09ff 00                 	!byte  0 		; Einschaltmeldung kürzen (+10 Char possible)
   618                          
   619                          backlinkarr2:
   620  0a00 8559               	sta aryptr+1		; Folge-Array H
   621                          
   622  0a02 28                 	plp			; Arraytyp:
   623  0a03 3020               	bmi blaskip		; kein String-Array
   624  0a05 8a                 	txa
   625  0a06 101d               	bpl blaskip		; kein String-Array
   626                          
   627  0a08 c8                 	iny			; Y=4
   628  0a09 b122               	lda (ptr),y		; Anzahl der Dimensionen (< 126 !)
   629  0a0b 0a                 	asl 			; *2
   630  0a0c 6905               	adc #5			; + 5 (Var.Name+Offset+Dimensionen)
   631  0a0e 6522               	adc ptr			; auf 1. Element ...
   632  0a10 8522               	sta ptr 
   633  0a12 9002               	bcc bla1
   634  0a14 e623               	inc ptr+1 
   635  0a16 a623               bla1	ldx ptr+1		; positionieren
   636                          
   637  0a18 e459               blanext	cpx aryptr+1		; Array-Ende erreicht?
   638  0a1a d004               	bne blaset		; nein, Backlink setzen
   639  0a1c c558               	cmp aryptr
   640  0a1e f007               	beq blafinish		; Array fertig, Bugfix 2: Z-Flag löschen!
   641                          blaset
   642  0a20 20e6b5             	jsr backlink		; Backlink setzen
   643  0a23 d0f3               	bne blanext		; immer (High-Byte != 0)
   644                          
   645                          blaskip
   646  0a25 a558               	lda aryptr		; Zeiger auf Folge-Array
   647                          blafinish
   648  0a27 a659               	ldx aryptr+1 		; Z=0 sicherstellen
   649                          
   650  0a29 8522               setptr	sta ptr			; Arbeitszeiger setzen
   651  0a2b 8623               	stx ptr+1
   652  0a2d 60                 	rts			; immer Z=0
   653                          
   654                          ;--- $e4b7 - $e4d2 unused ($aa)
   655                          ;--- $e4d3 - $e4d9 unused ($aa) bei altem kernal,
   656                          ;----              sonst Patch für andere Zwecke
   657                          
   658                          }
   659                          part4_real_end
   660                          
   661                          
   662                          ; ******************************* part 2 *************************************
   663                          
   664                          part2_real
   665                          !pseudopc $e4ba {
   666                          
   667                          part2:
   668                          
   669                          ;**** String Allocation (Fortsetzung)
   670                          ;
   671                          ;	in: 	TOS		; Länge
   672                          ;		fretop		; String-Adresse
   673                          ;	out:	fretop		; String-Adresse
   674                          ;		strptr		; String-Adresse (wird nicht verwendet)
   675                          ;				; (bei alternate_stralloc eventuell mit
   676                          ;				; inkrementiertem High-Byte)
   677                          ;		A		; Länge
   678                          ;		X,Y		; String-Adresse (L,H)
   679                          ;	called:	allocate (in Fortsetzung)
   680                          
   681                            !ifndef alternate_stralloc {
   682                          stralloc:
   683                          	sta strptr		; strptr = A/X = FRETOP
   684                          	stx strptr+1
   685                          	tax			; A in X aufheben
   686                          	pla			; Länge temp. vom Stack 
   687                          	pha			; wieder auf Stack, nun auch in A
   688                          	tay			; Index=Länge (Backlink-position)
   689                          	sta (fretop),y		; Backlink L = String-/Lückenlänge
   690                          	iny			; Y=Länge+1
   691                          	bne sa1			; wenn Länge=255, dann
   692                          	inc fretop+1		; Überlauf, aber nur temporär!
   693                          
   694                          sa1	lda #$ff		; Backlink H = Markierung "Lücke"
   695                          	sta (fretop),y
   696                          	ldy strptr+1
   697                          	sty fretop+1		; Überlaufkorr. rückgängig
   698                          	pla			; Länge vom Stack nehmen
   699                          	rts
   700                          
   701                            } else {
   702                          ; alternative, etwas kürzere Variante (-3 T, -2 B)
   703                          
   704                          stralloc:
   705  0a2e 8535               	sta strptr		; strptr = A/X = FRETOP
   706  0a30 8636               	stx strptr+1
   707  0a32 aa                 	tax			; A in X aufheben
   708  0a33 68                 	pla			; Länge temp. vom Stack 
   709  0a34 48                 	pha			; wieder auf Stack, nun auch in A
   710  0a35 a8                 	tay			; Index=Länge (Backlink-position)
   711  0a36 9135               	sta (strptr),y		; Backlink L = String-/Lückenlänge
   712  0a38 c8                 	iny			; Y=Länge+1
   713  0a39 d002               	bne sa1			; wenn Länge=255, dann
   714  0a3b e636               	inc strptr+1		; Überlauf, aber nur temporär!
   715                          
   716  0a3d a9ff               sa1	lda #$ff		; Backlink H = Markierung "Lücke"
   717  0a3f 9135               	sta (strptr),y
   718  0a41 a434               	ldy fretop+1		; in Y String-Adresse High-Byte
   719  0a43 68                 	pla			; Länge vom Stack nehmen
   720  0a44 60                 	rts
   721                          				; Hier weicht strptr+1 u.U. von fretop+1 ab,
   722                          				; was aber kein Problem darstellt, da
   723                          				; es im BASIC-Interpreter keine Stellt gibt,
   724                          				; die nach einem allocate-Aufruf den
   725                          				; Pointer strptr/strptr+1 verwendet!
   726                            }
   727                          }
   728                          
   729                          part2_real_end
   730                          
   731                          
   732                          ; Einsprungspunkt an korrekter Position?
   733                          
   734                          ; Kann erst nach dem Label docollect gemacht werden!
   735                          
   736                          !if (garcoll != docollect) {
   737                          	!error "Einstiegspunkt nicht an richtiger Stelle! ",garcoll,"!=",docollect
   738                          }
