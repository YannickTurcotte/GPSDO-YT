;V 1.5
;1.5 Add delay to always start count at the same place. Correct some display error. wrong frequency was display of +- .006 some time or .002. 
;return in phase 4 after reset.
;v1.51 ajouter unreachable frequency
;v1.52q remove moyenne sub routine. faisait un bug que pwm changeais a une valeur incorrecte. Jamais trouvé pourquoi, fonctionne en simulateur mais en vrai bug intermittent,
;de plus celle ci n'était pas nécessaire car apres analyse, je ne peux faire une moyenne car le pwm change trop d'un bord ou l'autre selon la température. Le fair de le ramener
;au millieu apres 20 1000s n'aidait en rien.
;pour atmega 48 on doit effacer le eearh dans eeprom car il n'existe pas. par contre il doit etre la pour les mega88 et 328p
;pour atmega 328. choisir le bon fichier include interrupt
;choisir aussi le bon  include pour le uC 
;1.52q et c ajouter jumper pour classis et quick ensemble (pb5 a 0) et un autre pour baud rate a 4800 pour jorge qui utilise un vieux gps module
;
;1.53 -ajouter ligne code to 512 bytes memory. (clear waitflag wasn't cleared) Mais ce n'était pas mon bug.
;dans wait, quand j'appuie sur le bouton,j'affiche le temps et la config a la place de bypasser le wait. Apres analyse, ce n'était pas le wait_flag mais plutot du rebond sur le bouton int1. 2 interrupt back to back ne fait aller directement afficher l'heure.
;j'ai donc ajouter du code pour améliorer cela
;-Un pulse manque, on passe en self running, un pulse revien, sa affiche la phase et attendait le prochain pulse qui venait jamais pour cause de signal faible. On reste sur un afficheur ph3, 60s
;J'ai donc activé le watchdog plus de tot. Au début du retour en mode interrupt.
;-Ajouter LedInit
;

;Probleme intermitent. Il semble que le pwm change. Tout va bien on a 10,000,000.000 et le coup d'apres on a 9,999,999.761 Pourtant la fois d'avant c'était bien 00
;Quand on a 00 on ne fait pas de correction. On save le pwm en eeprom et on moyenne. J'ai revérifier la routine de moyenne et elle marche bien
;Ce n'est pas non plus une trop grande correction car je l'avais limité a +-3. De plus en ayant 00 on est meme pas suppose corriger.
;Le bug arrive quelque part dans la routine qu'on save le eeprom moyenne et qu''on repart le tout. Une fois le pwm changé il est trop tard il se stabilise a .744
;et le eeprom ecris 00 pour lui ,744 est bon.
;reste a savoir si la valeur ecrite dans le eeprom quand le bug survient est bonne. Si oui je pourrais monitorer la variation de frequence. Si trop grande je recharge le pwm avec le eeprom
;8481 bonne valeur eeprom 8478 now 8466 845a 845a 8460 8457 8457 8460 8466
;8424 sur le bureau
;reactivé moyen, probleme revenu
;845D 8459 845c et boom
;A2000001ff
;782e en pwm pas bon en analysant le .eep le A2 semble survernir en affectant la moyenne. De plus j'ai trouver de 02 et fe dans le log ce qui n'arrive pas sans la moyenne.
;je la déactive.
;deactivé depuis 1 semaine jamais revenu. toujours des 00 ff ou 01. J'active la grande correction:
;1.54  ajouter counting led qui flash. Si jamais le uC plante on s'en appercoit. La led est on ou off
;1.55 enlever les phase pour les remplacer par le pwm. Nettoyer le code.
;1.56 add serial tx data to monitor with putty or other on uart.
