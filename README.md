Description
===========

CrashPlan for Small Business is backup software that allows Windows, Mac and Linux users to back up their data to an offsite data center as well as to attached drives / shared folders. Files are encrypted using AES-256 encryption before transmission. Backup transmission is then scrambled using 128-bit encryption.

This it the sources to create a QPKG installable on an x86 64-bits QNAP device (QTS >= 4.3).

Building QPKG
=============
Script `build.sh` can be used to build the QPKG.
The script is pretty ugly and uncommented, feel free to improve!
It only takes one parameter which is the CrashPlan tgz file.
Make sure to read the script to understand what it's doing.

`src/qpkg/shared/crashplan.sh` is the init script that will be copied inside QPKG to start/stop/restart CrashPlan service.

`src/qpkg/shared/htdocs` is the directory of the pretty basic web interface provided to the users to change amount of RAM allocated to JAVA process as well as be able to change listening IP address.

`src/qpkg/shared/bin/restartLinux.sh` is a script that could be used by CrashPlan service if restart is needed.

`src/qpkg/x86` contains things related to CrashPlan for x86 architecture.

Finally `src/qpkg/shared` contains things not provided by CrashPlan's tgz.

File `src/qpkg/qpkg.cfg` contains information about QPKG. You will most likely want to change `QPKG_VER` (*As a matter of information, ending integer is increased upon each release*).

Make sure [QDK](http://wiki.qnap.com/wiki/QPKG_Development_Guidelines) is installed on your QNAP to be able to build QPKG.

Build result will be located in `target/qpkg/build`.
