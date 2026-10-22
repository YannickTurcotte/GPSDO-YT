@echo off
avrdude -c usbtiny -p m328p -B12 -U flash:w:Gpsdo.hex -F
avrdude -c usbtiny -p m328p -U lfuse:w:0xCF:m -U hfuse:w:0xD9:m -U efuse:w:0xFC:m -F

echo If progmmation is ok, make sure you have a external clock to run the uC. 
echo Now with fuse bits programmed YOU NEED an external clock
echo to run uC or to run futur programmation.
pause
rem -B12 is for program speed
