#!/usr/bin/bash
#
# v1 2023-11-13, By Nandgate/NMSA
#
# Check funcion show_help() for more info
#
# This script parses configuration files from WinUAE Loader/Config Creator.
##############################################################################

VERSION="v1 2023-11-13"

export LC_ALL=C
export LANG=en_EN

PROC=${0##*/}

FXMLDEFAULT="WHDLoad.xml"
FOUTPUT="ABR.UAE.cfg"
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

# checks for dos2unix
rc=`which dos2unix`
if [[ $? -eq 0 ]]
then
  DOS2UNIX=$rc
else
  echo "Executable dos2unix not found, aborting..."
  exit 1
fi

##############################################################################
# FUNCTIONS
##############################################################################
show_help()
{
  echo "${VERSION} - by Nandgate/NMSA"
  echo "Description:"
  echo "  Parse \"${FXMLDEFAULT}\" file from WinUAE Loader/Config Creator."
  echo "  Outputs file \"${FOUTPUT}\" to used by script ABR.rexx."
  echo "  After processing, it is advised to check and correct their results if needed."
  echo "Syntax:"
  echo "  ${PROC} [-h] [file]"
  echo "Parameters:"
  echo "  [-h] : This help."
  echo "  [file] : The XML file. If not given, \"${FXMLDEFAULT}\" is used."
  echo "Examples:"
  echo "  ${PROC} \"${FXMLDEFAULT}\""
  exit 1
}

##############################################################################
# MAIN
##############################################################################


if [[ $# -ne 1 ]]
then
  show_help
fi

FXML="$1"

if [ ! -f "$FXML" ]
then
	echo "ERROR: File \"${FXML}\" does not exist!"
  exit 1
fi

$DOS2UNIX $FXML
		
echo "Parsing file \"${FXML}\" ..."

IFS="
"

${AWK} \
-v FOUTPUT="$FTMP1" -v FXML="$FXML" '
BEGIN { FS="\r"; OFS="|"; c=0
}
{
  L=$0
  gsub(/&#xA;/,"",L)
  gsub(/&amp;/,"\\&",L)
  S=""
  if (match(L,/[\&\.0-9A-Z_a-z+-]+.[sS][lL][aA][vV][eE]/)) { 
    S=substr(L,RSTART,RLENGTH-6)
    L=substr(L,1,RSTART) substr(L,RSTART+RLENGTH+1)
  }
  if (S!="") {
    C=""
    if (match(L,/UAEConfig=\"[^\"]+\"/)) {
      C=substr(L,RSTART+11,RLENGTH-11-1)
      L=substr(L,1,RSTART-1) substr(L,RSTART+RLENGTH+1)
    }
    if (C!="") {
      c++
      print "|" S "|" C "|" > FOUTPUT
    }
  }
}
END {
  print "Total \"" FXML "\" entries parsed: " c
}
' "$FXML"

sort "$FTMP1" -t "|" -k 2,2 -f -u > "$FOUTPUT"

rm -f "$FTMP1"

echo "Total \"${FOUTPUT}\" entries generated: "`cat "${FOUTPUT}" | wc -l`

exit 0
