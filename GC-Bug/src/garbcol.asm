!to "garbcol.o",cbm	
;
;  **** Garbage Collection ****
;
; 64'er, Oct. 1988
;
; In zwei Schritten wird der String-Speicher kompaktiert:
;   1) Alle Strings im String-Descriptor-Stack (SDS),
;      in Variablen und Arrays erhalten im
;      Backlink den Verweis auf den Descriptor.
;      Nicht mehr referenzierte Strings bleiben als
;      ungenutzt markiert und verweisen auf den
;      n�chsten String Richtung niedriger Adressen.
;   2) Nun wird der String-Speicher absteigend durchgegangen,
;      wobei nur die aktiven Strings nach "oben" �ber
;      etwaige L�cken hinweg kopiert werden. Die ungenutzten
;      L�cken werden dabei �bergangen.
;      Beim Kopieren wird der Backlink wieder entfernt
;      (als ungenutzt markiert), da ja bis zur n�chsten
;      Kompaktierung der Speicher aufgegeben werden k�nnte.
;
; Im Vergleich zu der von CBM eingesetzten Routine, wird
; hier auf eine platzraubende Optimierung verzichtet,
; wenn ein Teil oder der gesamt String-Speicher schon
; kompaktiert sein sollte. Es werden dann die Strings
; im schlimmsten Fall wieder �ber sich selbst kopiert.
;
; Ein gleichwertiger Ansatz w�re eine einfache Abfrage
; bei opt_no_copy, ob ptr (Arbeitszeiger auf den alten
; Heap) gleich newptr (neuer Heap) ist. Solange diese
; der Fall ist, ist keine Kopieraktion (und auch
; keine Descriptor-Korrektur) notwendig.
; In diesem Fall kann allerdings die Optimierung #3 nicht
; verwendet werden, da sonst die Backlink-Markierung
; nicht in allen F�llen passieren w�rde!
;
; �berarbeitetet und korrigiert:
;	2013-11-15 Johann E. Klasek, johann at klasek at
; Optimiert:
;	2019-03-20 Johann E. Klasek, johann at klasek at
;
; Bugfixes:
;
;	1) in backlinkarr:
;	   das C-Flag ist beim Errechnen des Folge-Arrays
;	   definiert zu l�schen, sonst werden ev. nicht 
;	   alle Elemente aller Arrays mit einem korrekten
;	   Backlink versehen und der String-Heap wird 
;	   durch die GC korrumpiert!
;
;	2) in backlinkarr bei blanext:
;	   Muss zum Aufrufer immer mit Z=0 r�ckkehren,
;	   und erkennt sonst immer nur das 1. Array!
;	   Damit liegen die anderen Strings dann im 
;	   freien Bereich und werden nach und nach 
;	   �berschrieben!
;
; Optimierungen:
;    
;    #1 Schnellere Kopierroutine (+5 Byte Code, -2 T/Zeichen):
;	Wegen des l�ngeren Codes und und einem deswegen l�nger werdenden
;	Branch-Offset, wurde der Code ab cfinish zur�ckversetzt.
;	Da im Teilbereich 1 nur noch 3 Bytes frei sind, muss auch
;	noch an anderer Stelle eingespart werden.
;	Dabei wird unmittelbar vor dem Kopieren des Strings nicht
;	mehr explizit der Fall eines Strings mit L�nge 0 betrachtet,
;	der an dieser Stelle auch nicht auftreten kann, da
;	der erste Durchgang durch alle Strings am SDS, bei den
;	Variablen und den Arrays Strings der L�nge 0 �bergeht. 
;	Selbst, wenn jemand b�swilligerweise via allocate-Routine
;	0-L�ngen-Speicher anfordert (was immer 2 Link-Bytes kostet),
;	k�nnen diese Leerstring nicht referenziert werden. Im Zuge
;	des zweiten Durchlaufs (Collection) w�rden diese degenerieren
;	0-L�ngen-Strings auch wieder verschwinden.
;
;	Aktivierbar via use_fast_copy-Variable.
;
;    #2 allocate etwas kompakter/schneller (-2 Byte Code, -3 T)
;       Der Backlink wird via strptr/strptr+1 gesetzt, wobei
;       bei einem String l�nger 253 Bytes das High-Byte in strptr+1
;	erh�ht wird, statt dies mit fretop+1 zu machen, welches
;	dann restauriert werden muss.
;       
;	Aktivierbar via alternate_stralloc-Variable.
;
;    #3 Die L�ckenmarkierung (Low-Byte mit der L�nge) wird beim
;	Kopieren des Strings mitgemacht. (-4 Byte Code, -5 T/String)
;	Siehe no_opt_3-Abfrage bei Label cw3.
;
;    #4 Kein String-Kopieren durchf�hren, solange der String-Heap
;	geordnet ist (also solange ptr = newptr ist). Sobald
;	eine L�cke eliminiert wurde, laufen ptr und newptr auseinander.
;

; Optimierung #1: Die optimierte Kopierroutine verwenden
; aktiv
!set use_fast_copy=1

; Optimierung #2: etwas k�rzere und schnellere stralloc-Routine
; inaktiv
!set alternate_stralloc=1

; Optimierung #3: L�ckmarkierung teilweise mit String-Kopieren mitmachen.
; ist immer aktiv

; Optimierung #4: Kein String-Kopieren, solange Heap geordnet ist.
; Wenn aktiv (passt aber nicht ins ROM!), dann darf nicht Optimierung #3
; aktiv sein!
; inaktiv
;!set opt_no_copy=1

!ifdef opt_no_copy {
!set no_opt_3=1
}


; Basic-Zeiger und -konstanten

collected = $0f

sdsbase  = $0019	; 1. Element String-Descriptor-Stacks (SDS)
			; w�chst nach oben, max. 3 Elemente
			; zu je 3 Bytes.
sdsptr   = $16		; Zeiger auf n�chstes freie Element
			; des String-Descriptor-Stacks (SDS)

vartab   = $2d		; Basicprogrammende = Variablenanfang
arytab   = $2f		; Variablenende = Array-Bereichanfang
strend   = $31		; Array-Bereichende = unterste String-Heap-Adresse 
fretop   = $33		; aktuelle String-Heap-Adresse
strptr	 = $35		; tempor�rer Stringzeiger
memsiz   = $37		; h�chste RAM-Adresse f�r Basic, Start
			; des nach unten wachsenden String-Heaps
; Hilfsvariablen

ptr	 = $22		; Arbeitszeiger, alter Heap
newptr	 = $4e		; Neuer Stringzeiger, neuer Heap
desclen	 = $53		; akt. L�nge eines Stringdescriptors
aryptr	 = $58		; Array-Zeiger
descptr	 = $5f		; Descriptor-Zeiger

garcoll  = $b526

; Vorbelegung der Speicherpl�tze

romsize  = $2000	; ROM L�nge 8K

prozport = $01		; Prozessorport
memrom = %00110111	; Basic+Kernal ROM
membas = %00110110	; Basic RAM+kernal ROM
memram = %00110101	; Basic+Kernal RAM


; Datenstrukturen
;
; String am Heap:
;
;   +--------------------------------------+
;   |       +--------------+               |
;   V       |              V               |
;   +---+---+---+          +-----------+---+---+
;   |LEN|LO |HI |          |STRINGDATEN|LO |HI |
;   +---+---+---+          +-----------+---+---+
;   ^    *******           ^            *******
;   |       String.-Adr.   |               Descriptor-Adr.
;   +-Descriptor-Adresse   +-String-Adresse
;
; L�cken am Heap:
;                      
;   +-------------+   +--------------+
;   V             |   V              |
;    +-----------+---+---+---------+---+---+
;    |L�CKE 2    |LEN|$FF|L�CKE 1  |LEN|$FF|
;    +-----------+---+---+---------+---+---+
;                  ^  ***            ^  ***
;                  |   L�ckenmark.   |   L�ckenmarkierung
;                  Backlink-Adresse  Backlink-Adresse



!source "loader.asm"

;
; Patch-Liste f�r "loader"
;

patchlist:

!wo part1_real,part1_real_end-part1_real,part1
!wo part2_real,part2_real_end-part2_real,part2
!wo part3_real,part3_real_end-part3_real,part3
!wo part4_real,part4_real_end-part4_real,part4
!wo part5_real,part5_real_end-part5_real,part5
!wo 0  ; Endemarkierung


; ******************************* part 1 *************************************

part1_real:

!pseudopc $b4f4 {

part1:

;***** Speicher von String-Heap anfordern
;
;	in:	A		; L�nge anforderung
;		fretop
;	mod:	collected	; "GC aufgerufen"-Flag
;		strptr		; temp. Zeiger
;	out:	fretop		; Adresse auf String
;		X,Y		; Adresse auf String
;
; Der String wird im Backlink stets als ungebrauchte L�cke
; markiert! Dann muss die GC nur noch die Backlinks
; der aktiven Strings setzen und kann die ungebrauchten
; Strings �berspringen.


basicerror = $b4d2		; Basic-Fehlermeldung

allocate:
	lsr collected		; Flag l�schen
retry	pha			; L�nge der Anforderung,
				; f�r 2. Teil
				; L�nge 0 m�glich, verbraucht aber 2 Bytes
	eor #$ff		; negieren
	sec
	adc fretop		; A/X = fretop; A/X -= L�nge
	ldx fretop+1
	bcs l1
	dex
	sec
l1	sbc #2			; A/X -= 2 Platz f�r Backlink einrechnen
	bcs l2
	dex
l2	cpx strend+1		; String-Heap voll (Array-Bereichende)?
	bcc checkcollect
	bne alloc		; nein, Bereich anfordern
	cmp strend 
	bcs alloc		; nein, Bereich anfordern
checkcollect
	ldx #16			; Basic-Fehler 16: "OUT OF MEMORY"
	lda collected
	bmi basicerror		; Collection schon gelaufen?
	jsr docollect		; nein, dann Garbage Collection, C=1 (immer!)
	ror collected		; Flag setzen (Bit 7) setzen
	pla			; L�nge angeforderter Bereich
	jmp retry		; nochmal versuchen (ob durch GC Platz frei wurde)

alloc	jsr setfretop		; FRETOP = A/X
	jmp stralloc		; zum 2. Teil: Allokation abschlie�en


;***** garbage collection

;	in:	-
;	mod:	ptr		; Zeiger auf alten String-Heap
;		newptr		; Zeiger auf neuen String-Heap
;		descptr		; Zeiger auf Descriptor
;		desclen		; Descriptor-Schrittweite
;	out:	fretop		; Neue String-Heap-Position
;		C=1

docollect


; Backlink aller tempor�ren Strings am String-Descriptor-Stack setzen

sds:	lda #<sdsbase		; Startadr. String-Descriptor-Stack
	ldx #>sdsbase		; da in 0-Page, immer 0
	jsr setptr		; damit ptr setzen

sdsnext	cmp sdsptr		; am 1. freien SDS-Element? (nur Low-Byte!)
	beq vars		; Ja, SDS durch, weiter mit Variablen
	jsr backlink		; sonst Backlink setzen
	beq sdsnext		; immer, weil High-Byte 0; n�chsten SDS-Descriptor

; Backlink aller String-Variablen setzen

vars:	lda #5			; Descriptor-Schritt f�r Variablen
	sta desclen
	lda vartab		; Variablenbeginn
	ldx vartab+1
	jsr setptr		; ptr = A/X

varnext	cpx arytab+1		; Variablenende?
	bne varbl
	cmp arytab
	beq arrays		; ja, weiter mit Arrays
varbl	jsr backlinkvar		; Backlink f�r n�chste String-Variable setzen
	bne varnext		; immer; n�chsten Var.-Descriptor

; Backlink bei allen String-Arrays setzen

arrays:
	sta aryptr		; Variablenbereichende = Array-Bereichanfang
	stx aryptr+1 
	ldy #3			; Descriptor-Schritt bei String-Arrays
	sty desclen

arrnext	cpx strend+1		; Array-Bereichende?
	bne arrbl
	cmp strend
	beq cleanwalk
arrbl	jsr backlinkarr		; Backlinks f�r n�chstes String-Array setzen -> Z=0!
	bne arrnext		; immer; n�chstes Array-Element


; Ende, Zeiger zum neuen String-Heap �bernehmen

cfinish
	lda newptr		; Aufger�umtzeiger ist ..
	ldx newptr+1
setfretop
	sta fretop		; neues FRETOP
	stx fretop+1 
	rts			; fertig!

; Nachdem nun alle Backlinks gesetzt sind
; den String-Heap von oben nach unten durchgehen
; und zusammenschieben ...

cleanwalk:
	lda memsiz		; beim Basic-Speicherende
	ldx memsiz+1
	sta newptr		; ... beginnen
	stx newptr+1 

; Aufr�umschleife

cwnext	cpx fretop+1		; A/X: altes FRETOP erreicht,
	bne cwclean		; dann Heap durch und fertig.
	cmp fretop		; andernfalls aufr�umen ...
	beq cfinish		; fertig, weil A/X = FRETOP

; n�chsten String "aufr�umen" ...

cwclean	sec			; Aufger�umtzeiger auf Backlink
	sbc #2
	bcs cw1
	dex			; A/X -> Backlink

cw1	jsr setptr		; A/X -> ptr (Alt-String-Zeiger)

	ldy #0
	lda (ptr),y		; Backlink low oder L�ckenl�nge
	iny			; Y=1
	tax			; -> X
	lda (ptr),y		; Backlink high
	cmp #$ff		; "String-nicht gebraucht"-Markierung
	bcc cwactive		; aktiver String

	txa			; L�ckenl�nge
	eor #$ff		; negieren, C=1 (Komplement, +1)
	adc ptr			; (ptr - L�ckenl�nge)
	ldx ptr+1 
	bcs cwnext		; weiter mit n�chstem/r String/L�cke
	dex			; High Byte

cw2	bne cwnext		; immer (Heap ist nie in Page 1)
				; weiter mit n�chstem/r String/L�cke

; einen aktiven String nach oben schieben

cwactive			; immer mit Y=1 angesprungen
	sta descptr+1		; Descriptor-Adresse
	stx descptr 

	lda newptr		; Aufger�umtzeiger -= 2
	sbc #1			; weil bereits C=0!
	sta newptr		; newptr -= 2
	bcs cw3
	dec newptr+1
	sec			; f�r SBC unten

cw3	lda #$ff		; Backlink h: als L�cke markieren
	sta (newptr),y		; Y=1
	dey			; Y=0
!ifdef no_opt_3 {
	lda (descptr),y		; Descriptor: String-L�nge
	sta (newptr),y		; Backlink l: L�ckenl�nge
} else {
				; Backlink l: L�ckenl�nge sp�ter beim
				; Kopieren ...
}
	lda newptr		; Aufger�umtzeiger -= String-L�nge
	sbc (descptr),y		; minus String-L�nge, immer C=1, Y=0
	sta newptr
	bcs cw4
	dec newptr+1
	sec			; f�r SBC unten

cw4	lda ptr			; Alt-String-Zeiger -= String-L�nge
	sbc (descptr),y		; immer C=1
	sta ptr			; Arbeitszeiger = alte String-Adresse
	bcs cw5
	dec ptr+1
cw5
	; An dieser Stelle w�re eine Optimierung m�glich, um das
	; Kopieren zu verhindern, wenn der String an der gleichen
	; Stelle bleibt - dabei darf die Optimierung #3 nicht
	; in Verwendung sein und es w�rden zus�tzlich 10 Bytes gebraucht!
!ifdef opt_no_copy {
	cmp newptr		; ptr bereits in A
	bne cw6			; ptr != newptr, also kopieren
	lda ptr+1		; High Byte ...
	cmp newptr+1
	beq cwheapordered	; ptr = newptr, nicht kopieren
cw6
}

	lda (descptr),y		; String-L�nge
!ifndef use_fast_copy {

				; immer, da L�nge >0
!ifdef no_opt_3 {
	beq cwnocopy		; falls doch L�nge 0, kein Kopieren,
				; Descriptor trotzdem anpassen ...
	tay			; als Index, mit Dekrementieren beginnen
} else { ; mit Optimierung #3
	tay			; L�nge als Index
	bne cwbllen		; immer, zuerst Backlink-Low-Markierung
				; mit L�ckenl�nge belegen
}
cwloop	dey			; -> Startindex f�rs Kopieren
	lda (ptr),y		; Arbeitszeiger mit altem String
cwbllen sta (newptr),y		; Aufger�umtzeiger mit neuem String-Ort
	tya			; Test auf Z-Flag!
	bne cwloop		; Index = 0 -> fertig kopiert

} else { ; use_fast_copy!

				; + 3 Byte, -2 T/Zeichen 
	tay			; L�nge als Index
!ifdef no_opt_3 {
	bne cwentry		; immer, da L�nge in Y>0, bei
				; Dekrementieren beginnen!
} else { ; mit Optimierung #3
	bne cwbllen		; immer, zuerst Backlink-Low-Markierung
				; mit L�ckenl�nge belegen
}
				; -> Startindex f�rs Kopieren
cwloop	lda (ptr),y		; Arbeitszeiger mit altem String
cwbllen	sta (newptr),y		; Aufger�umtzeiger mit neuem String-Ort
cwentry	dey			; Test auf Z-Flag!
	bne cwloop		; Index = 0 -> fertig kopiert
cwone	lda (ptr),y		; Arbeitszeiger mit altem String
	sta (newptr),y		; Aufger�umtzeiger mit neuem String-Ort
}

cwnocopy:
				; Y=0
	iny			; Y=1
	lda newptr		; im Descriptor:
	sta (descptr),y		; String-Adresse L: neue Adresse
	iny			; Y=2
	lda newptr+1
	sta (descptr),y		; String-Adresse H: neue Adresse

cwheapordered:
	lda ptr
	ldx ptr+1		; High-Byte immer !=0
	bne cwnext		; immer; weiter in Schleife


;**** Backlink setzen
;
; 	in:		ptr	Descriptor-Adresse
; 	out:		ptr	Descriptor-Adresse
;			A/X
;			Z=0	wenn nicht am SDS
;			Z=1	wenn am SDS
;	destroy:	newptr
;	called:		blaset, backlinkvar

backlink:
	ldy #0
	lda (ptr),y		; String-L�nge
	beq blnext		; fertig, wenn =0
	iny
	clc
	adc (ptr),y		; Backlink-Position (am String-Ende)
	sta newptr		; Backlink-Zeiger L
	tax
	iny
	lda (ptr),y
	adc #0
	sta newptr+1		; Backlink-Zeiger H
	cmp strend+1		; < Array-Bereichende (au�erhalb Heap)?
	bcc blnext		; ja, denn n�chsten String
	bne blsetdesc
	cpx strend 
	bcc blnext		; < Array-Bereichende (au�erhalb Heap)?

blsetdesc:
	ldy #1
	lda ptr+1
	sta (newptr),y		; Descriptor-Adresse ...
	dey
	lda ptr
	sta (newptr),y		; in den Backlink �bertragen

blnext	lda desclen		; n�chster String/n�chste Variable
	clc			; Schrittweite zum n�chsten Descriptor
	adc ptr			; ptr += desclen
	sta ptr
	bcc +
	inc ptr+1
+	ldx ptr+1		; immer != 0 -> Z=0 (au�er bei SDS, Z=1)
	rts

;**** N�chste String-Variable und Backlink setzen
;
; 	in:		ptr	Variablenadresse
; 	out:		ptr	Variablenadresse
;			A/X
;			Z=0
;	destroy:	newptr
;	called:		varbl (vars)

backlinkvar:
	ldy #0			;							
	lda (ptr),y		; Variablenname 1. Zeichen
	tax			; Typstatus merken
	iny
	lda (ptr),y		; Variablenname 2. Zeichen
	tay			; Typstatus merken

	lda #2			; Descriptor-Adresse (in Variable)
	clc
	adc ptr			; ptr += 2
	sta ptr
	bcc +
	inc ptr+1
+
	txa			; Variablentyp pr�fen
	bmi blnext		; keine String, n�chste Variable
	tya
	bmi backlink		; Backlink setzen
	bpl blnext		; keine String-Var., n�chste Variable

}
part1_real_end

; Codebereich 1: darf den zur Verf�gung stehenden Bereich nicht �berschreiten!

!set part1_end = (part1_real_end-part1_real)+part1
!if ( part1_end > $B63D ) {
	!error "Code-Teil 1 ist zu lang! ",part1,"-",part1_end
}


; ******************************* part 4 *************************************

part2_real
!pseudopc $b6c1 {

part2:

part2_continue = $b6d6
	jmp part2_continue

;**** N�chste Array-Variable und Backlink setzen
;
; 	in: 		ptr	Arrayadresse
; 	out:		ptr	Adresse Folge-array
;			aryptr	Adresse Folge-array
;			A/X	Adresse Folge-array
;			Z=0
;	destroy:	newptr
;	called:		arrbl (arrays)

backlinkarr:
	ldy #0
	lda (ptr),y		; Variablenname 1. Zeichen
	php			; f�r sp�ter
	iny
	lda (ptr),y		; Variablenname 2. Zeichen
	tax			; f�r sp�ter

	iny
	lda (ptr),y		; Offset n�chstes Array
	clc			; Bugfix 1: C=0 definiert setzen
	adc aryptr
	jmp part3
				; weiter an anderer Stelle!
blapast
!if blapast > part2_continue {
	!error "part2 ist zu lang!"
}
}
part2_real_end


; ******************************* part 3 *************************************

part3_real
!pseudopc $bf53 {

part3:
	sta aryptr		; Folge-Array L
	iny
	lda (ptr),y
	adc aryptr+1 
	sta aryptr+1		; Folge-Array H

	plp			; Arraytyp:
	bmi +		; kein String-Array
	txa
	bpl +		; kein String-Array

	iny			; Y=4
	lda (ptr),y		; Anzahl der Dimensionen (< 126 !)
	asl 			; *2
	adc #5			; + 5 (Var.Name+Offset+Dimensionen)
	jmp backlinkarr2

+	jmp blaskip_cont 
}
part3_real_end



part4_real
!pseudopc $e460 { ; +7 bytes wegen part4pre

part4:

 	; Einschaltmeldung k�rzen; analog zu 2. Einschalttext
	; " bytes free"\n\0"
	!byte  $20, $42, $59, $54, $45, $53, $20
	!byte  $46, $52, $45, $45, $0d, $00
	; 6 Bytes frei f�r anderen Patch
	!byte  $aa, $aa, $aa, $aa, $aa, $aa

	; "� commodore 64 basic v2 \0"
	!byte  $93, $20, $43, $4f, $4d, $4d, $4f, $44
	!byte  $4f, $52, $45, $20, $36, $34, $20, $42
	!byte  $41, $53, $49, $43, $20, $56, $32, $20
	!byte  $00

backlinkarr2:		; $e48c
	adc ptr			; auf 1. Element ...
	sta ptr 
	bcc +
	inc ptr+1 
+	ldx ptr+1		; positionieren

blanext	cpx aryptr+1		; Array-Ende erreicht?
	bne blaset		; nein, Backlink setzen
	cmp aryptr
	beq blafinish		; Array fertig, Bugfix 2: Z-Flag l�schen!
blaset
	jsr backlink		; Backlink setzen
	bne blanext		; immer (High-Byte != 0)

blaskip_cont
	lda aryptr		; Zeiger auf Folge-Array
blafinish
	ldx aryptr+1 		; Z=0 sicherstellen

setptr	sta ptr			; Arbeitszeiger setzen
	stx ptr+1
	rts			; immer Z=0
}
part4_real_end


; ******************************* part 2 *************************************

part5_real
!pseudopc $e4ba {

part5:

;**** String Allocation (Fortsetzung)
;
;	in: 	TOS		; L�nge
;		fretop		; String-Adresse
;	out:	fretop		; String-Adresse
;		strptr		; String-Adresse (wird nicht verwendet)
;				; (bei alternate_stralloc eventuell mit
;				; inkrementiertem High-Byte)
;		A		; L�nge
;		X,Y		; String-Adresse (L,H)
;	called:	allocate (in Fortsetzung)

  !ifndef alternate_stralloc {
stralloc:
	sta strptr		; strptr = A/X = FRETOP
	stx strptr+1
	tax			; A in X aufheben
	pla			; L�nge temp. vom Stack 
	pha			; wieder auf Stack, nun auch in A
	tay			; Index=L�nge (Backlink-position)
	sta (fretop),y		; Backlink L = String-/L�ckenl�nge
	iny			; Y=L�nge+1
	bne sa1			; wenn L�nge=255, dann
	inc fretop+1		; �berlauf, aber nur tempor�r!

sa1	lda #$ff		; Backlink H = Markierung "L�cke"
	sta (fretop),y
	ldy strptr+1
	sty fretop+1		; �berlaufkorr. r�ckg�ngig
	pla			; L�nge vom Stack nehmen
	rts

  } else {
; alternative, etwas k�rzere Variante (-3 T, -2 B)

stralloc:
	sta strptr		; strptr = A/X = FRETOP
	stx strptr+1
	tax			; A in X aufheben
	pla			; L�nge temp. vom Stack 
	pha			; wieder auf Stack, nun auch in A
	tay			; Index=L�nge (Backlink-position)
	sta (strptr),y		; Backlink L = String-/L�ckenl�nge
	iny			; Y=L�nge+1
	bne sa1			; wenn L�nge=255, dann
	inc strptr+1		; �berlauf, aber nur tempor�r!

sa1	lda #$ff		; Backlink H = Markierung "L�cke"
	sta (strptr),y
	ldy fretop+1		; in Y String-Adresse High-Byte
	pla			; L�nge vom Stack nehmen
	rts
				; Hier weicht strptr+1 u.U. von fretop+1 ab,
				; was aber kein Problem darstellt, da
				; es im BASIC-Interpreter keine Stellt gibt,
				; die nach einem allocate-Aufruf den
				; Pointer strptr/strptr+1 verwendet!
  }
}

part5_real_end


; Einsprungspunkt an korrekter Position?

; Kann erst nach dem Label docollect gemacht werden!

!if (garcoll != docollect) {
	!error "Einstiegspunkt nicht an richtiger Stelle! ",garcoll,"!=",docollect
}
