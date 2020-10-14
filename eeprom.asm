 
;xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx ECR01 xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
; sous programme d'écriture dans l'eeprom à l'adresse $00
;ecris ce qui se retrouve dans pwmphase6h, 6l
eepromw:
ecr01:	
		sbic EECR,EEPE			; vérifie si EEWE=0 
		rjmp ecr01
		clr temp2				;met l'adresse 00 dans EEarl
		out EEARL, temp2		;va commencer a écrire a l'adresse 0 dans le eeprom
		out EEARH, temp2
		ldi	ZH,high(pwmphase6h)	;met l'adresse que pointe pwm6h dans z
		ldi	ZL,low(pwmphase6h)	;init Z-pointer
ram2eeprom:
		ld	temp, Z+			;load la valeur contenu dans la memoire que pointe Z soit pwmphase6h et incrémente si pour plusieur bytes.
		out EEDR, TEMP
		ldi temp, $04
		out eecr, temp
		sbi EECR, EEMPE
		sbi EECR, EEPE
ecr02:
		sbic EECR, EEPE			;vérifie si EEWE=0 (écriture éffectuée)
		rjmp ecr02
		inc temp2
		out EEARL, temp2		;je ne m'occupe pas de eearh ici car on ne depasse pas ff
		cpi temp2, $02			;ici mettre la valeur du nombre de byte + 1
		brne ram2eeprom
		clr temp2
		ret

;ecris la frequence_1 a l'adresse de eeprompointer. Elle commence a 2
eepromwritebytes:
ecr01q:	
		sbic EECR,EEPE		; vérifie si EEWE=0 
		rjmp ecr01q
		clr temp2
		lds temp, eeprompointer	;charge l'adresse de eeprom qu'on est rendu on commence a 2 car 0 et 1 sont utilisé
		cpi temp, $ff			;regarde si on a attein la fin du eeprom
		brne onyva
		ldi temp,$02
		sts eeprompointer,temp
onyva:
		clr temp2
		out EEARH, temp2
		out EEARL, temp  ;va commencer a écrire a l'adresse eeprompointer. 2 par default
		ldi	ZH,high(frequence_1)	; met l'adresse que pointe frequence_1 dans z
		ldi	ZL,low(frequence_1)	;init Z-pointer
ram2eepromq:
		ld	temp,Z+	;load temp (r16) avec le contenu dans $134 et incrémente si pour plusieur bytes.
		out EEDR,TEMP
		ldi temp, $04
		out eecr, temp
		sbi EECR,EEMPE
		sbi EECR,EEPE
ecr02q:
		sbic EECR,EEPE		;vérifie si EEWE=0 (écriture éffectuée)
		rjmp ecr02q
		inc temp2
		out EEARL, temp2
		cpi temp2, $01	;ici mettre la valeur du nombre de byte + 1
		brne ram2eepromq
		lds temp, eeprompointer	
		inc temp
		sts eeprompointer, temp	;4 valeur a l'heure. j'en ai pour 62 heure avant de remplir le eeprom
		ret

;xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx eepromr: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;lit le eeprom de l'addrres 0 et 1 et l'écris dans pwmphase6h et pwmphase6l 
eepromr:
		sbic EECR,EEPE		; vérifie si EEWE=0 
		rjmp eepromr
		clr xl
		clr xh	
		out EEARL, xl  ;va commencer a lire à l'adresse 0 dans le eeprom
		out EEARH, xh
		ldi	ZH,high(pwmphase6h)	; met l'adresse ou mettre la valeur lu dans z	(12b)
		ldi	ZL,low(pwmphase6h)	;init Z-pointer
lir01:
		sbi EECR,EERE		; validation de lecture avec EERE=1
lir02:				; remise à 0 Watchdog
		sbic	EECR,EERE	; attendre que EERE=0
		rjmp	lir02	
		in	temp ,EEDR	; transfert de la donnée lu dans temp
		st	Z+, temp	;store la valeur de temp dans memoire pwmphase6h et incremente z+ ($12c) 
		adiw xh:xl, 1
		out EEARL, xl
		out EEARH, xh
		cpi xl, $02	;mettre ici le nombre de byte a lire
		brne lir01
		ret

; efface 256 bytes du eeprom
effaceeeprom:
		clr xh	;commence avec adresse 0
		clr xl
; Wait for completion of previous write
effaceencore:
		sbic EECR,EEPE
		rjmp effaceencore
; Set up address (xh:xl) in address register
		out EEARH, xh
		out EEARL, xl
; Write data (r16) to Data Register
		ser r16
		out EEDR,r16
; Write logical one to EEMPE
		sbi EECR,EEMPE
; Start eeprom write by setting EEPE
		sbi EECR,EEPE
		inc xl			;ici on efface seulement le 256 bytes du eeprom. Xl passe de 0 a FF et deborde a 100 donc xl vaut un moment donné 0. on a fait le tour.
		brne effaceencore
		ret

affiche_eeprom:
		;ici on affiche la valeur du pwm et les derniere frequence trouvé. Bref l'eeprom
		rcall videecran
		rcall posi1
		call nextline
		ldi r31,high(data39*2)  		;"config= "   
		ldi r30,low(data39*2)		
		rcall message
		rcall eepromr ;lit le eeprom de l'addrres 0 et 1 et l'écris dans pwmphase6h et pwmphase6l 
		lds temp, pwmphase6h
		rcall affichememoire		;affiche la valeur du eeprom trouvé
		call affichememoireserial
		lds temp, pwmphase6l
		rcall affichememoire
		call affichememoireserial
		rcall posi2
		call nextline
		ldi r31,high(data40*2)  		;"Last Frequency="   
		ldi r30,low(data40*2)		
		rcall message
		rcall tempo5s
;page 2 on ecris les dernieres frequences de la plus recente a la plus vieille
		rcall videecran
		rcall posi1
		call nextline
eepromr3:
		sbic EECR,EEPE		; vérifie si EEWE=0 
		rjmp eepromr3
		clr yl
		lds xl, eeprompointer	;on charge le pointeur pour savoir ou il faut lire dans le eeprom
		dec xl					;on doit soustraire un pour lire l'adresse pointé -1 car l.adresse pointé na pas été écris encore.
		clr xh
		cpi xl, $01	;
		breq Debut_du_eeprom_atteint ;ya pas encore de donné en fait.
		out EEARL, xl  ;va commencer a lire à l'adresse du pointeur
		out EEARH, xh
lir01a:
		sbi EECR,EERE		; validation de lecture avec EERE=1
lir02a:				; remise à 0 Watchdog
		sbic	EECR,EERE	; attendre que EERE=0
		rjmp	lir02a	
		in	temp ,EEDR	; transfert de la donnée lu dans temp
		rcall affichememoire
		call affichememoireserial
		dec xl
		out EEARL, xl
		cpi xl, $01	;
		breq Debut_du_eeprom_atteint
		inc yl
		cpi yl, 8
		brne lir01a
;ligne2
		clr yl
		rcall posi2
eepromr4:
		sbic EECR,EEPE		; vérifie si EEWE=0 
		rjmp eepromr4
		clr yl
lir01b:
		sbi EECR,EERE		; validation de lecture avec EERE=1
lir02b:				; remise à 0 Watchdog
		sbic	EECR,EERE	; attendre que EERE=0
		rjmp	lir02b	
		in	temp ,EEDR	; transfert de la donnée lu dans temp
		rcall affichememoire
		call affichememoireserial
		dec xl
		out EEARL, xl
		cpi xl, $01	;
		breq Debut_du_eeprom_atteint
		inc yl
		cpi yl, 8
		brne lir01b
Debut_du_eeprom_atteint:
		call nextline
		rcall tempo5s
		ret