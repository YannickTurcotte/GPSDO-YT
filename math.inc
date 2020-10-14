;********************************************************************************************************
;********************************************************************************************************
;********************************************************************************************************
;********************************************************************************************************
;*******************************************     Math    ************************************************
;********************************************************************************************************
;********************************************************************************************************
;********************************************************************************************************
;********************************************************************************************************
;Math

mul16: ;Hardware
;r21:r20 x r23:r22 = r5:r4:r3:r2
		clr R24 ; clear for carry operations
		mul r21,r23 ; Multiply MSBs
		mov r4,R0 ; copy to MSW Result
		mov r5,R1
		mul r20,r22 ; Multiply LSBs
		mov r2,R0 ; copy to LSW Result
		mov r3,R1
		mul r21,r22 ; Multiply 1M with 2L
		add r3,R0 ; Add to Result
		adc r4,R1
		adc r5,r24 ; add carry
		mul r20,r23 ; Multiply 1L with 2M
		add r3,R0 ; Add to Result
		adc r4,R1
		adc r5,r24
		ret



;***************************************************************************
;* r23:r22:r21:r20  +  r19:r18:r17:r16  =  r23:r22:r21:r20
Add32:	add	r20,r16	; Addition des octets de poids faible
		adc	r21,r17	;
		adc	r22,r18	;
		adc	r23,r19	; Addition des octets de poids fort avec retenue
		ret

;***************************************************************************
;*
;* mul32 - multiplication 32x32 
;*
;* r23::r20  x  r19::r16    =  r27::r20
;*   
;* r23:r22:r21:r20 x  r19:r18:r17:r16   =  r27:r26:r25:r24:r23:r22:r21:r20
;*
;* Nombre de mots		:25
;* Nombre de  cycles	:464-560
;* Registre Bas utilisés	:Aucun
;* Registre Haut utilisés   :13
;***************************************************************************
Mul32b: 	clr	r17		;multiplicand is one byte
Mul32w: 	clr	r18		;		 two bytes
Mul32t: 	clr	r19		;		 three bytes
Mul32:		clr	r27		;clear 4 highest bytes of result
			clr	r26		;
			clr	r25		;
			sub	r24,r24	;and carry
			ldi	r28,33	;init loop counter
m32u_loop:	ror	r23		;rotate result and multiplier
			ror	r22		;
			ror	r21		;
			ror	r20		;
			dec	r28 	;decrement loop counter
			breq	Return32u	;if counter zero return
			brcc	m32u_skip	;if bit 0 of multiplier set
			add	r24,r16	;   add multiplicand to result
			adc	r25,r17	;
			adc	r26,r18	;
			adc	r27,r19	;
m32u_skip:	ror	r27		;shift right result byte 7
			ror	r26		;rotate right result
			ror	r25		;
			ror	r24		;
			rjmp	m32u_loop	;
Return32u:	ret


ClrAllRegister:
		clr r16
		clr r17
		clr r18
		clr r19
		clr r20
		clr r21
		clr r22
		clr r23
		clr r24
		clr r25
		clr r26
		clr r27
		clr r28
		clr r29
		clr r30
		clr r31
		ret

;*************************************************************************************
;*************************************************************************************
seconde_tempo:
		wdr
		ldi  R23, $42
LOOP0y:	ldi  R24, $D6
LOOP1y:	ldi  R25, $EB
LOOP2y:	dec  R25
		brne LOOP2y
		dec  R24
		brne LOOP1y
		dec  R23
		brne LOOP0y
		ldi  R23, $03
LOOP3y:	dec  R23
		brne LOOP3y
		nop
		ret

;*************************************************************************************
;*************************************************************************************
;***************       Wait fonctionne avec seconde tempo          *******************
;*************************************************************************************
wait:
		clr yh
		clr yl
wait2:		;boucle ici le nombre de temps qui est dans x en seconde
		rcall seconde_tempo	;attends 1 seconde
		rcall affichesatellite	;regarde si ya de quoi recu par le serial. sinon il revient ici aussitot et fait rien.
		wdr
		lds temp, wait_flag		;regarde si waitflag a été mis a 0 par int1 (push button)
		cpi temp, $00
		breq fini
		adiw yh:yl, $01	;incremente le compteur
		cp yl, xl		;attend le nombre de seconde qui se retrouve dans xh:xl
		cpc yh, xh
		brlo wait2		;compare x avec y. Branche si x est plus bas
fini:
		ret

;********************************** Clear All Merory ********************************
ClearAllMemory:
		ldi zh,$1		;load $100 dans z
		ldi zl,00
MemoryClearNext:
		clr temp
		st z+,temp
		ldi r16, $00	;nombre de byte + 1 (clear all memory of atmega 48. (512 bytes)
		ldi r17, $03
		cp zl, r16
		cpc zh, r17
		brne MemoryClearNext
		ret

hex2bcdyt:
;********************************* input Hex r20:r19:r18:r17:r16 outupt bcd r25:r24:r23:r22:r21 
		clr yh
		clr yl
		clr r21
		clr r22
		clr r23
		clr r24
		clr r25
		clr r26
		ldi yl,$28	;nombre de fois a shifter
again:
		rcall checkif
		lsl r16		;on shift tout a gauche.
		rol r17
		rol r18
		rol r19
		rol r20		
		rol r21
		rol r22
		rol r23
		rol r24
		rol r25		;ici tout a ete shifter une fois. regandons les 4bits qui depasse ou egale a 5.
		rol r26
		dec yl
		brne again
		ret				;done answer in r25:r21

checkif:
		push r21		;r21 est conserver on regarde si plus que 5 par 4 bit
		andi r21,$0f	;on garde les lsb
		cpi r21,$05
		brlo rienafaire
		subi r21,-0x03	;plus que 5 on ajoute 3
		mov yh, r21		;on garde les 4 lsb dans yh
rienafaire:
		mov yh, r21		;on garde les 4 lsb dans yh
		pop r21			; rappel r21	
		andi r21,$f0	;on garde les msb
		cpi r21, $50	;compare avec 50 pour voir si les 4 msb depasse 5
		brlo rienafaire2
		subi r21,-0x30	;ajoute 3 au msb
rienafaire2:
		add r21, yh

		push r22		;r21 est conserver on regarde si plus que 5 par 4 bit
		andi r22,$0f	;on garde les lsb
		cpi r22,$05
		brlo rienafaire3
		subi r22,-0x03	;plus que 5 on ajoute 3
		mov yh, r22		;on garde les 4 lsb dans yh
rienafaire3:
		mov yh, r22		;on garde les 4 lsb dans yh
		pop r22			; rappel r21	
		andi r22,$f0	;on garde les msb
		cpi r22, $50	;compare avec 50 pour voir si les 4 msb depasse 5
		brlo rienafaire4
		subi r22,-0x30	;ajoute 3 au msb
rienafaire4:
		add r22, yh

		push r23		;r21 est conserver on regarde si plus que 5 par 4 bit
		andi r23,$0f	;on garde les lsb
		cpi r23,$05
		brlo rienafaire5
		subi r23,-0x03	;plus que 5 on ajoute 3
		mov yh, r23		;on garde les 4 lsb dans yh
rienafaire5:
		mov yh, r23		;on garde les 4 lsb dans yh
		pop r23			; rappel r21	
		andi r23,$f0	;on garde les msb
		cpi r23, $50	;compare avec 50 pour voir si les 4 msb depasse 5
		brlo rienafaire6
		subi r23,-0x30	;ajoute 3 au msb
rienafaire6:
		add r23, yh

		push r24		;r21 est conserver on regarde si plus que 5 par 4 bit
		andi r24,$0f	;on garde les lsb
		cpi r24,$05
		brlo rienafaire7
		subi r24,-0x03	;plus que 5 on ajoute 3
		mov yh, r24		;on garde les 4 lsb dans yh
rienafaire7:
		mov yh, r24		;on garde les 4 lsb dans yh
		pop r24			; rappel r21	
		andi r24,$f0	;on garde les msb
		cpi r24, $50	;compare avec 50 pour voir si les 4 msb depasse 5
		brlo rienafaire8
		subi r24,-0x30	;ajoute 3 au msb
rienafaire8:
		add r24, yh
	
		push r25		;r21 est conserver on regarde si plus que 5 par 4 bit
		andi r25,$0f	;on garde les lsb
		cpi r25,$05
		brlo rienafaire9
		subi r25,-0x03	;plus que 5 on ajoute 3
		mov yh, r25		;on garde les 4 lsb dans yh
rienafaire9:
		mov yh, r25		;on garde les 4 lsb dans yh
		pop r25			; rappel r21	
		andi r25,$f0	;on garde les msb
		cpi r25, $50	;compare avec 50 pour voir si les 4 msb depasse 5
		brlo rienafaire10
		subi r25,-0x30	;ajoute 3 au msb
rienafaire10:
		add r25, yh
		
		push r26		;r21 est conserver on regarde si plus que 5 par 4 bit
		andi r26,$0f	;on garde les lsb
		cpi r26,$05
		brlo rienafaire11
		subi r26,-0x03	;plus que 5 on ajoute 3
		mov yh, r26		;on garde les 4 lsb dans yh
rienafaire11:
		mov yh, r26		;on garde les 4 lsb dans yh
		pop r26			; rappel r21	
		andi r26,$f0	;on garde les msb
		cpi r26, $50	;compare avec 50 pour voir si les 4 msb depasse 5
		brlo rienafaire12
		subi r26,-0x30	;ajoute 3 au msb
rienafaire12:
		add r26, yh
		ret
	
	
;***************************************************************************
;*
;* Div32  - Division 32/32 
;*
;* r23::r20 	/ 	r19::r16 = (r23::r20) (r27::r24)
;*    dividende		/	   diviseur 	       résultat 	 :    	 reste
;*  r23r22r21r20         r19r18r17r16    	 r23r22r21r20	      r27r26r25r24
;*
;* Nombre de mots		:33
;* Nombre de  cycles	:158/198
;* Registre Bas utilisés	:0 
;* Registre Haut utilisés  	:8 
;*
;***************************************************************************

Div32b: clr	r17		;divisor is one byte
Div32w: clr	r18		;	    two bytes
Div32t: clr	r19		;	    three bytes
Div32:	clr	r24	;clear 4 lower remainde byte
		clr	r25	;
		clr	r26	;
		sub	r27,r27;and carry
		ldi	r28,33	;init loop counter
d32u_loop: rol	r20		;shift left dividend
		rol	r21		;
		rol	r22		;
		rol	r23		;
		dec	r28 	;decrement loop counter
		breq Com32		;if counter zero invert result
		rol	r24	;shift dividend into remainder
		rol	r25	;
		rol	r26	;
		rol	r27	;
		sub	r24,r16 ;remainder = remainder - divisor
		sbc	r25,r17 ;
		sbc	r26,r18 ;
		sbc	r27,r19 ;
		brcc d32u_loop	;clear carry to be shifted into res
		add	r24,r16 ;if result negative
		adc	r25,r17 ;   restore remainder
		adc	r26,r18 ;
		adc	r27,r19 ;
		rjmp d32u_loop	;   set carry to be shifted into res
Com32:	com	r20		;	&
		com	r21		;   (com result)
		com	r22		;
		com	r23		;   return set carry after com
		ret
