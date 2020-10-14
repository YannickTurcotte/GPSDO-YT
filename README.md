# GPSDO-YT
https://www.instructables.com/GPSDO-YT-10-Mhz-Lcd-2x16-With-LED/

Gpsdo Yannick.atsln  ---> Source file can be open with AtmelStudio 7

The nop loop is very important. It assure to take only one cycle to enter and come out of an interruption.
If you bypass the loop it will works. But the count will be +- .002 instead .001
