#!/bin/sh

QPKG_NAME="CrashPlan"
QPKG_BASE=""
QPKG_DIR=""

find_base()
{
        # Determine BASE installation location according to smb.conf
        publicdir=`/sbin/getcfg Public path -f /etc/config/smb.conf`
        if [ ! -z $publicdir ] && [ -d $publicdir ];then
                publicdirp1=`/bin/echo $publicdir | /bin/cut -d "/" -f 2`
                publicdirp2=`/bin/echo $publicdir | /bin/cut -d "/" -f 3`
                publicdirp3=`/bin/echo $publicdir | /bin/cut -d "/" -f 4`
                if [ ! -z $publicdirp1 ] && [ ! -z $publicdirp2 ] && [ ! -z $publicdirp3 ]; then
                        [ -d "/${publicdirp1}/${publicdirp2}/Public" ] && QPKG_BASE="/${publicdirp1}/${publicdirp2}"
                fi
        fi

        # Determine BASE installation location by checking where the Public folder is.
        if [ -z $QPKG_BASE ]; then
                for datadirtest in /share/HDA_DATA /share/HDB_DATA /share/HDC_DATA /share/HDD_DATA /share/HDE_DATA /share/HDF_DATA /share/HDG_DATA /share/HDH_DATA /share/MD0_DATA /share/MD1_DATA /share/MD2_DATA /share/MD3_DATA; do
                        [ -d $datadirtest/Public ] && QPKG_BASE="$datadirtest"
                done
        fi
        if [ -z $QPKG_BASE ] ; then
                /bin/echo "The Public share not found."
                exit 1
        fi
        QPKG_DIR="${QPKG_BASE}/.qpkg/${QPKG_NAME}"
}

find_base

$QPKG_DIR/crashplan.sh restart

exit 0
