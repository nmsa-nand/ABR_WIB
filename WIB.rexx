/* $VER: WIB.rexx 1.0 2024-01-14 by Nandgate/NMSA
 *
 * WHDLoad Info Batch
 *
 * Check Procedure pHelp() at bottom for usage help
 * Check "WIB.HISTORY.txt" for history changes
 * Check "WIB.README.txt" for more info
 */

Version="v1.0 2024-01-14"

/* ==== VARIABLES ==== */
vDelTT=0
vCmtTT=0
vUnCmtTT=0
vSetTT=0
vSetSlave=0
vSetEACfg=0
vSetEAList=0
vSetEAInfo=0
vCrCfg=0
vDir=0
vFile=0
vNoAsk=0
vAltScan=0
vLog=0
vDbg=0
vQuiet=0
vRootDir=""
vFileName=""
vEAlist=""
fLog=""
DROP vOper

/* ==== CONSTANTS USED WITH vOper ==== */
cDelTT=1
cCmtTT=2
cUnCmtTT=3
cSetTT=4
cSetSlave=5
cSetEACfg=6

/* ==== FILES USED ==== */
fTmp1="T:WIB.tmp1" /* holds all .info files found */
fTmp2="T:WIB.tmp2" /* holds all .info files found, sorted */
fTmp3="T:WIB.tmp3" /* holds all .info files found with ToolType SLAVE, and holds SLAVE value */
fTmp4="T:WIB.tmp4" /* holds ToolTypes Readed from a single .info file */
fTmp5="T:WIB.tmp5" /* holds ToolTypes to be Written to a single .info file */
fTmp6="T:WIB.tmp6" /* holds CFG list, unsorted */
fTmp7="T:WIB.tmp7" /* holds CFG list, sorted, with duplicates */
fCfg="ABR.Created_by_WIB.cfg"   /* holds CFG final list, sorted, no duplicates */

/* ==== PARAMETER READING ==== */
IF ARG()==0 THEN DO
  pHelp()
  EXIT 0
END

PARSE ARG cmdline
i=0
DO WHILE cmdline~==""
  cmdline=STRIP(cmdline,'B')
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

o=0
DO i=1 TO param.0
  parname=UPPER(param.i)
  SELECT
    WHEN parname=="DELEA" | parname=="SETEACFG" THEN DO
        o=o+1
        IF parname=="DELEA" THEN DO
          vOper.o.1=cDelTT
          vDelTT=o
        END
        ELSE DO
          vOper.o.1=cSetEACfg
          vSetEACfg=o
        END
        vOper.o.2="EXECUTEARGS"
        vOper.o.3=""
        vOper.o.4=""
      END
    WHEN parname=="SETSLAVE" THEN DO
        IF i<param.0 THEN DO
          i=i+1
          o=o+1
          n=param.i
          IF n<1 | n>2 THEN pError('Invalid method "'n'" for SETSLAVE parameter!')
          vSetSlave=o
          vOper.o.1=cSetSlave
          vOper.o.2="SLAVE"
          vOper.o.3=n
          vOper.o.4=""
        END
        ELSE pError('Missing method for parameter 'parname)
      END
    WHEN parname=="DELTT" | parname=="CMTTT" | parname=="UNCMTTT" THEN DO
        IF i<param.0 THEN DO
          i=i+1
          o=o+1
          n=UPPER(param.i)
          IF n=="IM1" | n=="IM2" THEN pError('ToolType "'n'" not allowed!')
          SELECT
            WHEN parname=="DELTT" THEN DO
                vOper.o.1=cDelTT
                vDelTT=o
              END
            WHEN parname=="CMTTT" THEN DO
                vOper.o.1=cCmtTT
                vCmtTT=o
              END
            WHEN parname=="UNCMTTT" THEN DO
                vOper.o.1=cUnCmtTT
                vUnCmtTT=o
              END
            OTHERWISE pError("in Code") /* should never happen */
          END
          vOper.o.2=n
        END
        ELSE pError('Missing ToolType name for parameter 'parname)
      END
    WHEN parname=="SETTT" THEN DO
        IF i<param.0 THEN DO
          i=i+1
          o=o+1
          PARSE VAR param.i n "=" v
          n=UPPER(n)
          IF n=="IM1" | n=="IM2" THEN pError('ToolType "'n'" not allowed!')
          vOper.o.1=cSetTT
          vOper.o.2=n
          vOper.o.3=v
          IF v=="" THEN vOper.o.4=n
          ELSE vOper.o.4=n"="v
          vSetTT=o
        END
        ELSE pError('Missing ToolType name for parameter 'parname)
      END
    WHEN parname=="SETEALIST" THEN DO
      IF vEAList=="" THEN DO
        IF i<param.0 THEN DO
          i=i+1
          vEAList=param.i
          vSetEAList=1
        END
        ELSE pError('Missing List name parameter 'parname)
      END
      ELSE pError("Only one SETEALIST parameter supported!")
    END
    WHEN parname=="DIR" THEN DO
      IF vRootDir=="" THEN DO
        IF i<param.0 THEN DO
          i=i+1
          vRootDir=param.i
          vDir=1
        END
        ELSE pError('Missing Root Dir for parameter 'parname)
      END
      ELSE pError("Only one FILE parameter supported!")
    END
    WHEN parname=="FILE" THEN DO
      IF vFileName=="" THEN DO
        IF i<param.0 THEN DO
          i=i+1
          vFileName=param.i
          vFile=1
        END
        ELSE pError('Missing Filename for parameter 'parname)
      END
      ELSE pError("Only one FILE parameter supported!")
    END
    WHEN parname=="LOG" THEN DO
      IF fLog=="" THEN DO
        IF i<param.0 THEN DO
          i=i+1
          fLog=param.i
          vLog=1
          OPEN(fhLog,fLog,"W")
        END
        ELSE pError('Missing Log filename for parameter 'parname)
      END
      ELSE pError("Only one LOG parameter supported!")
    END
    WHEN parname=="SETEAINFO" THEN vSetEAInfo=1
    WHEN parname=="ALTSCAN" THEN vAltScan=1
    WHEN parname=="CREATECFG" THEN vCrCfg=1
    WHEN parname=="NOASK" THEN vNoAsk=1
    WHEN parname=="DEBUG" THEN vDbg=1
    WHEN parname=="QUIET" THEN vQuiet=1
    OTHERWISE pError("Invalid cmdline parameter '"parname"'!")
  END
END
vOper.0=o

IF vDbg>0 THEN DO
  IF vLog>0 THEN pEcho("Log to: "fLog)
  IF vFileName~=="" THEN pEcho("Filename "vFileName)
  IF vRootDir~=="" THEN pEcho("Root Dir: "vRootDir)
  IF vAltScan>0 THEN pEcho("AltScan")
  IF vQuiet THEN pEcho("Quiet")
  IF vNoAsk>0 THEN pEcho("NoAsk")
  IF vDelTT>0 THEN pEcho("DelTT")
  IF vCmtTT>0 THEN pEcho("CmtTT")
  IF vUnCmtTT>0 THEN pEcho("UnCmtTT")
  IF vSetTT>0 THEN pEcho("SetTT")
  IF vCrCfg>0 THEN pEcho("CreateCfg")
  IF vSetEACfg>0 THEN pEcho("SetEACfg")
  IF vSetEAList>0 THEN pEcho("SetEAList: "vEAList)
  IF vSetEAInfo>0 THEN pEcho("SetEAInfo")
  DO z=1 TO vOper.0
    pEcho("Oper."z".1 = "pOperName(vOper.z.1))
    pEcho("Oper."z".2 : "vOper.z.2)
    IF vOper.z.1==cSetTT|vOper.z.1==cSetEACfg|vOper.z.1==cSetSlave THEN DO
      pEcho("Oper."z".3 : "vOper.z.3)
      pEcho("Oper."z".4 : "vOper.z.4)
    END
  END
END

/* ==== PARAMETER CHECK ==== */
IF vSetSlave>0 & (vDelTT+vCmtTT+vUnCmtTT+vSetTT+vSetEACfg)>0 THEN
  pError("Operation SETSLAVE cant be used with DELTT,CMTTT,UNCMTTT,SETTT or SETEACFG!")

IF vDir>0 & vFile>0 THEN
  pError("Cannot use both parameters DIR and FILE!")

IF vSetEACfg==0 THEN DO
  IF vSetEAList>0 THEN pError("Operation SETEALIST requires also operation SETEACFG!")
  IF vSetEAInfo>0 THEN pError("Operation SETEAINFO requires also operation SETEACFG!")
END

DO i=1 TO (vOper.0)-1
  DO c=i+1 TO vOper.0
    IF vOper.i.1~==vOper.c.1 & vOper.i.2==vOper.c.2 THEN
      pError("Operation "pOperName(vOper.i.1)" collides with "pOperName(vOper.c.1)" for same TT "vOper.i.2)
  END
END

IF vNoAsk==0 THEN DO
  SAY "*** WARNING ***"
  SAY "Make sure you have a backup of your INFO files before proceding."
  SAY "Check README file on how to do it."
  WRITECH(STDIN,"Proceed? (NO/yes): ")
  L=UPPER(READLN(STDIN))
  IF L~=="YES" & LEFT(L,1)~=='Y' THEN pError("Aborted by user")
  DO i=1 TO vOper.0
    IF vOper.i.1==cSetSlave THEN DO
      SAY "*** WARNING ***"
      SAY "Messing with the SLAVE ToolType can prevent WHDLoad to work properly."
      WRITECH(STDIN,"Proceed? (NO/yes): ")
      L=UPPER(READLN(STDIN))
      IF L=="YES" | LEFT(L,1)=='Y' THEN LEAVE
      ELSE pError("Aborted by user")
    END
  END
END

totalsteps=0
IF vCrCfg=1 THEN totalsteps=5
IF (vDelTT+vCmtTT+vUnCmtTT+vSetTT+vSetSlave+vSetEACfg)>0 THEN totalsteps=6

IF totalsteps==0 THEN DO
  pEcho("ERROR: Nothing to do!")
  EXIT 0
END

/* ==== REQUIRED EXECUTABLES CHECK ==== */

pFileExists("C:FileToTT")
pFileExists("C:TTTOFile")

/* ==== REQUIRED LIBRARIES */

IF (vDir>0 | vSetSlave>0) & ~SHOW('L','rexxsupport.library') THEN DO
  IF ADDLIB('rexxsupport.library',0,-30,0) THEN
    pEcho("Loaded: rexxsupport.library")
  ELSE
    pError('Could not load library "rexxsupport.library"')
END

/* ==== START OF PROCESSING ==== */

CALL TIME('R')

/* ==== STEP 1: GATHER INFO FILES ==== */

pEcho("STEP 1 OF "totalsteps":");
IF vFile>0 THEN DO
  pFileExists(vFileName)
  If UPPER(RIGHT(vFileName,5))~==".INFO" THEN pError('Given file "'vFileName'" is not an .INFO file!')
  pCmd('echo "'vFileName'" > 'fTmp2)
  dircount=0
  filecount=1
  totalfiles=1
END
ELSE DO
  IF vAltScan>0 THEN DO
    IF vRootDir=="" THEN DO
      pEcho('Creating list of eligible INFO files bellow dir <current>')
      pTraverseDir('')
    END
    ELSE DO
      pEcho('Creating list of eligible INFO files bellow dir "'vRootDir'"')
      pTraverseDir(vRootDir)
    END
  END
  ELSE DO
    IF vRootDir=="" THEN DO
      pEcho('Creating list of all INFO files bellow dir <current>')
      cmd='LIST PAT #?.info LFORMAT %P%N ALL > 'fTmp1
    END
    ELSE DO
      pEcho('Creating list of all INFO files bellow dir "'vRootDir'"')
      cmd='LIST DIR "'vRootDir'" PAT #?.info LFORMAT %P%N ALL > 'fTmp1
    END
    pCmd(cmd)
  END
END

pEcho("Elapsed Time "TIME('E')" seconds")

/* ==== STEP 2: COUNT TOTAL INFO FILES ==== */

IF vFile==0 THEN DO
  pEcho("STEP 2 OF "totalsteps":");
  pEcho("Counting INFO files...")
  
  IF vAltScan>0 THEN
    totalfiles=filecount /* from previous step */
  ELSE DO
    OPEN(fhR,fTmp1,"R")
    c=0
    DO FOREVER
      L=READLN(fhR)
      IF EOF(fhR) THEN LEAVE
      c=c+1
    END
    CLOSE(fhR)
    totalfiles=c
  END
  
  IF totalfiles==0 THEN DO
    pEcho("No INFO files to process!")
    EXIT 5
  END
  
  pEcho("Created a List with "totalfiles" INFO file(s) to process")
  pEcho("Elapsed Time "TIME('E')" seconds")

/* ==== STEP 3: SORT LIST OF FILES ==== */

  pEcho("STEP 3 OF "totalsteps":");
  pEcho("Sorting the list of INFO files")
  pCmd("SORT FROM "fTmp1" TO "fTmp2)
  IF vDbg==0 THEN pCmd("DELETE "fTmp1" >NIL:")  
  
  pEcho("Elapsed Time "TIME('E')" seconds")
END

/* ==== STEP 4: GATHER INFO FILES WITH SLAVES, READ SLAVE NAME, AND CREATE CFG ==== */

pEcho("STEP 4 OF "totalsteps":");
pEcho("Scan INFO files with SLAVE ToolType...")

OPEN(fhR,fTmp2,"R")
OPEN(fhW,fTmp3,"W")
IF vCrCfg>0 THEN DO
  pCmd('echo "; Cfg file generated with script WIB.rexx" > 'fCfg)
  pCmd('echo "|DEFAULT|" >> 'fCfg)
  pCmd('echo ";========" >> 'fCfg)
  OPEN(fhC,fTmp6,"W")
END
c=0
sc=0
DO UNTIL EOF(fhR)
  f=READLN(fhR)
  IF f~=="" THEN c=c+1
  If UPPER(RIGHT(f,5))==".INFO" THEN DO
    pEcho("Processing "f)
    IF vSetSlave>0 THEN DO
      SELECT
        WHEN vOper.vSetSlave.3==1 THEN DO /* method 1 */
          s=COMPRESS(pGetNameFromFile(f))
          s=LEFT(s,LENGTH(s)-5)
          WRITELN(fhW,f"|"s)
          IF vCrCfg>0 THEN WRITELN(fhC,"|"s"|")
          sc=sc+1
        END
        WHEN vOper.vSetSlave.3==2 THEN DO /* method 2 */
          s=COMPRESS(pGetSlaveFile(pGetDirFromFile(f)))
          IF UPPER(RIGHT(s,6))==".SLAVE" THEN DO
            s=LEFT(s,LENGTH(s)-6)
            WRITELN(fhW,f"|"s)
            IF vCrCfg>0 THEN WRITELN(fhC,"|"s"|")
            sc=sc+1
          END
        END
        OTHERWISE pError("in Code") /* should never happen */
      END
    END
    ELSE DO
      v=pGetTT(pReadIcon(f),"SLAVE")
      t=INDEX(UPPER(v),".SLAVE")
      IF t>1 THEN v=COMPRESS(LEFT(v,t-1))
      IF v=="" THEN pEcho("File "f" has no Slave!")
      ELSE DO
        pEcho("File "f" has SLAVE="v)
        WRITELN(fhW,f"|"v)
        IF vCrCfg>0 THEN WRITELN(fhC,"|"v"|")
        sc=sc+1
      END
    END
    pEcho("STEP 4 OF "totalsteps": "TRUNC(c/totalfiles*100,1)"% Done")
  END
END
CLOSE(fhR)
CLOSE(fhW)
IF vCrCfg>0 THEN CLOSE(fhC)
totalfilesslave=sc

IF vDbg==0 THEN pCmd("DELETE "fTmp2" >NIL:")

pEcho("Scanned "totalfiles" INFO files where "totalfilesslave" have SLAVE ToolType")
pEcho("Elapsed Time "TIME('E')" seconds")

/* ==== STEP 5: SORT CFG LIST AND REMOVE DUPLICATES ==== */

IF vCrCfg>0 THEN DO
  pEcho("STEP 5 OF "totalsteps":");
  pEcho("Sorting CFG list")
  pCmd("SORT FROM "fTmp6" TO "fTmp7)
  IF vDbg==0 THEN pCmd("DELETE "fTmp6" >NIL:")
  OPEN(fhR,fTmp7,"R")
  OPEN(fhC,fCfg,"A")
  LL=""
  DO UNTIL EOF(fhR)
    L=READLN(fhR)
    IF L~==LL THEN DO
      WRITELN(fhC,L)
      LL=L
    END
  END
  CLOSE(fhR)
  CLOSE(fhC)
  IF vDbg==0 THEN pCmd("DELETE "fTmp7" >NIL:")
  pEcho("Config file "fCfg" created")
  pEcho("Elapsed Time "TIME('E')" seconds")
END

/* ==== STEP 6: PROCESS ToolTypes FROM INFO FILE(S) ==== */

totalchanged=0
IF (vDelTT+vCmtTT+vUnCmtTT+vSetTT+vSetSlave+vSetEACfg)>0 THEN DO
  pEcho("STEP 6 OF "totalsteps": ")
  pEcho("Processing ToolTypes of INFO files")
  IF vEAList~=="" THEN vEAList="L "vEAList" "
  p=0
  OPEN(fhF,fTmp3,"R")
  DO UNTIL EOF(fhF)
    L=READLN(fhF)
    PARSE VAR L f "|" s
    p=p+1
    If UPPER(RIGHT(f,5))==".INFO" THEN DO
      pEcho("Processing ToolTypes of file "f)
      pCmd('TTToFile FROM "'f'" TO 'fTmp4)
      OPEN(fhR,fTmp4,"R")
      OPEN(fhW,fTmp5,"W")
      ch=0
      DO o=1 TO vOper.0 /* initialize flags for input INFO file parsing */
        vOper.o.6=0 /* same value, uncommented */
        vOper.o.7=0 /* same value, commented */
        vOper.o.8=0 /* diff value, uncommented */
        vOper.o.9=0 /* diff value, commented */
      END
      /* PASS 1 */
      DO FOREVER
        T=READLN(fhR)
        IF EOF(fhR) THEN LEAVE
        PARSE VAR T n "=" v
        n=UPPER(STRIP(n))
        IF INDEX(";*(",LEFT(n,1))>0 THEN DO
          c=1; n=STRIP(SUBSTR(n,2))
        END
        ELSE c=0
        IF vSetEACfg>0 THEN DO
          vEA="EXECUTEARGS="vEAList"C "s
          IF vSetEAInfo>0 THEN DO
            IF INDEX(f," ")>0 THEN DO
              pEcho("WARNING: Cannot put paths with spaces on EXECUTEARGS (I)NFO value!" '0a'x "Waiting 10 secs")
              pSleep(10)
            END
            ELSE vEA=vEA" I "f
            IF LENGTH(vEA)>127 THEN
              pError("The EXECUTEARGS tooltype exceeds the 127 chars per line allowed on INFO files!" '0a'x "Consider using ASSIGNs to shorten paths!")
          END
          vOper.vSetEACfg.3=substr(vEA,13)
          vOper.vSetEACfg.4=vEA
        END
        IF vSetSlave>0 THEN DO
          vOper.vSetSlave.3=s".slave"
          vOper.vSetSlave.4="SLAVE="s".slave"
        END
        DO o=1 TO vOper.0
          SELECT
            WHEN vOper.o.2==n&(vOper.o.1==cSetSlave|vOper.o.1==cSetTT|vOper.o.1==cSetEACfg) THEN DO
              IF vOper.o.3=v THEN
                IF c==0 THEN vOper.o.6=(vOper.o.6)+1; ELSE vOper.o.7=(vOper.o.7)+1
              ELSE
                IF c==0 THEN vOper.o.8=(vOper.o.8)+1; ELSE vOper.o.9=(vOper.o.9)+1
            END
            WHEN vOper.o.1==cDelTT|vOper.o.1==cCmtTT|vOper.o.1==cUnCmtTT THEN DO
              IF c==0 THEN vOper.o.6=(vOper.o.6)+1; ELSE vOper.o.7=(vOper.o.7)+1
            END
            OTHERWISE
          END
        END
      END
      /* PASS 2 */
      SEEK(fhR,0,'B')
      DO FOREVER
        T=READLN(fhR)
        IF EOF(fhR) THEN LEAVE
        PARSE VAR T n "=" v
        n=UPPER(STRIP(n))
        IF INDEX(";*(",LEFT(n,1))>0 THEN DO
          c=1; n=STRIP(SUBSTR(n,2))
        END
        ELSE c=0
        w=1
        DO o=1 TO vOper.0
            SELECT
              WHEN vOper.o.1==cSetEACfg|vOper.o.1==cSetSlave|vOper.o.1==cSetTT THEN DO
                IF (vOper.o.6+vOper.o.8)==0 THEN DO
                  WRITELN(fhW,vOper.o.4)
                  vOper.o.6=-1; vOper.o.8=-1; ch=1
                END
                ELSE IF vOper.o.2==n THEN DO
                  IF vOper.o.3==v THEN DO
                    IF vOper.o.6>1 THEN DO
                      vOper.o.6=(vOper.o.6)-1; ch=1; w=0; LEAVE
                    END
                    ELSE IF vOper.o.6==1 THEN DO
                      vOper.o.6=-1; LEAVE
                    END
                  END
                  ELSE DO
                    IF vOper.o.8>1 THEN DO
                      vOper.o.8=(vOper.o.8)-1; ch=1 w=0; LEAVE
                    END
                    ELSE IF vOper.o.8==1 THEN DO
                      WRITELN(fhW,vOper.o.4)
                      vOper.o.8=-1; ch=1; w=0; LEAVE
                    END
                  END
                END
              END
              OTHERWISE
            END
            IF vOper.o.2==n THEN DO
              SELECT
                WHEN c==0&vOper.o.1==cDelTT&vOper.o.6>0 THEN DO
                  vOper.o.6=(vOper.o.6)-1; ch=1; w=0; LEAVE
                END
                WHEN c==0&vOper.o.1==cCmtTT THEN DO
                  IF (LENGTH(T)>126) THEN WRITELN(fhW,";"LEFT(T,126))
                  ELSE WRITELN(fhW,";"T)
                  ch=1; w=0; LEAVE
                END
                WHEN c==1&vOper.o.1==cUnCmtTT&vOper.o.6==0 THEN DO
                  IF (vOper.o.7>1) THEN DO
                    vOper.o.7=(vOper.o.7)-1
                    ch=1; w=0; LEAVE
                  END
                  ELSE IF (vOper.o.7==1) THEN DO
                    T=STRIP(T,"L")
                    IF LEFT(T,1)="(" THEN T=STRIP(TRIM(T),"T",")")
                    WRITELN(fhW,SUBSTR(T,2))
                    vOper.o.7=-1
                    ch=1; w=0; LEAVE
                  END
                END
                OTHERWISE
              END
            END
        END
        IF w>0 THEN DO
          IF LENGTH(T)>127 THEN T=LEFT(T,127)
          IF T~=="" THEN WRITELN(fhW,T)
        END
      END
      CLOSE(fhR)
      CLOSE(fhW)
      IF ch>0 THEN DO
        pCmd('FileToTT FROM 'fTmp5' TO "'f'"')
        totalchanged=totalchanged+1
      END
      ELSE pEcho('File "'f'" has no ToolTypes changes')
      pEcho("STEP 6 OF "totalsteps": "TRUNC(p/totalfilesslave*100,1)"% Done")
    END
  END
  CLOSE(fhF)
  IF vDbg==0 THEN DO
    pCmd("DELETE "fTmp4" >NIL:")
    pCmd("DELETE "fTmp5" >NIL:")
  END
END

IF vDbg==0 THEN pCmd("DELETE "fTmp3" >NIL:")

pEcho("Total: "totalfiles" INFO(s), "totalfilesslave" with SLAVE, "totalchanged" updated")

IF (vDir>0 | vSetSlave>0) & SHOW('L',"rexxsupport.library") THEN DO
  IF REMLIB('rexxsupport.library') THEN
    pEcho("Unloaded: rexxsupport.library.")
  ELSE
    pError('Could not Unload library "rexxsupport.library"')
END

pEcho("Processing took "TIME('E')" seconds")

IF vLog>0 THEN CLOSE(fhLog)

IF vFile>0 THEN DO
  IF ch>0 THEN EXIT 0; ELSE EXIT 1
END
ELSE IF vDir>0 THEN DO
  IF totalchanged==0 THEN EXIT 1; ELSE EXIT 0
END

/* should never happen */
EXIT 20

/* ==== PROCEDURES & FUNCTIONS ==== */

/* echoes string */
pEcho: PROCEDURE EXPOSE vLog fhLog vQuiet
  m=ARG(1)
  IF vLog>0 THEN WRITELN(fhLog,m)
  IF vQuiet==0 THEN SAY m
  RETURN 0

/* echoes error and aborts script */
pError: PROCEDURE EXPOSE vLog fhLog vQuiet
  m="ERROR: "ARG(1)
  IF vLog>0 THEN WRITELN(fhLog,m)
  SAY m
  EXIT 20
  RETURN 0

/* executes shell command */
pCmd: PROCEDURE EXPOSE vLog fhLog vQuiet
  c=ARG(1)
  pEcho(c)
  ADDRESS COMMAND c
  r=RC
  IF r~==0 THEN pError("Command exit with ReturnCode="r)
  RETURN 0

/* sleep X seconds */
pSleep: PROCEDURE
  PARSE ARG x
  s=TIME('E')
  DO WHILE (TIME('E')-s)<x
  END
  RETURN 0

pPause: PROCEDURE
  PARSE ARG m
  IF m=="" THEN m="Press ENTER to continue"
  ADDRESS COMMAND 'ASK "'TRANSLATE(m,"'",'"')'"'
  RETURN 0

/* check if file exists */
pFileExists: PROCEDURE EXPOSE vLog fhLog vQuiet
  PARSE ARG f
  IF ~EXISTS(f) THEN pError("File "f" does not exist!")
  RETURN 0

/* get operation name from value */
pOperName: PROCEDURE EXPOSE cDelTT cCmtTT cUnCmtTT cSetTT cSetSlave cSetEACfg vAltScan
  o=ARG(1)
  SELECT
    WHEN o==cDelTT THEN r="DELTT"
    WHEN o==cCmtTT THEN r="CMTTT"
    WHEN o==cUnCmtTT THEN r="UNCMTTT"
    WHEN o==cSetTT THEN r="SETTT"
    WHEN o==cSetSlave THEN r="SETSLAVE"
    WHEN o==cSetEACfg THEN r="SETEACFG"
    OTHERWISE r="Unknown"
  END
  RETURN r

/* get icon data from INFO file */
pReadIcon: PROCEDURE
  fn=ARG(1)
  d=''
  IF OPEN(fh,fn,'R') THEN DO
    d=READCH(fh,65535)
    CALL CLOSE(fh)
  END
RETURN d

/* get ToolType Value from icon data */
pGetTT: PROCEDURE
  d=ARG(1) /* Icon file data */
  n=UPPER(ARG(2)) /* TT name */
  p=0;s=0;e=0;tt='';v=''
  IF d~=="" THEN DO
    p=INDEX(UPPER(d),n,1)
    IF p>0 THEN DO
      s=LASTPOS(D2C(0),d,p)+2
      e=INDEX(d,D2C(0),s)-1
      tt=STRIP(SUBSTR(d,s,(e+1)-s))
      IF LEFT(UPPER(tt),LENGTH(n))=n THEN DO
        PARSE VAR tt '=' v
        v=STRIP(v)
      END
    END
  END
RETURN v

/* Traverse a directory */
pTraverseDir: PROCEDURE EXPOSE fhT fTmp1 dircount filecount totalfiles
  r=ARG(1)
  dircount=0
  filecount=0
  totalfiles=0
  OPEN(fhT,fTmp1,"W")
  pVisitDir(STRIP(r,'T','/'))
  CLOSE(fhT)
  RETURN 0

/* process dir found in traverse */
pVisitDir: PROCEDURE EXPOSE fhT dircount filecount totalfiles
  r=ARG(1)
  fs=SHOWDIR(r,'F',':')
  DO FOREVER
    PARSE VAR fs f ":" fs
    IF f=="" THEN LEAVE
    totalfiles=totalfiles+1
    PARSE VAR f n "." e
    n=UPPER(n)
    e=UPPER(e)
    IF e=="INFO" & INDEX("||CODES|CHEAT|DISK|DOCS|GUIDE|HELP|HINTS|INSTRUCTIONS|KEY|KEYS|MANUAL|MAP|MAPS|PICS|PREFS|PREFERENCES|QUICKDOCS|READ_ME|READ-ME|README|RULEBOOK|SOLUTION|TABLES|TECHGUIDE|TIPS|USERGUIDE|","|"n"|")==0 THEN DO
      filecount=filecount+1
      WRITELN(fhT,r"/"f)
    END
  END
  dirs=SHOWDIR(r,'D',':')
  DO FOREVER
    PARSE VAR dirs d ":" dirs
    IF d=="" THEN LEAVE
    dircount=dircount+1
    IF r=="" THEN p=d
    ELSE IF RIGHT(r,1)==":" THEN p=r||d
         ELSE p=r"/"d
    pVisitDir(p)
  END
  RETURN 0

/* get path portion from fullpath */
pGetDirFromFile: PROCEDURE
  p=ARG(1) /* full path with filename */
  IF INDEX(p,"/")>0 THEN d=LEFT(p,LASTPOS("/",p))
  ELSE DO
    i=INDEX(p,":")
    IF i>0 THEN d=LEFT(p,i); ELSE d=""
  END
  RETURN d

/* get filename portion from fullpath */
pGetNameFromFile: PROCEDURE
  p=ARG(1) /* full path with filename */
  IF INDEX(p,"/")>0 THEN n=SUBSTR(p,LASTPOS("/",p)+1)
  ELSE DO
    i=INDEX(p,":")
    IF i>0 THEN n=SUBSTR(p,i+1); ELSE n=p
  END
  RETURN n

/* get first .slave file in a dir */
pGetSlaveFile: PROCEDURE
  d=ARG(1) /* dir to search */
  fs=SHOWDIR(d,"F",":")
  DO FOREVER
    PARSE VAR fs s ":" fs
    s=UPPER(s)
    IF fs=="" THEN LEAVE
    IF RIGHT(s,6)==".SLAVE" THEN RETURN s
  END
  RETURN ""
END

/* some help */
pHelp: PROCEDURE EXPOSE Version
  SAY "VERSION: "Version" by Nandgate/NMSA"
  SAY "PURPOSE:"
  SAY " AREXX script for WHDLoad INFO Batch processing"
  SAY "SYNTAX:"
  SAY " RX WIB.rexx <parameters>"
  SAY "PARAMETERS:"
  SAY " ALTSCAN : Use alternate method to scan INFO files"
  SAY " LOG <file> : Log all output to file"
  SAY " FILE <name> : Process single INFO file (or use param DIR)"
  SAY " DIR <root>  : Specify root directory to traverse"
  SAY "               If not given, use current directory"
  SAY " DELTT <tt> : Delete ToolType tt (if not commented)"
  SAY " DELEA : Delete ToolType EXECUTEARGS. Equivalent to DELTT EXECUTEARGS"
  pPause()
  SAY " CMTTT <tt> : Comment ToolType tt"
  SAY " UNCMTTT <tt> : UnComment ToolType tt"
  SAY " SETTT <tt[=value]> : Set/Update ToolType tt (with value, if given)"
  SAY " SETSLAVE <m> : Set/Update SLAVE ToolType, using method <m>"
  SAY "         This will process ALL INFO files found in dir traversal"
  SAY "   m=1 : SLAVE=<INFO filename with .slave extension>"
  SAY "   m=2 : SLAVE=<First file .slave found in same dir of INFO file>"
  SAY " CREATECFG : Create cfg file for script ABR.rexx"
  SAY "  with all SLAVEs found."
  SAY "  A file "fCfg" will be created on current directory"
  SAY " SETEACFG : Create TT ExecuteArgs=CONFIG <value of SLAVE>"
  SAY " SETEALIST <name> : Specify LIST value for use with SETEACFG"
  SAY " SETEAINFO : Set INFO filename for use with SETEACFG"
  SAY " NOASK : assume YES to all questions"
  SAY " QUIET : suppress output to console (except LOG and errors)"
  SAY " DEBUG : dont delete temp files. Also provides some debug info."
  RETURN 0
