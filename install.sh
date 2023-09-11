#!/bin/ksh
#
# +============================================================================+
# |             COPYRIGHT (c) 2010 ADP Canada, Financial Systems               |
# +============================================================================+
# |                                                                            |
# | Module      : xxmm_install.sh                                              |
# |                                                                            | 
# | Purpose     : Script to create install scripts for various components      | 
# |                                                                            | 
# | FUnctions   : Usage:  Function to put Usage Info                           |
# |               CheckInit:  Check & Initialize                               |
# |               Comments: Create Comments Block                              |
# |               ExecMode: Make the Install Script Executable                 |
# |               AddDbConnect: Common Shell Functions                         |
# |               AddFormFunctions: Form Compile Function                      |
# |               FileSearch: Identify the files to be included in the script  |
# |               CreateFormScript: Creates Forms Install Script               |
# |               CreateAppsScript: Create Apps Install Script                 |
# |               ShlScripts: Create Shell Install Script                      |
# |               HostScripts: Create Host (BIN) Install Script                |
# |               CreateInstallScript: Main program to call Install Scripts    |
# |               ExecutionReport: Generates the Execution Report              |
# |                                                                            | 
# |                                                                            | 
# | Author      : Ambikesh Pagare                                              |
# | Date        : 21-JUN-2022                                                  |
# | Version     : 1.1                                                          |
# |                                                                            |
# +----------------------------------------------------------------------------+
# |                               BIBLIOGRAPHY                                 |
# +----------------------------------------------------------------------------+
# |    Date     |     Author         |     SCR      |       Remarks            |
# +----------------------------------------------------------------------------+
# | 08-JUL-2010   Ambikesh Pagare      MONET         Initial Draft Version 0.1 |
# | 11-JUL-2010   Ambikesh Pagare      MONET         Added Shell and FNDLOAD   |
# | 14-JUL-2010   Ambikesh Pagare      MONET         Added HOST program and    |
# |                                                  more information in the   |
# |                                                  Execution Report          |
# | 21-JUN-2022   Ambikesh Pagare      CICD          Added sequencing to the   |
# |                                                  DB Deployment scripts     |
# |                                                  Added Master DB Script    |
# +============================================================================+

# Define all the Functions Here
# Follow the Scripting Standards
# The functions must be CamelCase and local variables must be lowercase only
# Basically everything is function here.


# ==================================================================== 
#
# Function    : Usage
# Purpose     : Prints the usage information and exits with return code 1
# Parameters  : None
#
# ====================================================================



Usage ()
{
    typeset script=$(basename $0)
    echo -e  "Usage: $script <Install Package Number> \n\t eg: $script $(date '+%Y%m%d')"
    exit 1
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


    # Check for Instance 
    if [ -z "$XXMM_TOP" ]
    then
        echo -e  "ERROR: APPS environment is not set.\nPlease source the environment [ . adpenv <INSTANCE> ] before running the script."
        exit 1
    fi

    # Define Config File
    # The COnfig File Defines the BASE INSTALL DIR under which the Install Package Dir
    # is created. Also contains the file extensions which are to be included in the
    # install scripts
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

    # Check if we have got Install Package or not    
    if [ -z "$1"  ]
    then
        echo -e  "Please enter the Install Package Number: \c"
        read installpackage
        
    else
        installpackage=$1
    fi
    
    # If we still do not have the package, then show it to the BOSS
    if [ -z "$installpackage" ]
    then
        Usage
    fi
    
    
    # Initialize the Variables here
    
    installdir="$BASE_INSTALL_DIR/$installpackage"
    t=$(date '+%Y%m%d')
    joblog="${installdir}/install.${t}.log"
    topline="-----------------------------------------------"

    # If Install Package Directory does not exist
    # Exit

    if [ ! -d   $installdir ]
    then
        echo -e  "ERROR: The Install Package directory [$installdir] not found. Please check."
        Usage
    fi
    
    
}



# ==================================================================== 
#
# Function    : Comments
# Purpose     : Utility Function to write the Comments Block in the
#               scripts to be created - both Shell and SQL
#               Uses a HERE-DOC to print the Comments
# Parameters  : None
#
# ====================================================================

Comments ()
{
    typeset year=$(date '+%Y')
    typeset -u ddmonyyy=$(date '+%d-%h-%Y')   
    typeset author="Ambikesh Pagare"

    # Get the Script Extension
    typeset -u filetype="${installscript##*.}"

    # Check how the comments should be made

    if [ $filetype = "SH" ] # this is a shell script
    then
        typeset header="#!/bin/ksh" # We're running in the KSH
        typeset rem="#"
    else 
    # We assume everything else would be SQL script, what else you expect???
        typeset rem="--"
    fi

# Create a Here-Doc for the Header
# The following section MUST NOT be formatted (indented) at ALL
cat <<DOC
$header
$rem 
$rem +=======================================================
$rem |          COPYRIGHT (c) $year ADP Canada    
$rem +=======================================================
$rem |                                                     
$rem | Module      : $(basename $installscript)
$rem |                                                     
$rem | Purpose     : Install Script for $dir components
$rem | Install No. : $installpackage                       
$rem |                                                     
$rem | Author      : $author                      
$rem | Date        : $ddmonyyy                       
$rem |                                                     
$rem +=======================================================           
$rem

DOC
}



# ==================================================================== 
#
# Function    : ExecMode
# Purpose     : Just a little cute function to make the install script
#               executable only for the user. Used for Shell Scripts
# Parameters  : None
#
# ====================================================================


ExecMode ()
{
    if [ -f $installscript ]
    then
        echo -e  "The $dir script $installscript generated. \n\tMarking it as executable. \n"
        chmod u+x $installscript
    fi
}

# ==================================================================== 
#
# Function    : AddDbConnect
# Purpose     : To write Database Connection Function in the Shell script
#               Only required in the Shell Script that require DB Connection
# Parameters  : None
#
# ====================================================================


AddDbConnect ()
{

cat <<DOC

# This is just an overkill, but check the DB Connection for the USER/PWD
CheckConn ()

{
# Connect to the SQL*Plus in Silent mode -s
# We want to try connecting only once, use -l
sqlplus -l -s \$1 <<SQL
exit
SQL
}

# The Rudimentary Usage function goes here
Usage ()
{
    echo -e  "Usage \$(basename \$0) APPS/PWD"
    exit 1
}

# Define Variable for APPS/PWD
# If password is not passed then get it from the ID file
appspwd="\${1:-\$( cat \$XXMM_TOP/shl/xxmm_concsub.id )}"

# If password is not provided, show Usage and exit
if [ -z "\$appspwd" ] 
then
    echo -e  "ERROR: APPS/Password not provided" 
    Usage
else
    # Check User Id Password 
    CheckConn "\$appspwd" && echo -e  "DB Connection Successful.\n" || Usage
fi


DOC
}
    
# ==================================================================== 
#
# Function    : AddFormFunctions
# Purpose     : To write Common Form Functions in the Form Script
# Parameters  : None
#
# ====================================================================



AddFormFunctions ()
{

cat <<DOC

# Compile Form Function
CompileForm ()
{
    frmcmp_batch userid=\$appspwd compile_all=special batch=no \\
    module=\$1 \\
    output_file=\$2
}
# We're done with functions
# Lets start some real work !!!



DOC
}

# ==================================================================== 
#
# Function    : AddPllFunctions
# Purpose     : To write Common Pll Functions in the Pll Script
# Parameters  : None
#
# ====================================================================



AddPllFunctions ()
{

cat <<DOC

# Compile Form Function
CompilePll ()
{
    frmcmp_batch userid=\$appspwd compile_all=special batch=no module_type=library \\
    module=\$1 \\
    output_file=\$2 
}
# We're done with functions
# Lets start some real work !!!



DOC
}


# ==================================================================== 
#
# Function    : FileSearch
# Purpose     : Function to find the files that are to be included in scripts
#               This function uses the allowed extensions specified in the
#               Config File
# Parameters  : None
#
# ====================================================================

FileSearch ()
{
# Parameter string is File Extensions separated by a space

    filelist="$@"
    # Convert the extensions into the actual files that are available
    # This will build the static list of all the files located
    # within the directory
    searchfiles=$(echo -e  $filelist | sed 's/^/$installdir\/$dir\/\*./g; s/ / $installdir\/$dir\/\*./g')
    
    # Evaluate the expressions to actually convert into the files
    searchfiles=$(eval echo -e  $searchfiles)
    
    # List all the Files
    searchfiles=$(ls $searchfiles 2>/dev/null)
    
    # Get the Count
    if [ -z "$searchfiles" ]
    then
        cnt=0
    else
        cnt=$(ls -1 $searchfiles 2>/dev/null | wc -l)
    fi
    
    # Check if there are actually any eligible files to be included in the install
    if [ $cnt -gt 0 ]
    then
        echo -e  "$cnt file(s) found in $dir for installation.\n$searchfiles \n" 
    else
        echo -e  "No files found in $dir for installation. Not creating script for $dir \n"
        dirnofiles="$dirnofiles \n\t$dir"
    fi    

    
}

# ==================================================================== 
#
# Function    : CreatePllScript
# Purpose     : The Pll Script that does the real hard work for us.         
#               Backs up the pll/plx files and then generates the plx     
# Parameters  : None
#
# ====================================================================

CreatePllScript ()
{

# Define Variables
    plldir=$AU_TOP/resource
    logfile="$pll.log"
    installpll=$pll
    pll=$(basename $pll)
    plx="${pll%\.*}.plx"

cat <<DOC
    echo -e  ">>>===================================================>>>"
    echo -e  "Installing Pll $pll ... \n"
    

# Copy the pll file if it exists  
    if [ -f $plldir/$pll ]; then
        echo -e  "A copy of $pll exists. Backing it up ..."
        mv $plldir/$pll $plldir/$pll.$installpackage && echo -e  "Done.\n" || echo -e  "****** ERROR Backing up $pll ******\n"
    fi 

# Copy the pll file to Plls directory    
    echo -e  "Copying Pll $pll from install directory to $plldir ..."
    cp -p $installpll $plldir/$pll && echo -e  "Done.\n" || echo -e  "****** ERROR copying the Pll $pll ******\n"

# Copy the plx file if it exists
    if [ -f $plldir/$plx ]; then 
        echo -e  "A copy of $plx exists. Backing it up ..."
        mv $plldir/$plx $plldir/$plx.$installpackage && echo -e  "Done.\n" || echo -e  "****** ERROR Backing up $plx ******\n"
    fi

# Compile Pll now
    echo -e  "Compiling $pll ... "
    CompilePll $plldir/$pll $plldir/$plx > $logfile 2>&1
    
# Check for the status 
    if [ \$? -eq 0 ]; then
        echo -e  "Done.\n" 
        echo -e  "Pll $pll successfully compiled and installed.\n" 
    else 
        echo -e  "****** ERROR Compiling Pll $pll ****** \n"
        grep ERROR $logfile
        echo -e  "Check log $logfile for details. \n"
    fi

    echo -e  "<<<===================================================<<<\n"    
    
    # We're done with compiling Pll $pll 
DOC
}




# ==================================================================== 
#
# Function    : CreateFormScript
# Purpose     : The form Script that does the real hard work for us.         
#               Backs up the FMB/FMX files and then generates the FMX     
#               This scripts the form script with the commands in it
# Parameters  : None
#
# ====================================================================

CreateFormScript ()
{

# Define Variables
    logfile="$form.log"
    fmb=$(basename $form)
    fmx="${fmb%\.*}.fmx"

cat <<FRMDOC
    echo -e  ">>>===================================================>>>"
    echo -e  "Installing form $fmb ... \n"
    

# Copy the FMB file if it exists  
    if [ -f $FORMDIR/$fmb ]; then
        echo -e  "A copy of $fmb exists. Backing it up ..."
        mv $FORMDIR/$fmb $FORMDIR/$fmb.$installpackage && echo -e  "Done.\n" || echo -e  "****** ERROR Backing up $fmb ******\n"
    fi 

# Copy the FMB file to Forms directory    
    echo -e  "Copying form $fmb from install directory to $FORMDIR ..."
    cp -p $form $FORMDIR && echo -e  "Done.\n" || echo -e  "****** ERROR copying the Form $form ******\n"

# Copy the FMX file if it exists
    if [ -f $FORMDIR/$fmx ]; then 
        echo -e  "A copy of $fmx exists. Backing it up ..."
        mv $FORMDIR/$fmx $FORMDIR/$fmx.$installpackage && echo -e  "Done.\n" || echo -e  "****** ERROR Backing up $fmx ******\n"
    fi

# Compile Form now
    echo -e  "Compiling $fmb ... "
    CompileForm $FORMDIR/$fmb $FORMDIR/$fmx > $logfile 2>&1
    
# Check for the status 
    if [ \$? -eq 0 ]; then
        echo -e  "Done.\n" 
        echo -e  "Form $fmb successfully compiled and installed.\n" 
    else 
        echo -e  "****** ERROR Compiling form $fmb ****** \n"
        grep ERROR $logfile
        echo -e  "Check log $logfile for details. \n"
    fi

    echo -e  "<<<===================================================<<<\n"    
    
    # We're done with compiling form $fmb 
FRMDOC
}


# ==================================================================== 
#
# Function    : Pll
# Purpose     : The PLL wrapper script that creates the install script      
#               Loops through the PLL directory and calls the PllScript 
#               to generate the compile script of each PLL.        
# Parameters  : None
#
# ====================================================================

Pll ()
{

    
    echo -e  "Generating PLL Script ... $installscript"
    typeset counter=0
    components="$topline\n"
    # Insert Comments for the Script
    # This will override any existing script, so be careful
    Comments >$installscript
    
    
    # Create CompilePll, Usage, Check function within the script
    AddDbConnect >>$installscript
    AddPllFunctions >>$installscript
    
    # Loop through the directory and look for files
    # that have the allowed extensions set in the config file
    
    for pll in $searchfiles 
    do
        counter=$(( counter + 1 ))
        components="$components \t\t${counter}. $(basename $pll) \n"
        # Create Form Script and write to the script
        CreatePllScript >> $installscript
    done
    components="$components\t\t$topline\n"
    echo -e  "# We're Done. Want more?? Write to ambikesh.pagare@adp.com \n" >> $installscript
    # Make this executable script
    ExecMode
    
}




# ==================================================================== 
#
# Function    : Forms
# Purpose     : The form wrapper script that creates the install script      
#               Loops through the Form directory and calls the FormScript 
#               to generate the compile script of each form.        
# Parameters  : None
#
# ====================================================================

Forms()
{

    
    echo -e  "Generating Forms Script ... $installscript"
    typeset counter=0
    components="$topline\n"
    # Insert Comments for the Script
    # This will override any existing script, so be careful
    Comments >$installscript
    
    
    # Create CompileForm, Usage, Check function within the script
    AddDbConnect >>$installscript
    AddFormFunctions >>$installscript
    
    # Loop through the directory and look for files
    # that have the allowed extensions set in the config file
    
    for form in $searchfiles 
    do
        counter=$(( counter + 1 ))
        components="$components \t\t${counter}. $(basename $form) \n"
        # Create Form Script and write to the script
        CreateFormScript >> $installscript
    done
    components="$components\t\t$topline\n"
    echo -e  "# We're Done. Want more?? Write to ambikesh.pagare@adp.com \n" >> $installscript
    # Make this executable script
    ExecMode
    
}

# Create Apps SQL Script
# Common Function for all Database Objects

# ==================================================================== 
#
# Function    : Apps
# Purpose     : Common Function for all Database Object Scripts
#               Loops through the Objects directory and calls the AppsScript 
#               to generate the compile script of each database objects
# Parameters  : None
#
# ====================================================================

Apps()
{
    echo -e  "Generating $dir Script ... "
    typeset counter=0
    components="$topline\n"
    # Insert the Comments Header Block
    Comments >$installscript
    
    
    for file in $searchfiles 
    do
        counter=$(( counter + 1 ))
        components="$components \t\t${counter}. $(basename $file) \n"
        CreateAppsScript >>$installscript
    done
    components="$components\t\t$topline\n"
    
    echo -e  "-- We're Done. Want more?? Write to ambikesh.pagare@adp.com \n" >> $installscript
    echo -e  "$dir Script generated $installscript"
}

# ==================================================================== 
#
# Function    : CreateAppsScript
# Purpose     : This simply creates a spooler for each DB object script
# Parameters  : None
#
# ====================================================================
CreateAppsScript ()
{
    logfile="$file.log"
    echo -e  "spool $logfile"
    echo -e  "prompt Executing $file ..."
    echo -e  "@$file"
    echo -e  "show error"
    echo -e  "spool off"
}




# ==================================================================== 
#
# Function    : FndLoad
# Purpose     : This simply creates a FndLoad master scripts which     
#               executes the FNDLOAD scripts. This script assumes that
#               FNDLOAD sh scripts will upload the LDT files. Hence
#               this scripts only searches for the Shell Scripts inside
#               fndload directory. 
# Parameters  : None
#
# ====================================================================

FndLoad()
{
    echo -e  "Generating $dir Script ... "
    typeset counter=0
    components="$topline\n"
    # Insert the Comments Header Block
    Comments >$installscript
    
    # Insert Shell Functions
    AddDbConnect >>$installscript
    # Since the files to upload are in the directory
    # make it the current directory
    echo -e  "# Since the files to upload are in the $dir directory, move in there. \n cd $installdir/$dir \n" >> $installscript
    
    echo -e  "logfile=install_${dir}.log \n" >> $installscript
    
    for file in $searchfiles 
    do
        fndshl=$( basename $file )
        counter=$(( counter + 1 ))
        components="$components \t\t${counter}. $fndshl  \n"

    echo -e  "Marking the Fndload Script $fndshl executable ... "
    chmod u+x $file
    # Put all the commands in a block and write to the InstallScript
{
cat <<LDTDOC
# ========== $counter. $fndshl START ============
        # Call the $fndshl script to upload the LDT
        echo -e  "Executing $fndshl...\n"
        $file \$appspwd | tee -a \$logfile
        
        if [ \$? -eq 0 ]; then 
            echo -e  "Upload Successful.\n"
        else 
            echo -e  "****** ERROR: Upload Failed [RC: \$?] ****** "
            echo -e  "Please check the log file for details.\n"
        fi 
# ========== $counter. $fndshl DONE ============        
LDTDOC
} >>$installscript
    done
    components="$components\t\t$topline\n"

    echo -e  "# We're Done. Want more?? Write to ambikesh.pagare@adp.com \n" >> $installscript
    echo -e  "$dir Script generated $installscript"
    
    ExecMode
    
}


# ==================================================================== 
#
# Function    : ShlScripts
# Purpose     : This simply copies the shl scripts to $XXMM_TOP/shl    
#               and marks them executable                               
# Parameters  : None
#
# ====================================================================

ShlScripts ()
{
    echo -e  "Generating $dir Script ... "
    typeset counter=0
    components="$topline\n"

    
    # Insert the Comments Header Block
    Comments >$installscript
    
    
    echo -e  "logfile=install_${dir}.log \n" >> $installscript
    
    for file in $searchfiles 
    do
       shlscript="\$XXMM_TOP/shl/$(basename $file)"
       counter=$(( counter + 1 ))
       components="$components \t\t${counter}. $(basename $file) \n"
    # Put all the commands in a HERE-DOC and write to the InstallScript
    {
cat<<SHLDOC

# ========== $counter. $shlscript START ============
# Backup the existing shell script $shlscript"
    if [ -f $shlscript ]; then 
        echo -e  "Backing up the existing $shlscript ...\n"
        mv $shlscript ${shlscript}.${installpackage}
    fi    
# Copy the script now
    echo -e  "Copying the new script now ..."
    cp $file $shlscript 

    if [ \$? -eq 0 ]; then 
        echo -e  "Shell Script $shlscript copied successfully.\n"
        echo -e  "Marking the Shell Script $shlscript executable ... "
        chmod ug+x $shlscript
    else 
        echo -e  "****** ERROR: Copy Script Failed [RC: \$?] ******  Please check the log file.\n"
    fi
# ========== $counter. $shlscript DONE ============    
SHLDOC
    } >>$installscript
    done
    components="$components\t\t$topline\n"
    
    echo -e  "# We're Done. Want more?? Write to ambikesh.pagare@adp.com \n" >> $installscript
    echo -e  "$dir Script generated $installscript"
    
    ExecMode
    
}

# ==================================================================== 
#
# Function    : ConfFiles
# Purpose     : This simply copies the config files to $XXMM_TOP/shl/config    
#                   
# Parameters  : None
#
# ====================================================================

ConfFiles ()
{
    echo -e  "Generating $dir Script ... "
    typeset counter=0
    components="$topline\n"

    
    # Insert the Comments Header Block
    Comments >$installscript
    
    
    echo -e  "logfile=install_${dir}.log \n" >> $installscript
    
    for file in $searchfiles 
    do
       conffiles="\$XXMM_TOP/shl/config/$(basename $file)"
       counter=$(( counter + 1 ))
       components="$components \t\t${counter}. $(basename $file) \n"
    # Put all the commands in a HERE-DOC and write to the InstallScript
    {
cat<<CONFDOC

# ========== $counter. $conffiles START ============
# Backup the existing config files $conffiles"
    if [ -f $conffiles ]; then 
        echo -e  "Backing up the existing $conffiles ...\n"
        mv $conffiles ${conffiles}.${installpackage}
    fi    
# Copy the config file now
    echo -e  "Copying the new script now ..."
    cp $file $conffiles 

    if [ \$? -eq 0 ]; then 
        echo -e  "Config Files $conffiles copied successfully.\n"
        echo -e  "Marking the config files $conffiles readable ... "
        chmod ug=rwx,o=r $conffiles
    else 
        echo -e  "****** ERROR: Copy Script Failed [RC: \$?] ******  Please check the log file.\n"
    fi
# ========== $counter. $conffiles DONE ============    
CONFDOC
    } >>$installscript
    done
    components="$components\t\t$topline\n"
    
    echo -e  "# We're Done. Want more?? Write to ambikesh.pagare@adp.com \n" >> $installscript
    echo -e  "$dir Script generated $installscript"
    
    ExecMode
    
}

# ==================================================================== 
#
# Function    : Reports
# Purpose     : This simply copies the Oracle RDF Reports to $XXMM_TOP/reports/US
# Parameters  : None
#
# ====================================================================

Reports ()
{
    echo -e  "Generating $dir Script ... "
    typeset counter=0
    components="$topline\n"

    
    # Insert the Comments Header Block
    Comments >$installscript
    
    
    echo -e  "logfile=install_${dir}.log \n" >> $installscript
    
    for file in $searchfiles 
    do
       rdf="\$XXMM_TOP/reports/US/$(basename $file)"
       counter=$(( counter + 1 ))
       components="$components \t\t${counter}. $(basename $file) \n"
    # Put all the commands in a HERE-DOC and write to the InstallScript
    {
cat<<RDF

# ========== $counter. $rdf START ============
# Backup the existing RDF $rdf"
    if [ -f $rdf ]; then 
        echo -e  "Backing up the existing $rdf ...\n"
        mv $rdf ${rdf}.${installpackage}
    fi    

# Copy the RDF now
    echo -e  "Copying the new report RDF now ..."
    cp $file $rdf 

    if [ \$? -eq 0 ]; then 
        echo -e  "Oracle Report $rdf installed successfully.\n"
    else 
        echo -e  "****** ERROR: Copy RDF Failed [RC: \$?] ******"
        echo -e  "Please check the log file.\n"
    fi
    
# ========== $counter. $rdf DONE ============
RDF

    } >>$installscript
    done
    components="$components\t\t $topline\n"
    
    echo -e  "# We're Done. Want more?? Write to ambikesh.pagare@adp.com \n" >> $installscript
    echo -e  "$dir Script generated $installscript"
    
    ExecMode
}



# ==================================================================== 
#
# Function    : HostScripts
# Purpose     : This script will create install scripts for the HOST   
#               programs in $XXMM_TOP/bin directory. Also, recreates    
#               the $FND_TOP/bin/fndcpesr symbolic link for Concurrent Program            
# Parameters  : None
#
# ====================================================================

HostScripts ()
{
    echo -e  "Generating $dir Script ... "
    typeset counter=0
    components="$topline\n"

    
    # Insert the Comments Header Block
    Comments >$installscript
    
    
    echo -e  "logfile=install_${dir}.log \n" >> $installscript
    
    for file in $searchfiles 
    do
    
    hostscript="\$XXMM_TOP/bin/$(basename $file)"
    symlink="\$XXMM_TOP/bin/$(basename $hostscript .prog)"
    counter=$(( counter + 1 ))
    components="$components \t\t${counter}. $(basename $file) \n"

    {
cat <<HOSTDOC     

# Backup the existing Host script $hostscript
if [ -f $hostscript ]; then 
    echo -e  "Backing up the existing $hostscript ...\n"
    mv $hostscript ${hostscript}.${installpackage} 
fi

echo -e  "Copying the new script now ..."
cp $file $hostscript 

if [ \$? -eq 0 ]; then 
    echo -e  "Host Script $hostscript copied successfully.\n"
    echo -e  "Now creating FND link for the Concurrent program ..."

# Following command will create a symlink, and if it exists then remove and recreate the link 
    ln -fs $FND_TOP/bin/fndcpesr $symlink
    echo -e  "Marking the Host Script $hostscript and $symlink executable ... "
    chmod ug+x $hostscript $symlink
else 
    echo -e  " ****** ERROR: Copy Script Failed [RC: \$?] ****** Please check the log file.\n"
fi
HOSTDOC
        
    } >>$installscript
    done
    components="$components\t\t$topline\n"
    
    echo -e  "# We're Done. Want more?? Write to ambikesh.pagare@adp.com \n" >> $installscript
    echo -e  "$dir Script generated $installscript"
    
    ExecMode
    
}


# ==================================================================== 
#
# Function    : MasterDBScript
# Purpose     : The master DB script combines all the SQL scripts into
#               a single script that could be executed directly.   
#               The sequencing is also taken care in the master script
# Parameters  : None
#
# ====================================================================

MasterDBScript ()
{
 typeset script
 typeset cnt=0
 components=
 installscript="$installdir/install_db_master.sql"
 Comments >$installscript
 echo -e "Generating Master DB Script ..."
 for script in "${dbscript[@]}"
 do
 	let cnt++
 	components="$components${cnt}. $(basename $script) \n\t\t"
  echo -e "@$script " >> $installscript
 done 
 scriptnames[0]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
 echo -e "DB Script: $scriptnames[0]"
}


# ==================================================================== 
#
# Function    : CreateInstallScript
# Purpose     : The main script that sets the variables, loops thru    
#               the various directories and calls the appropriate     
#               Functions to generate the scripts for those dir.
# Parameters  : None
#
# ====================================================================

CreateInstallScript ()
{

    echo -e  "Creating Install Scripts for Package Number : $installpackage "
    
    # The Directories which were not installed
    # as they're not listed in the case
    notinstalled=
    
   
    # Directories with no eligibile files in it 
    dirnofiles=
    
    # Sequence of scripts to be created.
    # This list identifies which directory would be scanned first for creation of scripts 
    # This list could be moved to a config as well
    dirseq=("table" "view" "sequence" "index" "synonym" "trigger" "package_spec" "package_body" "misc_sql" )

    # List of install directories
    installs=$(ls -d $installdir/*/ | awk -F '/' '{ print $(NF-1) }')
    
    # Identify the sequence of the install directories 
    for i in "${dirseq[@]}"
    do
	 
     [[ "$installs" == *"$i"* ]] && list="$list $i" 
     
    done
    
    
    # Capture directories that are not in sequence Config
    
    for i in $installs
    	do
    		echo install $i
    		[[ ! "$list" ==  *"$i"* ]] && nolist="$nolist $i"
    	done
    
    echo "List: $list $nolist"
    
    list="$list $nolist"
    
    typeset -Z2 seq=0
    for dir in $list
    do
    # Create a local variable for UPPER case dirname
    
    typeset -u DIR=$dir
    echo -e  "Current processing Directory is $dir \n"
    
    # Increment the counter 
    let seq++
    
    case $DIR in
    # First is the TABLE Scripts
        TABLE)
        
        FileSearch $TABLE
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/${seq}_install_table.sql"
        Apps
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Add this script to master DB Script
        dbscript[$seq]=$installscript
        # Nullify the variable
        installscript=
        ;;
        

    # View Script Now
        VIEW)
        # seq=02
        FileSearch $VIEW
        installscript="$installdir/${seq}_install_view.sql"
        Apps
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Add this script to master DB Script
        dbscript[$seq]=$installscript
        # Nullify the variable
        installscript=
        ;;
        
    
    # Sequence Script Now
        SEQUENCE)
        # seq=05
        FileSearch $SEQUENCE
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/${seq}_install_sequence.sql"
        Apps
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Add this script to master DB Script
        dbscript[$seq]=$installscript
        # Nullify the variable
        installscript=
        ;;
        
    # Index Script Now
        INDEX)
        # seq=04
        FileSearch $INDEX
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/${seq}_install_index.sql"
        Apps
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Add this script to master DB Script
        dbscript[$seq]=$installscript
        # Nullify the variable
        installscript=
        ;;


    # Synonym Script Now
        SYNONYM)
        # seq=03
        FileSearch $SYNONYM
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/${seq}_install_synonym.sql"
        Apps
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Add this script to master DB Script
        dbscript[$seq]=$installscript
        # Nullify the variable
        installscript=
        ;;
        

    # Trigger Script Now
        TRIGGER)
        # seq=08
        FileSearch $TRIGGER
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/${seq}_install_trigger.sql"
        Apps
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Add this script to master DB Script
        dbscript[$seq]=$installscript
        # Nullify the variable
        installscript=
        ;;
        


    # Package Specification Script
        PACKAGE_SPEC)
        # seq=06
        FileSearch $PACKAGE_SPEC
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/${seq}_install_package_spec.sql"
        Apps
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Add this script to master DB Script
        dbscript[$seq]=$installscript
        # Nullify the variable
        installscript=
        ;;
        
        
    # Package Body Script    
        PACKAGE_BODY)
        # seq=07
        FileSearch $PACKAGE_BODY
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/${seq}_install_package_body.sql"
        Apps
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Add this script to master DB Script
        dbscript[$seq]=$installscript
        # Nullify the variable
        installscript=
        ;;
        
    # Misc SQL Script    
        MISC_SQL)
        # seq=09
        FileSearch $MISC_SQL
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/${seq}_install_misc_sql.sql"
        Apps
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Add this script to master DB Script
        dbscript[$seq]=$installscript
        # Nullify the variable
        installscript=
        ;;

        
    # Form Scripts    
        FORM)
        seq=20
        FileSearch $FORM
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/install_form.sh"
        Forms 
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Nullify the variable
        installscript=
        ;;

    # PLL Scripts    
        PLL)
        seq=21
        FileSearch $PLL
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/install_pll.sh"
        Pll 
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Nullify the variable
        installscript=
        ;;



    # RDF Report Scripts    
        REPORT)
        seq=22
        FileSearch $REPORT
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/install_report.sh"
        Reports 
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Nullify the variable
        installscript=
        ;;
        

    # FNDLOAD Scripts    
        FNDLOAD)
        seq=23
        FileSearch $FNDLOAD
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/install_fndload.sh"
        FndLoad 
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Nullify the variable
        installscript=
        ;;
        

    # BIP Definition Scripts    
        BIP_DEF)
        seq=24
        FileSearch $BIP_DEF
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/install_bip_def.sh"
        FndLoad 
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Nullify the variable
        installscript=
        ;;

    # BIP Template Scripts    
        BIP_TMPL)
        seq=25
        FileSearch $BIP_TMPL
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/install_bip_tmpl.sh"
        FndLoad 
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Nullify the variable
        installscript=
        ;;

        
    # Shell Scripts    
        SHL)
        seq=26
        FileSearch $SHL
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/install_shl.sh"
        ShlScripts
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Nullify the variable
        installscript=
        ;;

    # Config Files    
        CONFIG)
        seq=27
        FileSearch $CONFIG
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/install_config.sh"
        ConfFiles
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Nullify the variable
        installscript=
        ;;
        
    # Host Programs BIN     
        BIN)
        seq=28
        FileSearch $BIN
        [ $cnt -gt 0 ] || continue;
        installscript="$installdir/install_bin.sh"
        HostScripts
        scriptnames[$seq]="$(basename $installscript) \n\t\tComponents Included:$cnt \n\t\t$components \n\t"
        # Nullify the variable
        installscript=
        ;;


    # Here catch everything else, but do not do anything on them
    # Just for logging the exceptions
        *)
        echo -e  "Installation instructions for $dir not available. Please recheck or install manually.\n"
        notinstalled="$notinstalled \n\t$dir"
    
    esac
    done

  # Generate master DB Script
  MasterDBScript
  # We're done here!  
    
}

# ==================================================================== 
#
# Function    : ExecutionReport
# Purpose     : This is the Function that writes output to the Console 
#               after the script is done after all the hard work      
# Parameters  : None
#
# ====================================================================

ExecutionReport ()
{
# Lets get a bit fancy here
# Do some highlighting and BOLD stuff ;-)
    beginhi=$(tput smso)
    endhi=$(tput rmso)
    bold=$(tput bold)
    normal=$(tput sgr0)
    
    echo -e  "\n\t================================================="
    echo -e  "\t $beginhi INSTALL EXECUTION REPORT : $bold $installpackage $normal $endhi"
    echo -e  "\t=================================================\n"
    
    scriptcount=0
    scriptcount=${#scriptnames[@]}
    # First Check if any scripts are generated
    if [ $scriptcount -gt 0 ]; then
        
      echo -e  "\tScript Generation complete. \n\tNumber of install Scripts generated: $scriptcount \n"
        
      counter=0
      for script  in "${scriptnames[@]}"
      	do
      		let counter++
      		echo -e "\n\t ${counter}. $script"
      done 
      echo -e "\n \n "
    else
        echo -e  "\tNo Script generated. Please check for errors, if any.\n"
    fi

    # Check if any of the Directories were uninstalled
    if [ ! -z "$notinstalled" -o ! -z "$dirnofiles" ]; then
        echo -e  "\t******* $beginhi EXCEPTIONS $endhi ********"
        
        if [ ! -z "$notinstalled" ]; then
            echo -e  "\tFollowing directories must be installed manually: \n $bold $notinstalled $normal \n"
            
        fi
        if [ ! -z "$dirnofiles" ]; then
            echo -e  "\tFollowing Directories do no have any eligible installation files: \n $bold $dirnofiles $normal \n"
            echo -e  "\tPlease check the extensions of the files\n"
        fi    
        echo -e  "\t******* $beginhi EXCEPTIONS $endhi ********\n"
    fi

    echo -e  "#Please check the log file $joblog for details."
    

}

# The real execution starts here

# First Check and Initialize
CheckInit $1 $2

# Call Create Scripts and redirect output to the log file
CreateInstallScript > $joblog

# Publish the Execution Report and also to the log file
ExecutionReport | tee -a $joblog
# Done, want more?? Write to ambikesh.pagare@adp.com
