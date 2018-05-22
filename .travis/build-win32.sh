#!/bin/bash

export WINEPREFIX=$HOME/.wine-dmd
export WINEARCH=win32
export WINEDEBUG=-all

if [[ "$1" == "before_install" ]]; then
	set -e

	sudo apt-get install -y wine p7zip
	wineboot

	INSTALL_DIR=$WINEPREFIX/drive_c/dmd-win32

	DMD_VERSION=`dmd --version | grep -P -o "2\.\d{3}\.\d"`

	wget http://downloads.dlang.org/releases/2.x/${DMD_VERSION}/dmd.${DMD_VERSION}.windows.7z -O /tmp/dmd.7z
	7zr x -o$INSTALL_DIR /tmp/dmd.7z


	DUB_VERSION=`dub --version | grep -P -o "\d+\.\d+\.\d+"`

	wget http://code.dlang.org/files/dub-${DUB_VERSION}-windows-x86.zip -O /tmp/dub.zip
	unzip -o /tmp/dub.zip -d $INSTALL_DIR/dmd2/windows/bin/


	DMC_VERSION=857
	wget http://ftp.digitalmars.com/Digital_Mars_C++/Patch/dm${DMC_VERSION}c.zip -O /tmp/dmc.zip
	unzip -o /tmp/dmc.zip -d $WINEPREFIX/drive_c/dmc


	echo "[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment]
\"PATH\"=\"c:\\\\windows;c:\\\\windows\\\\system;c:\\\\dmd-win32\\\\dmd2\\\\windows\\\\bin;c:\\\\dmc\\\\dm\\\\bin\"" | wine regedit -

fi