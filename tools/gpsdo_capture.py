#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gpsdo_capture.py - Capture le flux serie du GPSDO-YT vers un CSV horodate.

Usage:
    python gpsdo_capture.py COM3 [baud] [-o log.csv]
    python gpsdo_capture.py --list

Le port serie du GPSDO sort la meme chose que ce qui s'affiche sur l'ecran
(frequence mesuree, pwm, satellites). Ce script enregistre chaque ligne telle
quelle, avec un horodatage du PC, dans un CSV a 3 colonnes:
    timestamp,epoch,brut

Arreter avec Ctrl-C (le CSV est flushé a chaque ligne, rien n'est perdu).
Le baud rate est celui detecte par le GPSDO au demarrage (9600 par defaut).

Analyse ensuite avec gpsdo_adev.py.
"""

import argparse
import csv
import sys
import time
from datetime import datetime


def list_ports():
    try:
        from serial.tools import list_ports
    except ImportError:
        sys.exit("pyserial manquant:  python -m pip install pyserial")
    ports = list(list_ports.comports())
    if not ports:
        print("Aucun port serie trouve.")
        return
    for p in ports:
        print("%s  -  %s" % (p.device, p.description))


def main():
    ap = argparse.ArgumentParser(description="Capture le flux serie du GPSDO-YT vers un CSV.")
    ap.add_argument("port", nargs="?", help="port COM (ex: COM3)")
    ap.add_argument("baud", nargs="?", type=int, default=9600, help="baud rate (defaut: 9600)")
    ap.add_argument("-o", "--output", default=None, help="fichier CSV de sortie (defaut: gpsdo_AAAAMMJJ_HHMMSS.csv)")
    ap.add_argument("--list", action="store_true", help="liste les ports serie disponibles et quitte")
    args = ap.parse_args()

    if args.list:
        list_ports()
        return
    if not args.port:
        ap.error("indique un port (ex: COM3) ou --list")

    try:
        import serial
    except ImportError:
        sys.exit("pyserial manquant:  python -m pip install pyserial")

    if args.output is None:
        args.output = "gpsdo_%s.csv" % datetime.now().strftime("%Y%m%d_%H%M%S")

    try:
        ser = serial.Serial(args.port, args.baud, timeout=2)
    except serial.SerialException as e:
        sys.exit("Impossible d'ouvrir %s: %s" % (args.port, e))

    print("Capture sur %s @ %d bauds -> %s   (Ctrl-C pour arreter)" % (args.port, args.baud, args.output))
    n = 0
    t0 = time.time()
    try:
        with open(args.output, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["timestamp", "epoch", "brut"])
            while True:
                brut = ser.readline().decode("latin-1", "replace").rstrip("\r\n")
                if brut:
                    w.writerow([datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                                "%.3f" % time.time(), brut])
                    f.flush()
                    n += 1
                    if n % 100 == 0:
                        print("%d lignes, %.1f h" % (n, (time.time() - t0) / 3600.0))
    except KeyboardInterrupt:
        pass
    finally:
        ser.close()
    print("\n%d lignes en %.2f h -> %s" % (n, (time.time() - t0) / 3600.0, args.output))


if __name__ == "__main__":
    main()
