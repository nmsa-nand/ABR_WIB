#!/usr/bin/ksh
#
# Check funcion show_help() for more info
#
# Pistorm EMU68 Compatibility sheet:
# https://docs.google.com/spreadsheets/d/1Y-2eRNB6LaLTRhYJo_Wxsp3AUeZmWp-0QBYirMoHkc8/edit#gid=1759583759
#
# HISTORY:
#  v1 2023-11-13 - Nandgate/NMSA - Created
#  v2 2023-11-21 - Nandgate/NMSA - Added SCS=x, bug fixing
#  v3 2024-01-09 - Nandgate/NMSA - Added params WHD=, NBW
#
#####################################################################################################

VERSION="v3 2024-01-09"

export LC_ALL=C
export LANG=en_EN

PROC=${0##*/}

# input files - these 2 come from WIB.rexx script (slave keys used by WHDLoad)
FWHDDEMOS="WHDLoad.Demos.txt"
FWHDGAMES="WHDLoad.Games.txt"
# input XLS sheet to parse (exported to TSV - with TAB delimited fields)
FSHEETDEFAULT="Pistorm32 testing - LATEST TESTING.tsv"
# input translation files (translate strings from XLS sheet to WHDLoad keys)
FTRLTDEMOS="Sheet2WHDLoad.Demos.txt"
FTRLTGAMES="Sheet2WHDLoad.Games.txt"
# files generated from previous TXT XLS sheet
FPARSEDDEMOS="Parsed.Demos.txt"
FPARSEDGAMES="Parsed.Games.txt"
# output files (to be used by ABR.rexx script)
FDEMOS="ABR.Demos.EMU68.cfg"
FGAMES="ABR.Games.EMU68.cfg"
# output files with Games/Demos missing in translation files
FNEWDEMOS="New.Demos.txt"
FNEWGAMES="New.Games.txt"
# temporary files
FTMP1="tmp1.tmp"

# checks for Cygwin
rc=`uname -a | grep -i CYGWIN`
if [[ $? -eq 0 ]]
then
  # Cygwin
  AWK=gawk
  INCYGWIN=true
else
  # Unix
  AWK=nawk
fi

#############################################################################################
# FUNCTIONS
#############################################################################################
show_help()
{
  echo "${VERSION} - by Nandgate/NMSA"
  echo "Description:"
  echo "  Parse Pistorm XLS Compatibility Sheet, and generates files:"
  echo "  \"${FDEMOS}\" and \"${FGAMES}\" for use with ABR.rexx script."
  echo "  After processing, it is advised to check and correct their results if needed."
  echo "Requires:"
  echo "  Files \"${FTRLTDEMOS}\" and \"${FTRLTGAMES}\" must be edited"
  echo "  and manually mantained to make the correspondence between what it is written on"
  echo "  XLS sheet and what is the corresponding SLAVE keyword used by WHDLoad."
  echo "  Files \"${FWHDDEMOS}\" and \"${FWHDGAMES}\" must be manually"
  echo "  mantained, and contain all the SLAVE keywords used by WHDLoad, for Demos and Games."
  echo "Additional Output:"
  echo "  Files \"${FNEWDEMOS}\" and \"${FNEWGAMES}\" are created with missing keys"
  echo "  which need to be classified in files \"${FTRLTDEMOS}\" and"
  echo "  \"${FTRLTGAMES}\", respectivelly."
  echo "Syntax:"
  echo "  ${PROC} <column>"
  echo "  ${PROC} <file> <column>"
  echo "Parameters:"
  echo "  <file> : the TAB delimited TXT file, converted from the XLS file"
  echo "           if not given, assumes \"${FSHEETDEFAULT}\""
  echo "  <column> : the column number with data. Column 5 means column E on the XLS sheet"
  echo "Examples:"
  echo "  ${PROC} 5"
  echo "  ${PROC} \"${FSHEETDEFAULT}\" 6"
  exit 1
}

#############################################################################################
# MAIN
#############################################################################################

if [[ $# -ne 1 && $# -ne 2 ]]
then
  show_help
fi

if [ $# -eq 2 ]
then
  FSHEET="$1"
  FIELD="$2"
else
  FSHEET="${FSHEETDEFAULT}"
  FIELD="$1"
fi

if [ ! -f "$FSHEET" ]
then
  echo "ERROR: File \"${FSHEET}\" does not exist!"
  exit 1
fi

if [ ! -f "$FWHDDEMOS" ]
then
  echo "ERROR: File \"${FWHDDEMOS}\" does not exist!"
  exit 1
fi

if [ ! -f "$FWHDGAMES" ]
then
  echo "ERROR: File \"${FWHDGAMES}\" does not exist!"
  exit 1
fi

if [ ! -f "$FTRLTDEMOS" ]
then
  echo "ERROR: File \"${FTRLTDEMOS}\" does not exist!"
  exit 1
fi

if [ ! -f "$FTRLTGAMES" ]
then
  echo "ERROR: File \"${FTRLTGAMES}\" does not exist!"
  exit 1
fi

echo "Parsing column ${FIELD} of file \"${FSHEET}\" ..."

IFS="
"

${AWK} \
-v FPARSEDDEMOS="$FPARSEDDEMOS" -v FPARSEDGAMES="$FPARSEDGAMES" -v FIELD=$FIELD '
function parse(p1,p2,a) {
  a=toupper(a)
  r=""
  w=""
  gsub(/[\"\?,]|\xE2\x9C\x93\x7C/,"",a)
  gsub(/\s+/," ",a)
  if (match(a,/WHDLOAD NOCACHE/)) { w=w " NoCache"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/WHDLOAD CACHE/)) { w=w " Cache"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/CUSTOM[0-9]+=[^\s]+/)) { w=w " " substr(a,RSTART,RLENGTH); a=substr(a,1,RSTART-1) "|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/EXPCHIP/)) { w=w " ExpChip"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/FULLCHIP/)) { w=w " FullChip"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/NOVBRMOVE/)) { w=w " NoVBRMove"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/NOMMU/)) { w=w " NoMMU"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/NORESINT/)) { w=w " NoResInt"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH+1); }
  if (match(a,/ICNT.[0-9]+/)) { r=r "ICNT=" substr(a,RSTART+5,RLENGTH-5) "|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/CCRD.[0-9]+/)) { r=r "CCRD=" substr(a,RSTART+5,RLENGTH-5) "|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/SCS=[1-8]/)) { r=r "SCS=" substr(a,RSTART+4,1) "|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/^\s*SC\s*/)) { r=r "SDCHIP=SC|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/\s*SC\s*/)) { r=r "SDCHIP=SC|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/\s*SC\s*$/)) { r=r "SDCHIP=SC|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/SETTURBO.(0|1)/)) { r=r "TURBO=" substr(a,RSTART+9,1) "|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/TURBO.(0|1)/)) { r=r "TURBO=" substr(a,RSTART+7,1) "|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/NBW/)) { r=r "NBW=1|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/NOCACHE/)) { r=r "NCache=NOCACHE|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/CACHE/)) { r=r "NCache=CACHE|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/(UNDER|DOWN)CLOCK.*[0-9]+.*MHZ/)) { v=substr(a,RSTART,RLENGTH); gsub(/[ a-zA-Z]+/,"",v); r=r "ARMCLK=" v "|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/SETCLOCKRATE.[0-9]+/)) { r=r "ARMCLK=" substr(a,RSTART+13,RLENGTH-13) "|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/MHZ.[0-9]+/)) { r=r "ARMCLK=" substr(a,RSTART+4,RLENGTH-4) "|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (w!="") { r="WHD=" substr(w,2) "|" r; }
  gsub(/EMUCONTROL|EMU68INFO|WHDLOAD|OPTION|NEEDS/,"",a)
  gsub(/WHD\s+$/,"",a)
  gsub(/AND\s+$/,"",a)
  gsub(/WITH\s+$/,"",a)
  gsub(/USE\s+$/,"",a)
  gsub(/\sS$/,"",a)
  gsub(/\s+)/,")",a)
  gsub(/^[ \t]+/,"",a)
  gsub(/[ \t]+$/,"",a)
  gsub(/\s+/," ",a)
  if (a!="") { r=r " ; " a}
  if (p1=="") {
    if (r=="") {
      r=";" p1 "|" p2 "|"
    } else {
      r=p1 "|" p2 "|" r
    }
  } else {
    if (r=="") {
      r=";|" p2 "(" p1 ")|"
    } else {
      r="|" p2 "(" p1 ")|" r
    }
  }
  return r
}
BEGIN { FS="\t"; OFS="|"; g=0; d=0; print "Total Parsed:" }
{
  if ($2=="") {
    if (g==1) { g=0; }
    if (d==1) { d=0; }
  }
  if (g==1) { gc++; v2=$2; gsub(/[\047\ \./-]/,"",v2); print parse("",v2,$FIELD) > FPARSEDGAMES }
  if (d==1) { dc++; v1=$1; gsub(/[\047\ \./-]/,"",v1); v2=$2; gsub(/[\047\ \./-]/,"",v2); print parse(v1,v2,$FIELD) > FPARSEDDEMOS }
  if (g==0) { if (toupper($1)=="GAMES:") {g=1} }
  if (d==0) { if (toupper($1)~"DEMOS") {d=1} }
}
END {
  print "Demos = " dc
  print "Games = " gc
}
' "$FSHEET"

## GAMES

sort "$FWHDGAMES" -t "|" -k 2,2 -f -u > "$FTMP1"
mv "$FTMP1" "$FWHDGAMES"

sort "$FTRLTGAMES" -t "|" -k 1,1 -f > "$FTMP1"
mv "$FTMP1" "$FTRLTGAMES"

sort "$FPARSEDGAMES" -t "|" -k 2,2 -f -u > "$FTMP1"
mv "$FTMP1" "$FPARSEDGAMES"

join -i -t "|" -j1 2 -j2 1 -o 1.1,2.2,1.3,1.4,1.5,1.6,1.7,1.8,1.9 "$FPARSEDGAMES" "$FTRLTGAMES" | sort -t "|" -k 2,2 -f -u > "$FTMP1"

sed 's/||*/|/g;/^;|$/d' "$FTMP1" > "$FGAMES"

join -i -t "|" -j1 2 -j2 1 -a 1 -v 1 -o 1.2 "$FPARSEDGAMES" "$FTRLTGAMES" | sort -t "|" -k 1,1 -f -u > "$FNEWGAMES"

rm -f "$FTMP1"

## DEMOS

sort "$FWHDDEMOS" -t "|" -k 2,2 -f -u > "$FTMP1"
mv "$FTMP1" "$FWHDDEMOS"

sort "$FTRLTDEMOS" -t "|" -k 1,1 -f > "$FTMP1"
mv "$FTMP1" "$FTRLTDEMOS"

sort "$FPARSEDDEMOS" -t "|" -k 2,2 -f -u > "$FTMP1"
mv "$FTMP1" "$FPARSEDDEMOS"

join -i -t "|" -j1 2 -j2 1 -o 1.1,2.2,1.3,1.4,1.5,1.6,1.7,1.8,1.9 "$FPARSEDDEMOS" "$FTRLTDEMOS" | sort -t "|" -k 2,2 -f -u > "$FTMP1"

sed 's/||*/|/g;/^;|$/d' "$FTMP1" > "$FDEMOS"

join -i -t "|" -j1 2 -j2 1 -a 1 -v 1 -o 1.2 "$FPARSEDDEMOS" "$FTRLTDEMOS" | sort -t "|" -k 1,1 -f -u > "$FNEWDEMOS"

rm -f "$FTMP1"

md=`cat "$FNEWDEMOS" | wc -l`
mg=`cat "$FNEWGAMES" | wc -l`

if [[ md -gt 0 || mg -gt 0 ]]
then
  echo "Missing keys: (to be added and classified on \"${FTRLTDEMOS}\" and \"${FTRLTGAMES}\")"
  if [ md -gt 0 ]
  then
    echo "Demos = "$md", check file \"$FNEWDEMOS\""
  fi
  if [ mg -gt 0 ]
  then
    echo "Games = "$mg", check file \"$FNEWGAMES\""
  fi
fi

echo "Total for Output files:"
echo "Demos = "`cat "$FDEMOS" | egrep -v "^;" | wc -l`", check file \"$FDEMOS\""
echo "Games = "`cat "$FGAMES" | egrep -v "^;" | wc -l`", check file \"$FGAMES\""

exit 0
