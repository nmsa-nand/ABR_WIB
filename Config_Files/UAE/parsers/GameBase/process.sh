#!/usr/bin/bash
#
# v1 2023-11-13, By Nandgate/NMSA
#
# This script parses configuration files from GameBase64 for WINUAE emulator.
##############################################################################

export LC_ALL=C
export LANG=en_EN

# these 2 come from WIB.rexx script (slave keys for WHDLoad)
FWHDGAMES="WHDLoad.Games.txt"
FWHDDEMOS="WHDLoad.Demos.txt"
# these 2 come from Gamebase64 Games & Demos Access database files (exported to TXT)
FGBGAMES="GB.Games.txt"
FGBDEMOS="GB.Demos.txt"
# output files
FGAMES="ABR.Games.UAE.cfg"
FDEMOS="ABR.Demos.UAE.cfg"
# temporary files
FTMP1="tmp1.tmp"

##############################################################################
# MAIN
##############################################################################

if [ ! -f "$FWHDGAMES" ]
then
	echo "ERROR: File \"${FWHDGAMES}\" does not exist!"
  exit 1
fi

if [ ! -f "$FWHDDEMOS" ]
then
	echo "ERROR: File \"${FWHDDEMOS}\" does not exist!"
  exit 1
fi

if [ ! -f "$FGBGAMES" ]
then
	echo "ERROR: File \"${FGBGAMES}\" does not exist!"
  exit 1
fi

if [ ! -f "$FGBDEMOS" ]
then
	echo "ERROR: File \"${FGBDEMOS}\" does not exist!"
  exit 1
fi

sort "$FWHDGAMES" -t "|" -k 2,2 -f -u > "$FTMP1"
mv "$FTMP1" "$FWHDGAMES"

sort "$FGBGAMES" -t "|" -k 2,2 -f -u > "$FTMP1"
mv "$FTMP1" "$FGBGAMES"

join -i -t "|" -j1 2 -j2 2 -o 1.1,2.2,1.3,1.4,1.5,1.6,1.7,1.8,1.9 "$FGBGAMES" "$FWHDGAMES" | tr -d '\r' | sort -t "|" -k 2,2 -f -u > "$FTMP1"

sed 's/||*/|/g' "$FTMP1" > "$FGAMES"

rm -f "$FTMP1"

sort "$FWHDDEMOS" -t "|" -k 2,2 -f -u > "$FTMP1"
mv "$FTMP1" "$FWHDDEMOS"

sort "$FGBDEMOS" -t "|" -k 2,2 -f -u > "$FTMP1"
mv "$FTMP1" "$FGBDEMOS"

join -i -t "|" -j1 2 -j2 2 -o 1.1,2.2,1.3,1.4,1.5,1.6,1.7,1.8,1.9 "$FGBDEMOS" "$FWHDDEMOS" | tr -d '\r' | sort -t "|" -k 2,2 -f -u > "$FTMP1"

sed 's/||*/|/g' "$FTMP1" > "$FDEMOS"

rm -f "$FTMP1"

echo "Processed:"
echo "Total Games: "`cat "$FGAMES" | wc -l`
echo "Total Demos: "`cat "$FDEMOS" | wc -l`

exit 0
