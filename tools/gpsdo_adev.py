#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gpsdo_adev.py - Frequence vs temps + deviation d'Allan a partir d'un log GPSDO-YT.

Usage:
    python gpsdo_adev.py log.csv [options]
    python gpsdo_adev.py capture_brute.txt -o resultat --detrend

Le log peut etre:
  - le CSV produit par gpsdo_capture.py (colonnes: timestamp,epoch,brut)
  - un fichier texte brut du port serie (horodatage absent)
  - un vieux log PuTTY brut (=~=~=~= header): les reboots, self-running,
    gates perdues et ecrans du bouton decoupent le log en sections, et
    l'ADEV est calculee sur la plus longue section continue

Ce que le script considere comme un echantillon valable:
  une frequence "10,000,000.000Hz" IMMEDIATEMENT suivie d'un pwm "0x####,1000,"
  (l'ecran statique self-running affiche aussi 10,000,000.000Hz mais sans pwm:
  il est ignore automatiquement). La porte de ces echantillons est 1000 s exactement,
  car le compteur vise 1e9 cycles par porte cadencee par le 1PPS GPS.

Reference: la deviation d'Allan est calculee sur y_i = (f_i - 1e7)/1e7
via la phase cumulee x_i = tau0 * somme(y), estimateur d'Allan superpose.
Plancher de ton setup: +-0.001 Hz = 1e-10 par echantillon -> sigma plancher
d'environ 3e-11 a tau = 1000 s (quantification + jitter du 1PPS).

Options:
  -o PREFIX         prefixe des sorties (defaut: prefixe du fichier d'entree)
  --skip N          ignore les N premiers echantillons (fin de calibration phase 5)
  --detrend         retire la derive lineaire avant l'ADEV (utile en self-running)
  --gap S           ecart max entre 2 echantillons pour etre contigus (defaut 1100 s)
"""

import argparse
import bisect
import csv
import os
import re
import sys

import numpy as np

import matplotlib
matplotlib.use("Agg")          # fonctionne sans ecran; le PNG est toujours sauvegarde
import matplotlib.pyplot as plt

# Groupement strict des milliers: '10,000,000.005' OK, mais '12,10,000,000.005'
# (le '12,' du nombre de satellites colle a la freq sur la meme ligne) est refuse.
# L'ESPACE avant 'Hz' est obligatoire: le firmware envoie '...005 Hz' pour une vraie
# mesure (tx $20 avant Hz dans Latch) mais '10,000,000.000Hz' SANS espace pour
# l'ecran statique self-running (message data33) -> ce dernier est exclude d'office.
RE_FREQ = re.compile(r"(\d{1,3}(?:,\d{3})+\.\d{3}|\d+\.\d{3}) Hz")
RE_PWM = re.compile(r"0x([0-9A-Fa-f]{4})")
RE_GATE = re.compile(r",\s*1000\s*s?\s*,")
RE_SAT = re.compile(r"S\s*=\s*(\d{1,2})")

TAU0 = 1000.0        # porte en secondes, exacte par construction
FREF = 1e7           # 10 MHz


def lire_log(chemin):
    """Retourne (texte_complet, epochs_par_ligne).

    epochs_par_ligne[i] = epoch du PC de la ligne i, ou None si inconnu (mode brut).
    """
    epochs = []
    morceaux = []
    with open(chemin, "r", encoding="utf-8", errors="replace") as f:
        prem = f.readline()
        f.seek(0)
        csv_mode = prem.startswith("timestamp") or ("epoch" in prem and prem.count(",") >= 2)
        if csv_mode:
            for row in csv.reader(f):
                if len(row) < 3:
                    continue
                morceaux.append(row[2])
                try:
                    epochs.append(float(row[1]))
                except ValueError:
                    epochs.append(None)
        else:
            for ligne in f:
                morceaux.append(ligne.rstrip("\r\n"))
                epochs.append(None)
    return "\n".join(morceaux), epochs


def extraire_echantillons(texte, epochs, pos_lignes):
    """Echantillons = freq '10,000,000.005 Hz' de porte 1000 s uniquement.

    Format reel du GPSDO (une ligne par porte):
        0x86DD,1000,S=12,10,000,000.005 Hz
    Le pwm imprime sur la meme ligne juste AVANT la frequence est celui qui a
    produit la mesure (le GPSDO imprime la freq a la fin de la porte, puis le
    pwm apres correction, donc ligne N = pwm de la porte N + freq de la porte N).
    Les phases 1s/10s/60s/200s s'impriment sans decimales ni 'Hz' -> jamais
    confondues. L'ecran statique self-running '10,000,000.000Hz' n'a pas de pwm
    -> ignore. Secours: si aucun pwm avant (capture coupee en plein milieu),
    on cherche apres la frequence.
    """
    ech = []
    matches = list(RE_FREQ.finditer(texte))
    for i, m in enumerate(matches):
        f = float(m.group(1).replace(",", ""))
        debut_avant = matches[i - 1].end() if i > 0 else 0
        fin_apres = matches[i + 1].start() if i + 1 < len(matches) else min(len(texte), m.end() + 250)

        # 1) pwm sur la meme ligne, juste avant la freq (pairage exact)
        avant = texte[debut_avant:m.start()]
        pwm = None
        for pm in RE_PWM.finditer(avant):
            pwm = pm              # derniere occurrence = celle de cette ligne
        fenetre = None
        if pwm and RE_GATE.search(avant[pwm.end():]):
            fenetre = avant[pwm.end():]

        # 2) secours: pwm apres la freq (debut de capture coupe en plein milieu)
        if fenetre is None:
            apres = texte[m.end():fin_apres]
            pwm = RE_PWM.search(apres)
            if pwm and RE_GATE.search(apres):
                fenetre = apres

        if fenetre is None:
            continue  # pas de pwm + porte 1000 s associee
        sat = RE_SAT.search(fenetre)
        idx_ligne = 0
        for k in range(len(pos_lignes) - 1):
            if pos_lignes[k] <= m.start() < pos_lignes[k + 1]:
                idx_ligne = k
                break
        ep = epochs[idx_ligne] if idx_ligne < len(epochs) else None
        ech.append((ep, f, pwm.group(1).upper(), sat.group(1) if sat else "", m.start()))
    return ech


# Ruptures structurelles d'un log brut (sans horodatage): tout ce qui signale
# que des portes ont ete perdues ou que le GPSDO a redemarre.
RE_RUPTURE = re.compile(
    r"(No config found|Config found|Set PWM to 50%|Self running|No pulse|"
    r"Last Frequency|Config = 0x|\d{2}:\d{2}:\d{2} UTC|"
    r"0x[0-9A-Fa-f]{4},1000,S=\d{1,2},\n)")


def ruptures_brutes(texte):
    """Positions des ruptures (reboot, self-running, gate sans resultat, ecrans bouton)."""
    return [m.start() for m in RE_RUPTURE.finditer(texte)]


def plus_longue_sequence_contigue(ech, gap_max):
    """Decoupe selon les trous horaires (redemarrage, pulse perdu). Garde la plus longue.

    Retourne aussi le nombre d'echantillons jetes. Si les epochs sont inconnus
    (mode texte brut), tout est suppose contigu.
    """
    if not ech or ech[0][0] is None:
        return ech, 0
    runs = [[0]]
    for i in range(1, len(ech)):
        if ech[i][0] - ech[i - 1][0] <= gap_max:
            runs[-1].append(i)
        else:
            runs.append([i])
    meilleur = max(runs, key=len)
    jetes = len(ech) - len(meilleur)
    return [ech[i] for i in meilleur], jetes


def allan_superpose(y, tau0):
    """Deviation d'Allan superposee a partir des frequences fractionnaires.

    Passe par la phase cumulee x = tau0 * somme(y), puis l'estimateur standard:
    sigma^2(m*tau0) = <(x[i+2m] - 2*x[i+m] + x[i])^2> / (2*(m*tau0)^2)
    """
    n = len(y)
    x = tau0 * np.cumsum(y)
    taus = []
    adevs = []
    for m in range(1, n // 2 + 1):
        d = x[2 * m:] - 2.0 * x[m:-m] + x[:-2 * m]
        if d.size == 0:
            break
        taus.append(m * tau0)
        adevs.append(float(np.sqrt(np.mean(d ** 2) / (2.0 * (m * tau0) ** 2))))
    return np.array(taus), np.array(adevs)


def main():
    ap = argparse.ArgumentParser(description="Frequence + deviation d'Allan depuis un log GPSDO-YT.")
    ap.add_argument("log", help="CSV de gpsdo_capture.py ou texte brut du port serie")
    ap.add_argument("-o", "--output", default=None, help="prefixe des fichiers de sortie")
    ap.add_argument("--skip", type=int, default=0, help="ignore les N premiers echantillons")
    ap.add_argument("--detrend", action="store_true", help="retire la derive lineaire avant l'ADEV")
    ap.add_argument("--gap", type=float, default=1100.0, help="ecart max entre echantillons contigus (s)")
    args = ap.parse_args()

    texte, epochs = lire_log(args.log)
    if not texte:
        sys.exit("Fichier vide ou illisible: %s" % args.log)

    lignes = texte.split("\n")
    pos_lignes = [0]
    for l in lignes:
        pos_lignes.append(pos_lignes[-1] + len(l) + 1)

    ech = extraire_echantillons(texte, epochs, pos_lignes)
    if not ech:
        sys.exit("Aucun echantillon trouve (une mesure = freq '... Hz' avec son pwm '0x####,1000,').\n"
                 "Verifie que le GPSDO est en mode run (porte 1000 s) et que le log n'est pas vide.")

    if ech[0][0] is not None:
        # CSV horodate: decoupe selon les trous de temps
        ech, jetes = plus_longue_sequence_contigue(ech, args.gap)
        note_segment = ""
        seg_count = 0
    else:
        # log brut sans horodatage: decoupe aux ruptures structurelles
        # (reboots, self-running, gates perdues, ecrans du bouton)
        rupt = ruptures_brutes(texte)
        groupes = {}
        for s in ech:
            groupes.setdefault(bisect.bisect_left(rupt, s[4]), []).append(s)
        meilleur = max(groupes.values(), key=len)
        jetes = len(ech) - len(meilleur)
        seg_count = len(groupes)
        note_segment = " (log brut: %d sections separees par des ruptures, ADEV sur la plus longue)" % seg_count
        ech = meilleur
    if args.skip:
        ech = ech[args.skip:]
    n = len(ech)
    if n < 10:
        sys.exit("Seulement %d echantillons contigus: il faut au moins 10 pour un ADEV utile." % n)

    f = np.array([e[1] for e in ech], dtype=float)
    pwm = [e[2] for e in ech]
    duree_h = n * TAU0 / 3600.0
    prefixe = args.output or os.path.splitext(args.log)[0]

    ecart_hz = f - FREF
    y = ecart_hz / FREF

    y_adev = y
    note_detrend = ""
    if args.detrend:
        t_h = np.arange(n) * TAU0 / 3600.0
        c = np.polyfit(t_h, y, 1)
        y_adev = y - np.polyval(c, t_h)
        note_detrend = " (derive lineaire retiree: %.3e /h)" % c[0]

    taus, adevs = allan_superpose(y_adev, TAU0)

    # ---- CSV des resultats ADEV
    csv_out = prefixe + "_adev.csv"
    with open(csv_out, "w", newline="", encoding="utf-8") as fo:
        w = csv.writer(fo)
        w.writerow(["tau_s", "tau_h", "allan_dev", "paires"])
        for i, (t, a) in enumerate(zip(taus, adevs)):
            w.writerow(["%.0f" % t, "%.2f" % (t / 3600.0), "%.6e" % a, n - 2 * (i + 1)])

    # ---- figure 2 panneaux (libelles en anglais pour publication/Instructable)
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(9, 7))
    t_h = np.arange(1, n + 1) * TAU0 / 3600.0
    l_freq, = ax1.plot(t_h, ecart_hz, ".-", ms=3, lw=0.6, color="#0b6fa4")
    ax1.axhline(0, color="k", lw=0.5)
    ax1.set_xlabel("time (hours)")
    ax1.set_ylabel("f - 10 MHz (Hz)")
    titre = "GPSDO-YT - %d samples, %.1f h, 1000 s gate%s" % (n, duree_h, note_detrend)
    if seg_count > 1:
        titre += " - longest of %d continuous sections" % seg_count
    ax1.set_title(titre)
    ax1.grid(True, which="both", alpha=0.3)

    # trace du PWM (DAC) sur un axe secondaire: montre l'action integrale du servo
    # (une rampe lente = derive de l'OCXO que la boucle compense)
    pwm_val = np.array([int(e[2], 16) for e in ech], dtype=float)
    axt = ax1.twinx()
    l_pwm, = axt.plot(t_h, pwm_val, "-", lw=0.9, color="#d6604d", alpha=0.8)
    axt.set_ylabel("PWM (DAC counts)", color="#a33e33")
    axt.tick_params(axis="y", colors="#a33e33")
    ax1.legend([l_freq, l_pwm], ["frequency error (Hz)", "PWM (DAC counts)"],
               fontsize=8, loc="best")

    ax2.loglog(taus, adevs, "o-", ms=4, lw=1, color="#b3122f", label="Allan deviation")
    if len(taus) > 2:
        for pente, txt, col in ((-0.5, "white FM ($\\tau^{-1/2}$)", "#555555"),
                                (0.0, "flicker FM", "#888888")):
            ref = adevs[0] * (taus / taus[0]) ** pente
            ax2.loglog(taus, ref, ":", lw=1, color=col, label=txt)
    ax2.set_xlabel("averaging time $\\tau$ (s)")
    ax2.set_ylabel("$\\sigma_y(\\tau)$")
    ax2.set_title("Allan deviation (quantization floor ~3e-11 at 1000 s)")
    ax2.grid(True, which="both", alpha=0.3)
    ax2.legend(fontsize=8)
    fig.tight_layout()
    png_out = prefixe + "_adev.png"
    fig.savefig(png_out, dpi=130)

    # ---- rapport console
    print("=" * 62)
    print("Echantillons: %d contigus de 1000 s  (%.2f heures)%s" % (n, duree_h, note_segment))
    if jetes:
        print("Echantillons ignores (trou horaire / hors sequence): %d" % jetes)
    print("PWM debut/fin: 0x%s -> 0x%s" % (pwm[0], pwm[-1]))
    print("Ecart a 10 MHz: min %.3f Hz, max %.3f Hz, moyenne %.4f Hz"
          % (ecart_hz.min(), ecart_hz.max(), ecart_hz.mean()))
    print(note_detrend.strip(" ()"))
    print("-" * 62)
    print("   tau        sigma_y(tau)     paires")
    # table console log-espacee (le CSV contient tous les tau)
    i_affiche = []
    m = 1
    while m <= len(adevs):
        i_affiche.append(m - 1)
        m = max(m + 1, int(round(m * 1.4)))
    for i in i_affiche:
        t, a = taus[i], adevs[i]
        print("%7.0f s (%5.2f h)   %.3e      %d" % (t, t / 3600.0, a, n - 2 * (i + 1)))
    print("=" * 62)
    print("Ecrit: %s" % png_out)
    print("Ecrit: %s" % csv_out)


if __name__ == "__main__":
    try:
        main()
    except SystemExit as e:
        # si le log a ete glisse-depose sur le .py, la fenetre s'ouvre et se ferme
        # aussitot: pause pour laisser le temps de lire le message d'erreur
        try:
            if sys.stdin is not None and sys.stdin.isatty() and e.code not in (None, 0):
                input("\nAppuyez sur Entree pour fermer...")
        except (AttributeError, EOFError):
            pass
        raise
    # meme pause apres un rapport reussi (fenetre de glisser-deposer)
    try:
        if sys.stdin is not None and sys.stdin.isatty():
            input("\nAppuyez sur Entree pour fermer...")
    except (AttributeError, EOFError):
        pass
