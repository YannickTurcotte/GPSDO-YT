# GPSDO-YT

https://www.instructables.com/GPSDO-YT-10-Mhz-Lcd-2x16-With-LED/

Gpsdo Yannick.atsln  ---> Source file can be open with AtmelStudio 7

The nop loop is very important. It assure to take only one cycle to enter in an interrupt.
If you bypass the loop it will works. But the count will be +- .002 instead .001

# Version revision

-On version 1.5 i added some code to always start counting at same time after the pulse. Like, i dont have any pluse arriving while timer overflow sub routine.
This correct an intermittent problem where between 1,000,000.006 and 1,000,000.002 were displayed.

-I also change. When you unplug the device, this one restart at phese 4 even if a config is found. SOme time the drift is to far to go in running mode directly.



-Version 1.51 i added some routine to track when the pwm overflow. In other word, when pwm arrive to 0v or 5v. Unreachable Frequency message will be display if your OCXO isn't compatible. Some OCXO have input 0-8v instead 0-5v. In this case you will need to add an op-amp to match the OCXO. See here you will find a schematic.

-Add pwm value and 16 last know frequency when pus button is pressed. Value are from newer to older. Exemple: 00FF0000010000001. Last frequency was .000 before that was .999 and so on.

-Also enhanced the frequency finding algorithm. Arrive to run mode faster than before. Now if for exemple at phase 4 you find 2000000006. Instead to drop of 0.4 hertz at each of 200s until reach 0, i multiply the difference (here 6) by the know step of 200s. ie 1/(200x152,59uv) = 32.77 So i remove 32x6 directly from pwm to target 2000000000 directly. Doing this for phase 3,4,5 (no phase 6 anymore). But if the difference is only 1. I kept the 0.4 change.

-Also remove phase 6, yes a 15 minutes less. In fact phase 6 is now phase 5. With the new finding algorithm no need to do a step of 900s anymore. We pass directly to 1000s. Now often in run mode < 1 hour.


1.52

-Version 1.52 Some users had no good results with the new algorithm. This one was suppose to be more quicker and it is. But if your ocxo isn't moving 2hz/Volt this can be a problem. So i did 2 algorithms in one. To have the classic version and quick.

For Classic, adding a jumper to have pb5 to gnd. I programmed pb4 to 0 so just add jumper between pb4 and pb5 see picture (blue jumper)

Also, one user is using an old gps module running at 4800 baud. For him just add the red jumper will change the Baud rate to 4800 instead 9600.

Remove the averaging algorithm. After 20 good know values, an average was made and the pwm was programmed with this new number.. The goal was to have better accuracy in a long run. But after many reading of results, this was more a problem than a good thing. Often after this pwm change, the frequency was plus or minus 2 instead of 0. I have better result without this.

1.53
-Ennenced antibouncing on push button
-Fix when lost and signal reappers display problem.
-Add led display on startup

1.54
-Counting LED is now blinking when is counting. Led toggle each 1024 tcnt0 overflow. Led frequency is 19,07 hz

1.55
-remove phase1,2,3,4,5 and replace it by the pwm value.

1.56
-add serial tx data to monitor with putty or other on uart.

1.57
-Change the watchdog to 2 second instead of 1s. Some user had self running message no pulse detected. The watchdog was to tight in some cases. So I change this to 2 second and add some code to track when a pulse is missing in a different way.
-In some gps module GGA code are slightly different. In the string some have ,09, other have ,9, (no zero) I added some code to fix this and now have more compatibility with different models.
-The RUN led is also now a Hit LED. This LED turn on at the first time 10,000,000.000 is Hit. (Run mode) The LED will stay on if frequency is between + or - 0.001 If not the LED will be off until the target is hit again.

1.58
-So far, at 1000 seconds gate. Code was comparing only the 2 lasts digits. It was fair enough, result should be only +- 1 or so. But it some case, bug or miscount, uC could stick on a wrong frequency if the jump is too large. Now comparison is done on the whole one billion number. No more mistake.

If a miscount of + or - .050 happen. uC will reload the last good config from eeprom and do a recount first. If result isn't fix, uC return to 1 second gate to do a full recalibration.
-Now the count LED is only flashing at 2HZ. The LED turn on IRQ0 and turn off on next IRQ0. IRQ0 is the 1 second pulse. This LED was flashing too quick and was producing harmonic.
