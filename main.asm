;GPSDO YT
;1000s gate
.Org $0000
.include "int_atmega328p.inc"

;définition des régistres.
.def temp =R16	
.def temp2=r17

;memoire
.equ comptel = $100	;flag. Si = 1 = ca compte
.equ compteh = $101
.equ wait_flag = $102
.equ calibrationphase = $103 ;le numero de phase ou la calibration est rendu
.equ frequence_1 = $109
.equ frequence_2 = $10a
.equ frequence_3 = $10b
.equ frequence_4 = $10c
.equ frequence_5 = $10d
.equ byte = $121
.equ frebcd1 = $122
.equ frebcd2 = $123
.equ frebcd3 = $124
.equ frebcd4 = $125
.equ frebcd5 = $126
.equ frebcd6 = $127
.equ pwmphase6h = $12b
.equ pwmphase6l= $12c
.equ echantillon_timel = $12e
.equ echantillon_timeh = $12f
.equ eeprompointer = $134
.equ satelliteh = $136
.equ satellitel = $137
.equ affichesatelliteflag = $138
.equ heureh= $220
.equ heurel= $221
.equ minuteh= $222
.equ minutel= $223
.equ secondeh= $224
.equ secondel= $225
.equ QuickOrClassic = $226 ;1 = quick
.equ ledcompteurflag = $227
.equ ledcompteurflag2 = $228
;memoire lattitute longitude
.equ gga = $240 ; ne rien mettre en haut de 240 car la string que je garde est assez longue. 40 bytes ou plus

.eseg 
.db $84,$2d ;genere un fichier eeprom lors de la compilation avec les valeurs de .eseg

.CSEG	;code segment. 
;.include "m48def.inc"
;.include "m88def.inc"
.include "m328pdef.inc"		;instruction jmp utiliser pour interrupt
.include "macros.inc"
.include "afficheur.asm"
.include "math.inc"
.include "eeprom.asm"
.include "serial.asm"

;********************************* RESET *******************************************
;***********************************************************************************
RESET:	ldi	temp,low(RAMEND)
		out	SPL,temp			; Initialisation de la pile à   
		ldi	temp,high(RAMEND)	; l'adresse haute de la SRAM
		out	SPH,temp 

;init memory to 0
		call ClearAllMemory ;dans math
		call WDT_off	;doit mettre a off selon datasheet pour protection. Peut s'enabler tout seul.
		call ClrAllRegister
;break
;direction des ports
		ldi temp, 0b00010011
		out ddrb, temp	;port b en sortie pour pwm et un led pb0. PB4 en sortie avec 0v pour detection avec pb5 en entree(jumper)
		com temp
		out portb,temp	;met les pull up sur les entrées et met 0v sur les sorties. Le LED sur pb0 warming est off
		ser temp
		out ddrc, temp	;afficheur portc en sortie
		ldi temp, 0b11100000
		out ddrd, temp	;en entree (int0,1) pd5,6,7 en sortie
		com temp		;inverse temp pour activer les pullup sur pd0,1,2,3,4 et mettre pd5,6,7 a 0
		out portd, temp	;pull up 
		clr temp
		out portc, temp	;afficheur tous les broches du port C a 0
;interrupt *************************************************************************
		ldi temp, (0<<int0)|(1<<int1)	;active int1 push button seulement pour commencer. 
		out EIMSK,temp		;active int1 dans External Interrupt Mask Register – EIMSK
		ldi temp, (1<<ISC01)|(1<<ISC00)|(1<<ISC11)|(0<<ISC10)	;falling edge les 2
		sts eicra, temp
;initialisation du pointeur de eeprom
		ldi temp, $02	;on commence a ecrire a l'adresse 2. On garde 0,1 pour le pwm config
		sts eeprompointer, temp
;init flag
		;tous les flags sont a 0 par ClrAllMemory
;check for classicmode or quick mode by sensong jumper pb5. if pb5 is 0 (jumper on) = classic.  1 = quick (jumper off)
		sbis pinb, pb5	;si jumper is on saute la ligne
		rjmp classic
		ldi temp, 1
		sts QuickOrClassic, temp
		rjmp QuickOrClassicEnd
classic:
		clr temp
		sts QuickOrClassic, temp
QuickOrClassicEnd: ;
;init serial uart
		call USART_Init
		call nextline
		call tx
;init afficheur
		call reset_afficheur
		call videecran
		call posi1
		lds temp, QuickOrClassic
		cpi temp, 1
		brne classicmode1
		ldi r31,high(data7*2)  		;"GPSDO YT 1.56q "    Ici on va chercher l'addresse mémoire ou se retrouve le data à afficher.
		ldi r30,low(data7*2)		;cette addresse se retrouve dans le registe Z. Qui est constitué en fait
		call message
		call nextline
		call posi2
		ldi r31,high(data1*2)  		
		ldi r30,low(data1*2)
		call message
		call nextline
		call tx
		rjmp classicmode2						;du registre R31 et R30. Z est en fait 16 bits de long.
classicmode1:
		ldi r31,high(data7*2)  		;"GPSDO YT 1.56c "    Ici on va chercher l'addresse mémoire ou se retrouve le data à afficher.
		ldi r30,low(data7*2)		;cette addresse se retrouve dans le registe Z. Qui est constitué en fait
		call message				;dans message, on affiche ce que pointe Z "ceci est un test"
		call nextline
		call posi2
		ldi r31,high(data2*2)  		
		ldi r30,low(data2*2)
		call message
		call nextline
classicmode2:
		call tempo5s
;Ledinit
		call LedInit ;allume les led un a un. routine dans afficheur
;initialise le pwm 16 bits
		ldi temp,$FF		;set le top			*******************  TOUJOURS LOADER VALEUR H EN PREMIER sinon fonctionne pas. J'ai chercher longtemps sacrement lol
		sts icr1h, temp		;					*******************  TOUJOURS LOADER VALEUR H EN PREMIER
		ldi temp, $FF		;FFFF = 65535 pour 16 bit de resolution.
		sts icr1l, temp
		ldi temp, (1<<COM1A1)|(1<<WGM11)|(0<<WGM10)	;mode 14 fast pwm top = ICR1
		sts tccr1a, temp
		ldi temp, (1<<WGM12)|(1<<WGM13)|(1<<CS10)	;no prescaler
		sts tccr1b, temp

;*********************************************************************************************************************************
;PUSH  BUTTON et EEPROM ***********************************************************************************************************
;*********************************************************************************************************************************
;Sonde le push button, si pushbutton est enfonce = reset eeprom par valeur default 
		sbic pind, pd3		;(Skip if Bit in I/O Register is Cleared)
		rjmp valeureepromutilise			
		call videecran		;push button est appuyé = reset default
		call posi1
		ldi r31,high(data20*2)  	;Set to default                Ici on va chercher l'addresse mémoire ou se retrouve le data à afficher.
		ldi r30,low(data20*2)		;cette addresse se retrouve dans le registe Z. Qui est constitué en fait du registre R31 et R30. Z est en fait 16 bits de long.								
		call message				;dans message, on affiche ce que pointe Z "ceci est un test"
		call nextline
		call effaceeeprom
		call tempo5s
	
valeureepromutilise:	
;Push button pas appuyé.
		call eepromr			;va lire la config du eeprom et se retrouve dans pwmphase6h, 6l
		lds r17, pwmphase6l
		lds r18, pwmphase6h
		ldi temp, $ff
		cp r17, temp			;compare avec FF. Si = veux dire que le eeprom est vide ou a ses valeurs par default. On part donc avec un pwm 50%
		cpc r18, temp			;cp cpc est pour comparer 32 bit ensemble.
		breq pasdevaleurdanseeprom2
;Valeur trouvé.
		lds temp, pwmphase6h
		sts ocr1ah, temp
		lds temp, pwmphase6l	
		sts ocr1al, temp			;on le met dans ocr1 pour le pwm
		call videecran
		call posi1
		ldi r31,high(data21*2)  	;config found
		ldi r30,low(data21*2)	
		call message
		call nextline
		call posi2
		ldi r31,high(data24*2)  	;0x
		ldi r30,low(data24*2)	
		call message
		lds temp, pwmphase6h
		call affichememoire		;affiche la valeur du eeprom trouvé
		lds temp, pwmphase6l
		call affichememoire

		lds temp, pwmphase6h
		call affichememoireserial		;affiche la valeur du eeprom trouvé
		lds temp, pwmphase6l
		call affichememoireserial
		call nextline
		call tempo5s
		ldi temp, $07				;Nul besoin de recommencer a phase 1. ici je met 7 et plus loin je l'envoie dans la phase que je veux que ca commence. pour le moment  c'est 4. 200s
		sts calibrationphase, temp
		rjmp ytyt
pasdevaleurdanseeprom2:
;Aucune valeur trouvé dans eeprom (FFFF) nous commencons donc le pwm a 50%
		ldi temp, $7f	;ffff = 100 7fff = 50%
		sts ocr1ah, temp
		ldi temp, $ff		
		sts ocr1al, temp
		call videecran
		call posi1
		ldi r31,high(data22*2)  	;No config
		ldi r30,low(data22*2)	
		call message
		call nextline
		call posi2
		ldi r31,high(data23*2)  	;set to 50%
		ldi r30,low(data23*2)	
		call message
		call nextline		
		call tempo5s
		ldi temp, $01				;on commence a la phase 1
		sts calibrationphase, temp

;compteurs
;*********************************************************************************************************************************
;**************************************************** compteurs timer0 ***********************************************************
;*********************************************************************************************************************************
ytyt:
;overflow du timer0
		ldi temp, (1<<TOIE0)	;active interupt overflow
		sts timsk0, temp
		ldi temp, (0<<CS00)	;stop counter 8 bit
		out TCCR0B,temp
		clr temp	
		out tcnt0, temp		;met le compteur a 0 au cas
		ldi temp, $01
		sts wait_flag, temp	;flag est a 1 on est dans la boucle d'attente
		call debutcalibration ;waiting time 15 min for heatup oscillator. peut etre bypassed par push button.
watchdogsetup:	;active int watchdog 1 secondes. Si le gps pulse manque un pulse. Le watchdow timeout et on passe en mode selfrunning
		wdr		;Au debut je croyais que 1 seconde serait trop court car on a seulement un wdr a chaque seconde. Après test, aucun probleme, J'imagine que le watchdog est un peu plus lent.
		ldi temp, (1<<WDCE)|(1<<WDE) ;toujours envoyé ces 2 valeurs en premier, ensuite en dedans de 4 clock nous pouvons changer le registre
		sts	WDTCSR,temp
		ldi temp, (0<<WDE)|(1<<WDIE)|(0<<wdp3)|(1<<wdp2)|(1<<wdp1)|(0<<wdp0) ;enable watchdog 1s. interrupt seulement pas de reset
		sts WDTCSR,temp
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;on est ou ? On regarde on commence a quel phase.... Run ou au debut ?

		lds temp, calibrationphase
		cpi temp, $07
		breq onpassedirectarun	;ca n'égalle pas ff donc ya une valeur la config a déja été fait on passe en mode run
		rjmp phase1				;sinon on est en phase 1
onpassedirectarun:
;		rjmp runmode
		rjmp phase4 ;apres experience meme en revenant avec une config ca doit etre reajusté un peu, on va a phase 4


;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***************************************************        Phase 1      ***********************************************************
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;calcul.... 5v/FFFF= 76.295 uV de pas. L'ocxo varie de 2HZ par volt.
; 76.295uV X 2hz = 152.59 uHz par pas du pwm
;pour une seconde. Pour avoir un pas de + ou - 0.4HZ  0.4/152.59uhz = 2621 = a3d
;CORRECTION apres calcul sur 10 secondes ocxo varie de 962 a 1046 donc 84  de difference entre 0-5v
;ca qui donne 8.4 hz et non 10hz (2hz/v) Le pas passe est donc a 128.175uv au lieu de 152.59uv
;donc a3d devien c30
;MAIS comme j'ai ajouté un unreachable frequency. des saut de c30 c'est beaucoup pour certain ocxo qui sont peut etre au bord des limite. J'ai eu quelque painte que
;ca ne fonctionnait plus depuis cette mise a jour. Je garderai donc a3d.. non plutot 222. FFFF / (60 secondes) 2 donc pour la phase 1 de plus petit coup pour un maximun de 120 seconde qui donne 60 seconde car on commence au millieu.
;donc le maximun qu'on devrait rester en phase 1 sera de 60 secondes et le unreachable frequency  
;calibration phase 1,
phase1:		
		ldi temp, $01
		sts echantillon_timel, temp	;nombre de seconde a echantilloner
		clr temp
		sts echantillon_timeh, temp
		call videecran
		call affichephase1	;affiche la phase et va chercher la frequence
		call affichesatellite2
		rjmp Retour_en_mode_interrupt
phase1next:		;revien ici avec valeur de frequence pour une seconde


		lds temp, frequence_1	;on charge seulement le lsb
		cpi temp, $80 ;ici 80 car 0d10,000,000 = ?0x989680? (ca fini par 80)
		breq nextphase	;c'est égale on passe a la phase suivante
		brlo Frequence_trop_basse
		;Frequence_trop_haute:
		;ici il faut diminuer car le résultat est positif
		lds xh, ocr1ah		;c'est donc positif on descent
		lds xl,ocr1al
		lds r21, ocr1ah		;je copie aussi dans r21:r20 pour comparer plus bas
		lds r20,ocr1al
		subi xl,$22	;Subtract low bytes
		sbci xh,$02		;Add high byte with carry
		cp xl, r20		;compare avec 0. Si plus haut l'ocxo est incompatible. Frequency unreachable
		cpc xh, r21		;Je vien de soustraire ca devrait etre forcement plus bas. Je verifie. Si plus haut on a defoncé.
		brsh unreachable1
		sts ocr1ah, xh		
		sts ocr1al, xl
		call affichephase1	;Je dois réafficher car si le nombre de sattelite change, ca doit être refresh
		call affichesatellite2
		rjmp Retour_en_mode_interrupt
unreachable1: rjmp unreachable				
nextphase:
		call awesome  ;posi fin + message
		call tempo5s
		rjmp phase2
Frequence_trop_basse:		;faut augmenteraugement pwm
		lds xh, ocr1ah
		lds xl,ocr1al
		lds r21, ocr1ah		;je copie aussi dans r21:r20 pour comparer plus bas
		lds r20,ocr1al
		ldi temp ,$22		;Add en passant par registre r16 et r17 car la fonction addi n'existe pas
		ldi temp2 ,$02		;Add high byte with carry
		add xl, temp
		adc xh, temp2
		cp xl, r20			;si plus bas c'est qu'on a fait le tour, on a défoncé... unreachable
		cpc xh, r21
		brlo unreachable1
		sts ocr1ah, xh
		sts ocr1al, xl
		call affichephase1		;P.2 10 sec
		call affichesatellite2
		rjmp Retour_en_mode_interrupt

;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***************************************************        Phase 2      ***********************************************************
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;pour 10 secondes. Por avoir un pas de + ou - 0.4HZ  0.4/(10x152.59uhz) = 262.14 = 106
;128.75uv = 310 = 136
Phase2:
		call videecran
		call affichephase2		;P.2 10 sec
		call affichesatellite2
		ldi temp, $02
		sts calibrationphase, temp
		ldi temp, 10	;10 secondes
		sts echantillon_timel, temp	;nombre de seconde a echantilloner
		clr temp
		sts echantillon_timeh, temp
		rjmp Retour_en_mode_interrupt

phase2next:	;Formule:  FFFF/(frMax-Frmin) X (10E6-Frmin)
		lds temp, frequence_1			;on charge seulement le lsb
		cpi temp, $00					;compare en hex car la lib bin2bdc ne fonctionne pas avec 5bytes d'entree. Quand $80 = 00
		breq nextphase2
		lds temp, frequence_1			;on charge seulement le lsb
		cpi temp, $7F					;Compare avec la moitié de FF. Si + haut = freq trop basse sinon trop haute
		brsh Frequence_trop_basse2			;exemple. On a 04<32 si oui branche au dessusdezero. sinon 99<32 = non ne branchera pas	
		;Frequence_trop_haute:
		;ici il faut diminuer car le résultat est positif
		lds xh, ocr1ah		;c'est donc positif on descent
		lds xl,ocr1al
		lds r21, ocr1ah		;je copie aussi dans r21:r20 pour comparer plus bas
		lds r20,ocr1al
		subi xl,$00
		sbci xh,$01
		cp xl, r20			;compare avec 0. Si plus haut l'ocxo est incompatible. Frequency unreachable
		cpc xh, r21			;Je vien de soustraire ca devrait etre forcement plus bas. Je verifie. Si plus haut on a defoncé.
		brsh unreachable2
		sts ocr1ah, xh		
		sts ocr1al, xl
		call affichephase2		;P.2 10 sec
		call affichesatellite2
		rjmp Retour_en_mode_interrupt

unreachable2: rjmp unreachable	
nextphase2:
		call awesome
		call tempo5s
		rjmp phase3
Frequence_trop_basse2:	
		lds xh, ocr1ah
		lds xl,ocr1al
		lds r21, ocr1ah		;je copie aussi dans r21:r20 pour comparer plus bas
		lds r20,ocr1al
		ldi temp ,$00		;Add en passant par registre r16 et r17 car la fonction addi n'existe pas
		ldi temp2 ,$01		;Add high byte with carry
		add xl, temp
		adc xh, temp2
		cp xl, r20			;si plus bas c'est qu'on a fait le tour, on a défoncé... unreachable
		cpc xh, r21
		brlo unreachable2
		sts ocr1ah, xh
		sts ocr1al, xl
		call affichephase2		;P.2 10 sec
		call affichesatellite2
		rjmp Retour_en_mode_interrupt


;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***************************************************        Phase 3      ***********************************************************
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;pour 60 secondes. Por avoir un pas de + ou - 0.4HZ  0.4/(60x152.59uhz) = 43 = 2b
;128.175us = 52 = $34
phase3:
		call videecran
		call affichephase3
		call affichesatellite2
		ldi temp, $03
		sts calibrationphase, temp
		ldi temp, 60								;60 seconde
		sts echantillon_timel, temp					;nombre de seconde a echantilloner
		clr temp
		sts echantillon_timeh, temp
		rjmp Retour_en_mode_interrupt

phase3next:	;Formule:  FFFF/(frMax-Frmin) X (10E6-Frmin)
		lds temp, frequence_1				;on charge seulement le lsb
		cpi temp, $00						;compare en hex car la lib bin2bdc ne fonctionne pas avec 5bytes d'entree. Quand $80 = 00
		breq nextphase3
		cpi temp, $7f					
		brsh Frequence_trop_basse3
;Frequence_trop_haute:
		lds temp, QuickOrClassic
		cpi temp, 1
		brne classic_1
		;ici il faut diminuer car le résultat est positif
		;je regarde si je corrige un peu ou beaucoup
		lds temp2, frequence_1 ;ici frequence 1 est superieur a 0. C'est exactement le nombre de hz de trop
		cpi temp2, 1
		brne Cavautlapeine3a
		ldi temp,$34
		ldi temp2,$00
		rjmp calcul3a
classic_1:
		ldi temp,$2b
		ldi temp2,$00
		rjmp calcul3a
Cavautlapeine3a:
		ldi temp, 109		;on charge le pas. 60s = 7 1/(60x152.59uhz) = 109.22
		mul temp2, temp		;reponse dans R0
		movw temp, r0			;je garde cette réponse dans r17:r16
calcul3a:
		lds xh, ocr1ah		;c'est donc positif on descent
		lds xl,ocr1al
		lds r21, ocr1ah		;je copie aussi dans r21:r20 pour comparer plus bas
		lds r20,ocr1al
		sub xl, temp
		sbc	xh,temp2
		cp xl, r20			;compare avec 0. Si plus haut l'ocxo est incompatible. Frequency unreachable
		cpc xh, r21			;Je vien de soustraire ca devrait etre forcement plus bas. Je verifie. Si plus haut on a defoncé.
		brsh unreachable3
		sts ocr1ah, xh		
		sts ocr1al, xl
		call affichephase3					;refresh
		call affichesatellite2
		rjmp Retour_en_mode_interrupt
unreachable3: rjmp unreachable	
nextphase3:
		call awesome
		call tempo5s
		lds r19, ocr1ah	;kept in eeprom
		lds r18,ocr1al
		sts pwmphase6h, r19	
		sts pwmphase6l, r18
		call eepromw
		rjmp phase4
Frequence_trop_basse3:
		lds temp, QuickOrClassic
		cpi temp, 1
		brne classic_2

		lds temp, frequence_1
		ldi temp2, $ff		;ff - frequence + 1 est ce qui manque pour arriver a 0 pile
		sub temp2, temp
		inc temp2			;temp2 a maintenant le nombre de hz manquant
		cpi temp2, 1
		brne Cavautlapeine3b
		ldi temp ,$34		;Add en passant par registre r16 et r17 car la fonction addi n'existe pas
		ldi temp2 ,$00		;Add high byte with carry
		rjmp calcul3b
classic_2:
		ldi temp,$2b
		ldi temp2,$00
		rjmp calcul3b
Cavautlapeine3b:
		ldi temp, 109		;on charge le pas. 60s = 7 1/(60x152.59uhz) = 109.22
		mul temp2, temp
		movw temp, r0			;je garde cette réponse dans r17:r16
calcul3b:
		lds xh, ocr1ah
		lds xl,ocr1al
		lds r21, ocr1ah		;je copie aussi dans r21:r20 pour comparer plus bas
		lds r20,ocr1al
		add xl, temp
		adc xh, temp2
		cp xl, r20			;si plus bas c'est qu'on a fait le tour, on a défoncé... unreachable
		cpc xh, r21
		brlo unreachable3
		sts ocr1ah, xh
		sts ocr1al, xl
		call affichephase3					;refresh
		call affichesatellite2
		rjmp Retour_en_mode_interrupt
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***************************************************        Phase 4      ***********************************************************
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;pour 200 secondes. Por avoir un pas de + ou - 0.4HZ  0.4/(200x152.59uhz) = 12.53 = C
;128.175us = 15.6 (16) = 10
phase4:
		call videecran
		call affichephase4
		call affichesatellite2
		ldi temp, $04
		sts calibrationphase, temp
		ldi temp, 200						;200 seconde
		sts echantillon_timel, temp			;nombre de seconde a echantilloner
		clr temp
		sts echantillon_timeh, temp
		rjmp Retour_en_mode_interrupt

phase4next:	;Formule:  FFFF/(frMax-Frmin) X (10E6-Frmin)

		lds temp, frequence_1					;on charge seulement le lsb
		cpi temp, $00							;compare en hex car la lib bin2bdc ne fonctionne pas avec 5bytes d'entree. Quand $80 = 00
		breq nextphase4
		cpi temp, $7f							
		brsh Frequence_trop_basse4
;Frequence_trop_haute:
		lds temp, QuickOrClassic
		cpi temp, 1
		brne classic_3
		;ici il faut diminuer car le résultat est positif
		;je regarde si je corrige un peu ou beaucoup
		lds temp2, frequence_1 ;ici frequence 1 est superieur a 0. C'est exactement le nombre de hz de trop
		cpi temp2, 1
		brne Cavautlapeine4a
		ldi temp,$10
		ldi temp2,$00
		rjmp calcul4a
classic_3:
		ldi temp,$0c
		ldi temp2,$00
		rjmp calcul4a
Cavautlapeine4a:
		ldi temp, 33		;on charge le pas. 200s = 7 1/(200x152.59uhz) = 32.76
		mul temp2, temp		;temp2 est la frequence. reponse dans R0
		movw temp, r0			;je garde cette réponse dans r17:r16
calcul4a:
		lds xh, ocr1ah		;c'est donc positif on descent
		lds xl,ocr1al
		lds r21, ocr1ah		;je copie aussi dans r21:r20 pour comparer plus bas
		lds r20,ocr1al
		sub xl, temp
		sbc	xh,temp2
		cp xl, r20			;compare avec 0. Si plus haut l'ocxo est incompatible. Frequency unreachable
		cpc xh, r21			;Je vien de soustraire ca devrait etre forcement plus bas. Je verifie. Si plus haut on a defoncé.
		brsh unreachable4
		sts ocr1ah, xh		
		sts ocr1al, xl
		call affichephase4						;refresh
		call affichesatellite2
		rjmp Retour_en_mode_interrupt
unreachable4: rjmp unreachable	
nextphase4:
		call awesome
		call tempo5s
		lds r19, ocr1ah	;kept in eeprom
		lds r18,ocr1al
		sts pwmphase6h, r19	
		sts pwmphase6l, r18
		call eepromw
		rjmp phase5

Frequence_trop_basse4:
		lds temp, QuickOrClassic
		cpi temp, 1
		brne classic_4

		lds temp, frequence_1
		ldi temp2, $ff		;ff - frequence + 1 est ce qui manque pour arriver a 0 pile
		sub temp2, temp
		inc temp2			;temp2 a maintenant le nombre de hz manquant
		cpi temp2, 1
		brne Cavautlapeine4b
		ldi temp ,$10		;Add en passant par registre r16 et r17 car la fonction addi n'existe pas
		ldi temp2 ,$00		;Add high byte with carry
		rjmp calcul4b
classic_4:
		ldi temp,$0c
		ldi temp2,$00
		rjmp calcul4b
Cavautlapeine4b:
		ldi temp, 33		;on charge le pas. 200s = 7 1/(200x152.59uhz) = 32.76 
		mul temp2, temp
		movw temp, r0			;je garde cette réponse dans r17:r16
calcul4b:
		lds xh, ocr1ah
		lds xl,ocr1al
		lds r21, ocr1ah		;je copie aussi dans r21:r20 pour comparer plus bas
		lds r20,ocr1al
		add xl, temp
		adc xh, temp2
		cp xl, r20			;si plus bas c'est qu'on a fait le tour, on a défoncé... unreachable
		cpc xh, r21
		brlo unreachable4
		sts ocr1ah, xh
		sts ocr1al, xl
		call affichephase4						;refresh
		call affichesatellite2
		rjmp Retour_en_mode_interrupt

;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***************************************************        Phase 5      ***********************************************************
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;pour 1000 secondes. Por avoir un pas de + ou - 0.4HZ  0.4/(1000x152.59uhz) = 2,6= 2
;avec 128.75us = 3.1 donc 3
phase5:
		call videecran
		call affichephase5
		call affichesatellite2
		ldi temp, $5
		sts calibrationphase, temp
		ldi temp,$E8 ;1000 secondes
		sts echantillon_timel, temp	;nombre de seconde a echantilloner
		ldi temp, $03
		sts echantillon_timeh,temp
		rjmp Retour_en_mode_interrupt
phase5next:	;Formule:  FFFF/(frMax-Frmin) X (10E6-Frmin)

		call eepromwritebytes	;ecris la frequence_1 trouvé dans eeprom commence a l'adresse 2 et incremente pour le prochain tour.
		;;rendu a la phase 5 je garde tous les resultata pour analyse dans eeprom.
		lds temp, frequence_1	;on charge seulement le lsb
		cpi temp, $00 
		breq nextphase5
		cpi temp, $7f
		brsh Frequence_trop_basse5
Frequence_trop_haute5:
		;Frequence_trop_haute:
		lds temp, QuickOrClassic
		cpi temp, 1
		brne classic_5
		;ici il faut diminuer car le résultat est positif
		;je regarde si je corrige un peu ou beaucoup
		lds temp2, frequence_1 ;ici frequence 1 est superieur a 0. C'est exactement le nombre de hz de trop
		cpi temp2, 1
		brne Cavautlapeine5a
		ldi temp,$03
		ldi temp2,$00
		rjmp calcul5a		;PHASE 5 C'EST +-3. 8XFREQUENCE EN QUICK 
classic_5:
		ldi temp,$03
		ldi temp2,$00
		rjmp calcul5a
Cavautlapeine5a:
		ldi temp, $08		;on charge le pas.  1/(1000x152.59uhz) = 6.55 apres calcul sur 10 secondes ocxo varie de 962 a 046 donc 84  de difference entre 0-5v
		;ca qui donne 8.4 hz et non 10 (2hz/v) Le pas passe donc a 128.175uv pour une valeur de 1/(1000x128.74uv) = 7.8 donc je met 8
		mul temp2, temp		;reponse dans R0
		movw temp, r0			;je garde cette réponse dans r17:r16
calcul5a:
		lds xh, ocr1ah		;c'est donc positif on descent
		lds xl,ocr1al
		lds r21, ocr1ah		;je copie aussi dans r21:r20 pour comparer plus bas
		lds r20,ocr1al
		sub xl, temp
		sbc	xh,temp2
		cp xl, r20			;compare avec 0. Si plus haut l'ocxo est incompatible. Frequency unreachable
		cpc xh, r21			;Je vien de soustraire ca devrait etre forcement plus bas. Je verifie. Si plus haut on a defoncé.
		brsh unreachable5
		sts ocr1ah, xh		
		sts ocr1al, xl
		call affichephase5			;refresh
		call affichesatellite2
		rjmp Retour_en_mode_interrupt
unreachable5: rjmp unreachable	
nextphase5:
		call awesome
		call tempo5s
		lds r19, ocr1ah	;kept in eeprom
		lds r18,ocr1al
		sts pwmphase6h, r19	
		sts pwmphase6l, r18
		call eepromw
		rjmp runmode
Frequence_trop_basse5:
		lds temp, QuickOrClassic
		cpi temp, 1
		brne classic_6
		lds temp, frequence_1
		ldi temp2, $ff		;ff - frequence + 1 est ce qui manque pour arriver a 0 pile
		sub temp2, temp
		inc temp2			;temp2 a maintenant le nombre de hz manquant
		cpi temp2, 1
		brne Cavautlapeine5b
		ldi temp ,$03		;Add en passant par registre r16 et r17 car la fonction addi n'existe pas
		ldi temp2 ,$00		;Add high byte with carry
		rjmp calcul5b
classic_6:
		ldi temp,$03
		ldi temp2,$00
		rjmp calcul5b
Cavautlapeine5b:
		ldi temp, $08		;on charge le pas.  1/(1000x152.59uhz) = 6.55 apres calcul sur 10 secondes ocxo varie de 962 a 046 donc 84  de difference entre 0-5v
		;ca qui donne 8.4 hz et non 10 (2hz/v) Le pas passe donc a 128.175uv pour une valeur de 1/(1000x128.74uv) = 7.8 donc je met 8
		mul temp2, temp
		movw temp, r0			;je garde cette réponse dans r17:r16		;je garde cette réponse dans r17:r16
calcul5b:
		lds xh, ocr1ah
		lds xl,ocr1al
		lds r21, ocr1ah		;je copie aussi dans r21:r20 pour comparer plus bas
		lds r20,ocr1al
		add xl, temp
		adc xh, temp2
		cp xl, r20			;si plus bas c'est qu'on a fait le tour, on a défoncé... unreachable
		cpc xh, r21
		brlo unreachable5
		sts ocr1ah, xh
		sts ocr1al, xl
		call affichephase5			;refresh
		call affichesatellite2
		rjmp Retour_en_mode_interrupt


;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***************************************************        Run      ***********************************************************
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;pour 1000 secondes. Por avoir un pas de + ou - 0.4HZ  0.4/(1000x152.59uhz) = 2,6= 2 mais en mode run on dessend au plus bas = 1
runmode:	;Formule:  FFFF/(frMax-Frmin) X (10E6-Frmin)
		call afficherunmode
		call affichesatellite2
		ldi temp, $07
		sts calibrationphase, temp
		ldi temp,$e8 ;1000 secondes
		sts echantillon_timel, temp	;nombre de seconde a echantilloner
		ldi temp,$3
		sts echantillon_timeh,temp
;allume le led RUN
		call RunLedOn
		rjmp Retour_en_mode_interrupt

runmodenext:

		call eepromwritebytes	;track tous les valeur dans eeprom adresse 02 to ff et tourne en boucle
		lds temp, frequence_1	;on charge seulement le lsb
		cpi temp, $00 
		breq nextphase7
		cpi temp, $7f 
		brsh Frequence_trop_basse7
;		rjmp Frequence_trop_haute5
		lds temp, QuickOrClassic
		cpi temp, 1
		brne classic_7
Frequence_trop_haute7:
		;ici il faut diminuer car le résultat est positif
		;je regarde si je corrige un peu ou beaucoup
		lds temp2, frequence_1 ;ici frequence 1 est superieur a 0. C'est exactement le nombre de hz de trop
		cpi temp2, 1
		brne Cavautlapeine7a ;je l'ai deactivé. car quand une gps pulse error survient. La corection etait trop grande. En run mode une grande correction ne devrait pas arriver
		ldi temp,$01	;je met 3. ca prend 8 pour plus ou moins 1 hz. a 1 c'est trop lent et la fréquence change plus vite que la correction. A 3 c'Est mieux
		ldi temp2,$00	;a 2 aussi c'etait pas si mal; Finalement j'ai mis 1.
		rjmp calcul7a
classic_7:
		ldi temp,$01
		ldi temp2,$00
		rjmp calcul7a
Cavautlapeine7a:
		ldi temp, $04		;on charge le pas.  1/(1000x152.59uhz) = 6.55 apres calcul sur 10 secondes ocxo varie de 962 a 046 donc 84  de difference entre 0-5v
		;ce qui donne 8.4 hz et non 10 (2hz/v) Le pas passe donc a 128.175uv pour une valeur de 1/(1000x128.74uv) = 7.8 donc je met 8
		mul temp2, temp		;reponse dans R0
		movw temp, r0			;je garde cette réponse dans r17:r16
calcul7a:
		lds xh, ocr1ah		;c'est donc positif on descent
		lds xl,ocr1al
		lds r21, ocr1ah		;je copie aussi dans r21:r20 pour comparer plus bas
		lds r20,ocr1al
		sub xl, temp
		sbc	xh,temp2
		cp xl, r20			;compare avec 0. Si plus haut l'ocxo est incompatible. Frequency unreachable
		cpc xh, r21			;Je vien de soustraire ca devrait etre forcement plus bas. Je verifie. Si plus haut on a defoncé.
		brsh unreachable7
		sts ocr1ah, xh		
		sts ocr1al, xl
		call afficherunmode
		call affichesatellite2
		rjmp Retour_en_mode_interrupt


unreachable7: rjmp unreachable
nextphase7:
		call afficherunmode
		call affichesatellite2
		lds r19, ocr1ah		;10,000,000.000 vient d'etre compté ici on conserve la valeur trouvé dans l'eeprom.
		lds r18,ocr1al
		sts pwmphase6h, r19	
		sts pwmphase6l, r18
		call eepromw
		rjmp Retour_en_mode_interrupt

Frequence_trop_basse7:	
;		rjmp Frequence_trop_basse5
		lds temp, QuickOrClassic
		cpi temp, 1
		brne classic_8
		lds temp, frequence_1
		ldi temp2, $ff		;ff - frequence + 1 est ce qui manque pour arriver a 0 pile
		sub temp2, temp
		inc temp2			;temp2 a maintenant le nombre de hz manquant
		cpi temp2, 1
		brne Cavautlapeine7b ;je l'ai deactivé. car quand une gps pulse error survient. La corection etait trop grande. En run mode une grande correction ne devrait pas arriver
		ldi temp ,$01		;Add en passant par registre r16 et r17 car la fonction addi n'existe pas
		ldi temp2 ,$00		;Add high byte with carry
		rjmp calcul7b
classic_8:
		ldi temp,$01
		ldi temp2,$00
		rjmp calcul7b
Cavautlapeine7b:
		ldi temp, $04		;on charge le pas.  1/(1000x152.59uhz) = 6.55 apres calcul sur 10 secondes ocxo varie de 962 a 046 donc 84  de difference entre 0-5v
		;ca qui donne 8.4 hz et non 10 (2hz/v) Le pas passe donc a 128.175uv pour une valeur de 1/(1000x128.74uv) = 7.8 donc je met 8
		mul temp2, temp
		movw temp, r0			;je garde cette réponse dans r17:r16		;je garde cette réponse dans r17:r16
calcul7b:
		lds xh, ocr1ah
		lds xl,ocr1al
		lds r21, ocr1ah		;je copie aussi dans r21:r20 pour comparer plus bas
		lds r20,ocr1al
		add xl, temp
		adc xh, temp2
		cp xl, r20			;si plus bas c'est qu'on a fait le tour, on a défoncé... unreachable
		cpc xh, r21
		brlo unreachable7
		sts ocr1ah, xh
		sts ocr1al, xl
		call afficherunmode
		call affichesatellite2
		rjmp Retour_en_mode_interrupt

;*****************************************************************************************************************************************
;*********************************************************unreachable*********************************************************************
;*****************************************************************************************************************************************
;*****************************************************************************************************************************************
unreachable:
		call videecran
		call posi1
		ldi r31,high(data37*2)  	;Unreachable
		ldi r30,low(data37*2)		;
		call message
		call nextline
		call posi2
		ldi r31,high(data38*2)  	;frequency. Halt
		ldi r30,low(data38*2)		;
		call message
		call nextline
Halted: rjmp Halted	

;*****************************************************************************************************************************************
;*****************************************************************************************************************************************
;*********************************************************   Push button   ***************************************************************
;*****************************************************************************************************************************************
;*****************************************************************************************************************************************
pushbutton:		;dans le mode warming up 15 minute. Push button génere aussi un interruption. On regarde ici si elle arrive derant le 15 minutes
		push temp
		load temp, sreg	
		push temp
		lds temp, wait_flag
		cpi temp, $01
		brne pasca

		;sinon 15 minutes baypassed. On remet le flag a 0
		clr temp		
		sts wait_flag,temp
;tempo pour antirebond, code ajouter pour corriger probleme d'afficher l'heure a la place de bypasser le wait.
dwdw1:	call tempo10ms
dwdw:	sbis pind, pd3	;Bouton enfoncé. 0v Attends que ca remonte a 5v.
		rjmp dwdw
		call tempo10ms
		sbis pind, pd3	;double check, devrait etre remonté a 5v sinon 
		rjmp dwdw1
		call tempo300ms
		ldi temp, 0b00000010	;remove int1 flag si jamais ca rebondi et passé au travers de l'antirebond
		store eifr, temp
		pop temp
		store sreg, temp
		pop temp
		reti
pasca:
;ici on veut afficher l'heure. On sait que le bouton a été appuyer dans le mode count. On doit donc tout rénitialiser car ici on bypass le reti. C'est pas évident de fonctionner ainsi
;mais j'ai pas le choix.
		wdr
		clr temp
		sts affichesatelliteflag, temp ;empeche le nombre de satellite de s'afficher. deja mis a 0 auparavent mais eu un bug que ca affichait.
;ferme le led counter
		call CounterLedOff
;affiche heure et position. (dure 20 secondes)
		call afficheheureposition ;se trouve dans serial
;affiche eeporom
		call affiche_eeprom ;(se trouve dans eeprom.asm)
			
		call seconde_tempo
		wdr	
;on doit tout rénitialiser car on revient ici par interruption push button quand on etait en train de compter. Donc on remet a 0 et on
;retourne à la phase ou nous etions
		sbi eifr, 1
		ldi temp, 0b00000010	;remove int1 flag pour etre encore plus sur. (je l'ai déja vu 2 fois de fille comme l'interrupt se faisait 2 fois.
		store eifr, temp
		ldi temp, (0<<CS00)	;stop counter 8 bit
		out TCCR0B,temp
		clr temp	
		out tcnt0, temp		;remet le compteur a 0
		sts comptel, temp	;initialise le flag compte. Il part a 0
		sts compteh, temp
		call clrallregister
		ldi	temp,low(RAMEND)
		out	SPL,temp			; Initialisation de la pile à   
		ldi	temp,high(RAMEND)	; l'adresse haute de la SRAM
		out	SPH,temp
		ldi temp,0b00000001
		store TIFR0, temp		;annule timer l'overflow si il y a eu un
		rjmp etondispatchencore

;*****************************************************************************************************************************************
;*****************************************************************************************************************************************
;*********************************************************   TIM0_OVF *    ***************************************************************
;*****************************************************************************************************************************************
;*****************************************************************************************************************************************
TIM0_OVF:	;viens ici a APRES chaque 256 clock a l'aide le int overflow
;			In normal operation the	Timer/Counter Overflow Flag (TOV0) will be set in the same timer clock cycle as the TCNT0 becomes zero
;Important: Si le dernier pulse arrive dans cette interruption. Celui ci sera fait apres. DOnc le sample aura 4,5,6 tic de trop.
;Je n'ai aucun moyen de corriger ca. Par chance, Vu que je roule a 10 mhz pile, si le dernier pulse n'arrive pas dedans, il n'arrivera donc jamais dedans.
;Et si il arrive toujours dedans, il va etre toujours dedans. Dans ce cas je changerai ou ajouterai une boucle de temps au depart.
;Apres test le dernier pulse arrive a 00 en phase 2,4,5,6 et a 80 a 1 et 2.
;Reponse. Il vient ici avant le dernier latch car le compteur est parti a 7,8 tic en retard, Donc il vient ici 7-8 tic avant la fin. Quand le compteur est arreté dans l'interruption latch. Il est rendu a 0 a ce moment.
;En aucun cas l'interruption latch peut arriver en même temps que un timer overflow pour cette raison.
		ldi temp, $ff
		cp xl, temp			;tcnt0 monte a FF et retourne a 0. Un intterruption survien et on arrive ici. 
		cpc xh, temp		;On incremente x et regarde si le registre x est rendu plein, compare a $FFFF
		breq incy			;x est incrementé de 1 a chaque 256 clock. quand x = FFFF on monte y de 1 (ca prend un clk et ffff monte a 10000) et on remet x a 0.
		adiw xh:xl, $01		;monte de 1 le registre x de 16 bit: X vaut (FFFF+1) x $100 = $10,00,00 1000000 (6 zero)

;toggle led buffer
;ici je fais clignotter la led count. Si jamais le uC plante on s'en appercoit. La led est solid on ou off
;vitesse du clignottement: (1/10E6) x 256 x (256x4) = 26.21 ms ca toggle. Donc 26ms hi 26ms low. 26x2 = un cycle. 1/(26.21msx2) = 19.07 hz
		load temp, ledcompteurflag
		inc temp
		store ledcompteurflag, temp
		cpi temp, $ff
		brne onsenpasse
		load temp, ledcompteurflag2
		inc temp
		store ledcompteurflag2, temp
		cpi temp, $4
		brne onsenpasse
;toggle le led counter
		sbis portd, 6
		rjmp onturnon
		call CounterLedOff
		clr temp
		sts ledcompteurflag, temp
		sts ledcompteurflag2, temp
		reti
onturnon:
		call CounterLedOn
		clr temp
		sts ledcompteurflag, temp
		sts ledcompteurflag2, temp
onsenpasse:
		reti

incy:						;y vaux (1,00,00,00)...
		adiw yh:yl, $01		;On monte y et on remet x a 0
		clr xl
		clr xh
		reti

;*****************************************************************************************************************************************
;*****************************************************************************************************************************************
;*********************************************************   Latch gate    ***************************************************************
;*****************************************************************************************************************************************
;*****************************************************************************************************************************************
Latch:
; Un pulse arrive chaque seconde. On calcul le nombre de hertz a l'aide du compteur 8bit en incrémentant le registre x et y.
; meme nombre de clock (operations) pour partir ou arreter le compteur pour que ca balance.
; un probleme peut survenir. Le compteur tcnt0 compte sans arret.
; si l'interruption arrive quand tcnt0 est a 254... il se créé un overflow pendant l'interruption. Par contre le flag reste en suspand et n'est pas pris en compte
; tout de suite car les int sont disable durant le traitement de celle ci.
; le comprteur est donc faussé car tcnt0 est additionné au total mais maintenant il vaut seulement 0 ou 1 car il a recommencé.
; par contre l'interruption en mémoire est executé aussitot sorti de cette interruption et les 256 clock de perdu sont additionné au prochain.
;***IMPORTANT** finalement l'overflow se gere comme un neuvieme bit qui vaut (256) $100. Simplement ajouter le tcnt0 + $100 quand le tov0 est a 1
; jai donc inclus du code pour gerer le bit overflow quand cela se produit
;XX*** important: J'ai lu apres dans le datasheet: tov0 peut etre considéré comme un 9iem bit!!! Plus facile de penser comme cela. il passe a 1 en meme temps qu'il passe tcnt0 a 0.

		lds r16, compteh ;compte est incrementé a chaque seconde
		lds r17, comptel
		lds r18, echantillon_timeh	;on echantillone combien de temps ???? C'est ici
		lds r19, echantillon_timel
		cp r17, r19
		cpc r16, r18
		breq off
		wdr	;reset watchdog et balance le depart et l'arret 16 cycles exactement juste apres l'interrupt. Tous les cycles sont important et doivent etre compte.
		ldi temp, (1<<CS00)	;start counter 8 bit
		out TCCR0B,temp

	;peux ajouter du code ici sans changer le resultat du count mais ne doit pas depasser 256 clock
	;pourquoi... parce que ici les interruption sont deactivé. Si ca prend plus que 256 clock le compteur tcnt0 va faire un ou plusieur overflow mais ne sera
	;pas pris en compte car il y a un buffer de seulement 1 interruption.

	
		lds zh, compteh
		lds zl, comptel
		adiw zh:zl, 1
		sts compteh, zh
		sts comptel, zl
		reti
off:
		ldi temp, (0<<CS00)	;stop counter 8 bit
		out TCCR0B,temp
		clr temp
		sts compteh, temp	;remet le compteur a 0
		sts comptel, temp
		wdr
		cli		;arrete tous les futurs interruptions
		call CounterLedOff

;ici on doit gerer la valeur de x et y qui s'est accumulé dans l'echantionnage
;(xh:xl x $100) + (yh:yl x $1000000) + le reste du compteur tcnt0 + overflow (256) si actif = nombre de clock écoulé total.

rere:
;r21:r20 x r23:r22 = r5:r4:r3:r2
		mov r21, xh	;x x 256
		mov r20, xl
		ldi r23, $01		;$100 = 256
		ldi r22 ,$00
		call mul16				;M1M:M1L x M2M:M2L = res4:res3:res2:res1 = r5:r4:r3:r2
		push r2		;conserve la reponse
		push r3
		push r4
		push r5
		push yh	;conservons y
		push yl
;y x 1000000
;* r23:r22:r21:r20 x  r19:r18:r17:r16   =  r27:r26:r25:r24:r23:r22:r21:r20	(seulement r24 a r20 se remplissent) r24 vaut 2 a 9 000 000 000hz
		call clrallregister	;clr toute les registre de 16 a 31
		pop yl
		pop yh
		mov r20, yl			;r32,r22,yh,yl
		mov r21, yh
		ldi r19, $01		;$01:00:00:00 = $10000000 x Y
		call mul32			;reponse dans r27:r26:r25:r24:r23:r22:r21:r20
;additionons les 2
		pop r19			;reponse de x (x x 256)
		pop r18
		pop r17
		pop r16
		clr r25
		add	r20,r16		;Addition des octets de poids faible
		adc	r21,r17	
		adc	r22,r18	
		adc	r23,r19		;Addition des octets de poids fort avec retenue
		adc r24, r25	;conserve le carre dans r24 
		;reponse dans r27:r26:r25:r24:r23:r22:r21:r20
;ajoutons tcnt0
		in r16, tcnt0	;r16 = tcnt0
		clr r17
		clr r18
		clr r19
		clr r25
		add	r20,r16		; Addition des octets de poids faible
		adc	r21,r17	
		adc	r22,r18	
		adc	r23,r19		;Addition des octets de poids fort avec retenue
		adc r24,r25
		;reponse dans r27:r26:r25:r24:r23:r22:r21:r20
;test overflow bit
		sbis TIFR0, tov0	;skip if bit is set (bit overflow)  Si il y a eu overflow entre l'interrup et l'arret on ajoute 256
		rjmp fiou
		ldi temp, (1<<TOV0)	;annule l'overflow pending et la future interruption par le fait meme. Faire a la main car reti est bypassé.
		out tifr0, temp
		clr r16
		ldi r17,$01		;additionne 256
		clr r18
		clr r19
		clr r25
		add	r20,r16		;Addition des octets de poids faible
		adc	r21,r17	
		adc	r22,r18
		adc	r23,r19		;Addition des octets de poids fort avec retenue
		adc r24,r25
	;reponse dans r27:r26:r25:r24:r23:r22:r21:r20
fiou:
		sts frequence_1, r20
		sts frequence_2, r21
		sts frequence_3, r22
		sts frequence_4, r23
		sts frequence_5, r24	;dans 900 seconde r24 monte a 2
;stop: rjmp stop
;ici le nombre de hertz par seconde est dans la memoire frequence en HEX
;convertissons HEX to BDC
;	r20:r19:r18:r17:r16	    >>>   	r25:r24:r23:r22:r21

		lds r20, frequence_5
		lds r19, frequence_4
		lds r18, frequence_3
		lds r17, frequence_2
		lds r16, frequence_1
		call hex2bcdyt		;conversion bcd	;fonctionne bien pas de bug testé avec afficheur ca concorde.
		sts frebcd1, r21
		sts frebcd2, r22
		sts frebcd3, r23
		sts frebcd4, r24
		sts frebcd5, r25
		sts frebcd6, r26

;On affiche
;**************************************************** affiche
		call posi2
		call effaceligne
		;call nextline
		call posi2
		lds temp, calibrationphase	;quand on est a 6 on affiche la frequence et non le compte
		cpi temp, $5
		brsh displaymhz ;­>=

		lds temp, frebcd5	;jusque phase 1 a 5 on affiche seulement 5 bytes
		call affichenombre
		call affichenombreserial
		lds temp, frebcd4
		call affichenombre
		call affichenombreserial
		lds temp, frebcd3
		call affichenombre
		call affichenombreserial
		lds temp, frebcd2
		call affichenombre
		call affichenombreserial
		lds temp, frebcd1
		call affichenombre
		call affichenombreserial

		rjmp onnettoie

displaymhz:						;0 10,000,000.000
		lds temp, frebcd6		;01 00 00 00 00 00  ou 00 99 99 99 99 99
		cpi temp, 0
		brne aldo				;si frebcd6 = 0 on affiche un espace a place
		call espace			;
		call espaceserial
		rjmp yahoo
aldo:
		lds temp, frebcd6	;1
		call affichelsb
		call affichenombreSeriallow
yahoo:
		lds temp, frebcd5	;0      jusque phase 1 a 5 on affiche seulement 5 bytes
		call affichemsb
		call affichenombreSerialhigh
		ldi temp, $2c		;,      virgule
		call afficheascii
		call tx
		lds temp, frebcd5	;0 00   jusque phase 1 a 5 on affiche seulement 5 bytes
		call affichelsb
		call affichenombreSeriallow
		lds temp, frebcd4
		call affichenombre
		call affichenombreserial
		ldi temp, $2c		;,virgule
		call afficheascii	;00 0
		call tx
		lds temp, frebcd3
		call affichenombre
		call affichenombreserial
		lds temp, frebcd2
		call affichemsb
		call affichenombreSerialhigh
		ldi temp, $2e		; point
		call afficheascii	;0 00
		call tx
		lds temp, frebcd2
		call affichelsb
		call affichenombreSeriallow
		lds temp, frebcd1
		call affichenombre
		call affichenombreserial
		ldi temp, $20		;espace sur serial
		call tx
hzhz:	ldi temp, $48	;Hz
		call afficheascii
		call tx
		ldi temp, $7a
		call afficheascii
		call tx
onnettoie:
		call clrallregister
		out tcnt0, temp
		sts comptel, temp
		sts compteh, temp
		;ldi temp, (1<<TOIE0)	;active interupt overflow
		;sts timsk0, temp
dispatch:
;maintenat qu'on a la frequence. déterminons ou nous devons aller pour le traitement de la calibration. Quel phase sonne nous rendu.
		lds temp, calibrationphase
		cpi temp,01
		brne nono
		ldi	temp,low(RAMEND)
		out	SPL,temp			; Initialisation de la pile à   
		ldi	temp,high(RAMEND)	; l'adresse haute de la SRAM
		out	SPH,temp
		rjmp phase1next
nono:
		cpi temp,02
		brne nono1
		ldi	temp,low(RAMEND)
		out	SPL,temp			; Initialisation de la pile à   
		ldi	temp,high(RAMEND)	; l'adresse haute de la SRAM
		out	SPH,temp
		rjmp phase2next
nono1:
		cpi temp,03
		brne nono2
		ldi	temp,low(RAMEND)
		out	SPL,temp			; Initialisation de la pile à   
		ldi	temp,high(RAMEND)	; l'adresse haute de la SRAM
		out	SPH,temp
		rjmp phase3next
nono2:
		cpi temp,04
		brne nono3
		ldi	temp,low(RAMEND)
		out	SPL,temp			; Initialisation de la pile à   
		ldi	temp,high(RAMEND)	; l'adresse haute de la SRAM
		out	SPH,temp
		rjmp phase4next
nono3:
		cpi temp,05
		brne nono5
		ldi	temp,low(RAMEND)
		out	SPL,temp			; Initialisation de la pile à   
		ldi	temp,high(RAMEND)	; l'adresse haute de la SRAM
		out	SPH,temp
		rjmp phase5next

nono5:
		cpi temp,07
		brne nono6
		ldi	temp,low(RAMEND)
		out	SPL,temp			; Initialisation de la pile à   
		ldi	temp,high(RAMEND)	; l'adresse haute de la SRAM
		out	SPH,temp
		rjmp runmodenext
nono6:
		rjmp reset	;si ca se rend ici ca ne va pas bien

;**********************************************************************************************************************************************************
;**********************************************************************************************************************************************************
;************************************************************** debutcalibration **************************************************************************
;**********************************************************************************************************************************************************
debutcalibration:	
;Debut de la calibration waiting time 15 minute
;temps d'attente
		call videecran
		call posi1				;Warming & Sat
		ldi r31,high(data31*2)
		ldi r30,low(data31*2)				
		call message
		call nextline			
		call posi2				
		ldi r31,high(data3*2)  	;calibration wait 15m
		ldi r30,low(data3*2)					
		call message
		call nextline
		call tempo5s		
;allume le led 1 warming
		call WarmingLedOn
		call videecran
		call posi1				;push buitton
		ldi r31,high(data4*2)
		ldi r30,low(data4*2)				
		call message
		call nextline			
		call posi2				
		ldi r31,high(data5*2)  	;to pass
		ldi r30,low(data5*2)					
		call message
		call nextline
		call tempo5s
		call videecran
		call posi1
		ldi r31,high(data32*2)  ;waiting...
		ldi r30,low(data32*2)			
		call message
		call nextline
		ldi xh, $03
		ldi xl, $84	;metre 15x60 ic pour la version final 900 = $384
		ldi temp, 01
		sts affichesatelliteflag, temp	;flag qui permet au nombre de satellite d'etre affiché.
		wdr
		ldi temp, 0b00000011	;enleve les interrupt pending avant l'activation des interrupt. Si push button a ete poussé trop top
		store eifr,temp
		sei			;int1 seulement est activé ici pour permettre au bouton de bypasser le temps de réchaufement de l'oscillateur et serial interrupt active ausi.
		call wait	;att end le nombre de seconde qui est dans x sous routine est dans math
		clr temp
		sts affichesatelliteflag, temp	;clear le flag d'affichage des satellite
		cli
		call videecran
;ferme le led warming et active le pulse
		call WarmingLedPulse
		ret
;********************************************************************************************************************
;********************************************************************************************************************
;********************************************************************************************************************
watchdog_overflow:
	;le module gps a perdu son antenne ou a un faible signal. Nous devons rouler sans pulse gps.
	;a partir de ce moment nous ne devons plus changer le pwm
		cli
		wdr
;etein le led counter et sattelite forcement
		call CounterLedOff
		call SatLedOff
		lds temp, calibrationphase		;on confirme si nous somme en phase 7
		cpi temp, $07
		breq ondoitafficher10000000
		rjmp ghgh
ondoitafficher10000000:	;ici on a pus de pulse mais on est en phase 7. Nous prenons la derniere valeur de 10mhz connu dans le eeprom pour le pwm
		call posi1
		call nextline
		ldi r31,high(data19*2)  	;"self running..."
		ldi r30,low(data19*2)
		call message
		call posi2
		call nextline
		ldi r31,high(data33*2)  	;"10,000,000.000Hz"
		ldi r30,low(data33*2)
		call message
		call nextline
		call eepromr			;va lire la config du eeprom et se retrouve dans pwmphase6h, 6l
		lds temp, pwmphase6h	;ffff = 100 7fff = 50
		sts ocr1ah, temp
		lds temp, pwmphase6l	
		sts ocr1al, temp
		rjmp jsjs
ghgh:
		call videecran
		call posi1
		call nextline
		ldi r31,high(data18*2)  	;Ici on va chercher l'addresse momoire ou se retrouve le data à afficher.
		ldi r30,low(data18*2)		;no pulse
		call message
		call posi2
		call nextline
		ldi r31,high(data19*2)  	;;self running
		ldi r30,low(data19*2)
		call message
		call nextline
jsjs:

		ldi temp, (1<<TOV0)	;annule l'overflow pending et la future interruption par le fait meme. Faire a la main car reti est bypassé.
		out tifr0, temp
		ldi temp, (0<<CS00)	;stop counter 8 bit
		out TCCR0B,temp
		call clrallregister
		clr temp	
		out tcnt0, temp		;met le compteur a 0 au cas
		sts comptel, temp	;initialise le flag compte. Il repart a 0
		sts compteh, temp

;ici on dois attendre la detection d'un gps pulse. donc on loop ici et quand un pulse est detecté, on affiche la bonne phase et on repart la calibration

toujoursrien:
		wdr				;empeche un autre interrupt watchdog de survenir. Sinon le flag interrupt watchdog se met a 1 et un autre interrupt watchdog est excuté aussitot sei embarqué
		sbic pind, pd2
		rjmp toujoursrien

etondispatchencore:
		call videecran
;pulse detecté on affiche la bonne phase ou l'on se trouve avant de lancer le compteur.
		lds temp, calibrationphase
		cpi temp,$01
		brne zx
		rjmp phase1
zx:
		cpi temp,$02
		brne zxx
		rjmp phase2
zxx:
		cpi temp,$03
		brne zxxx
		rjmp phase3
zxxx:
		cpi temp,$04
		brne zxxxx
		rjmp phase4
zxxxx:
		cpi temp,$05
		brne zxxxxxx
		rjmp phase5
zxxxxxx:
		call affiche10000000
		rjmp runmode	;forcement 7

;watchdog off vient du datasheet
WDT_off:
		cli
		wdr
		in r16, MCUSR
		andi r16, ~(1<<WDRF)
		out MCUSR, r16
		lds r16, WDTCSR
		ori r16, (1<<WDCE) | (1<<WDE)
		sts WDTCSR, r16
		ldi r16, (0<<WDE)
		sts WDTCSR, r16
		ret
;****************************************************************** retour en mode interrupt ************************************************************
;****************************************************************** retour en mode interrupt ************************************************************
;****************************************************************** retour en mode interrupt ************************************************************
Retour_en_mode_interrupt:

		ldi temp, (1<<int1)|(0<<int0)	;deactive int0 interrup gps pulse
		out EIMSK,temp					;deactive int0 dans External Interrupt Mask Register – EIMSK
		wdr
		in temp, MCUSR			;enleve le watchdog interrupt pending avant le sei.
		andi temp, ~(1<<WDRF)
		out MCUSR, r16	
		sei ;active les interrupt (watchdog seument pour senser le pulse)
		;boucle de temps pour laisser le voltage du pwm se stabilisé (condensabeur chargé) peut etre pas nécessaire mais pour 2 secondes rien ne presse
		call seconde_tempo
		wdr
		call seconde_tempo
		wdr
		; Add delay to always start count at the same place.
pasencorepret:	;;ici on attend un pulse et part tout de suite apres. le but est de balancer le pulse de la fin pour qu'il n'arrive pas en meme temps qu'un timer ovf
		sbic pind, PD2
		rjmp pasencorepret
		wdr
pasencorepret2:
		sbis pind, PD2
		rjmp pasencorepret2
		wdr		;viens tous juste des passer a 5v
		call clrallregister
		ldi temp, 0b00000011	;enleve les interrupt pending avant l'activation des interrupt
		store eifr,temp
		ldi temp, (1<<int1)|(1<<int0)	;active int0 interrup gps pulse
		out EIMSK,temp					;active int0 dans External Interrupt Mask Register – EIMSK
		wdr	
.include "NopLoop.asm"
