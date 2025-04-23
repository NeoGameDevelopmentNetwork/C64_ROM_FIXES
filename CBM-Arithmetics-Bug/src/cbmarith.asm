!to "cbmarith.o",cbm	
;
;  **** Func RND ****

;!set opt_no_copy=1

!ifdef opt_no_copy {
!set no_opt_3=1
}


; Basic-Zeiger und -konstanten

; Hilfsvariablen

ptr	 	= $22		; Arbeitszeiger, alter Heap
fl_akku2= $70		; Fließkomma-Akku #2: Runden
fl_res_1= $26		; Fließkommaergebnis 1
fl_res_2= $27		; Fließkommaergebnis 2
fl_res_3= $28		; Fließkommaergebnis 3
fl_res_4= $29		; Fließkommaergebnis 4


!source "loader.asm"

;
; Patch-Liste für "loader"
;

patchlist:

!wo part1_real,part1_real_end-part1_real,part1
!wo part2_real,part2_real_end-part2_real,part2
!wo 0  ; Endemarkierung


; ******************************* part 2 *************************************

part1_real:

!pseudopc $bf53 {

part1:

;***** Neue Pre-Shift Funktion
	lda fl_res_4
	sta fl_akku2
	ldx #$03
l1	lda fl_res_1-1,x
	sta fl_res_1,x
	dex
	bne l1
	ldy #$01
	tya
	lsr
	sta fl_res_1
	rts
}
part1_real_end

; Codebereich 2: darf den zur Verfügung stehenden Bereich nicht überschreiten!

!set part1_end = (part1_real_end-part1_real)+part1
!if ( part1_end > $bf67 ) {
	!error "Code-Teil 1 ist zu lang! ",part1,"-",part1_end
}

; ******************************* part 1 *************************************

part2_real:

!pseudopc $ba5b {

part2:
	jmp part1
;***** Sprung auf neue Pre-Shift Funktion

}
part2_real_end

; Codebereich 1: darf den zur Verfügung stehenden Bereich nicht überschreiten!

!set part2_end = (part2_real_end-part2_real)+part2
!if ( part2_end > $ba5e ) {
	!error "Code-Teil 2 ist zu lang! ",part2,"-",part2_end
}


