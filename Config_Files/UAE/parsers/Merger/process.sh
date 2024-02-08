#!/usr/bin/bash
#
# v1 2023-11-13, By Nandgate/NMSA
#
# This script Merges 2 ABR.xxx.cfg files, using CONFIG ID as key.
# The Output file will have all "LEFT.cfg" entries,
# and all entries on "RIGHT.cfg" that do not exist on "LEFT.cfg".
##############################################################################

export LC_ALL=C
export LANG=en_EN

FINPUTL=LEFT.cfg
FINPUTR=RIGHT.cfg
FOUTPUT=OUTPUT.cfg
FTMP1=tmp1
FTMP2=tmp2
FTMP3=tmp3

##############################################################################
# MAIN
##############################################################################

if [ ! -f "$FINPUTL" ]
then
	echo "ERROR: File \"${FINPUTL}\" does not exist!"
  exit 1
fi

if [ ! -f "$FINPUTR" ]
then
	echo "ERROR: File \"${FINPUTR}\" does not exist!"
  exit 1
fi

sort $FINPUTL -t "|" -f -k 2,2 -u > $FTMP1
mv $FTMP1 $FINPUTL

sort $FINPUTR -t "|" -f -k 2,2 -u > $FTMP1
mv $FTMP1 $FINPUTR

echo "Merging the two files..."
echo "Left  File = "`cat $FINPUTL | wc -l`
echo "Right File = "`cat $FINPUTL | wc -l`

join -i -t "|" -j1 2 -j2 2 -a 1 -a 2 -o 1.2,2.2 $FINPUTL $FINPUTR > $FTMP1

sort $FTMP1 -t "|" -f -k 1,1 -u > $FTMP2
sort $FTMP1 -t "|" -f -k 2,2 -u > $FTMP3

join -i -t "|" -j1 1 -j2 2 -o 2.1,2.2,2.3,2.4,2.5,2.6,2.7,2.8,2.9,2.10,2.11,2.12,2.13,2.14,2.15,2.16,2.17,2.18,2.19 $FTMP2 $FINPUTL > $FOUTPUT

join -i -t "|" -j1 2 -j2 2 -o 2.1,2.2,2.3,2.4,2.5,2.6,2.7,2.8,2.9,2.10,2.11,2.12,2.13,2.14,2.15,2.16,2.17,2.18,2.19 $FTMP3 $FINPUTR >> $FOUTPUT

sort $FOUTPUT -t "|" -f -k 2,2 -u > $FTMP1

sed 's/||*/|/g' "$FTMP1" > "$FOUTPUT"

rm $FTMP1 $FTMP2 $FTMP3

echo "Output File = "`cat $FOUTPUT | wc -l`

exit 0
