#!/usr/bin/ksh
#
# Check funcion show_help() for more info
#
# Parser for WHDLoadWrapper Databases
# Example Database:
# https://docs.google.com/document/d/1WOPgUkc0XCY7oEYT170KtHdcRgdZP7FF3lkA6LTfqz8/edit
#
# HISTORY:
#  v1 2023-11-21 - Nandgate/NMSA - Created
#  v2 2024-01-09 - Nandgate/NMSA - Added WHD=, NBW
#
#####################################################################################################

VERSION="v2 2024-01-09"

export LC_ALL=C
export LANG=en_EN

PROC=${0##*/}

# input file
FINPUT="WHDLoad-Database.txt"
# output files (to be used by ABR.rexx script)
FDEMOS="ABR.Demos.EMU68.cfg"
FGAMES="ABR.Games.EMU68.cfg"
# temporary files
FTMP1="tmp1.tmp"
FTMP2="tmp2.tmp"

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

# checks for dos2unix
rc=`which dos2unix`
if [[ $? -eq 0 ]]
then
  DOS2UNIX=$rc
else
  echo "Executable dos2unix not found, aborting..."
  exit 1
fi

#############################################################################################
# FUNCTIONS
#############################################################################################
show_help()
{
  echo "${VERSION} - by Nandgate/NMSA"
  echo "Description:"
  echo "  Parse WHDLoadWrapper Databases"
  echo "Syntax:"
  echo "  ${PROC} [file]"
  echo "Parameters:"
  echo "  [file] : WHDLoadWrapper Database input file."
  echo "           If not given, it assumes \"${FINPUT}\""
  echo "Examples:"
  echo "  ${PROC} \"${FINPUT}\""
  exit 1
}

#############################################################################################
# MAIN
#############################################################################################

if [[ $# -gt 1 ]]
then
  show_help
fi

if [ "$1" != "" ]
then
  FINPUT="$1"
fi

if [ ! -f "$FINPUT" ]
then
  echo "ERROR: File \"${FINPUT}\" does not exist!"
  exit 1
fi

$DOS2UNIX "$FINPUT"

echo "Parsing file \"${FINPUT}\" ..."

IFS="
"

${AWK} \
-v FDEMOS="$FDEMOS" -v FGAMES="$FGAMES" -v FCOMMON="$FTMP1" '
function parse(p1,p2) {
  a=toupper(p2)
  r=""
  w=""
  gsub(/\xE2\x80\x9D/,"\"",a)
  gsub(/\s+/," ",a)
  if (match(a,/WNC/)) { w=w " NoCache"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/WEC/)) { w=w " ExpChip"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/WHD=\"[^"]+\"/)) { w=w " " substr(a,RSTART+5,RLENGTH-6); a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/ICNT.[0-9]+/)) { r=r "ICNT=" substr(a,RSTART+5,RLENGTH-5) "|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/SCS=[1-8]/)) { r=r "SCS=" substr(a,RSTART+4,1) "|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/^\s*SC\s*/)) { r=r "SDCHIP=SC|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/\s*SC\s*/)) { r=r "SDCHIP=SC|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/\s*SC\s*$/)) { r=r "SDCHIP=SC|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/NOTURBO/)) { r=r "TURBO=0|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/NBW/)) { r=r "NBW=1|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/NFC/)) { r=r "NCache=NOCACHE|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (match(a,/MHZ.[0-9]+/)) { r=r "ARMCLK=" substr(a,RSTART+4,RLENGTH-4) "|"; a=substr(a,1,RSTART-1) substr(a,RSTART+RLENGTH); }
  if (w!="") { r="WHD=" substr(w,2) "|" r; }
  gsub(/\s+)/,")",a)
  gsub(/^[ \t]+/,"",a)
  gsub(/[ \t]+$/,"",a)
  gsub(/\s+/," ",a)
  if (a!="") { r=r " ; " a}
  if (r=="") {
    r=";|" p1 "|"
  } else {
    r="|" p1 "|" r
  }
  return r
}
BEGIN { FS=";"; OFS="|"; g=1; d=1; print "Total Parsed:" }
{
  v1=$1
  v2=substr($0,index($0,";")+1)
  if (substr($0,1,1)!=";") {
    if (g==1 && d==1) { print parse(v1,v2) > FCOMMON }
    if (g==1 && d==0) { gc++; print parse(v1,v2) > FGAMES }
    if (d==1 && g==0) { dc++; print parse(v1,v2) > FDEMOS }
  } else {
    if (toupper($2)~"WHDLOAD GAMES") {g=1; d=0;}
    if (toupper($2)~"WHDLOAD DEMOS") {d=1; g=0;}
  }
}
END {
  print "Demos = " dc
  print "Games = " gc
}
' "$FINPUT"

## DEMOS

sort "$FDEMOS" -t "|" -k 2,2 -f -u > "$FTMP2"
cat "$FTMP1" "$FTMP2" > "$FDEMOS"

rm -f "$FTMP2"

## GAMES
 
sort "$FGAMES" -t "|" -k 2,2 -f -u > "$FTMP2"
cat "$FTMP1" "$FTMP2" > "$FGAMES"
 
rm -f "$FTMP1" "$FTMP2"

echo "Total Processed:"
echo "Demos = "`cat "$FDEMOS" | wc -l`", check file \"$FDEMOS\""
echo "Games = "`cat "$FGAMES" | wc -l`", check file \"$FGAMES\""

exit 0
