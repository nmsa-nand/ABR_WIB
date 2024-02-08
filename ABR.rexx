/* $VER: ABR.rexx 1.0 2024-01-14 by Nandgate/NMSA
 *
 * Accelerator Board Reconfigurator
 *
 * Check Procedure pHelp() at bottom for usage help
 * Check "ABR.HISTORY.txt" for history changes
 * Check "ABR.README.txt" for more info
 */

Version="v1.0 2024-01-14"

vNoDef=0
vFirstMatch=0
vQuiet=0

/* ==== param READING ==== */
IF ARG()==0 THEN DO
  pHelp()
  EXIT 0
END

PARSE ARG cmdline
i=0
DO WHILE cmdline~==""
  cmdline=STRIP(cmdline)
  i=i+1
  SELECT
    WHEN LEFT(cmdline,1)='"' THEN
      PARSE VAR cmdline '"'param.i'"' cmdline
    WHEN LEFT(cmdline,1)="'" THEN
      PARSE VAR cmdline "'"param.i"'" cmdline
    OTHERWISE
      PARSE VAR cmdline param.i cmdline
  END
END
param.0=i
DROP cmdline i

list=""
config=""
vInfo=""
DO i=1 TO param.0
  parname=UPPER(param.i)
  SELECT
    WHEN parname=="LIST" THEN DO
      IF list=="" THEN DO
        IF i<param.0 THEN DO
          i=i+1
          list=STRIP(param.i)
        END
      END
      ELSE pError("Only one LIST parameter supported!" '0a'X)
    END
    WHEN parname=="CONFIG" THEN DO
      IF config=="" THEN DO
        IF i<param.0 THEN DO
          i=i+1
          config=STRIP(param.i)
        END
      END
      ELSE pError("Only one CONFIG parameter supported!" '0a'X)
    END
    WHEN parname=="INFO" THEN DO
      IF vInfo=="" THEN DO
        IF i<param.0 THEN DO
          i=i+1
          vInfo=STRIP(param.i)
        END
      END
      ELSE pError("Only one INFO parameter supported!" '0a'X)
    END
    WHEN parname=="NODEFAULT" THEN vNoDef=1
    WHEN parname=="FIRSTMATCH" THEN vFirstMatch=1
    WHEN parname=="QUIET" THEN vQuiet=1
    OTHERWISE pError("Invalid parameter '"parname"'!")
  END    
END

IF config=="" THEN pError("No CONFIG given!" '0a'X)
config2="|"UPPER(config)"|"

/* ==== ENVIRONMENT VARIABLES READING ==== */
BOARDNAME=pGetEnv("BOARDNAME")
IF BOARDNAME=="" THEN DO
  pError("Environment variable ENV:BOARDNAME not set. Check if it is defined.")
  EXIT 20
END

/*BOARDNAME="UAE" for testing purposes */

/* ==== CHECK REQUIRED ENVIRONMENT ASSIGNS ==== */
DIRCFG="REXX:"
DIRCMD="REXXC:"
pAssignExists(DIRCFG)
/*pAssignExists(DIRCMD)*/

/* ==== PATHs AND COMMANDS ==== */
UAECONFIGURATION="UAE:uae-configuration"
EMU68INFO="EMU68:emu68info"
EMU68CONTROL="EMU68:emucontrol"
EMU68DOWNCLOCKER="EMU68:emu68downclocker"
MUSASHIPI="MUSASHI:pi"
MUSASHIPISTORM="MUSASHI:pistorm"
MUSASHIPISIMPLE="MUSASHI:pisimple"
MUSASHIPIAUDIO="MUSASHI:piaudio"
RX=DIRCMD"RX"
WIBREXX=DIRCFG"WIB.REXX"

/* ==== CHECK REQUIRED ENVIRONMENT COMMANDS ==== */
/*pFileExists(WIBREXX)*/

SELECT
  /* --- GENERIC CONFIG --- */
  WHEN BOARDNAME=='GENERIC' THEN NOP
  /* --- UAE CONFIG --- */
  WHEN BOARDNAME=='UAE' THEN DO
    pAssignExists("UAE:")
    pFileExists(UAECONFIGURATION)    
  END
  /* --- EMU68 CONFIG --- */
  WHEN BOARDNAME=='EMU68' THEN DO
    pAssignExists("EMU68:")
    pFileExists(EMU68INFO)
    pFileExists(EMU68CONTROL)
    /*pFileExists(EMU68DOWNCLOCKER)*/
  END
  /* --- MUSASHI CONFIG --- */
  WHEN BOARDNAME=='MUSASHI' THEN DO
    pAssignExists("MUSASHI:")
    pFileExists(MUSASHIPI)
    pFileExists(MUSASHIPISTORM)
    pFileExists(MUSASHIPISIMPLE)
    pFileExists(MUSASHIPIAUDIO)
  END
  /* --- UNKNOWN UNSUPPORTED BOARD CONFIG --- */
  OTHERWISE DO
    IF BOARDNAME=="" THEN
      pError("Running in unknown unsupported board")
    ELSE
      pError("Running in unknown unsupported board called "BOARDNAME)
  END
END

/* ==== MAIN CODE ==== */

/* Some Flags */
found=0
applied=0

pEcho("Using CONFIG="config)

/* CHOOSE BOARDNAME CONFIG */
SELECT
  /* --- GENERIC / UAE CONFIG --- */
  WHEN BOARDNAME=='GENERIC' | BOARDNAME=='UAE' THEN DO
    pEcho("Running on Board: "BOARDNAME)
    IF list=="" THEN
      filecfg=DIRCFG"ABR."BOARDNAME".cfg"
    ELSE
      filecfg=DIRCFG"ABR."list"."BOARDNAME".cfg"
    pFileExists(filecfg)
    pEcho("Using config file: "filecfg)
    OPEN(fh,filecfg,"r")
    lc=0
    DO FOREVER
      L=STRIP(READLN(fh))
      IF EOF(fh) THEN LEAVE
      lc=lc+1
      IF LEFT(L,1)~==";" & INDEX(UPPER(L),config2)>0 THEN DO
        found=1
        pEcho("Found config in Line "lc": "L)
        DO FOREVER
          PARSE VAR L param "|" L
          PARSE VAR L "|" param "|"
          param=STRIP(param)
          IF param=="" | LEFT(param,1)==";" THEN LEAVE
          PARSE VAR param parname "=" parvalue
          parname=pLower(parname)
          SELECT
            WHEN parname=="errorbox" THEN pErrorBox(parvalue)
            WHEN parname=="infobox" THEN pInfoBox(parvalue)
            WHEN parname=="shell" THEN pCmd(parvalue)
            WHEN parname=="pause" THEN pPause(parvalue)
            WHEN parname=="sleep" THEN pSleep(parvalue)
            WHEN parname=="echo" THEN pEchoMsg(parvalue)
            WHEN parname=="whd" THEN r=pWHDLoad(parvalue)
            OTHERWISE DO
              IF BOARDNAME=="UAE" THEN DO
                r=pCmd(UAECONFIGURATION" "parname" "parvalue)
                IF r~==0 THEN
                  pErrorBox('Line 'lc': Error setting UAE param: 'param', ReturnCode='r)
                ELSE
                  applied=1
              END
              ELSE DO
                pErrorBox("Line "lc": Unknown param in config file: "param)
              END
            END
          END
        END
      END
      IF found>0 & vFirstMatch>0 THEN LEAVE
    END
    CLOSE fh
  END
  
  /* --- EMU68 CONFIG --- */
  WHEN BOARDNAME=='EMU68' THEN DO
    pEcho("Running in EMU68")
    IF list=="" THEN
      filecfg=DIRCFG"ABR.EMU68.cfg"
    ELSE
      filecfg=DIRCFG"ABR."list".EMU68.cfg"
    pFileExists(filecfg)
    pEcho("Using config file: "filecfg)
    OPEN(fh,filecfg,"r")
    lc=0
    DO FOREVER
      L=STRIP(READLN(fh))
      IF EOF(fh) THEN LEAVE
      lc=lc+1
      IF LEFT(L,1)~==";" & INDEX(UPPER(L),config2)>0 THEN DO
        found=1
        pEcho("Found config in Line "lc": "L)
        DO FOREVER
          PARSE VAR L param "|" L
          PARSE VAR L "|" param "|"
          param=STRIP(param)
          IF param=="" | LEFT(param,1)==";" THEN LEAVE
          PARSE VAR param parname "=" parvalue
          parname=UPPER(parname)
          SELECT
            WHEN parname=="ERRORBOX" THEN pErrorBox(parvalue)
            WHEN parname=="INFOBOX" THEN pInfoBox(parvalue)
            WHEN parname=="SHELL" THEN pCmd(parvalue)
            WHEN parname=="PAUSE" THEN pPause(parvalue)
            WHEN parname=="SLEEP" THEN pSleep(parvalue)
            WHEN parname=="ECHO" THEN pEchoMsg(parvalue)
            WHEN parname=="WHD" THEN r=pWHDLoad(parvalue)
            WHEN parname=="JIT" THEN DO
              parJITwords=WORDS(TRANSLATE(parvalue," ","-"))
              applied=0
              SELECT
                /* JIT=a-b-c-r-d */
                WHEN parJITwords==5 THEN DO
                  PARSE VAR parvalue parICNT "-" parIRNG "-" parLCNT "-" parCCRD "-" parSFL
                  IF parICNT>0 & parICNT<=256 & parIRNG>0 & parIRNG<=65535 & parLCNT>0 & parLCNT<=16 & parCCRD>=0 & parCCRD<=31 & parSFL>0 & parSFL<=4000 THEN DO
                    pCmd(EMU68INFO" SETJITICNT "parICNT" SETJITIRNG "parIRNG" SETJITLCNT "parLCNT" SETJITSFL "parSFL)
                    applied=1
                    IF parICNT==1 THEN pCmd(EMU68CONTROL" CCRD 0")
                    ELSE pCmd(EMU68CONTROL" CCRD "parCCRD)
                  END
                END
                /* JIT=a-b-c-d */
                WHEN parJITwords==4 THEN DO
                  PARSE VAR parvalue parICNT "-" parIRNG "-" parLCNT "-" parSFL
                  IF parICNT>0 & parICNT<=256 & parIRNG>0 & parIRNG<=65535 & parLCNT>0 & parLCNT<=16 & parSFL>0 & parSFL<=4000 THEN DO
                    pCmd(EMU68INFO" SETJITICNT "parICNT" SETJITIRNG "parIRNG" SETJITLCNT "parLCNT" SETJITSFL "parSFL)
                    applied=1
                    IF parICNT==1 THEN pCmd(EMU68CONTROL" CCRD 0")
                  END
                END
                /* JIT=a-b-c */
                WHEN parJITwords==3 THEN DO
                  PARSE VAR parvalue parICNT "-" parIRNG "-" parLCNT
                  IF parICNT>0 & parICNT<=256 & parIRNG>0 & parIRNG<=65535 & parLCNT>0 & parLCNT<=16 THEN DO
                    pCmd(EMU68INFO" SETJITICNT "parICNT" SETJITIRNG "parIRNG" SETJITLCNT "parLCNT)
                    applied=1
                    IF parICNT==1 THEN pCmd(EMU68CONTROL" CCRD 0")
                  END
                END
                OTHERWISE /* error */
              END
              IF applied==0 THEN pErrorBox("Line "lc": Invalid JIT value of "parvalue)
            END
            WHEN parname=="ICNT" THEN DO
              IF parvalue>0 & parvalue<=256 THEN DO
                pCmd(EMU68INFO" SETJITICNT "parvalue)
                applied=1
                IF parvalue==1 THEN pCmd(EMU68CONTROL" CCRD 0")
              END
              ELSE pErrorBox("Line "lc": Invalid ICNT value of "parvalue". Expected 1..256")
            END
            WHEN parname=="IRNG" THEN DO
              IF parvalue>0 & parvalue<=65535 THEN DO
                pCmd(EMU68INFO" SETJITIRNG "parvalue)
                applied=1
              END
              ELSE pErrorBox("Line "lc": Invalid IRNG value of "parvalue". Expected 1..65535")
            END
            WHEN parname=="LCNT" THEN DO
              IF parvalue>0 & parvalue<=16 THEN DO pCmd(EMU68INFO" SETJITLCNT "parvalue)
                applied=1
              END
              ELSE pErrorBox("Line "lc": Invalid LCNT value of "parvalue". Expected 1..16")
            END
            WHEN parname=="SFL" THEN DO
              IF parvalue>0 & parvalue<=4000 THEN DO
                pCmd(EMU68INFO" SETJITSFL "parvalue)
                applied=1
              END
              ELSE pErrorBox("Line "lc": Invalid SFL value of "parvalue". Expected 1..4000")
            END
            WHEN parname=="CCRD" THEN DO
              IF parvalue>=0 & parvalue<=31 THEN DO
                pCmd(EMU68CONTROL" CCRD "parvalue)
                applied=1
              END
              ELSE pErrorBox("Line "lc": Invalid CCRD value of "parvalue". Expected 0..31")
            END
            WHEN parname=="NCACHE" THEN DO
              IF parvalue=="CACHE" | parvalue=="NOCACHE" THEN DO
                pCmd(EMU68CONTROL" "parvalue" S")
                applied=1
              END
              ELSE pErrorBox("Line "lc": Invalid NCACHE value of "parvalue". Expected CACHE, NOCACHE")
            END
            WHEN parname=="TURBO" THEN DO
              IF parvalue==0 | parvalue==1 THEN DO
                pCmd(EMU68INFO" SETTURBO "parvalue)
                applied=1
              END
              ELSE pErrorBox("Line "lc": Invalid TURBO value of "parvalue". Expected 0, 1")
            END
            WHEN parname=="NBW" THEN DO
              SELECT
                WHEN parvalue==0 THEN DO pCmd(EMU68CONTROL" BW"); applied=1; END
                WHEN parvalue==1 THEN DO pCmd(EMU68CONTROL" NBW"); applied=1; END
                OTHERWISE pErrorBox("Line "lc": Invalid NBW value of "parvalue". Expected 0, 1")
              END
            END
            WHEN parname=="SDCHIP" THEN DO
              IF parvalue=="SC" | parvalue=="NSC" THEN DO
                pCmd(EMU68CONTROL" "parvalue)
                applied=1
              END
              ELSE pErrorBox("Line "lc": Invalid SDCHIP value of "parvalue". Expected SC, NSC")
            END
            WHEN parname=="SCS" THEN DO
              IF parvalue>=1 & parvalue<=8 THEN DO
                pCmd(EMU68CONTROL" SC SCS "parvalue)
                applied=1
              END
              ELSE pErrorBox("Line "lc": Invalid SCS value of "parvalue". Expected 1..8")
            END
            WHEN parname=="SDDBF" THEN DO
              IF parvalue=="DBF" | parvalue=="NDBF" THEN DO
                pCmd(EMU68CONTROL" "parvalue)
                applied=1
              END
              ELSE pErrorBox("Line "lc": Invalid SDDBF value of "parvalue". Expected DBF, NDBF")
            END
            WHEN parname=="ARMCLK" THEN DO
              IF parvalue=="" THEN pErrorBox("Line "lc": Missing ARMCLK value")
              ELSE DO
                PARSE VAR parvalue pv1 " " pv2
                IF pv1>=600 THEN DO
                  pCmd(EMU68INFO" SETCLOCKRATE "parvalue)
                END
                ELSE DO
                  pFileExists(EMU68DOWNCLOCKER)
                  pCmd(EMU68DOWNCLOCKER" "pv1)
                END
                applied=1
              END
            END
            WHEN parname=="DWNCLK" THEN DO
              IF parvalue=="" THEN pErrorBox("Line "lc": Missing DWNCLK value")
              ELSE DO
                pFileExists(EMU68DOWNCLOCKER)
                pCmd(EMU68DOWNCLOCKER" "parvalue)
                applied=1
              END
            END
            WHEN parname=="CLKRT" THEN DO
              IF parvalue=="" THEN pErrorBox("Line "lc": Missing CLKRT value")
              ELSE DO
                pCmd(EMU68INFO" SETCLOCKRATE "parvalue)
                applied=1
              END
            END
            WHEN parname=="EMUCONTROL" THEN DO
              IF parvalue=="" THEN pErrorBox("Line "lc": Missing EMUCONTROL values")
              ELSE DO
                pCmd(EMU68CONTROL" "parvalue)
                applied=1
              END
            END
            WHEN parname=="EMU68INFO" THEN DO
              IF parvalue=="" THEN pErrorBox("Line "lc": Missing EMU68INFO values")
              ELSE DO
                pCmd(EMU68INFO" "parvalue)
                applied=1
              END
            END
            WHEN parname=="EMU68DOWNCLOCKER" THEN DO
              IF parvalue=="" THEN pErrorBox("Line "lc": Missing EMU68DOWNCLOCKER values")
              ELSE DO
                pFileExists(EMU68DOWNCLOCKER)
                pCmd(EMU68DOWNCLOCKER" "parvalue)
                applied=1
              END
            END
            OTHERWISE pErrorBox("Line "lc": Unknown param in config file: "param)
          END
        END
      END
      IF found>0 & vFirstMatch>0 THEN LEAVE
    END
    CLOSE fh
  END
    
  /* --- MUSASHI CONFIG --- */
  WHEN BOARDNAME=='MUSASHI' THEN DO
    pEcho("Running in MUSASHI")
    IF list=="" THEN
      filecfg=DIRCFG"ABR.MUSASHI.cfg"
    ELSE
      filecfg=DIRCFG"ABR."list".MUSASHI.cfg"
    pFileExists(filecfg)
    pEcho("Using config file: "filecfg)
    OPEN(fh,filecfg,"r")
    lc=0
    DO FOREVER
      L=STRIP(READLN(fh))
      IF EOF(fh) THEN LEAVE
      lc=lc+1
      IF LEFT(L,1)~==";" & INDEX(UPPER(L),config2)>0 THEN DO
        found=1
        pEcho("Found config in Line "lc": "L)
        DO FOREVER
          PARSE VAR L param "|" L
          PARSE VAR L "|" param "|"
          param=STRIP(param)
          IF param=="" | LEFT(param,1)==";" THEN LEAVE
          PARSE VAR param parname "=" parvalue
          parname=UPPER(parname)
          SELECT
            WHEN parname=="ERRORBOX" THEN pErrorBox(parvalue)
            WHEN parname=="INFOBOX" THEN pInfoBox(parvalue)
            WHEN parname=="SHELL" THEN pCmd(parvalue)
            WHEN parname=="PAUSE" THEN pPause(parvalue)
            WHEN parname=="SLEEP" THEN pSleep(parvalue)
            WHEN parname=="ECHO" THEN pEchoMsg(parvalue)
            WHEN parname=="WHD" THEN r=pWHDLoad(parvalue)
            WHEN parname=="PI" THEN DO pCmd(MUSASHIPI" "parvalue); applied=1; END
            WHEN parname=="PISTORM" THEN DO pCmd(MUSASHIPISTORM" "parvalue); applied=1; END
            WHEN parname=="PISIMPLE" THEN DO pCmd(MUSASHIPISIMPLE" "parvalue); applied=1; END
            WHEN parname=="PIAUDIO" THEN DO pCmd(MUSASHIPIAUDIO" "parvalue); /* applied=1; */ END
            OTHERWISE pErrorBox("Line "lc": Unknown param in config file: "param)
          END
        END
      END
      IF found>0 & vFirstMatch>0 THEN LEAVE
    END
    CLOSE fh
  END

  /* this should never happen */
  OTHERWISE pError("Error in script")
END

IF found==1 THEN DO
  IF applied==1 THEN
    pEcho("BoardReconfigured")
END
ELSE DO
  IF UPPER(config)~=="DEFAULT" & vNoDef==0 THEN DO
    pEcho("No config '"config"' found, applying DEFAULT...")
    cmd='REXXC:RX REXX:ABR.rexx CONFIG DEFAULT'
    IF list~=="" THEN cmd=cmd' LIST 'list
    IF vQuiet>0 THEN cmd=cmd" QUIET"
    ADDRESS COMMAND cmd
    EXIT RC
  END
END

pEcho("Script Terminated")
EXIT 0

/* ==== PROCEDURES & FUNCTIONS ==== */
pLower: PROCEDURE
  PARSE ARG s
  lo='abcdefghijklmnopqrstuvwxyzãäâàáêèéîìíõôòóüûùú'
  up='ABCDEFGHIJKLMNOPQRSTUVWXYZÃÄÂÀÁÊÈÉÎÌÍÕÔÒÓÜÛÙÚ'
  RETURN TRANSLATE(s,lo,up)

pEcho: PROCEDURE EXPOSE vQuiet
  PARSE ARG m
  IF vQuiet==0 THEN SAY m
  RETURN 0  

pEchoMsg: PROCEDURE
  PARSE ARG m
  SAY m
  RETURN 0  

pError: PROCEDURE
  PARSE ARG m
  SAY "ERROR: "m
  EXIT 20
  RETURN 20
      
pInfoBox: PROCEDURE EXPOSE vQuiet
  PARSE ARG m
  pEcho("Info: "m)
  ADDRESS COMMAND 'RequestChoice Info "'TRANSLATE(m,"'",'"')'" Ok >NIL:'
  RETURN 0

pErrorBox: PROCEDURE EXPOSE vQuiet
  PARSE ARG m
  pEcho("Error: "m)
  ADDRESS COMMAND 'RequestChoice Error "'TRANSLATE(m,"'",'"')'" Ok >NIL:'
  EXIT 20
  RETURN 20

pPause: PROCEDURE
  PARSE ARG m
  IF m=="" THEN m="Press ENTER to continue"
  ADDRESS COMMAND 'ASK "'TRANSLATE(m,"'",'"')'"'
  RETURN 0

pSleep: PROCEDURE
  PARSE ARG x
  s=TIME('E')
  DO WHILE (TIME('E')-s)<x
  END
  RETURN 0

pCmd: PROCEDURE EXPOSE vQuiet
  PARSE ARG c
  pEcho(c)
  ADDRESS COMMAND c
  r=RC
  IF r~==0 THEN pEchoMsg("Command exited with ReturnCode="r)
  RETURN r

pGetEnv: PROCEDURE
  n=ARG(1)
  IF OPEN(fh,"ENV:"n,"r") THEN DO
    v=READLN(fh)
    CLOSE(fh)
    v=UPPER(v)
  END
  ELSE v=""
  RETURN v

pAssignExists: PROCEDURE EXPOSE vQuiet
  PARSE ARG a
  ADDRESS COMMAND "ASSIGN EXISTS "a" >NIL:"
  IF RC~==0 THEN pError("Assign "a" not defined!")
  RETURN 0

pFileExists: PROCEDURE EXPOSE vQuiet
  PARSE ARG f
  IF ~EXISTS(f) THEN pError("File "f" does not exist!")
  RETURN 0

pWHDLoad: PROCEDURE EXPOSE RX WIBREXX vInfo vQuiet
	PARSE ARG L
	sp=0
	up=0
	r=0
  DO FOREVER
    PARSE VAR L p " " L
    IF p=="" THEN BREAK
    o=LEFT(p,1)
    SELECT
      WHEN o=='+' THEN DO; sp=sp+1; s.sp=SUBSTR(p,2); END
      WHEN o=="-" THEN DO; up=up+1; u.up=SUBSTR(p,2); END
      OTHERWISE DO; sp=sp+1; s.sp=p; END
    END
  END
  IF sp==0 & up==0 THEN RETURN 0
  w=""
 	IF sp>0 THEN DO
 	  w=w"Set:*n"
 		DO i=1 TO sp
 		  w=w||s.i"*n"
 		END
  END
 	IF up>0 THEN DO
 	  w=w"UnSet:*n"
 		DO i=1 TO up
 		  w=w||u.i"*n"
 		END
 	END  
  IF vInfo~=="" THEN DO
  	pEcho("Checking if INFO file needs TT updates...")
  	m=""
  	IF sp>0 THEN
  		DO i=1 TO sp
  		  m=m" SETTT "s.i
  		END
  	IF up>0 THEN
  		DO i=1 TO up
  		  m=m" DELTT "u.i
  		END
  	c=RX" "WIBREXX" QUIET NOASK FILE "vInfo||m
  	r=pCmd(c)
    IF r==1 THEN RETURN r
    ELSE IF r==0 THEN DO
      pInfoBox("The INFO file was updated with settings bellow.*nPlease relaunch the game/demo.*n"||w)
 		  RETURN r
    END
    m="Error updating INFO file with "WIBREXX" script.*n"
  END
  ELSE m=""
	m=m"Please change WHDLoad settings manually:*n"
  pInfoBox(m||w)
	RETURN r
	  
pHelp: PROCEDURE EXPOSE Version
  SAY "VERSION: "Version" by Nandgate/NMSA"
  SAY "PURPOSE:"
  SAY " AREXX script for Accelerator Board Reconfiguration"
  SAY "SYNTAX:"
  SAY " REXXC:RX REXX:ABR.rexx <parameters>"
  SAY "PARAMETERS:"
  SAY " <CONFIG name> : Specify name of config to use."
  SAY "     If name not found in config file, DEFAULT will be used."
  SAY " [LIST name] : use name of list to use for config files."
  SAY " [INFO file] : use INFO file for updating TTs with WHD config param."
  SAY " [NODEFAULT] : Do not call DEFAULT if config not found"
  SAY " [FIRSTMATCH] : Exit script on 1st config file matched line."
  SAY "     Use this if your config file is large."
  SAY " [QUIET] : suppress output to console (except errors)"
  RETURN 0
