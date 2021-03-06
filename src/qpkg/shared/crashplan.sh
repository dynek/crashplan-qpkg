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
BACKUP_ARCH_DIR="${QPKG_DIR}/backupArchives" # (to be removed in a few releases)
JAVACOMMON="/usr/local/jre/bin/java"
APACHE_CONF_FILE="/etc/default_config/apache-crashplan.conf"
APACHE_PROXY_FILES="/etc/apache-sys-proxy.conf /etc/apache-sys-proxy-ssl.conf"

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

      # Lock to avoid running service twice
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
      fi

      # Symlink identity and increment max_user_watches
      /bin/rm -rf /var/lib/crashplan
      /bin/ln -sf $QPKG_DIR/var /var/lib/crashplan
      /bin/chmod o+r $QPKG_DIR/var
      /bin/echo 1048576 > /proc/sys/fs/inotify/max_user_watches

      # CrashPlan web interface
      /bin/chown -R httpdusr:administrators "${HTDOCS_DIR}"
      /bin/chmod 440 "${HTDOCS_DIR}/"* "${HTDOCS_DIR}/images/"*
      /bin/chmod 550 "${HTDOCS_DIR}" "${HTDOCS_DIR}/images"
      /bin/chmod 660 "${HTDOCS_DIR}/config.conf"

      # Remove old symlink
      [[ -L "${WEB_SHARE}" ]] && rm -f "${WEB_SHARE}"

      # If not there, create http configuration
      if [[ ! -f "${APACHE_CONF_FILE}" ]]; then
        echo "Missing CrashPlan Apache configuration file - creating it"
        cat <<-EOF >"${APACHE_CONF_FILE}"
	<IfModule alias_module>
	  Alias /crashplan "${HTDOCS_DIR}"
	  <Directory "${HTDOCS_DIR}">
	    Require all granted
	  </Directory>
	  ProxyPass /crashplan !
	  ProxyPass /php.mod_fastcgi/crashplan !
	</IfModule>
	EOF
      fi

      # add crashplan apache conf into main conf
      for file in ${APACHE_PROXY_FILES}; do
        # fix bug in previous version
	/bin/sed -i 's/<\/VirtualHost>\s*Include \/etc\/default_config\/apache-crashplan.conf/<\/VirtualHost>/' "${file}"

        if ! /bin/grep -i "${APACHE_CONF_FILE}" "${file}" >/dev/null 2>&1; then
          echo -e "\nInclude ${APACHE_CONF_FILE}" >> "${file}"
        fi

        # reload apache conf
        if [[ "${file}" == *"ssl"* ]]; then
          /usr/local/apache/bin/apache_proxys -k graceful -f "${file}" >/dev/null 2>&1
        else
          /usr/local/apache/bin/apache_proxy -k graceful -f "${file}" >/dev/null 2>&1
        fi
      done

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
      FULL_CP="$QPKG_DIR/lib/com.backup42.desktop.jar:${QPKG_DIR}/lang"

      # Set JAVA tmp directory
      TMP_JAVA_OPTS="-Djava.io.tmpdir=${QPKG_DIR}/tmp"

      cd "${QPKG_DIR}"
      ${JAVACOMMON} ${SRV_JAVA_OPTS} ${QPKG_JAVA_OPTS} ${TMP_JAVA_OPTS} -classpath ${FULL_CP} com.backup42.service.CPService >"${QPKG_DIR}/log/engine_output.log" 2>"${QPKG_DIR}/log/engine_error.log" &
      if [[ $! -gt 0 ]]; then
        /bin/echo $! > "${PID_FILE}"


	# Configure network stack to redirect traffic to localhost (could not find a better way)
        if [[ ! -z "${SYS_INTERFACE}" ]]; then
	  sysctl -w "net.ipv4.conf.${SYS_INTERFACE}.route_localnet=1" >/dev/null
	  [[ -f "${QPKG_DIR}/log/service.log.0" ]] && mv -f "${QPKG_DIR}/log/service.log.0" "${QPKG_DIR}/log/service.log.0.bak"
          echo -n "waiting for service.log.0 creation to fetch listening port";
	  cnt=0
          while ! grep "Interface LISTENING on" "${QPKG_DIR}/log/service.log.0" >/dev/null 2>&1; do
	    if (( cnt == 90 )); then
	      echo "timed out"
	      exit 1
	    fi
	    echo -n "."
            sleep 1
	    (( cnt++ ))
          done
          PORT="$(grep -i "Interface LISTENING on" "${QPKG_DIR}/log/service.log.0" | sed -r 's/.*(\w{4})$/\1/')"
	  echo -e "\nListening port will be ${PORT}"
	  iptables -t nat -I PREROUTING -i "${SYS_INTERFACE}" -p tcp --dport "${PORT}" -j DNAT --to-destination "127.0.0.1:${PORT}"
	fi

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

      # Remove backupArchives directory if symbolic link (to be removed in a few releases)
      [[ -h "${BACKUP_ARCH_DIR}" ]] && /bin/rm -f "${BACKUP_ARCH_DIR}"

      # Remove symlink to CrashPlan web interface
      [[ -d "${WEB_SHARE}" ]] && /bin/rm -f "${WEB_SHARE}"

      # Remove network stack config to redirect traffic to localhost (could not find a better way)
      sysctl -a | grep -i "route_localnet = 1" | cut -f1 -d' ' | xargs -I% sysctl -w %=0 >/dev/null 2>&1
      iptables -t nat -L PREROUTING --line-numbers | grep "DNAT.*tcp.*127.0.0.1:42" | cut -f1 -d' ' | sort -rn | xargs -I% iptables -t nat -D PREROUTING %

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
