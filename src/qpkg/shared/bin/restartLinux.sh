#!/bin/sh

QPKG_NAME="CrashPlan"
QPKG_CFG_FILE="/etc/config/qpkg.conf"
QPKG_DIR="$(/sbin/getcfg "${QPKG_NAME}" Install_Path -f ${QPKG_CFG_FILE})"

$QPKG_DIR/crashplan.sh restart

exit 0
