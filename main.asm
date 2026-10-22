;GPSDO YT
;1000s gate
.Org $0000
.include "int_atmega328p.inc"

;définition des régistres.
.def temp =R16	
.def temp2=R17

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
.equ difference_1 = $10e
.equ difference_2 = $10f
.equ difference_3 = $111
.equ difference_4 = $112
.equ difference_5 = $113
.equ sign = $114 ;1 = positif 0 = negatif
.equ toolargeflag = $115	;si difference trop grance monte a 1
.equ toolargeflag_try1 = $116 ;si encore trop grand
.equ byte = $121
.equ frebcd1 = $122
.equ frebcd2 = $123
.equ frebcd3 = $124
.equ frebcd4 = $125
.equ frebcd5 = $126
.equ frebcd6 = $127
.equ pwmphase6h = $12b		;saved in eeprom later
.equ pwmphase6l= $12c		;saved in eeprom later
.equ SerialSpeed = $12d		;saved in eeprom later
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
.equ PulseMissingCompteurL = $227
.equ PulseMissingCompteurH = $228

;memoire lattitute longitude
.equ gga = $240 ; ne rien mettre en haut de 240 car la string que je garde est assez longue. 40 bytes ou plus

;*********************************************************************************************************************
;Constante
;How to adjust those number:
;First: 5volts/0xFFFF= 76.295 uV
;So each step of pwm add 76.295uV volts on the OCXO vfc.
;You must know the frequency range of your OCXO from 0 to 5v. To know that you can use the OCXO range from step 23. Substract the large number - lowest number will give you the range.
;My double OCXO is 8.4HZ and my simple OCXO (as you saw in step 23) is 13.1HZ
;8.4HZ/5v = 1.68HZ per volt
;pwm step x hz per volt = HZ step by pwm.
;76.295uV x 1.68HZ = 128.1756 uH (not forget, for one second)
;In other word, each time the pwm is rise 1, frequency rise 128.1756 uH assuming your OCXO is lineair. If your 10mhz is around the middle (2.5v) it will be fine.
;Anoher quicker method is to take 8.4HZ/0xFFFF = 128.175uHZ

;To have a step of 0.4HZ Using 0.4 to be sure to hit the target. Each try will add or remove voltages to rise or down the count for 0.4HZ
;Classic formula
;Hertz whanted/(second x minimum step)
;Phase 1: 0.4/128.18uhz = 3120 = 0x0C30		(I choosen 0x222)
;Phase 2: 0.4/(10x128.18uhz) = 312 = 0x138	(I choosen 0x100)
;Phase 3: 0.4/(60x128.18uhz) = 52 = 0x34	(I Choosen 0x2b)
;Phase 4: 0.4/(200x128.18uhz) = 15.6 = 0x10 (I choosen 0x0c)
;Phase 5: 0.4/(1000x128.18uhz) = 3.12 = 0x3 
;Phase 6: 0.4/(1000x128.18uhz) = 3.12 = 0x1
;As you can see I have lowest the jump a bit to be sure to not mis the target. Some user use different OCXO. Little jump are maybe slower but convenient for more type OCXO.

;Quick mode is different. Quick mode is only used in phase 3,4,5,6 By default if you didn't had a jumper you are in quick mode.
;Exemple. If we have 10,000,000.005 for 1000s we have miss the target from 5 cycles for 1000s
;Same formula as classic but we use 1 hertz instead 0.4.
;Hertz whanted/(second x minimum step)
;1/(1000x128.18uHZ) = 7.80
;So if I multiply 7.80 x 5 = 39. 39 should be the number to add to hit .000 at the second count.
;This is quick mode. Insread to do many little jump, uC is doing large calculated jump to reach the target sooner. This mode need to adjust to your OCXO to work well.

;1/(60x128.18uHZ) = 130	(I choosen 109)
;1/(200x128.18uHZ) = 39 (I choosen 33)
;1/(1000x128.18uHZ) = 7.80 (I choosen 8)
;1/(1000x128.18uHZ) = 7.80 (I choosen 4)

;In regard to QuickLittleStep, it's the jump when the target is missed for +-1 only. 
;Exemple 10,000,000.001 will lower the pwm of 1 for run mode.
;Exemple 10,000,000.002 will lower the pwm of 2 x 4 for run mode. So 8
;Another exemple live from putty phase 5 .997 = 3 cycle missed. 3x8=24 Result: 0x8375 + 0d24 = 0x838D for the next try
;0x8375,1000,S=10, 9,999,999.997 Hz
;0x838D,1000,S=09,

;knowing this you can adjust those number the best of you can. I choose always a lower number just a bit to be sure the frequency wasn't jumping around the target and never hit this.


.equ Hit = 0x02 ; when the RUN led is on. For exemple for 2 if + or - .002 the led will be on outside of this off

;phase1
.equ Phase1Jump_H = 0x02	;Exemple here: 0x0222
.equ Phase1Jump_L = 0x22
;phase2
.equ Phase2Jump_H = 0x01	;Exemple here: 0x0100
.equ Phase2Jump_L = 0x00

;phase3
;Classic
.equ Phase3Jump_H = 0x00	;Exemple here: 0x002b
.equ Phase3Jump_L = 0x2b
;Quick
.equ Phase3QuickLittleStep_H = 0x00
.equ Phase3QuickLittleStep_L = 0x34
.equ Phase3QuickLargeStep = 109		;decimal 109

;phase4
;Classic
.equ Phase4Jump_H = 0x00
.equ Phase4Jump_L = 0x0c
;Quick
.equ Phase4QuickLittleStep_H = 0x00
.equ Phase4QuickLittleStep_L = 0x10
.equ Phase4QuickLargeStep =	33		;decimal 33

;phase5
;Classic
.equ Phase5Jump_H = 0x00
.equ Phase5Jump_L = 0x03
;Quick
.equ Phase5QuickLittleStep_H = 0x00
.equ Phase5QuickLittleStep_L = 0x03
.equ Phase5QuickLargeStep = 0x08

;run
;classic
.equ Phase6Jump_H = 0x00
.equ Phase6Jump_L = 0x01
;Quick
.equ Phase6QuickLittleStep_H = 0x00
.equ Phase6QuickLittleStep_L = 0x01
.equ Phase6QuickLargeStep = 0x04
;invert output
.equ Invert=0 ; 0 for normal 1 to inverse pwm output. Routine is in Math.inc
.equ EepromStartPointer = $03		;The beginning where last frequency will be saved. 0-1 = pwm 2=serial speed
.eseg 
.db $9f,$19 ;genere un fichier eeprom lors de la compilation avec les valeurs de .eseg

.CSEG	;code segment. 
.include "m328pdef.inc"		;instruction jmp utiliser pour interrupt
.include "macros.inc"
.include "afficheur.asm"
.include "math.inc"
.include "eeprom.asm"
.include "serial.asm"

;***********************************************************************************
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
;interrupt
		ldi temp, (0<<int0)|(1<<int1)	;active int1 push button seulement pour commencer. 
		out EIMSK,temp		;active int1 dans External Interrupt Mask Register – EIMSK
		ldi temp, (1<<ISC01)|(1<<ISC00)|(1<<ISC11)|(0<<ISC10)	;falling edge les 2
		sts eicra, temp
;initialisation du pointeur de eeprom
		ldi temp, EepromStartPointer	;on commence a ecrire a l'adresse 3, non 2. On garde 0,1 pour le pwm config et 2 pour serial speed
		sts eeprompointer, temp
;init flag
		;tous les flags sont a 0 par ClrAllMemory
;init afficheur
		call reset_afficheur
;check for classicmode or quick mode by sensong jumper pb5. if pb5 is 0 (jumper on) = classic.  1 = quick (jumper off)
		sbis pinb, pb5	;si jumper is on saute la ligne
		rjmp classic
		ldi temp, 1
		sts QuickOrClassic, temp		;set the flag with jumper setting
		rjmp QuickOrClassicEnd
classic:
		clr temp
		sts QuickOrClassic, temp
QuickOrClassicEnd:
;Displaying Version quick mode
		call videecran
		call posi1
		lds temp, QuickOrClassic		;read flag previously set
		cpi temp, 1
		brne classicmode1
		ldi r31,high(data7*2)  		;"    GPSDO YT    " (version affichee via data1/data2)    Ici on va chercher l'addresse mémoire ou se retrouve le data à afficher.
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
;Displaying Version classic mode
		ldi r31,high(data7*2)  		;"    GPSDO YT    " (version affichee via data2)    Ici on va chercher l'addresse mémoire ou se retrouve le data à afficher.
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
		call eepromr			;va lire la config du eeprom et se retrouve dans pwmphase6h, 6l read 0,1,2 0-1 for pwm value and 2 for serial
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
		ldi temp, $06				;Nul besoin de recommencer a phase 1. ici je met 6 et plus loin je l'envoie dans la phase que je veux que ca commence. pour le moment  c'est 4. 200s
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
;compteurs and init serial
;*********************************************************************************************************************************
;**************************************************** compteurs timer0 ***********************************************************
;*********************************************************************************************************************************
ytyt:
;init serial uart
		call USART_Init
		call nextline
		call tx
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
		ldi temp, (0<<WDE)|(1<<WDIE)|(0<<wdp3)|(1<<wdp2)|(1<<wdp1)|(1<<wdp0) ;enable watchdog 2s. interrupt seulement pas de reset
		sts WDTCSR,temp

;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;on est ou ? On regarde on commence a quel phase.... Run ou au debut ?
		lds temp, calibrationphase
		cpi temp, $06
		breq onpassedirectarun	;ca n'égalle pas ff donc ya une valeur la config a déja été fait on passe en mode run
		rjmp phase1				;sinon on est en phase 1
onpassedirectarun:
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
phase1next:
		;revien ici avec valeur de frequence pour une seconde
		call compare		;Le resultat est dans frequence et on compare avec la frequence selon la phase. Difference en cycle est dans difference_1 a 5
		call testhit		;V1.61: Z=1 si difference_1..5 tous a zero (vrai hit, plus seulement le LSB)
		breq nextphase	;c'est égale on passe a la phase suivante
		rjmp correction		;sign (1=trop haute, 0=trop basse) est appliqué par la routine commune (V1.60)
nextphase:
		call awesome  ;posi fin + message
		call tempo5s
		rjmp phase2

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
		call compare		;Le resultat est dans frequence et on compare avec la frequence selon la phase. Difference en cycle est dans difference_1 a 5
		call testhit		;V1.61: Z=1 si difference_1..5 tous a zero (vrai hit, plus seulement le LSB)
		breq nextphase2	;c'est égale on passe a la phase suivante
		rjmp correction		;sign (1=trop haute, 0=trop basse) est appliqué par la routine commune (V1.60)
nextphase2:
		call awesome
		call tempo5s
		rjmp phase3

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
		call compare		;Le resultat est dans frequence et on compare avec la frequence selon la phase. Difference en cycle est dans difference_1 a 5
		call testhit		;V1.61: Z=1 si difference_1..5 tous a zero (vrai hit, plus seulement le LSB)
		breq nextphase3	;c'est égale on passe a la phase suivante
		rjmp correction		;sign (1=trop haute, 0=trop basse) est appliqué par la routine commune (V1.60)
nextphase3:
		call awesome
		call tempo5s
		lds r19, ocr1ah	;kept in eeprom
		lds r18,ocr1al
		sts pwmphase6h, r19
		sts pwmphase6l, r18
		call eepromw
		rjmp phase4

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
		call compare		;Le resultat est dans frequence et on compare avec la frequence selon la phase. Difference en cycle est dans difference_1 a 5
		call testhit		;V1.61: Z=1 si difference_1..5 tous a zero (vrai hit, plus seulement le LSB)
		breq nextphase4	;c'est égale on passe a la phase suivante
		rjmp correction		;sign (1=trop haute, 0=trop basse) est appliqué par la routine commune (V1.60)
nextphase4:
		call awesome
		call tempo5s
		lds r19, ocr1ah	;kept in eeprom
		lds r18,ocr1al
		sts pwmphase6h, r19
		sts pwmphase6l, r18
		call eepromw
		rjmp phase5

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
		call eepromwritebytes	;ecris la frequence_1 trouvé dans eeprom commence a l'adresse 3 et incremente pour le prochain tour.
		call compare		;Le resultat est dans frequence et on compare avec la frequence selon la phase. Difference en cycle est dans difference_1 a 5
		call testhit		;V1.61: Z=1 si difference_1..5 tous a zero (vrai hit, plus seulement le LSB)
		breq nextphase5	;c'est égale on passe a la phase suivante
		rjmp correction		;sign (1=trop haute, 0=trop basse) est appliqué par la routine commune (V1.60, checkrunled inclus pour cette phase)
nextphase5:
		call awesome
		call tempo5s
		lds r19, ocr1ah	;kept in eeprom
		lds r18,ocr1al
		sts pwmphase6h, r19
		sts pwmphase6l, r18
		call eepromw
		call RunLedOn ;allume le led RUN
		rjmp runmode

;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***************************************************        Run      ***************************************************************
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***********************************************************************************************************************************
;pour 1000 secondes. Por avoir un pas de + ou - 0.4HZ  0.4/(1000x152.59uhz) = 2,6= 2 mais en mode run on dessend au plus bas = 1
runmode:	;Formule:  FFFF/(frMax-Frmin) X (10E6-Frmin)
		call afficherunmode		;comprend le pwm, le ,1000,
		call affichesatellite2	;s=xx
		ldi temp, $06
		sts calibrationphase, temp
		ldi temp,$e8 ;1000 secondes
		sts echantillon_timel, temp	;nombre de seconde a echantilloner
		ldi temp, $3
		sts echantillon_timeh,temp
		rjmp Retour_en_mode_interrupt

runmodenext:
		call eepromwritebytes	;track tous les valeur dans eeprom adresse 03 to ff et tourne en boucle
		call compare		;Le resultat est dans frequence et on compare avec la frequence de phase (reference 10E9 ici). Difference en cycle est dans difference_1 à 5
		call testhit		;V1.61: Z=1 si difference_1..5 tous a zero (vrai hit, plus seulement le LSB)
		breq nextphase7_	;c'est égale on passe a la phase suivante

		call compare2			;compare si la difference est torp grande et met le flag a 1 si oui.
		lds temp,toolargeflag	;sense si la difference est trop grande
		cpi temp, $0
		breq cestgood
		call affichestall
		call tempo5s
		call runledoff
		lds temp,toolargeflag_try1
		cpi temp,1
		breq mustrestart
		call eepromr			;reload eeprom to be sure et retry.
		ldi temp, 0x01
		sts toolargeflag_try1, temp
		rjmp runmode
mustrestart:
		ldi temp, 1
		sts calibrationphase, temp
		clr temp
		sts toolargeflag_try1,temp
		rjmp phase1

nextphase7_ :rjmp nextphase7
cestgood:
		clr temp						;reset toolargeflag_try1
		sts toolargeflag_try1,temp
		rjmp correction		;sign (1=trop haute, 0=trop basse) est appliqué par la routine commune (V1.60, checkrunled inclus)

nextphase7:
		call RunLedOn
		call afficherunmode
		call affichesatellite2
		lds r19, ocr1ah		;10,000,000.000 vient d'etre compté ici on conserve la valeur trouvé dans l'eeprom.
		lds r18,ocr1al
		sts pwmphase6h, r19
		sts pwmphase6l, r18
		clr temp						;reset toolargeflag_try1
		sts toolargeflag_try1,temp
		call eepromw
		rjmp Retour_en_mode_interrupt

;*****************************************************************************************************************************************
;*****************************************************************************************************************************************
;*********************************************************   testhit *********************************************************************
;*****************************************************************************************************************************************
;V1.61: teste si la frequence comptee est EXACTEMENT egale a la reference de la phase.
;Avant, seul difference_1 (le LSB) etait teste: une erreur de 256, 512... cycles (LSB a zero)
;passait pour un hit parfait et, en mode run, sauvegardait une mauvaise config dans l'eeprom.
;Entree: difference_1..5 remplis par compare. Sortie: Z = 1 si vrai hit (tous a zero).
;Corrige aussi le LED run via CheckRunLed qui teste difference_2 maintenant.
testhit:
		lds temp, difference_1
		lds temp2, difference_2
		or temp, temp2
		lds temp2, difference_3
		or temp, temp2
		lds temp2, difference_4
		or temp, temp2
		lds temp2, difference_5
		or temp, temp2
		ret

;*****************************************************************************************************************************************
;*********************************************************   correction commune **********************************************************
;*****************************************************************************************************************************************
;V1.60: une seule routine remplace les 8 blocs de correction (phases 1 a 6, trop haute / trop basse).
;Appel APRES compare. sign = 1 → frequence trop haute (on descend le pwm), sign = 0 → trop basse (on monte le pwm).
;Les pas et la routine d'affichage sont lus dans PhaseTable selon calibrationphase:
;- classic (jumper pb5): pas fixe Jump
;- quick (phases 3 a 6 seulement): si l'erreur vaut 1 → QuickLittleStep, sinon erreur x QuickLargeStep
;V1.61: l'erreur est maintenant sur 16 bits (difference_2:difference_1). Avant elle etait tronquee
;a 8 bits (frequence_1 = erreur mod 256), donc fausse des 256 cycles d'ecart (saut faux, ou saut nul
;si l'erreur etait un multiple exact de 256). Si le pas calcule depasse 65535 (correction plus grande
;que la portee complete du pwm) → unreachable.
;- debordement du pwm (0000 ou FFFF franchi) → unreachable
;Terminaison par rjmp Retour_en_mode_interrupt (pas de ret, comme les blocs originaux).
correction:
		lds temp, calibrationphase		;phase 1 a 6 → index 0 a 5
		subi temp, 1
		lsl temp
		lsl temp
		lsl temp						;x 8 : 8 bytes par entree de table
		ldi zh, high(PhaseTable*2)
		ldi zl, low(PhaseTable*2)
		add zl, temp
		clr temp
		adc zh, temp
		lpm r18, z+						;Jump_L (classic)
		lpm r19, z+						;Jump_H
		lpm r20, z+						;QuickLittleStep_L
		lpm r21, z+						;QuickLittleStep_H
		lpm r22, z+						;QuickLargeStep
		lpm r23, z+						;flags: bit0 = checkrunled, bit1 = mode quick disponible
		lpm r24, z+						;adresse (mot) de la routine d'affichage de la phase
		lpm r25, z+

;calcul du pas selon classic/quick (le sens, lui, est applique plus bas a partir de sign)
		lds temp, QuickOrClassic
		cpi temp, 1
		brne corr_classic				;jumper pb5 = classic → pas fixe
		sbrs r23, 1						;bit1 = 0 (phases 1 et 2) → pas fixe meme en mode quick
		rjmp corr_classic
;V1.61: magnitude de l'erreur sur 16 bits = difference_2:difference_1. Avant: frequence_1 seul,
;donc l'erreur etait tronquee a 8 bits (mod 256) et les corrections etaient fausses des 256 cycles.
;La reference des phases 3 a 6 a un LSB a 0, donc difference EST l'erreur en cycles.
corr_quick:
		lds temp, difference_1
		lds temp2, difference_2
		cpi temp, 1
		brne corr_quick_multi
		cpi temp2, 0
		brne corr_quick_multi
		movw temp, r20					;erreur de 1 → petit pas
		rjmp corr_applique
corr_quick_multi:
;pas = erreur (16 bits) x QuickLargeStep → produit 24 bits b2:b1:b0
		mov r20, temp					;erreur L
		mov r21, temp2					;erreur H
		mul r20, r22					;errL x step → r1(h):r0(l)
		mov r18, r0						;b0 (poids faible du produit)
		mov r19, r1						;m1h
		mul r21, r22					;errH x step → r1(h):r0(l) = m2
		add r19, r0						;b1 = m1h + m2l
		clr temp
		adc temp, temp					;retenue du b1
		add temp, r1					;b2 = m2h + retenue
		tst temp
		brne corr_unreachable			;produit > 65535: la correction demandee depasse la portee complete du pwm
		movw temp, r18					;pas 16 bits = b0(L):b1(H)
		rjmp corr_applique
corr_classic:
		movw temp, r18					;pas fixe Jump
corr_applique:
;monte ou descend le pwm et detecte le debordement (0000 ou FFFF franchi)
		lds xh, ocr1ah
		lds xl, ocr1al
		mov r18, xh						;copie de l'ancienne valeur pour detecter le debordement
		mov r19, xl
		lds r0, sign
		tst r0
		breq corr_monte
;Frequence_trop_haute: il faut diminuer
		sub xl, temp
		sbc	xh, temp2
		cp xl, r19						;compare avec 0. Si plus haut l'ocxo est incompatible. Frequency unreachable
		cpc xh, r18						;Je vien de soustraire ca devrait etre forcement plus bas. Je verifie. Si plus haut on a defoncé.
		brsh corr_unreachable
		rjmp corr_sauve
corr_monte:
		add xl, temp
		adc xh, temp2
		cp xl, r19						;si plus bas c'est qu'on a fait le tour, on a défoncé... unreachable
		cpc xh, r18
		brlo corr_unreachable
corr_sauve:
		sts ocr1ah, xh
		sts ocr1al, xl
		sbrc r23, 0						;phases 5 et 6: compare marge d'erreur et allume ou ferme le led run
		call checkrunled
		movw zl, r24					;affiche le pwm + la phase (affichephase1 a 5 ou afficherunmode)
		icall
		call affichesatellite2
		rjmp Retour_en_mode_interrupt
corr_unreachable:
		rjmp unreachable

;************************************************************************************************
;V1.60: table des pas de correction par phase. 8 bytes par entree, phase 1 a 6 (lue par correction):
;  byte0-1 : Jump_L:Jump_H        pas fixe du mode classic
;  byte2-3 : QuickLittleStep_L:H  pas utilise en quick quand l'erreur (mod 256) vaut 1
;  byte4   : QuickLargeStep       en quick, le pas = erreur x cette valeur
;  byte5   : flags: bit0 = 1 → call checkrunled (phases 5 et 6), bit1 = 1 → mode quick disponible (phases 3 a 6)
;  byte6-7 : adresse (mot) de la routine d'affichage de la phase, pour icall
;************************************************************************************************
PhaseTable:
		.db Phase1Jump_L, Phase1Jump_H, 0, 0, 0, 0
		.dw affichephase1
		.db Phase2Jump_L, Phase2Jump_H, 0, 0, 0, 0
		.dw affichephase2
		.db Phase3Jump_L, Phase3Jump_H, Phase3QuickLittleStep_L, Phase3QuickLittleStep_H, Phase3QuickLargeStep, 2
		.dw affichephase3
		.db Phase4Jump_L, Phase4Jump_H, Phase4QuickLittleStep_L, Phase4QuickLittleStep_H, Phase4QuickLargeStep, 2
		.dw affichephase4
		.db Phase5Jump_L, Phase5Jump_H, Phase5QuickLittleStep_L, Phase5QuickLittleStep_H, Phase5QuickLargeStep, 3
		.dw affichephase5
		.db Phase6Jump_L, Phase6Jump_H, Phase6QuickLittleStep_L, Phase6QuickLittleStep_H, Phase6QuickLargeStep, 3
		.dw afficherunmode

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

;*************
;*************
CheckRunLed:
		lds temp2, difference_2	;V1.61: si difference_2 != 0, l'erreur depasse 255 → pas un hit
		tst temp2
		brne led_pas_un_hit
		lds temp2, difference_1	;ramasse la frequence obtenu
		cpi temp2, Hit+1			;compare avec marge d'erreur accepté. J'ajoute +1 pour coriger.
		brlo met_a_on
led_pas_un_hit:
		call RunLedOff
		rjmp No_
met_a_on:
		call RunLedOn
No_:
		ret

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
TIM0_OVF:	;viens ici a APRES chaque 256 clock a l'aide le int overflow. 
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


;Il faut un moyen de savoir si il manque un pulse ou non. On vient ici a chaque 256 clk. Donc chaque 25.6us. 1s/256us = 39062.5 fois par seconde (0x9896)
;Donc si le compteur 16 bits Overflow c'est que forcement c'est trop long car pour 2 seconde = 78125 qui est superieur a 65536.
;On laisse le compteur monter et si overflow = trop long = pulse missing et je l'envoie direct dans watchdog_overflow. Je voulais faire une boucle sans fin
;et laisser le watchdog embarquer. Mais apres test le watchdog embarque pas ici. Surement parque nous somme déja dans un interrupt.

		push xh
		push xl
		load xh, PulseMissingCompteurH
		load xl, PulseMissingCompteurL
		adiw xh:xl, $01
		breq troploin	;si le flag 0 est la on branche.
		store PulseMissingCompteurH, xh
		store PulseMissingCompteurl, xl
		pop xl
		pop xh
		rjmp onjump
troploin:
		rjmp Pulse_Missing ;(watchdog overflow) le watchdog va embarquer----> Non on est deja dans une routine interupt
onjump:
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
;reset le compteur de monitoring du pulse
		clr temp
		sts PulseMissingCompteurH, temp
		sts PulseMissingCompteurl, temp


	;peux ajouter du code ici sans changer le resultat du count mais ne doit pas depasser 256 clock
	;pourquoi... parce que ici les interruption sont deactivé. Si ca prend plus que 256 clock le compteur tcnt0 va faire un ou plusieur overflow mais ne sera
	;pas pris en compte car il y a un buffer de seulement 1 interruption.

;toggle le led counter
		sbis portd, 6
		rjmp onturnon
		call CounterLedOff
		rjmp vbvb
onturnon:
		call CounterLedOn
vbvb:
	
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
		cpi temp,06
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
Pulse_Missing:
	;le module gps a perdu son antenne ou a un faible signal. Nous devons rouler sans pulse gps.
	;a partir de ce moment nous ne devons plus changer le pwm
		cli
		wdr
;etein le led counter et sattelite forcement
		call CounterLedOff
		call SatLedOff
		call RunLedOff
		lds temp, calibrationphase		;on confirme si nous somme en phase 6
		cpi temp, $06
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
		rjmp runmode	;forcement 6

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
