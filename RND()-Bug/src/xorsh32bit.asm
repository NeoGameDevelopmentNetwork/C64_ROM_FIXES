!to "xorsh32bit.o",cbm	
;
;  **** Func RND ****

; Main Floating point Accumulator
v2	 = $61	; FAC Mantissa
v2e		= v2
v2d		= v2+1
v2c		= v2+2
v2b		= v2+3
v2a		= v2+4

; Floating RND Function Seed
v1	= $8B	; rndseedvalue
v1e		= v1
v1d		= v1+1
v1c		= v1+2
v1b		= v1+3
v1a		= v1+4


!source "loader.asm"

;
; Patch-Liste für "loader"
;

patchlist:

!wo part1_real,part1_real_end-part1_real,part1
!wo part2_real,part2_real_end-part2_real,part2
!wo 0  ; Endemarkierung



;====================
; (1.) v1 ^= v1 << 13
; (2.) v1 ^= v1 >> 17
; (3.) v1 ^= v1 << 5
;====================

part1_real:

!pseudopc $e097 {
part1: 
; (1.): [v1 ^= v1 << 13]
	ldx #$03	
-	lda v1d,x	; v2 = v1 << 8
	sta v2e,x
	dex
	bne -
	stx v2a
	jsr lsh; v2 = v2 << 5; v1 ^= v2		; (14b)
;-------------------------------------------------
; (2.): v1 ^= v1 >> 17
	stx v2d
	stx v2c
	lda v1d	
	lsr 	; 0 >> 1	v2 = v1 >> (1 + 16) [part 1]
	sta v2b	; 0 >> 16
	lda v1c
	ror		; c >> 1	v2 = v1 >> (1 + 16) [part 2]
	sta v2a	; c >> 16
	jsr dxo								; (17b)
;-----------------------------------------------------
; (3.): v1 ^= v2 << 5
;	ldx #$04		; Daten bereits kopiert in dxo !
;-	lda v1e,x ; v2 = v1
;	sta v2e,x
;	dex
;	bne -
	jsr lsh								; (12b)
;-----------------------------------------------
	jmp $e0e3 ;reply numer back to BASIC ; (6b)
;-----------------------------------------------
lsh	ldx #$05
-	asl v2a	; v2 = v2 << 5
	rol v2b
	rol v2c
	rol v2d
	dex
	bne -								; (13b)
;-----------------------------------------------
; xor v1 ^= v2	; eor for all 4 byte
dxo	ldx #$04
-	lda v1e,x	; read v1
	eor v2e,x	; v1 xor v2
	sta v1e,x 	; write v1
	sta v2e,x 	; write v2 
	dex
	bne -
	rts									; (14b)
;-----------------------------------------------		
}
part1_real_end

; Codebereich 1: darf den zur Verfügung stehenden Bereich nicht überschreiten!

!set part1_end = (part1_real_end-part1_real)+part1-1
!if ( part1_end > $e0e2 ) {
	!error "Code-Teil 1 ist zu lang! ",part1,"-",part1_end-1
}

part2_real:

!pseudopc $e3ba {
part2:
;***** copy result from v => v2 (alias basic fac1)
	!byte	$00, $00, $00, $00, $01
}
part2_real_end
