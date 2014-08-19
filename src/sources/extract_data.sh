#!/bin/sh

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

$CMD_RM -rf ./data
$CMD_MKDIR ./data
$CMD_TAR xzf $1 -C ./data/
CPIFILE_NAME=`$CMD_LS -1 data/CrashPlan-install/*cpi`
$CMD_MV $CPIFILE_NAME ./data/CrashPlan.cpi
cd ./data/ && $CMD_CAT ./CrashPlan.cpi | gzip -dc - | cpio -i --no-preserve-owner && cd ..

PATH_TO_JAVA=`which java`
echo "JAVACOMMON=$PATH_TO_JAVA" > ./data/crashplan.vars
$CMD_GREP "SRV_JAVA_OPTS" ./data/CrashPlan-install/scripts/run.conf >> ./data/crashplan.vars

$CMD_RM -rf ./data/CrashPlan-install
$CMD_RM -f ./data/CrashPlan.cpi
$CMD_MKDIR ./data/var
$CMD_RM -rf ./data/bin
$CMD_RM -rf ./data/upgrade
$CMD_RM -rf ./data/doc
$CMD_RM -rf ./data/skin
$CMD_RM -f ./data/libjniwrap64.so
$CMD_RM -f ./data/libjtux64.so
$CMD_RM -f ./data/libmd564.so

$CMD_RM -rf ../shared
$CMD_MKDIR ../shared
$CMD_MV ./data/* ../shared/
$CMD_RM -rf ./data

$CMD_MKDIR -p ../x86/lib
$CMD_MV ../shared/libjtux.so ../x86/
$CMD_MV ../shared/libmd5.so ../x86/
$CMD_CP ../shared/lib/jna-*.jar ../x86/lib/

$CMD_MKDIR -p ../x86_64/lib
$CMD_MV ../shared/libjniwrap64.so ../x86_64/
$CMD_MV ../shared/libjtux64.so ../x86_64/
$CMD_MV ../shared/libmd564.so ../x86_64/
$CMD_MV -f ../shared/lib/jna-*.jar ../x86_64/lib/

$CMD_CP -r ./qpkg/* ../shared/

$CMD_CHMOD +x ../shared/crashplan.sh
$CMD_MKDIR -p ../shared/bin
$CMD_MKDIR -p ../shared/tmp
$CMD_CHMOD +x ../shared/bin/restartLinux.sh
$CMD_CHOWN -R admin:administrators ../shared
$CMD_CHOWN -R httpdusr:administrators ../shared/htdocs
$CMD_CHMOD -R u+rw,g-rwx,o-rwx ../shared/htdocs
$CMD_CHMOD u+x ../shared/htdocs
