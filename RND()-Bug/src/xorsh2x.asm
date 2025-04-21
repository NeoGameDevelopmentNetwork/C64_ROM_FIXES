!to "xorsh2x.o",cbm	
;
;  **** Func RND ****

;!set opt_no_copy=1

!ifdef opt_no_copy {
!set no_opt_3=1
}


; Basic-Zeiger und -konstanten

; Hilfsvariablen

ptr	 	= $22		; Arbeitszeiger, alter Heap
xorsh1_l= $fb		; xor-shift 1 low variable
xorsh1_h= $fc		; xor-shift 1 high variable
xorsh2_l= $fd		; xor-shift 2 low variable
xorsh2_h= $fe		; xor-shift 2 high variable


; Vorbelegung der Speicherplätze

romsize  = $2000	; ROM Länge 8K

prozport = $01		; Prozessorport
memrom = %00110111	; Basic+Kernal ROM
membas = %00110110	; Basic RAM+kernal ROM
memram = %00110101	; Basic+Kernal RAM



!source "loader.asm"

;
; Patch-Liste für "loader"
;

patchlist:

!wo part1_real,part1_real_end-part1_real,part1
!wo 0  ; Endemarkierung


; ******************************* part 1 *************************************

part1_real:

!pseudopc $e097 {

part1:

;***** Neue RND Funktion
; 1st 16-bit xor-shift random generator
	lda xorsh1_l
	bne l1
	lda #01 ; seed, can be anything except 0
	sta xorsh1_l
l1	lda xorsh1_h
	lsr
	lda xorsh1_l
	ror
	eor xorsh1_h
	sta xorsh1_h ; high part of x ^= x << 7 done
	ror             ; a has now x >> 9 and high bit comes from low byte
	eor xorsh1_l
	sta xorsh1_l  ; x ^= x >> 9 and the low part of x ^= x << 7 done
	eor xorsh1_h 
	sta xorsh1_h ; x ^= x << 8 done
	
; 2nd 16-bit xor-shift random generator
	lda xorsh1_l
	bne l2
	lda #$ff ; seed, can be anything except 0
	sta xorsh2_l
l2	lda xorsh2_h
	ror
	lda xorsh1_l
	lsr
	eor xorsh2_h
	sta xorsh2_h ; high part of x ^= x >> 7 done
	lsr             ; a has now x << 9 and high bit comes from low byte
	eor xorsh2_l
	sta xorsh2_l  ; x ^= x << 9 and the low part of x ^= x >> 7 done
	eor xorsh2_h 
	sta xorsh2_h ; x ^= x >> 8 done

; copy resultats
	ldx #$04
l3	lda $fa,x
	sta $61,x
	dex 
	bne l3

	jmp $e0e3
}
part1_real_end

; Codebereich 1: darf den zur Verfügung stehenden Bereich nicht überschreiten!

!set part1_end = (part1_real_end-part1_real)+part1
!if ( part1_end > $e0e2 ) {
	!error "Code-Teil 1 ist zu lang! ",part1,"-",part1_end
}

