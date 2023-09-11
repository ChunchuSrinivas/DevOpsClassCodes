#!/bin/ksh
#
# +============================================================================+
# |             COPYRIGHT (c) 2013 ADP Canada, Financial Systems               |
# +============================================================================+
# |                                                                            |
# | Module      : xxmm_build.sh                                                |
# |                                                                            | 
# | Purpose     : Script to create build package for various components        | 
# |                                                                            | 
# | FUnctions   : Usage:  Function to put Usage Info                           |
# |               CheckInit:  Check & Initialize                               |
# |               LogTerm: Write Message to Terminal as well as to Log File    |
# |               LogMsg: Write message to Log File only                       |
# |               CheckDir: Check and Create Directory if not existing         |
# |               GetGITfile: Pull the given specific file for specific version|
# |               BuilSubDir: Create Sub Directory for file type               |
# |               ExecReport: Generates the Execution Report                   |
# |               CreateBuildPkg: Create the Build Package (Main Function)     | 
# |                                                                            | 
# | Author      : Ambikesh Pagare                                              |
# | Date        : 21-JUN-2022                                                  |
# | Version     : 1.2                                                          |
# |                                                                            |
# +----------------------------------------------------------------------------+
# |                               BIBLIOGRAPHY                                 |
# +----------------------------------------------------------------------------+
# |    Date     |     Author         |     SCR      |       Remarks            |
# +----------------------------------------------------------------------------+
# | 28-APR-2013   Ambikesh Pagare      IMMS          Initial Draft Version 0.1 |
# | 03-MAY-2013   Ambikesh Pagare      IMMS          Added WINDOWS file path   |
# |                                                  conversion back to UNIX   |
# |                                                  Also, added getting the   |
# |                                                  right filename when the   |
# |                                                  casename mismatched       |
# | 24-MAR-2022   Ambikesh Pagare      IMMS          Modified entire script to |
# |                                                  convert from SVN to GIT.  |
# |                                                  Now, the components are   |
# |                                                  fetched from BitBucket as |
# |                                                  per the CURL commands.    |
# | 21-JUN-2022   Ambikesh Pagare      CICD          Added sequencing for the  |
# |                                                  DB Scripts                |
# | 18-JUL-2022   Ambikesh Pagare      CICD          Made Repo and Branch as   |
# |                                                  mandatory parameters      |
# |                                                                            |
# +============================================================================+
#

# ==================================
# Functions Declaration Section
# ==================================


# ======================================================================= 
#
# Function    : Usage
# Purpose     : Prints the usage information and exits with return code 1
# Parameters  : None
#
# =======================================================================

Usage ()
{
    typeset script=$(basename $0)
    echo -e "Usage: $script <Build Number> <Repo> <Branch> \n\t eg: $script $(date '+%Y%m%d') IMMS master"
    exit 1
}

# ==================================================================== 
#
# Function    : LogTerm
# Purpose     : Show the input message on terminal and also to logfile
# Parameters  : Message
#
# ====================================================================

LogTerm ()
{
 
   echo -e "$* " | tee -a $logfile
  
}


# ==================================================================== 
#
# Function    : LogMsg
# Purpose     : LogMsg the input message to logfile
# Parameters  : Message
#
# ====================================================================

LogMsg ()
{

  echo -e "$* " >> $logfile

}


# ==================================================================== 
#
# Function    : RemCtrlChar
# Purpose     : Remove ^M Characters in the file   
# Parameters  : Input File Name
#
# ====================================================================



RemCtrlChar ()

{

 typeset infile="$1"
 typeset tmpfile="$infile.tmp"

 # Check if the File has any Other Control Characters in it.
 ctrlchar=0
 ctrlchar=$(od -toC -An  $infile | grep -c 015)
 LogMsg "Found $ctrlchar control characters (^M) by using Octal Value (015) in the file $infile" 

 if [ $ctrlchar -gt 0 ] 
 then

   LogMsg "Removing (^M) characters in the file $( basename $infile ) ... \\c" 

   # Create a temporary file without ^M characters
   # The carriage return will be seen on windows and ^M will be seen on UNIX.
   # The new line character must not be changed.
   
   sed 's/'`echo "\015"`'//g' $infile > $tmpfile && LogMsg " $ctrlchar ^M Characters removed successfully." || LogTerm "^M Characters removal Failed"

   # Rename the temporary file back to original filename
   mv $tmpfile $infile && LogMsg "Moved File $infile Successfully."  || LogMsg "Failed! in Moving File $infile" 

 fi
 
}

# ==================================================================== 
#
# Function    : CheckInit
# Purpose     : Check for Input Parameters and the APPS environment
#               Initialize some Global Variables
# Parameters  : None
#
# ====================================================================

CheckInit ()
{
    # Lets get a bit fancy here
    # Do some highlighting and BOLD stuff ;)
    beginhi=$(tput smso)
    endhi=$(tput rmso)
    bold=$(tput bold)
    normal=$(tput sgr0)

    # Initialize Exception List and Error List Variables
    exception_list=""
    error_list=""

    # Check for Instance 
    if [ -z "$XXMM_TOP" ]
    then
        echo -e "ERROR: APPS environment is not set.\nPlease source the environment [ . adpenv <INSTANCE> ] before running the script."
    fi
    
    # Define Config File
    # The Config File Defines the BASE INSTALL DIR under which the Install Package Dir
    # is created. Also contains the BitBucket Server and Access token
    
    configfile=$XXMM_TOP/shl/config/xxmm_install.conf

    # Check if the Config File exists or not
    # We cannot proceed without a Config file
    if [ ! -f $configfile ]
    then
        echo -e  "The Configfile $configfile is missing. Please restore and re-run."
        exit 1
    fi    
    
    # Source the Install Config file
    # Following preceeding DOT (.) must not be removed
    . $configfile 
    
    # Source the install directory from Config
    instdir="$BASE_INSTALL_DIR" 


    
    # Check if we have got Build Number or not    
    if [ -z "$1"  ]
    then
        echo -e "Please enter the Build Number: \c"
        read buildnum
        
    else
        buildnum=$1
    fi
    
    # If we still do not have the Build Number, then show it to the BOSS
    if [ -z "$buildnum" ]
    then
        Usage
    else
    
        # The file containing Build Components must be named same as Build Number
        buildlist="$instdir/$buildnum.csv"
        
        if [ ! -f "$buildlist" ]
        then
            echo -e "Build List file $buildlist does not exist. Please ensure the file is staged for BUILD"
            exit 1
        fi    

    fi
  
    # Global Repo & Branch, if passed
    REPO="$2"
    BRANCH="$3"

    if [ -z "$REPO" ] 
    then  
     LogTerm "ERROR: Repo is mandatory. Aborting" 
     Usage
    fi
 
   if [ -z "$BRANCH" ]
   then
    LogTerm "ERROR: Branch is mandatory. Aborting"  
    Usage 
   fi  

    # Set the logfile    
    logfile="$instdir/$buildnum/build.log"

                  
}



# ==================================================================== 
#
# Function    : CheckDir
# Purpose     : Check if directory exists, if not Create it
# Parameters  : Directory
#
# ====================================================================

CheckDir ()
{
 
 # Create the directory if it doesn't exist already 
  [ ! -d "$1"  ] &&  mkdir "$1"
      

}


# ==================================================================== 
#
# Function    : GetGITfile
# Purpose     : Get BitBucket file from the repo/branch based on input
# Parameters  : 1. Destination Build Directory where file to be placed
#
# ====================================================================

GetGITfile ()
{
 
 
  # The Destination Build File
  typeset buildfile="$1"
 
  # Catch the Download results
  typeset bitresult=""
    
  
  printf "%-90s" "Fetching $path/$filename  ... "
  # Download BitBucket URL for the RAW File
  dldURL=${ echo "$BITSERVER/$REPO/raw/$path/$filename?at=refs/heads/$BRANCH" | sed 's/ /%20/g' }
  
  # Prepare CURL command to download the file 
  # Flags -s=Silent -S=Show-Error -f=Failure Return Code -H=Header
	curlCMD="curl -s -S -f -H \"Authorization: Bearer $BBtoken\" -o $buildfile \"$dldURL\""

	LogMsg "Donwload command: $curlCMD"
 
 # This is the real deal, fetch the file from BitBucket
  bitresult=$( eval "$curlCMD" 2>&1 )
 
  
 # If Success then tell the BOSS :-)
 if [ $? -eq 0 ] 
 then 
     LogTerm "  DONE."
     LogMsg "$bitresult"
     
     # Check if the ^M Characters have to be removed
     # If yes, then remove them
     
    
     if $chkctrlchar  
     then 
       RemCtrlChar "$buildfile" 
     else
       LogMsg "No need to remove ^M Char"
     fi  
     
 else
     LogTerm "  FAILED.\n***ERROR: $bitresult***"
     
     error_list="Failed fetching $filename, ERROR: $bitresult \n$error_list"
 fi 
 
}

# ==================================================================== 
#
# Function    : ExecReport
# Purpose     : This is the Function that writes output to the Console 
#               when the script is done after all the hard work      
# Parameters  : None
#
# ====================================================================


ExecReport ()
{

  
  # Move to the Build Directory for ready INSTALL
  cd $instdir/$buildnum
  
  # Get the Directory List
  dirlist=$( find . -type d | awk -F '/' '{ if ( NR>1) printf "%3s %s \n", NR - 1, $2 }' )
  
  LogTerm "\n==========================================="
  LogTerm " EXECUTION REPORT BUILD# $bold $buildnum $normal"
  LogTerm "===========================================\n"
  LogTerm " Build Sub Directories Created:"
  sleep 1
  LogTerm "------------------------------------\n$dirlist"
  
  
  # If Any errors encountered, publish the list
  if [ ! -z "$error_list" ]
  then
    
    LogTerm "\n------------------------------------"
    LogTerm "$bold ERRORS $normal"
    LogTerm "------------------------------------"
    sleep 1
    LogTerm "$error_list"
    LogTerm "------------------------------------\n"
  fi

  # If any exceptions, publish the list
  if [ ! -z "$exception_list" ]
  then
    
    
    LogTerm "\n------------------------------------"
    LogTerm "$bold EXCEPTIONS $normal"
    LogTerm "------------------------------------"
    sleep 1
    LogTerm "$exception_list"
    LogTerm "------------------------------------\n"
  fi
 end=$( date +%s.%N )
 runtime=$( echo 'scale=2;'"$end - $start" | bc -l )
 
 LogTerm "==========================================="
 LogTerm " BUILD $beginhi $bold $buildnum $normal $endhi Complete in $runtime seconds" 
 LogTerm " Please review BUILD and hit INSTALL."
 LogTerm "===========================================\n"

}


# ==================================================================== 
#
# Function    : BuildSubdir
# Purpose     : Function to create component specific sub-directory
#               within build directory. Install scripts rely on this       
# Parameters  : Uses Global Variables
#
# ====================================================================


BuildSubdir ()
{

  # Define Variable for DB component
  isDB=false
   
  # Go through GIT Directory and File extension and create Build Sub Directories
  case "$filedir" in

  # These are the ones that have same Build Directory structure as GIT Directory
  "table" | "view" | "sequence" | "index" | "synonym" | "trigger" ) 
     build_subdir="$filedir"
     chkctrlchar=true
     isDB=true
     ;;

  # Host Scripts, same structure
  "bin" | "shl" | "config" ) 
     build_subdir="$filedir"
     chkctrlchar=true
     ;;  
     
  # For Package Spec and Body (including Handlers)
  "package spec" | "table handler spec") 
     build_subdir="package_spec"
     chkctrlchar=true
     isDB=true
     ;;

  "package body" | "table handler body") 
     build_subdir="package_body"
     chkctrlchar=true
     isDB=true
     ;;
  
  # For Forms and Reports
  "us") 
     if [ "$filextn" = "fmb" ] 
     then 
         build_subdir="form"
     else 
         build_subdir="report" 
     fi
     chkctrlchar=false
     ;;
 
  # For PLL Libraries
  "resource")
     build_subdir="pll"
     chkctrlchar=false
     ;;
  
  # For BIP Data Definitions
  "data definitions") 
     build_subdir="bip_def"
     chkctrlchar=true
     ;;

  # For BIP Data Templates
  "templates") 
     build_subdir="bip_tmpl"
     chkctrlchar=true
     ;;
    
  # Catch Everything else here  
  *)
    
    # If the Extension is LDT then its FNDLOAD
    if [ "$filextn" = "ldt" ]
    then
        build_subdir="fndload"
        chkctrlchar=true
     
    # If it's SQL then MISC_SQL
    elif [ "$filextn" = "sql" ]
    then
        build_subdir="misc_sql"
        chkctrlchar=true
        isDB=true
    
    # For Everything else catch under exception directory
    else
        build_subdir="exception"
        exception_list="$exception_list $filename\n"
        chkctrlchar=false
     
    fi
    ;;

  esac

   
}


# ==================================================================== 
#
# Function    : CreateBuildPkg
# Purpose     : Main Function that creates the Build Package       
# Parameters  : NONE                 
#
# ====================================================================

CreateBuildPkg ()
{

 # Check (and create) the Build Directory
 CheckDir "$instdir/$buildnum" 


 # So we start here, let people know we're doing something serious :)
 echo "" >$logfile
 LogTerm "================================================================="
 LogTerm "Building INSTALL Package: $buildnum  [$REPO|$BRANCH]"
 LogTerm "=================================================================\n"

 sleep 1

 # Variable for Sub Directory within Build Package
 typeset -l build_subdir


 # Read the CSV File
 # CSV File Structure:
 # REPO,BRANCH,PATH,FILENAME,PRIORITY,ISSUE#,COMMENTS
 
 # Define the priority variable with two digits, padded with 0
 typeset -Z2 priority 
 
 # Read the input file 
 while IFS="," read filename path priority issue others
 do
 	
   LogMsg "Before: $path \\c"
   # Cleanup any leading or trailing "/" in path
   path=$( echo $path | sed 's/^\///g; s/\/$//g' )
   
   LogMsg "After: $path"
   
   # Get the File Extension and Sub Directory name
   typeset -l filextn="${filename##*.}"
   typeset -l filedir=$( basename "$path" )
   
   # Based on Sub Directory and Extension
   # Build the Sub Directory within Package
   BuildSubdir 

  
   # Log the Details in the log file
   
   LogMsg "Path       : $path"
   LogMsg "File Name  : $filename"
   LogMsg "Extension  : $filextn"
   LogMsg "File Dir   : $filedir"
   LogMsg "Build Dir  : $build_subdir"
   LogMsg "Priority   : $priority"
   LogMsg "Issue#     : $issue"

   # For DB components, prefix the priority to file name 
   # This is to ensure that deployment runs in the order of priority
   ofile="$filename"
         
   if $isDB 
   then
   
     [ ! -z $priority ] && ofile="$priority"_"$filename" 
     
     LogMsg "Local File : $ofile"
     
   fi 
   

   # Check and Create Sub Directory
   CheckDir "$instdir/$buildnum/$build_subdir" 

   LogMsg "Fetching $path|$filename ... \\c"
   
   
   # Now Get the file from BitBucket
   # The argument passed is the local filename of the component, which could be different
   # for DB deployment files as per the sequence
   GetGITfile "$instdir/$buildnum/$build_subdir/$ofile" 
  


 done < $buildlist

}

# ============================
# End of Function Declarations
# ============================


# ============================
# Execution Starts here
# ============================

start=$( date +%s.%N )
# First Check and Initialize
CheckInit "$1" "$2" "$3"

# Build the Package
CreateBuildPkg

# Last generate the Execution Report
ExecReport


# =========================================================
# We're Done, want more?? Write to ambikesh.pagare@adp.com
# =========================================================
