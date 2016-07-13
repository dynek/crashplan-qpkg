#!/bin/sh

QPKG_NAME="CrashPlan"
QPKG_CFG_FILE="/etc/config/qpkg.conf"
NAS_CFG_FILE="/etc/config/uLinux.conf"
SAMBA_CFG_FILE="/etc/config/smb.conf"
QPKG_DIR="$(/sbin/getcfg "${QPKG_NAME}" Install_Path -f ${QPKG_CFG_FILE})"
WEB_SHARE="/share/$(/sbin/getcfg SHARE_DEF defWeb -d Qweb -f /etc/config/def_share.info)/crashplan"
PID_FILE="${QPKG_DIR}/${QPKG_NAME}.pid"
LOCK_FILE="/var/run/${QPKG_NAME}.lock"
CRASHPLAN_VARS_FILE="${QPKG_DIR}/crashplan.vars"
MYSERVICE_FILE="${QPKG_DIR}/conf/my.service.xml"
HTDOCS_DIR="${QPKG_DIR}/htdocs"
HTDOCS_CFG_FILE="${HTDOCS_DIR}/config.conf"
BACKUP_ARCH_DIR="${QPKG_DIR}/backupArchives"

# TEMPORARY: workaround for >= 4.5 >>>>>>>>>>>>>>>>>>>>
JRE_QPKG_DIR="$(/sbin/getcfg "JRE" Install_Path -f ${QPKG_CFG_FILE})"
if [[ "$(uname -m)" == armv[5-7]* ]]; then
  JRE_QPKG_DIR="$(/sbin/getcfg "JRE_ARM" Install_Path -f ${QPKG_CFG_FILE})"
fi
# TEMPORARY: workaround for >= 4.5 <<<<<<<<<<<<<<<<<<<<

case "$1" in
    "start")
      ENABLED="$(/sbin/getcfg "${QPKG_NAME}" Enable -u -d FALSE -f "${QPKG_CFG_FILE}")"
      if [[ "${ENABLED}" != "TRUE" ]]; then
        /bin/echo "${QPKG_NAME} is disabled."
        if [[ "${2}" != "force" ]]; then
          exit 1
        fi
        /bin/echo "Forcing startup..."
      fi

      # Lock to avoid running service twice (seems there's a bug on ARM when run from web interface)
      if [[ -f "${LOCK_FILE}" ]]; then
        /bin/echo "Lock file exists!"
        exit 1
      else
        touch "${LOCK_FILE}"
      fi

      # PID management
      if [[ -f "${PID_FILE}" ]]; then
        PID="$(/bin/cat "${PID_FILE}")"
        if [[ -f "/proc/${PID}/cmdline" ]] && [[ "$(/bin/grep "app=CrashPlanService" "/proc/${PID}/cmdline")" ]] && ( /bin/kill -0 "${PID}" 2>/dev/null ); then
          /bin/echo "${QPKG_NAME} is already running with pid ${PID}!"
          exit 1
        else
          # PID file exists but it is not CrashPlan running!
          /bin/rm -f "${PID_FILE}"
        fi
      fi

      if [[ -f "${CRASHPLAN_VARS_FILE}" ]]; then
        . "${CRASHPLAN_VARS_FILE}"
      else
        /bin/echo "Did not find ${CRASHPLAN_VARS_FILE} file."
        exit 1
      fi

      # So CrashPlan can read Java max heap size
      #[ ! -h $QPKG_DIR/bin/run.conf ] && /bin/ln -sf "${CRASHPLAN_VARS_FILE} $QPKG_DIR/bin/run.conf

      # Any upgrade stuff to remove?
      if [[ "$(/bin/ls -1 "${QPKG_DIR}/upgrade" 2>/dev/null)" ]]; then
        /bin/echo "Clearing upgrade bread crumb..."
        /bin/rm -rf "${QPKG_DIR}"/upgrade/*
      fi

      /bin/echo "Cleaning /tmp/*.jna files..."
      /bin/rm -f /tmp/jna*.tmp
      /bin/echo "Cleaning ${QPKG_DIR}/tmp/ files..."
      /bin/rm -rf "${QPKG_DIR}"/tmp/*

      /bin/echo "Starting ${QPKG_NAME}... "

      # Avoid sed'ing file on first launch (package installation)
      if [[ -f "${MYSERVICE_FILE}" ]]; then

        # Configure interface and port on which service will listen and memory size allocated
        if [[ -f "${HTDOCS_CFG_FILE}" ]]; then
          SYS_INTERFACE="$(/bin/cat "${HTDOCS_CFG_FILE}" | /bin/grep interface | /bin/cut -f2 -d=)"
          if [[ -n "${SYS_INTERFACE}" ]]; then /bin/echo -n "Using network interface defined in ${HTDOCS_CFG_FILE}: ${SYS_INTERFACE}"; fi
          SYS_MEMORY="$(/bin/cat "${HTDOCS_CFG_FILE}" | /bin/grep memory | /bin/cut -f2 -d=)"
        fi

        # Discovery of interface to use 1/2
        if [[ -z "${SYS_INTERFACE}" ]]; then
          SYS_INTERFACE="$(/sbin/getcfg Network "Default GW Device" -f $NAS_CFG_FILE)"
          if [[ -n "${SYS_INTERFACE}" ]]; then /bin/echo -n "Using network interface defined as default gateway in NAS configuration: ${SYS_INTERFACE}"; fi
        fi

        # Discovery of interface to use 2/2
        if [[ -z "${SYS_INTERFACE}" ]]; then
          SYS_INTERFACE="$(for iface in $(find /sys/class/net/ -type l | grep -iv "/lo"); do iface=$(/usr/bin/basename $iface); if ifconfig $iface | grep -i inet >/dev/null 2>&1; then echo $iface; fi; done)"
          if [[ -n "${SYS_INTERFACE}" ]]; then /bin/echo -n "Using network interface self-discovered: ${SYS_INTERFACE}"; fi
        fi

        # Failure
        if [[ -z "${SYS_INTERFACE}" ]]; then
          /bin/echo "Can't find any interface on which to listen!"
          exit 1
        fi

        # Config IP from interface
        SYS_IP="$(/sbin/ifconfig "${SYS_INTERFACE}" | /bin/awk '/addr:/{print $2}' | /bin/cut -f2 -d:)"
        /bin/echo " (${SYS_IP}) - This can be changed in the web interface"
        /bin/sed -ri "s/<serviceHost(\s*\/)?>.*/<serviceHost>${SYS_IP}<\/serviceHost>/" "${MYSERVICE_FILE}"

        # If no memory information has been found in config file
        if [[ -z "${SYS_MEMORY}" ]]; then
          SYS_MEMORY="512"
        fi

        /bin/echo "Java heap size: ${SYS_MEMORY}"

        # Set memory information
        SRV_JAVA_OPTS="$(/bin/echo "${SRV_JAVA_OPTS}" | /bin/sed -e "s/-Xms20m/-Xms${SYS_MEMORY}m/")"
        SRV_JAVA_OPTS="$(/bin/echo "${SRV_JAVA_OPTS}" | /bin/sed -e "s/-Xmx1024m/-Xmx${SYS_MEMORY}m/")"

        # Configure port on which service will listen for remote backups
        REMOTE_PORT="$(/bin/grep "<location>.*</location>" "${MYSERVICE_FILE}" | /bin/cut -f2 -d: | /bin/cut -f1 -d'<')"
        /bin/sed -i "s/<location>.*<\/location>/<location>${SYS_IP}:${REMOTE_PORT}<\/location>/" "${MYSERVICE_FILE}"

        # Avoid update / upgrade too quickly
        #/bin/sed -i 's/<upgradePath>.*<\/upgradePath>/<upgradePath>\/dev\/null<\/upgradePath>/' "${MYSERVICE_FILE}"
        #/bin/sed -i 's/<upgradeDelay>.*<\/upgradeDelay>/<upgradeDelay>150000000<\/upgradeDelay>/' "${MYSERVICE_FILE}"
      fi

      # Symlink identity and increment max_user_watches
      /bin/rm -rf /var/lib/crashplan
      /bin/ln -sf $QPKG_DIR/var /var/lib/crashplan
      /bin/chmod o+r $QPKG_DIR/var
      /bin/echo 1048576 > /proc/sys/fs/inotify/max_user_watches

      if [[ "${LC_ALL}" ]]; then
        LOCALE="$(/bin/sed 's/\..*//g' <<< ${LC_ALL})"
        export LC_ALL="${LOCALE}.UTF-8"
      elif [[ "${LC_CTYPE}" ]]; then
        LOCALE="$(/bin/sed 's/\..*//g' <<< ${LC_CTYPE})"
        export LC_CTYPE="${LOCALE}.UTF-8"
      elif [[ "${LANG}" ]]; then
        LOCALE="$(/bin/sed 's/\..*//g' <<< ${LANG})"
        export LANG="${LOCALE}.UTF-8"
      else
        export LANG="en_US.UTF-8"
      fi

      TIMEZONE="$(/sbin/getcfg System "Time Zone" -f ${NAS_CFG_FILE})"
      QPKG_JAVA_OPTS="-Duser.timezone=${TIMEZONE}"
      FULL_CP="$QPKG_DIR/lib/com.backup42.desktop.jar:$QPKG_DIR/lang"
      # If device is ARM
      if [[ "$(uname -m)" == armv[5-7]* ]]; then
        FULL_CP="${QPKG_DIR}/lib/jna-3.2.7.jar:${FULL_CP}"
        export LD_LIBRARY_PATH="${QPKG_DIR}/lib"
      fi

      # If CrashPlan share exists then symlink it to backupArchives
      CP_SHARE="$(/sbin/getcfg "${QPKG_NAME}" path -f "${SAMBA_CFG_FILE}")"
      if [[ "${CP_SHARE}" ]]; then
        [[ -d "${BACKUP_ARCH_DIR}" ]] && /bin/rm -rf "${BACKUP_ARCH_DIR}"
        /bin/ln -sf "${CP_SHARE}" "${BACKUP_ARCH_DIR}"
      else
        [[ -d "${BACKUP_ARCH_DIR}" ]] || /bin/mkdir "${BACKUP_ARCH_DIR}"
      fi

      # Set JAVA tmp directory
      TMP_JAVA_OPTS="-Djava.io.tmpdir=${QPKG_DIR}/tmp"

      # TEMPORARY: workaround for >= 4.5 >>>>>>>>>>>>>>>>>>>>
      if [[ -f "${JRE_QPKG_DIR}/jre/bin/java" ]]; then
        [[ -f "${JRE_QPKG_DIR}/jre/bin/java.patched" ]] && /bin/rm -f "${JRE_QPKG_DIR}/jre/bin/java.patched"
        [[ -d "/tmp/glibc-2.19" ]] && /bin/rm -rf "/tmp/glibc-2.19"
        if [[ "$(uname -m)" == armv[5-7]* ]] && [[ ! -f "${QPKG_DIR}/workaround/glibc-2.19/lib/libgcc_s.so.1" ]]; then /bin/cp /lib/libgcc_s.so.1 "${QPKG_DIR}/workaround/glibc-2.19/lib/"; fi
        /bin/cp "${QPKG_DIR}/workaround/java.patched" "${JRE_QPKG_DIR}/jre/bin/java.patched"
        /bin/ln -s "${QPKG_DIR}/workaround/glibc-2.19" /tmp/
	echo "[TEMPORARY] successfully applied workaround for CrashPlan >= 4.5"
      fi
      # TEMPORARY: workaround for >= 4.5 <<<<<<<<<<<<<<<<<<<<

      cd "${QPKG_DIR}"
      # TEMPORARY: workaround for >= 4.5 >>>>>>>>>>>>>>>>>>>>
      #${JAVACOMMON} ${SRV_JAVA_OPTS} ${QPKG_JAVA_OPTS} ${TMP_JAVA_OPTS} -classpath ${FULL_CP} com.backup42.service.CPService >"${QPKG_DIR}/log/engine_output.log" 2>"${QPKG_DIR}/log/engine_error.log" &
      /usr/local/jre/bin/java.patched ${SRV_JAVA_OPTS} ${QPKG_JAVA_OPTS} ${TMP_JAVA_OPTS} -classpath ${FULL_CP} com.backup42.service.CPService >"${QPKG_DIR}/log/engine_output.log" 2>"${QPKG_DIR}/log/engine_error.log" &
      # TEMPORARY: workaround for >= 4.5 <<<<<<<<<<<<<<<<<<<<
      if [[ $! -gt 0 ]]; then
        /bin/echo $! > "${PID_FILE}"

        # Create symlink to CrashPlan web interface
        /bin/chown -R httpdusr:administrators "${HTDOCS_DIR}"
        /bin/chmod -R u+rwx,g-rwx,o-rwx "${HTDOCS_DIR}"
        # If this isn't set then web interface says: Forbidden
        /bin/chmod o+x "${QPKG_DIR}"
        # Create symlink
        [[ ! -d "${WEB_SHARE}" ]] && /bin/ln -sf "${HTDOCS_DIR}" "${WEB_SHARE}"

        exit 0
      else
        exit 1
      fi
      ;;

    "stop")
      /bin/echo "Stopping ${QPKG_NAME}... "
      /bin/rm -f "${LOCK_FILE}"
      if [[ -f "${PID_FILE}" ]] ; then
        /bin/kill "$(/bin/cat "${PID_FILE}")"
        /bin/sleep 4
        /bin/rm -f "${PID_FILE}"
        /bin/sleep 6
      else
        /bin/echo "No PID found!"
        exit 1
      fi

      # Remove backupArchives directory if symbolic link
      [[ -h "${BACKUP_ARCH_DIR}" ]] && /bin/rm -f "${BACKUP_ARCH_DIR}"

      # Remove symlink to CrashPlan web interface
      [[ -d "${WEB_SHARE}" ]] && /bin/rm -f "${WEB_SHARE}"

      exit 0
      ;;

    "restart")
      "${0}" stop
      /bin/echo "Sleeping 10 seconds..."
      /bin/sleep 10
      "${0}" start
      exit 0
      ;;

    "status")
      if [[ -f "${PID_FILE}" ]]; then
        PID="$(/bin/cat "${PID_FILE}")"
        if [[ -f "/proc/${PID}/cmdline" ]] && [[ "$(/bin/grep "app=CrashPlanService" "/proc/${PID}/cmdline")" ]] && ( /bin/kill -0 "${PID}" 2> /dev/null ); then
          /bin/echo "${QPKG_NAME} (pid ${PID}) is running."
        else
          # Most likely ghost PID (since not CrashPlan)
          /bin/rm -f "${PID_FILE}"
        fi
      else
        /bin/echo "${QPKG_NAME} is stopped."
      fi
      exit 0
      ;;

    *)
      /bin/echo "Usage: ${0} {start|stop|restart|status}"
      exit 1
esac
