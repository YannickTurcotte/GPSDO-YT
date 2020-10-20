;
;
;Serial routine

.equ   baud=9600		;Baud rate 
.equ   fosc=10000000	;Crystal frequency 

USART_Init:
		in temp, pinb	;check si jumper sur pb3. Si oui on est a 4800 au lieu de 9600
		andi temp, 0b00001000
		cpi temp, 0
		breq onesta4800
		ldi r17, high(fosc/(16*baud)-1) 
		ldi r16, low(fosc/(16*baud)-1) 
		rjmp setbaudrate 
 onesta4800:
		ldi r17, high(fosc/(16*4800)-1) 
		ldi r16, low(fosc/(16*4800)-1)
setbaudrate:    
		STORE UBRR0H, r17 
		STORE UBRR0L, r16 
		ldi r16, (1<<RXEN0)|(1<<TXEN0) |(0<<RXCIE0)	; Enable receiver and transmitter, interrupt rx disabled
		STORE UCSR0B,r16 
		ldi r16, (0<<USBS0)|(3<<UCSZ00)				; Set frame format: 8data, 1stop bit 
		STORE UCSR0C,r16 
		ret 

RX: ; Wait for data to be received
		load r17,UCSR0A		 
		sbrs r17,RXC0			;This flag bit is set when there are unread data in the receive buffer and cleared when the receive buffer is empty. 1 = unread
		rjmp RX					;donc loop ici jusqu'au temps que rxc0 vaut 1
		lds r16, UDR0			; Get and return received data from buffer 
		ret 

TX: ; Wait for empty transmit buffer 
		load r17,UCSR0A         ;Load into R17 from SRAM UCSR0A. The UDRE0 Flag indicates if the transmit buffer (UDR0) is ready to receive new data. If UDRE0 is one,
		sbrs r17,UDRE0         ;the buffer is empty, and therefore ready to be written.. Skip next instruction If Bit Register is set 
		rjmp TX 
		STORE UDR0,r16		   ; Put data (r0) into buffer, sends the data 
		ret

;Ramasse le nombre de satellite et le met dans sateiilteh,l
checkgpgga:	;$GPGGA pour neo 6m MAIS GNGGA sur neo 8M Donc je regarde pour seulement GGA
		wdr
		rcall rx
		cpi temp, $47	;G
		brne checkgpgga
		rcall rx
		cpi temp, $47	;G
		brne checkgpgga
		rcall rx
		cpi temp, $41	;A
		brne checkgpgga
;ici on a detecter $GPGGA on doit rammaser le nombre de satellite
		clr r18
kjkj:		;on compte 7 virgules. Ensuite on lit le nombre de satellites.
		rcall rx
		cpi temp, $2C	;,
		brne kjkj
		inc r18
		cpi r18, $07
		brne kjkj		;compte 7 virgules
;ici s'en vienne les 2 nombres ascii. Exemple 31, 32 pour 12.
;Addition de code pour gerer les gps module qui envois 9 au lieu de 09.
		rcall rx
		sts satelliteh, temp
		rcall rx
		sts satellitel, temp		;ici le nombre de satellites est en ascii dans satelliteh:satellitel  exemple 31:32 pour afficher 12.
		cpi temp, $2c				;regarde si nous avous recu 9 virgule au lieu de 09
		breq pasmoduleublox
		ret
pasmoduleublox:
		lds temp, satelliteh		;prend 9
		sts satellitel, temp		;on le met dans le low
		clr temp				
		sts satelliteh, temp		;et on met 0 dans le high pour 09
		ret

;*********************************************************************************************************
;*********************************************************************************************************
affichesatellite:
		load r16, UCSR0A	;regarde si ya de quoi qui a été recu par le serial
		sbrs r16, RXC0		;skip if bit in register is set
		ret					;rxc0 est a 0 on a rien recu
;on a recu de quoi sur le serial
		lds temp, affichesatelliteflag
		cpi temp, $01
		breq onpeut
		ret
onpeut:
		adiw yh:yl, $01	;incremente le compteur du wait car on pert ici une seconde.
		rcall checkgpgga	;on ramasse le nombre de satellite
		rcall posi2
		ldi r31,high(data30*2)  ;sat locked = 
		ldi r30,low(data30*2)			
		rcall message
		lds temp, satelliteh
		rcall afficheascii
		rcall tx
		lds temp, satellitel
		rcall afficheascii
		rcall tx
		rcall nextline
		call SatelliteLedDriver
		ret
;*********************************************************************************************************
;*********************************************************************************************************
;S=12
affichesatellite2:
		load r16, UCSR0A	;regarde si ya de quoi qui a été recu par le serial
		sbrs r16, RXC0
		ret					;rxc0 est a 0 on a rien recu
		rcall checkgpgga	;on ramasse le nombre de satellite
		rcall posisat
		ldi temp, $53		; S
		rcall afficheascii
		call tx
		ldi temp, $3d		; =
		rcall afficheascii
		call tx
		lds temp, satelliteh
		rcall afficheascii
		call tx
		lds temp, satellitel
		rcall afficheascii
		call tx
		ldi temp, $2c		;,
		call tx
		call SatelliteLedDriver
		ret
;*********************************************************************************************************
;*********************************************************************************************************
SatelliteLedDriver:
;dois comparer si on a plus que 3 sat et allumer le led sinon le fermer..
		lds temp, satelliteh	;39 2c
		subi temp, $30
		lsl temp
		lsl temp
		lsl temp
		lsl temp
		lds r17, satellitel
		subi r17, $30
		add temp, r17
		cpi temp, $3
		brge onallumeleled22
		;sinon on ferme le led
		call SatLedOff
		ret
onallumeleled22:
		call SatLedOn
		ret

;*********************************************************************************************************
;*********************************************************************************************************
;*********************************************************************************************************
;*********************************************************************************************************
;$GPGGA,hhmmss.ss,llll.ll,a,yyyyy.yy,a,x,xx,x.x,x.x,M,x.x,M,x.x,xxxx*hh
afficheheureposition:
;affiche heure pour 10 secondes
		rcall videecran
		call nextline
		load r16, UCSR0A	;regarde si ya de quoi qui a été recu par le serial
		sbrs r16, RXC0		;skip if bit in register is set
		rjmp nosat					;rxc0 est a 0 on a rien recu pas de signal
		ldi r26, 10
afseconde:
		call nextline
		rcall checkgpggahp	;ramasse les valeur (heure)
		rcall posi1
		lds temp, heureh
		rcall afficheascii
		call tx
		lds temp, heurel
		rcall afficheascii
		call tx
		ldi temp, $3A		; :
		rcall afficheascii
		call tx
		lds temp, minuteh
		rcall afficheascii
		call tx
		lds temp, minutel
		rcall afficheascii
		call tx
		ldi temp, $3A		; :
		rcall afficheascii
		call tx
		lds temp, secondeh
		rcall afficheascii
		call tx
		lds temp, secondel
		rcall afficheascii
		call tx
		rcall espace
		call espaceserial
		ldi temp, $55	;U
		rcall afficheascii
		call tx
		ldi temp, $54	;T
		rcall afficheascii
		call tx
		ldi temp, $43	;C
		rcall afficheascii
		call tx
attendprochaineseconde:
		load r16, UCSR0A	;regarde si ya de quoi qui a été recu par le serial
		sbrs r16, RXC0		;skip if bit in register is set
		rjmp attendprochaineseconde				;rxc0 est a 0 on a rien recu
		dec r26
		brne afseconde
;le temps vien d'etre afficher 10 seconde maintenant latitude et longitude
		rcall videecran
		call nextline
		ldi r26, 10 ;pour 10 seconde
debutdeaffichagelatitudelongitude:
;affiche position pour 10 secondes
		rcall ramassegga	;ramasse la string gga au complet incluant l'heure
		rcall posi1
		call nextline
		ldi zh, high(gga)	;adresse de RAM $240 dans Z
		ldi Zl, low(gga)
		ldi r18, 2	;on passe 2 virgule pour se rendre a la latitude. On passe par dessus l'heure
aflatitude:	
		ld	r0, z+			;charge r0 avec le contenu de l'adresse que pointe z
		mov temp, r0	;
		cpi temp, $2c	;compare avec virgule
		brne aflatitude
		dec r18
		brne aflatitude
;debut latitude
		ld	r0, z+			;4
		mov temp, r0	;
		rcall afficheascii
		call tx
		ld	r0, z+			;6
		mov temp, r0	;
		rcall afficheascii
		call tx
		ldi temp, $27	;`
		rcall afficheascii
		call tx
suitelatitude:
		ld	r0, z+			;
		mov temp, r0	;compare avec virgule.... pourquoi ? parce que dans différent module il n'y a pas toujours le meme nombres de chiffre apres le point.
		cpi temp, $2c ;,
		breq emisphere
		rcall afficheascii
		call tx
		rjmp suitelatitude
emisphere:
		rcall espace
		call espaceserial
		ld	r0, z+			;on ecris N ou S
		mov temp, r0	;
		rcall afficheascii
		call tx
		rcall posi2
		call nextline
		ld	r0, z+		;passe virgule
		ld	r0, z+	
		mov temp, r0	;
		rcall afficheascii		;0
		call tx
		ld	r0, z+	
		mov temp, r0
		rcall afficheascii		;7
		call tx
		ld	r0, z+	
		mov temp, r0
		rcall afficheascii		;2
		call tx
		ldi temp, $27			;`
		rcall afficheascii
		call tx
nextline2:
		ld	r0, z+				;on affiche le reste jusqua la virgule.
		mov temp, r0
		cpi temp, $2c
		breq nextlinefini
		rcall afficheascii
		call tx
		rjmp nextline2
nextlinefini:
		rcall espace
		call espaceserial
		ld	r0, z+				;W ou E
		mov temp, r0
		rcall afficheascii
		call tx
		call nextline
		dec r26					;decremene 26 et on recommence sinon fini
		brne debutdeaffichagelatitudelongitude2
		ret
debutdeaffichagelatitudelongitude2:
		rjmp debutdeaffichagelatitudelongitude
nosat:
		call nextline
		rcall posi1
		ldi r31,high(data36*2)  	;P 1 1 sec
		ldi r30,low(data36*2)
		rcall message
		ret

;****************************************************************************************************************************************************************************************
;****************************************************************************************************************************************************************************************
;****************************************************************************************************************************************************************************************

;check heure seulement

checkgpggahp:	;$GPGGA pour neo 6m MAIS GNGGA sur neo 8M Donc je regarde pour seulement GGA
;checkgga heure position et store dans memoire heure et position
;$xxGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
		wdr
		rcall rx
		cpi temp, $47	;G
		brne checkgpggahp
		rcall rx
		cpi temp, $47	;G
		brne checkgpggahp
		rcall rx
		cpi temp, $41	;A
		brne checkgpggahp
		clr r18
kjkj1:		;on compte 1 virgules.
		rcall rx
		cpi temp, $2C	;,
		brne kjkj1
		inc r18
		cpi r18, $01
		brne kjkj1		;compte 1 virgules
		;ici s'en vienne les 6 nombres ascii. Exemple 31, 32 pour 12.
		rcall rx
		sts heureh, temp
		rcall rx
		sts heurel, temp		;
		rcall rx
		sts minuteh, temp
		rcall rx
		sts minutel, temp		;
		rcall rx
		sts secondeh, temp
		rcall rx
		sts secondel, temp		;
		ret


;****************************************************************************************************************************************************************************************
;****************************************************************************************************************************************************************************************
;****************************************************************************************************************************************************************************************
ramassegga:	;$ramasse toute la string de gga. et la met dans $240 +
		wdr
		rcall rx
		cpi temp, $47	;G
		brne ramassegga
		rcall rx
		cpi temp, $47	;G
		brne ramassegga
		rcall rx
		cpi temp, $41	;A
		brne ramassegga
		;	rcall rx ;passe la virgule
		;ici on a detecter $GPGGA on doit rammaser la string
		ldi zh, high(gga)		;adresse de RAM $240 dans Z
		ldi Zl, low(gga)
prochainbytes:	
		rcall rx
		mov r0,temp
		st z+, R0							;R0 dans ce que pointe Z ici $240 en montant
		cpi temp, $24			;regarde si rx recoit $. Si oui = veut dire qu'on a ramasser gga au complet
		breq donegga
		rjmp prochainbytes
donegga:
		ret
;		46`19.81427 m. N

;**********************************************************************************************
;**********************************************************************************************
;**********************************************************************************************
affichenombreSerial: 	;affiche un nombre DCB. Exemple si 0x17 est dans temp. 17 sera affiché sur port serie
		push temp		;17	;On additionne 30 sur lsb et msb donc 17 = 31 + 37
		swap temp		;71
		andi temp, $0F	;1
		subi temp, -$30 ;31
		rcall tx
		pop temp ;17
		andi temp, $0F
		subi temp, -$30 ;31
		rcall tx
		ret
;***************************************************************************************
affichenombreSerialhigh: 	;affiche un nombre DCB. Exemple si 0x17 est dans temp. 17 sera affiché sur port serie
		push temp
		swap temp		;71
		andi temp, $0F	;1
		subi temp, -$30 ;31
		rcall tx
		pop temp
		ret
affichenombreSeriallow:
		push temp
		andi temp, $0F
		subi temp, -$30 ;31
		rcall tx
		pop temp
		ret
;***************************************************************************************
messageserial:
		lpm				;lpm = load program memory. Le contenu de l'adresse pointé par Z se retrouve dans R0
		mov temp, r0	;comparons r0 avec 04 pour vois si le message est à la fin
		cpi temp, $04
		breq finmessageserial
		mov temp, r0  	;Il faut séparer la valeur lu, exemple:(41) en 40 et 10 pour envoyer à l'afficheur
		rcall tx
		adiw ZH:ZL,1	;incremente zh,zl et va relire l'addresse suivante
		rjmp messageserial
finmessageserial:
		ret
;************************************************************************************
affichegate1ksserial:
		ldi r31,high(data37*2)  		;Gate 1000s
		ldi r30,low(data37*2)
		rcall messageserial
		ldi temp, $2c		;,
		rcall tx
		ret
;***************************************************************************************
affichegate10ksserial:
		ldi r31,high(data34*2)  		;Gate 10000s
		ldi r30,low(data34*2)
		rcall messageserial
		ldi temp, $2c		;,
		rcall tx
		ret
;***************************************************************************************
affichesatellite2serial:
		load r16, UCSR0A	;regarde si ya de quoi qui a été recu par le serial
		sbrs r16, RXC0
		ret					;rxc0 est a 0 on a rien recu
		rcall checkgpgga	;on ramasse le nombre de satellite
		ldi temp, $53		; S
		rcall tx
		ldi temp, $3d		; =
		rcall tx
		lds temp, satelliteh
		rcall tx
		lds temp, satellitel
		rcall tx
		ldi temp, $2c		;,
		rcall tx
		ret
;**************************************************************************************
nextline:
		ldi temp, $d
		rcall tx
		ldi temp, $a
		rcall tx
		ret

;**************************** affichememoireserial *************************************
;affiche le contenu tel quel. exemple si $3a est dans temp 3a sera afficher
affichememoireserial:
		push temp
		swap temp		;exemple 3A
		andi temp, $0f	;on garde le  3
		ldi r31,high(hexa*2) ;pointe l'addresse le la database dans R0
		ldi r30,low(hexa*2)	; l'addresse de mémoire;
		add ZL, temp		;augmente l'adresse pour pointer le bon chiffre (r31 et r30 constitue zh et zl)
		brcc okpasdedepassementqserial	;(branch if carry est 0) si le carry est a 1 (il y a une retenue) = plus que FF on incrémente donc zh. Sinon il passe et laisse zl normal
		inc zh
okpasdedepassementqserial:
		lpm
		mov temp,r0
		rcall tx
		pop temp
		andi temp, $0f	;on garde le  3
		ldi r31,high(hexa*2) ;pointe l'addresse le la database dans R0
		ldi r30,low(hexa*2)	; l'addresse de mémoire;
		add ZL, temp		;augmente l'adresse pour pointer le bon chiffre (r31 et r30 constitue zl et zh)
		brcc okpasdedepassement7qserial	;(branch if carry est 0) si le carry est a 1 (il y a une retenue) = plus que FF on incrémente donc zh. Sinon il passe et laisse zl normal
		inc zh
okpasdedepassement7qserial:
		lpm
		mov temp,r0
		rcall tx	;3 est afficher
		ret

espaceserial:
		push temp
		ldi temp, $20
		call tx
		pop temp
		ret
