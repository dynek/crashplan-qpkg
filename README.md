Description
===========

CrashPlan is backup software that allows Windows, Mac, Linux and Solaris users to back up their data to an offsite data center, computers belonging to friends and family, as well as to attached drives /shared folders. There is a free version (for personal use only) and CrashPlan+ which is for both personal and business use. Both versions allow users to back up data automatically. Files are encrypted using 448-bit Blowfish encryption for CrashPlan+ and 128-bit encryption for the personal CrashPlan before transmission.

This it the sources to create a QPKG installable on a QNAP device (x86/arm based).

Building QPKG
=============
Script `build.sh` can used to build the QPKG.
The script is pretty ugly and uncommented, feel free to improve!
It only takes one parameter which is the _Linux.tgz file fetched from CrashPlan directly.
Make sure to read the script to understand what it's doing.

`src/qpkg/shared/crashplan.sh` is the init script that will be copied inside QPKG to start/stop/restart CrashPlan service.

`src/qpkg/shared/htdocs` is the directory of the pretty basic web interface provided to the users to change amount of RAM allocated to JAVA process as well as be able to change listening IP address.

`src/qpkg/shared/bin/restartLinux.sh` is a script that could be used by CrashPlan service if restart is needed.

`src/qpkg/x86` contains things related to x86 architecture.

`src/qpkg/arm-x19` and its symlink `src/qpkg/arm-x09` contains things related to ... arm architecture, you got it! **Note that originally CrashPlan doesn't support arm-based cpu.** This directory is where and how all the magic happens. Libraries might have to be rebuilt someday and I really hope people will do it for me cause I don't feel like creating the toolchain/cross-build environment again.

Finally `src/qpkg/shared` contains things shared between architectures.

File `src/qpkg/qpkg.cfg` contains information about QPKG. You will most likely want to change `QPKG_VER` (*As a matter of information, ending integer is increased upon each release*).

Make sure [QDK](http://wiki.qnap.com/wiki/QPKG_Development_Guidelines) is installed on your QNAP to be able to build QPKG.

Build result will be located in `target/qpkg/build`.
