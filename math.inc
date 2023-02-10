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

;*************************************************************************************************************************************
;*************************************************************************************************************************************
;*************************************************************************************************************************************
compare: ;compare la frequence optenu avec la réréfence et signe si c'est negatif ou positif. sign = 1 pour positif. 0 = negatif
	;on charge la frequence en hex commancant par le msb
	lds r16, frequence_5	;msb 02
	lds r17, frequence_4	;54
	lds r18, frequence_3	;0b
	lds r19, frequence_2	;e4
	lds r20, frequence_1	;lsb 00

;ldi r21,7
;sts calibrationphase,r21

;ldi r16,$2
;sts frequence_5,r16
;ldi r17,$54
;sts frequence_4,r17
;ldi r18,$0b
;sts frequence_3,r18
;ldi r19,$E3
;sts frequence_2,r19
;ldi r20,$a6
;sts frequence_1,r20

	lds r21,calibrationphase	;sense on est rendu ou
	cpi r21, 1
	breq comparephase1
	cpi r21, 2
	breq comparephase2
	cpi r21, 3
	breq comparephase3
	cpi r21, 4
	breq comparephase4
	;forcement 5 ou 6 donc 1billion
	rcall F1000secondes		;charge le bon nombre a comparer. 10 million, 60 200 ou 1 milliar
	rjmp compareensemble
comparephase1:	;10,000,000
	rcall F1seconde
	rjmp compareensemble
comparephase2:	;100,000,000
	rcall F10secondes
	rjmp compareensemble
comparephase3:	;600,000,000
	rcall F60secondes
	rjmp compareensemble
comparephase4:	;2,000,000,000
	rcall F200secondes
	rjmp compareensemble

compareensemble:
	cp r16,r21 ;compare r16 avec r21
    breq equal ; if equal, check next byte
    ; check if the variable is greater than the number
    brcc greater
    ; if the carry flag is clear, the variable is less than the number
    rjmp plusbas

equal:
    ; Compare the next most significant byte
    cpc r17, r22
    breq equal2 ; if equal, check next byte
    brcc greater
    rjmp plusbas
    
equal2:
    ; Compare the next byte
    cpc r18, r23
    breq equal3 ; if equal, check next byte
    brcc greater
    rjmp plusbas
    
equal3:
    ; Compare the next byte
    cpc r19, r24
    breq equal4 ; if equal, check next byte
    brcc greater
    rjmp plusbas
    
equal4:
    ; Compare the next byte
    cpc r20, r25
    breq equal5 ; if equal, check next byte
    brcc greater
    rjmp plusbas
    
equal5: ;egale ou plus grand
greater:
	call subtraction40bitsPositif	;trouve et save la difference
    ldi temp,0x01					;signed
	sts sign, temp
	ret
plusbas:
	call subtraction40bitsNegatif	;trouve et save la difference
	clr temp						;signed
	sts sign, temp
	ret
;****************************************************************************************************************
subtraction40bitsPositif:
;frequence, resultat dans R16-R20. Frequence est superieur a la référence.
	;on charge la frequence en hex commancant par le msb
	lds r16, frequence_5
	lds r17, frequence_4
	lds r18, frequence_3
	lds r19, frequence_2
	lds r20, frequence_1

	; on recharge la frequence de comparaison
	lds r21,calibrationphase	;sense on est rendu ou
	cpi r21, 1
	breq load1
	cpi r21, 2
	breq load2
	cpi r21, 3
	breq load3
	cpi r21, 4
	breq load4
	;forcement 5 ou 6 donc 1billion
	rcall F1000secondes
	rjmp Onsoustrait1
load1:	;10,000,000
	rcall F1seconde
	rjmp Onsoustrait1
load2:	;100,000,000
	rcall F10secondes
	rjmp Onsoustrait1
load3:	;600,000,000
	rcall F60secondes
	rjmp Onsoustrait1
load4:	;2,000,000,000
	rcall F200secondes
	rjmp Onsoustrait1
Onsoustrait1:
; Subtract the most significant byte
    sub r16,r21
    sbc r17,r22
    sbc r18,r23
    sbc r19,r24
    sbc r20,r25
	sts difference_1, r20	;lsb
	sts difference_2, r19
	sts difference_3, r18
	sts difference_4, r17
	sts difference_5, r16	;msb
	ret

;****************************************************************************************************************
subtraction40bitsNegatif:
;frequence, resultat dans R16-R20. 
	;on charge la frequence en hex commancant par le msb
	lds r16, frequence_5
	lds r17, frequence_4
	lds r18, frequence_3
	lds r19, frequence_2
	lds r20, frequence_1
	; on recharge la frequence de comparaison
	lds r21,calibrationphase	;sense on est rendu ou
	cpi r21, 1
	breq load1a
	cpi r21, 2
	breq load2a
	cpi r21, 3
	breq load3a
	cpi r21, 4
	breq load4a
	;forcement 5 ou 6 donc 1billion
	rcall F1000secondes
	rjmp Onsoustrait1a
load1a:	;10,000,000
	rcall F1seconde
	rjmp Onsoustrait1a
load2a:	;100,000,000
	rcall F10secondes
	rjmp Onsoustrait1a
load3a:	;600,000,000
	rcall F60secondes
	rjmp Onsoustrait1a
load4a:	;2,000,000,000
	rcall F200secondes
	rjmp Onsoustrait1a
Onsoustrait1a:
; Subtract lsb first
    sub r25,r20
	sbc r24,r19
	sbc r23,r18
	sbc r22,r17
	sbc r21,r16
	sts difference_1, r25	;lsb
	sts difference_2, r24
	sts difference_3, r23
	sts difference_4, r22
	sts difference_5, r21	;msb
	ret
;**************************** constante
F1seconde:
	ldi r21, 0x00	;msb
	ldi r22, 0x00
	ldi r23, 0x98
	ldi r24, 0x96
	ldi r25, 0x80	;lsb
	ret
F10secondes: ;100,000,000
	ldi r21, 0x00	;msb
	ldi r22, 0x05
	ldi r23, 0xf5
	ldi r24, 0xe1
	ldi r25, 0x00	;lsb
	ret
F60secondes: ;600,000,000
	ldi r21, 0x00	;msb
	ldi r22, 0x23
	ldi r23, 0xc3
	ldi r24, 0x46
	ldi r25, 0x00	;lsb
	ret
F200secondes: ;200 secondes
	ldi r21, 0x00	;msb
	ldi r22, 0x77
	ldi r23, 0x35
	ldi r24, 0x94
	ldi r25, 0x00	;lsb
	ret
F1000secondes:
	ldi r21, 0x02	;msb
	ldi r22, 0x54
	ldi r23, 0x0B
	ldi r24, 0xE4
	ldi r25, 0x00	;lsb
	ret

;*************************************************************************************************************************************
;*************************************************************************************************************************************
compare2: ;charge la difference optenu et compare avec 0x32 (50) si plus haut, toolargeflag is set.
	lds r16, difference_5 ;msb
	lds r17, difference_4
	lds r18, difference_3
	lds r19, difference_2
	lds r20, difference_1 ;lsb

	ldi r21, 0x00	;msb
	ldi r22, 0x00
	ldi r23, 0x00
	ldi r24, 0x00
	ldi r25, 0x32	;lsb	compare avec 0x32 (50)

	cp r16,r21
    breq equal1 ; if equal, check next byte
    ; check if the variable is greater than the number
    brcc greater1
    ; if the carry flag is clear, the variable is less than the number
    rjmp plusbas1

equal1:
    ; Compare the next most significant byte
    cpc r17, r22
    breq equal21 ; if equal, check next byte
    brcc greater1
    rjmp plusbas1
    
equal21:
    ; Compare the next byte
    cpc r18, r23
    breq equal31 ; if equal, check next byte
    brcc greater1
    rjmp plusbas1
    
equal31:
    ; Compare the next byte
    cpc r19, r24
    breq equal41 ; if equal, check next byte
    brcc greater1
    rjmp plusbas1
    
equal41:
    ; Compare the next byte
    cpc r20, r25
    breq equal51 ; if equal, check next byte
    brcc greater1
    rjmp plusbas1
    
equal51: ;egale ou plus grand
greater1:
    ldi temp,0x01					;signed
	sts toolargeflag, temp
	ret
plusbas1:
	clr temp						;signed
	sts toolargeflag, temp
	ret