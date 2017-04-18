#!/bin/sh

# Check dependency
command -v cpio >/dev/null 2>&1 || { echo >&2 "I require cpio but it's not installed. Aborting. You might want to try 'opkg install cpio'."; exit 1; }

CMD_RM="/bin/rm"
CMD_TAR="/bin/tar"
CMD_MKDIR="/bin/mkdir"
CMD_LS="/bin/ls"
CMD_MV="/bin/mv"
CMD_CAT="/bin/cat"
CMD_SED="/bin/sed"
CMD_CHMOD="/bin/chmod"
CMD_CHOWN="/bin/chown"
CMD_CP="/bin/cp"
CMD_WHICH="/usr/bin/which"
CMD_GREP="/bin/grep"
CMD_FIND="/usr/bin/find"
CMD_XARGS="/usr/bin/xargs"

DIR_SRC=./src
DIR_SRC_QPKG=$DIR_SRC/qpkg
DIR_TARGET=./target
DIR_QPKG=$DIR_TARGET/qpkg
DIR_DATA=$DIR_TARGET/data
DIR_SHARED=$DIR_QPKG/shared
DIR_X86=$DIR_QPKG/x86

# Create target folders
$CMD_RM -rf $DIR_TARGET
$CMD_MKDIR -p $DIR_QPKG
$CMD_MKDIR -p $DIR_DATA

# Copy qpkg source files
$CMD_CP -r $DIR_SRC_QPKG/* $DIR_QPKG

# Extract Crashplan package
$CMD_TAR xzf $1 -C $DIR_DATA
CPIFILE_NAME=`$CMD_LS -1 $DIR_DATA/[cC]rash[pP]lan*-install/*cpi`
$CMD_MV $CPIFILE_NAME $DIR_DATA/CrashPlan.cpi
cd $DIR_DATA && $CMD_CAT ./CrashPlan.cpi | gzip -dc - | cpio -i --no-preserve-owner && cd -

# Create crashplan.vars file
$CMD_GREP "SRV_JAVA_OPTS" $DIR_DATA/[cC]rash[pP]lan*-install/scripts/run.conf >> $DIR_DATA/crashplan.vars

# Clean data folder
$CMD_RM -rf $DIR_DATA/[cC]rash[pP]lan*-install
$CMD_RM -f $DIR_DATA/CrashPlan.cpi
$CMD_RM -rf $DIR_DATA/bin
$CMD_RM -rf $DIR_DATA/upgrade
$CMD_RM -rf $DIR_DATA/doc
$CMD_RM -rf $DIR_DATA/skin

# Move CrashPlan files
$CMD_MKDIR -p $DIR_X86
$CMD_MV $DIR_DATA/* $DIR_X86
$CMD_FIND $DIR_SHARED -name .gitignore | $CMD_XARGS $CMD_RM

# remove unused libraries
$CMD_LS -1 $DIR_X86 | $CMD_GREP -i "so" | $CMD_GREP -iv "64.so" | $CMD_XARGS -I% $CMD_RM "${DIR_X86}/%"

# Change rights
$CMD_CHMOD +x $DIR_SHARED/crashplan.sh
$CMD_CHMOD +x $DIR_SHARED/bin/restartLinux.sh
$CMD_CHOWN -R admin:administrators $DIR_SHARED
$CMD_CHOWN -R httpdusr:administrators $DIR_SHARED/htdocs
$CMD_CHMOD -R u+rw,g-rwx,o-rwx $DIR_SHARED/htdocs
$CMD_CHMOD u+x $DIR_SHARED/htdocs

echo "[*] done generating QPKG sources"

# Build qpkg
cd $DIR_QPKG && qbuild --force-config && cd -

echo "[*] done generating QPKG binaries"
