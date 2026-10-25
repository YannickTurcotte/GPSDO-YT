prep/ folder - flashing tools
=============================

Gpsdo.hex            Firmware to flash. Always the current version - see
                     README.md at the repository root for the version history
                     and the list of changes.
program usbasp.bat   Flash Gpsdo.hex with a USBasp programmer and set the fuse
                     bits. External clock required afterwards (see the note in
                     the bat file).
program usbtiny.bat  Same, with a USBtiny programmer.
avrdude.exe + .conf  Portable avrdude used by the bat files.
jumper_settings.jpg  Classic/quick mode and baud rate jumpers.

Note: this file was named "V1_58 readme.txt" because it described that old
version. The full version history now lives in README.md at the repository
root, which is always up to date with Gpsdo.hex.
