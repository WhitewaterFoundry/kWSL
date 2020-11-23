@ECHO OFF & NET SESSION >NUL 2>&1 
IF %ERRORLEVEL% == 0 (ECHO Administrator check passed...) ELSE (ECHO You need to run this command with administrative rights.  Is User Account Control enabled? && pause && goto ENDSCRIPT)
COLOR 1F
SET GITORG=DesktopECHO
SET GITPRJ=kWSL
SET BRANCH=master
SET BASE=https://github.com/%GITORG%/%GITPRJ%/raw/%BRANCH%

REM ## Enable WSL if required
POWERSHELL -Command "$WSL = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux' ; if ($WSL.State -eq 'Disabled') {Enable-WindowsOptionalFeature -FeatureName $WSL.FeatureName -Online}"

REM ## Find system DPI setting and get installation parameters
IF NOT EXIST "%TEMP%\windpi.ps1" POWERSHELL.EXE -ExecutionPolicy Bypass -Command "wget '%BASE%/windpi.ps1' -UseBasicParsing -OutFile '%TEMP%\windpi.ps1'"
FOR /f "delims=" %%a in ('powershell -ExecutionPolicy bypass -command "%TEMP%\windpi.ps1" ') do set "WINDPI=%%a"
:DI
CLS && SET RUNSTART=%date% @ %time:~0,5%
IF EXIST .\CMD.EXE CD ..\..

ECHO [kWSL Installer 20201122-5]
ECHO:
ECHO Enter a unique name for your kWSL distro or hit Enter to use default. 
SET DISTRO=kWSL& SET /p DISTRO=Keep this name simple, no space or underscore characters [kWSL]: 
IF EXIST "%DISTRO%" (ECHO. & ECHO Folder exists with that name, choose a new folder name. & PAUSE & GOTO DI)
WSL.EXE -d %DISTRO% -e . > "%TEMP%\InstCheck.tmp"
FOR /f %%i in ("%TEMP%\InstCheck.tmp") do set CHKIN=%%~zi 
IF %CHKIN% == 0 (ECHO. & ECHO There is a WSL distribution registered with that name; uninstall it or choose a new name. & PAUSE & GOTO DI)
SET RDPPRT=3399& SET /p RDPPRT=Port number for xRDP traffic or hit Enter to use default [3399]: 
SET SSHPRT=3322& SET /p SSHPRT=Port number for SSHd traffic or hit Enter to use default [3322]: 
                 SET /p WINDPI=Set a custom DPI scale, or hit Enter for Windows default [%WINDPI%]: 
FOR /f "delims=" %%a in ('PowerShell -Command "%WINDPI% * 96" ') do set "LINDPI=%%a"
SET DEFEXL=NONO& SET /p DEFEXL=[Not recommended!] Type X to eXclude from Windows Defender: 
SET DISTROFULL=%CD%\%DISTRO%
SET _rlt=%DISTROFULL:~2,2%
IF "%_rlt%"=="\\" SET DISTROFULL=%CD%%DISTRO%
SET GO="%DISTROFULL%\LxRunOffline.exe" r -n "%DISTRO%" -c

REM ## Download Ubuntu and install packages
IF NOT EXIST "%TEMP%\Ubuntu2004.zip" POWERSHELL.EXE -Command "Start-BitsTransfer -source https://aka.ms/wslubuntu2004 -destination '%TEMP%\Ubuntu2004.zip'"
POWERSHELL.EXE -command "Expand-Archive -Path '%TEMP%\Ubuntu2004.zip' -DestinationPath '%TEMP%' -force
%DISTROFULL:~0,1%: & MKDIR "%DISTROFULL%" & CD "%DISTROFULL%" & MKDIR logs > NUL
(ECHO [kWSL Inputs] && ECHO. && ECHO.   Distro: %DISTRO% && ECHO.     Path: %DISTROFULL% && ECHO. RDP Port: %RDPPRT% && ECHO. SSH Port: %SSHPRT%  && ECHO.DPI Scale: %WINDPI% && ECHO.) > ".\logs\%TIME:~0,2%%TIME:~3,2%%TIME:~6,2% kWSL Inputs.log"
IF NOT EXIST "%TEMP%\LxRunOffline.exe" POWERSHELL.EXE -Command "wget %BASE%/LxRunOffline.exe -UseBasicParsing -OutFile '%TEMP%\LxRunOffline.exe'"
ECHO:
ECHO Installing kWSL Distro [%DISTRO%] to "%DISTROFULL%" & ECHO This will take a few minutes, please wait... 
IF %DEFEXL%==X (POWERSHELL.EXE -Command "wget %BASE%/excludeWSL.ps1 -UseBasicParsing -OutFile '%DISTROFULL%\excludeWSL.ps1'" & START /WAIT /MIN "Add exclusions in Windows Defender" "POWERSHELL.EXE" "-ExecutionPolicy" "Bypass" "-Command" ".\excludeWSL.ps1" "%DISTROFULL%" &  DEL ".\excludeWSL.ps1")

ECHO:& ECHO [%TIME:~0,8%] Installing Ubuntu 20.04 LTS (~1m30s)
START /WAIT /MIN "Installing Distro Base..." "%TEMP%\LxRunOffline.exe" "i" "-n" "%DISTRO%" "-f" "%TEMP%\install.tar.gz" "-d" "%DISTROFULL%"
(FOR /F "usebackq delims=" %%v IN (`PowerShell -Command "whoami"`) DO set "WAI=%%v") & ICACLS "%DISTROFULL%" /grant "%WAI%":(CI)(OI)F > NUL
(COPY /Y "%TEMP%\LxRunOffline.exe" "%DISTROFULL%" > NUL ) & "%DISTROFULL%\LxRunOffline.exe" sd -n "%DISTRO%"

ECHO [%TIME:~0,8%] Git clone and update repositories (~1m15s)
START /MIN /WAIT "Git Clone kWSL" %GO% "cd /tmp ; git clone -b %BRANCH% --depth=1 https://github.com/%GITORG%/%GITPRJ%.git"
START /MIN /WAIT "Acquire KDE Neon Keys" %GO% "apt-key adv --recv-keys --keyserver keyserver.ubuntu.com E6D4736255751E5D"
START /MIN /WAIT "Acquire Mozilla Seamonkey Keys" %GO% "apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 2667CA5C"
%GO% "echo 'deb http://downloads.sourceforge.net/project/ubuntuzilla/mozilla/apt all main' >> /etc/apt/sources.list.d/mozilla.list"
%GO% "echo 'deb http://archive.neon.kde.org/user/ focal main' >>  /etc/apt/sources.list.d/neon.list"
%GO% "echo 'deb-src http://archive.neon.kde.org/user/ focal main' >>  /etc/apt/sources.list.d/neon.list"
%GO% "rm -rf /etc/apt/apt.conf.d/20snapd.conf /etc/rc2.d/S01whoopsie /etc/init.d/console-setup.sh" 
:APTRELY
START /MIN /WAIT "apt-get update" %GO% "apt-get update 2> /tmp/apterr"
for /F %%A in ("%DISTROFULL%\rootfs\tmp\apterr") do If %%~zA NEQ 0 GOTO APTRELY 
%GO% "DEBIAN_FRONTEND=noninteractive apt-get -y install aria2 libaria2-0 libc-ares2 libssh2-1 libc-ares2 ; chmod +x /tmp/kWSL/dist/usr/local/bin/apt-fast ; cp -p /tmp/kWSL/dist/usr/local/bin/apt-fast /usr/local/bin" > ".\logs\%TIME:~0,2%%TIME:~3,2%%TIME:~6,2% Repository Update.log"

ECHO [%TIME:~0,8%] Remove un-needed packages (~1m30s)
%GO% "DEBIAN_FRONTEND=noninteractive apt-get -y purge apparmor apport bolt cloud-init cloud-initramfs-copymods cloud-initramfs-dyn-netconf cryptsetup cryptsetup-initramfs dmeventd finalrd fwupd initramfs-tools initramfs-tools-core irqbalance isc-dhcp-client klibc-utils kpartx libaio1 libarchive13 libdevmapper-event1.02.1 libdns-export1109 libefiboot1 libefivar1 libestr0 libfastjson4 libfwupd2 libfwupdplugin1 libgcab-1.0-0 libgpgme11 libgudev-1.0-0 libgusb2 libisc-export1105 libisns0 libjson-glib-1.0-0 libjson-glib-1.0-common libklibc liblvm2cmd2.03 libmspack0 libnuma1 libsgutils2-2 libsmbios-c2 libtss2-esys0 liburcu6 libxmlb1 libxmlsec1 libxmlsec1-openssl libxslt1.1 linux-base lvm2 lz4 mdadm multipath-tools open-iscsi open-vm-tools overlayroot plymouth plymouth-theme-ubuntu-text popularity-contest sbsigntool secureboot-db sg3-utils sg3-utils-udev snapd squashfs-tools thin-provisioning-tools tpm-udev zerofree ; apt-get -y autoremove --purge"  > ".\logs\%TIME:~0,2%%TIME:~3,2%%TIME:~6,2% Remove un-needed packages.log" 2>&1

ECHO [%TIME:~0,8%] Migrate Ubuntu LTS to Neon (~3m15s)
%GO% "DEBIAN_FRONTEND=noninteractive apt-fast -y install /tmp/kWSL/deb/gksu_2.1.0_amd64.deb /tmp/kWSL/deb/libgksu2-0_2.1.0_amd64.deb /tmp/kWSL/deb/libgnome-keyring0_3.12.0-1+b2_amd64.deb /tmp/kWSL/deb/libgnome-keyring-common_3.12.0-1_all.deb /tmp/kWSL/deb/multiarch-support_2.27-3ubuntu1_amd64.deb /tmp/kWSL/deb/xrdp_0.9.13.1-2_amd64.deb /tmp/kWSL/deb/xorgxrdp_0.2.12-1_amd64.deb /tmp/kWSL/deb/fonts-cascadia-code_2005.15-1_all.deb x11-apps x11-session-utils x11-xserver-utils dialog distro-info-data dumb-init inetutils-syslogd xdg-utils avahi-daemon libnss-mdns binutils putty unzip zip rar unar unrar unzip dbus-x11 samba-common-bin base-files ubuntu-release-upgrader-core python3-distupgrade packagekit packagekit-tools lhasa arj unace liblhasa0 apt-config-icons apt-config-icons-hidpi apt-config-icons-large apt-config-icons-large-hidpi --no-install-recommends" > ".\logs\%TIME:~0,2%%TIME:~3,2%%TIME:~6,2% Migrate Ubuntu LTS to Neon.log" 2>&1

REM ECHO [%TIME:~0,8%] Update Neon Base (~4m30s)
REM %GO% "DEBIAN_FRONTEND=noninteractive apt-fast -y dist-upgrade --no-install-recommends" > ".\logs\%TIME:~0,2%%TIME:~3,2%%TIME:~6,2% Update Neon Base.log" 2>&1

ECHO [%TIME:~0,8%] KDE Plasma 5.20 (~11m30s)
%GO% "DEBIAN_FRONTEND=noninteractive apt-fast -y install appstream apulse ark aspell-en breeze-gtk-theme desktop-file-utils gdb gdbserver gstreamer1.0-plugins-base hunspell-en-us im-config javascript-common kaccounts-providers kactivities-bin kde-config-gtk-style kde-config-gtk-style-preview kde-plasma-desktop kdeconnect kdiff3 kgamma5 khelpcenter kimageformat-plugins kinfocenter kio-extras kmenuedit kpackagelauncherqml kpackagetool5 krename krusader kscreen ksshaskpass ksysguard ksysguard-data kuserfeedback-doc kwalletmanager kwin-x11 kwrited libaacs0 libappstream-glib8 libavahi-glib1 libbdplus0 libcanberra-gtk3-module libcc1-0 libc-dbg libfftw3-single3 libfwupd2 libgdk-pixbuf2.0-bin libgtk-3-bin libjs-jquery libkf5baloowidgets-bin libkf5config-bin libkf5dbusaddons-bin libkf5iconthemes-bin libkf5kdelibs4support5-bin libkf5khtml-bin libkf5pulseaudioqt2 libkf5purpose-bin libkf5xmlgui-bin libmarkdown2 libmtp-runtime libostree-1-1 libpam-kwallet5 libproxy-tools libqt5designer5 libqt5help5 libqt5multimedia5-plugins libqt5test5 libblkid1 libbrotli1 libfreetype6 libglib2.0-0 libglib2.0-bin libmount1 libsqlite3-0 libuuid1 libx11-6 zlib1g media-player-info mesa-utils mesa-va-drivers debconf-kde-data libdebconf-kde1 muon neon-apport p11-kit p11-kit-modules p7zip-full pulseaudio pavucontrol plasma-discover plasma-discover-common plasma-workspace-wallpapers policykit-desktop-privileges poppler-data pulseaudio-equalizer python3-dbus.mainloop.pyqt5 python3-pyqt5 python3-sip qml-module-org-kde-runnermodel qml-module-org-kde-purpose qml-module-org-kde-prison qt5-gtk-platformtheme qtspeech5-speechd-plugin qttranslations5-l10n qtwayland5 ruby sonnet-plugins systemsettings va-driver-all xdg-dbus-proxy apt-xapian-index libqapt3 libqapt3-runtime neon-apport python3-apport python3-problem-report python3-systemd python3-xapian qapt-batch debconf-kde-helper software-properties-qt ksystemlog ubuntu-drivers-common libcanberra-pulse plasma-pa pulseaudio-module-gsettings --no-install-recommends " > ".\logs\%TIME:~0,2%%TIME:~3,2%%TIME:~6,2% KDE Plasma 5.20.log" 2>&1

ECHO [%TIME:~0,8%] Install Mozilla Seamonkey and media playback (~1m30s)
%GO% "DEBIAN_FRONTEND=noninteractive apt-fast -y install seamonkey-mozilla-build vlc vlc-bin vlc-l10n vlc-plugin-notify vlc-plugin-qt vlc-plugin-samba vlc-plugin-skins2 vlc-plugin-video-splitter vlc-plugin-visualization --no-install-recommends" > ".\logs\%TIME:~0,2%%TIME:~3,2%%TIME:~6,2% Install Mozilla Seamonkey and media playback.log" 2>&1
%GO% "update-alternatives --install /usr/bin/www-browser www-browser /usr/bin/seamonkey 100 ; update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/bin/seamonkey 100 ; update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/seamonkey 100" > NUL

REM ## Additional items to install can go here...
REM ## %GO% "cd /tmp ; wget https://files.multimc.org/downloads/multimc_1.4-1.deb"
REM ## %GO% "apt-get -y install tilix /tmp/multimc_1.4-1.deb"

ECHO [%TIME:~0,8%] Final clean-up (~0m45s)
%GO% "apt-get -y purge gnustep-base-runtime libgnustep-base1.26 gnustep-base-common gnustep-common libgc1c2 libobjc4 powermgmt-base unar ; apt-get -y clean" > ".\logs\%TIME:~0,2%%TIME:~3,2%%TIME:~6,2% Final clean-up.log"

SET /A SESMAN = %RDPPRT% - 50
%GO% "which schtasks.exe" > "%TEMP%\SCHT.tmp" & set /p SCHT=<"%TEMP%\SCHT.tmp"
%GO% "sed -i 's#SCHT#%SCHT%#g' /tmp/kWSL/dist/usr/local/bin/restartwsl ; sed -i 's#DISTRO#%DISTRO%#g' /tmp/kWSL/dist/usr/local/bin/restartwsl"
%GO% "chmod a-x /usr/lib/x86_64-linux-gnu/libexec/kscreenlocker_greet"
%GO% "sed -i 's/QQQ/%WINDPI%/g' /tmp/kWSL/dist/etc/skel/.config/kdeglobals"
%GO% "sed -i 's/QQQ/%LINDPI%/g' /tmp/kWSL/dist/etc/skel/.config/kcmfonts"
%GO% "sed -i 's/ListenPort=3350/ListenPort=%SESMAN%/g' /etc/xrdp/sesman.ini"
%GO% "sed -i 's/thinclient_drives/.kWSL/g' /etc/xrdp/sesman.ini"
%GO% "sed -i 's/port=3389/port=%RDPPRT%/g' /tmp/kWSL/dist/etc/xrdp/xrdp.ini ; cp /tmp/kWSL/dist/etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini"
%GO% "sed -i 's/#Port 22/Port %SSHPRT%/g' /etc/ssh/sshd_config"
%GO% "sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config"
%GO% "sed -i 's/WSLINSTANCENAME/%DISTRO%/g' /tmp/kWSL/dist/usr/local/bin/initwsl"
%GO% "sed -i 's/\\h/%DISTRO%/g' /tmp/kWSL/dist/etc/skel/.bashrc ; ln -s /usr/lib/x86_64-linux-gnu/libexec/kf5/kdesu /usr/bin/kdesu"
%GO% "sed -i 's#Exec=ksystemlog -qwindowtitle %c#Exec=kdesu -n --noignorebutton -d -- bash -c +source /etc/profile.d/kWSL.sh ; ksystemlog -qwindowtitle %c+#g' /usr/share/applications/org.kde.ksystemlog.desktop ; sed -i 's#+#\"#g' /usr/share/applications/org.kde.ksystemlog.desktop"
%GO% "sed -i 's#Exec=plasma-discover %%F#Exec=kdesu -n --noignorebutton -d -- bash -c +source /etc/profile.d/kWSL.sh ; plasma-discover --backends packagekit-backend,kns-backend %%F+#g' /usr/share/applications/org.kde.discover.desktop"
%GO% "sed -i 's#Exec=plasma-discover --mode update#Exec=kdesu -n --noignorebutton -d -- bash -c +source /etc/profile.d/kWSL.sh ; plasma-discover --backends packagekit-backend,kns-backend --mode update+#g' /usr/share/applications/org.kde.discover.desktop ; sed -i 's#+#\"#g' /usr/share/applications/org.kde.discover.desktop"
%GO% "sed -i 's#Exec=plasma-discover --mode update#Exec=kdesu -n --noignorebutton -d -- bash -c +source /etc/profile.d/kWSL.sh ; plasma-discover --backends packagekit-backend,kns-backend --mode update+#g' /usr/share/applications/org.kde.discover.urlhandler.desktop ; sed -i 's#+#\"#g' /usr/share/applications/org.kde.discover.urlhandler.desktop"
%GO% "sed -i 's#Exec=plasma-discover --mode update#Exec=kdesu -n --noignorebutton -d -- bash -c +source /etc/profile.d/kWSL.sh ; plasma-discover --backends packagekit-backend,kns-backend --mode update+#g' /usr/share/applications/org.kde.discover.apt.urlhandler.desktop  ; sed -i 's#+#\"#g' /usr/share/applications/org.kde.discover.apt.urlhandler.desktop"
%GO% "sed -i 's#Exec=muon#Exec=kdesu -n --noignorebutton -d -- bash -c +source /etc/profile.d/kWSL.sh ; muon+#g' /usr/share/applications/org.kde.muon.desktop ; sed -i 's#+#\"#g' /usr/share/applications/org.kde.muon.desktop"
%GO% "sed -i 's#Exec=gksu /usr/bin/x-terminal-emulator#Exec=kdesu -n --noignorebutton -d -- bash -c +source /etc/profile.d/kWSL.sh ; konsole+#g' /usr/share/applications/gksu.desktop ; sed -i 's#+#\"#g' /usr/share/applications/gksu.desktop"
%GO% "sed -i 's/#enable-dbus=yes/enable-dbus=no/g' /etc/avahi/avahi-daemon.conf ; sed -i 's/#host-name=foo/host-name=%COMPUTERNAME%-%DISTRO%/g' /etc/avahi/avahi-daemon.conf ; sed -i 's/use-ipv4=yes/use-ipv4=no/g' /etc/avahi/avahi-daemon.conf"
%GO% "cp /mnt/c/Windows/Fonts/*.ttf /usr/share/fonts/truetype ; rm -rf /etc/pam.d/systemd-user ; rm -rf /etc/systemd ; rm -rf /usr/share/icons/breeze_cursors ; rm -rf /usr/share/icons/Breeze_Snow/cursors ; ssh-keygen -A ; adduser xrdp ssl-cert" > NUL
%GO% "mv /usr/bin/pkexec /usr/bin/pkexec.kWSL ; echo gksudo -k -S -g \$1 > /usr/bin/pkexec ; chmod 755 /usr/bin/pkexec"
%GO% "sed -i 's/adwaita//g' /usr/share/themes/Breeze/gtk-2.0/widgets/misc ; sed -i 's/adwaita//g' /usr/share/themes/Breeze-Dark/gtk-2.0/widgets/misc ; rm -rf /usr/share/themes/Default ; cp -Rp /usr/share/themes/Breeze-Dark /usr/share/themes/Default"
%GO% "chmod 644 /tmp/kWSL/dist/etc/wsl.conf ; chmod 644 /tmp/kWSL/dist/var/lib/xrdp-pulseaudio-installer/*.so"
%GO% "chmod 755 /tmp/kWSL/dist/usr/local/bin/restartwsl ; cp /tmp/kWSL/dist/usr/local/bin/restartwsl /tmp/kWSL/dist/etc/skel/.config/plasma-workspace/shutdown/restartwsl ; chmod 755 /tmp/kWSL/dist/usr/local/bin/initwsl ; chmod -R 700 /tmp/kWSL/dist/etc/skel/.config ; chmod -R 7700 /tmp/kWSL/dist/etc/skel/.local ; chmod -R 7700 /tmp/kWSL/dist/etc/skel/.cache ; chmod 700 /tmp/kWSL/dist/etc/skel/.mozilla"
%GO% "chmod 755 /tmp/kWSL/dist/etc/profile.d/kWSL.sh ; chmod +x /tmp/kWSL/dist/etc/profile.d/kWSL.sh ; chmod 755 /tmp/kWSL/dist/etc/xrdp/startwm.sh ; chmod +x /tmp/kWSL/dist/etc/xrdp/startwm.sh"
%GO% "rm /usr/lib/systemd/system/dbus-org.freedesktop.login1.service /usr/share/dbus-1/system-services/org.freedesktop.login1.service /usr/share/polkit-1/actions/org.freedesktop.login1.policy"
%GO% "rm /usr/share/dbus-1/services/org.freedesktop.systemd1.service /usr/share/dbus-1/system-services/org.freedesktop.systemd1.service /usr/share/dbus-1/system.d/org.freedesktop.systemd1.conf /usr/share/polkit-1/actions/org.freedesktop.systemd1.policy"
%GO% "unamestr=`uname -r` ; if [[ "$unamestr" == '4.4.0-17763-Microsoft' ]]; then apt-get purge -y plasma-discover ; sed -i 's/discover/muon/g' /tmp/kWSL/dist/etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc ; ln -s /usr/bin/software-properties-qt /usr/bin/software-properties-kde ; fi" > NUL
%GO% "cp -Rp /tmp/kWSL/dist/* / ; cp -Rp /tmp/kWSL/dist/etc/skel/.cache /root ; cp -Rp /tmp/kWSL/dist/etc/skel/.config /root ; cp -Rp /tmp/kWSL/dist/etc/skel/.local /root"

SET RUNEND=%date% @ %time:~0,5%
CD %DISTROFULL% 
ECHO:
SET /p XU=Enter name of primary user for %DISTRO%: 
POWERSHELL -Command $prd = read-host "Enter password for %XU%" -AsSecureString ; $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($prd) ; [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) > .tmp & set /p PWO=<.tmp
BASH -c "useradd -m -p nulltemp -s /bin/bash %XU%"
BASH -c "echo %XU%:%PWO% | chpasswd"
%GO% "sed -i 's/PLACEHOLDER/%XU%/g' /tmp/kWSL/kWSL.rdp"
%GO% "sed -i 's/COMPY/%COMPUTERNAME%/g' /tmp/kWSL/kWSL.rdp"
%GO% "sed -i 's/RDPPRT/%RDPPRT%/g' /tmp/kWSL/kWSL.rdp"
%GO% "cp /tmp/kWSL/kWSL.rdp ./kWSL._"
ECHO $prd = Get-Content .tmp > .tmp.ps1
ECHO ($prd ^| ConvertTo-SecureString -AsPlainText -Force) ^| ConvertFrom-SecureString ^| Out-File .tmp  >> .tmp.ps1
POWERSHELL -ExecutionPolicy Bypass -Command ./.tmp.ps1
TYPE .tmp>.tmpsec.txt
COPY /y /b kWSL._+.tmpsec.txt "%DISTROFULL%\%DISTRO% (%XU%) Desktop.rdp" > NUL
DEL /Q  kWSL._ .tmp*.* > NUL
BASH -c "echo '%XU% ALL=(ALL:ALL) ALL' >> /etc/sudoers"
ECHO:
ECHO Open Windows Firewall Ports for xRDP, SSH, mDNS...
NETSH AdvFirewall Firewall add rule name="%DISTRO% xRDP" dir=in action=allow protocol=TCP localport=%RDPPRT% > NUL
NETSH AdvFirewall Firewall add rule name="%DISTRO% Secure Shell" dir=in action=allow protocol=TCP localport=%SSHPRT% > NUL
NETSH AdvFirewall Firewall add rule name="%DISTRO% Avahi Multicast DNS" dir=in action=allow program="%DISTROFULL%\rootfs\usr\sbin\avahi-daemon" enable=yes > NUL
NETSH AdvFirewall Firewall add rule name="%DISTRO% KDE Connect" dir=in action=allow program="%DISTROFULL%\rootfs\usr\lib\x86_64-linux-gnu\libexec\kdeconnectd" enable=yes > NUL
NETSH AdvFirewall Firewall add rule name="%DISTRO% KDEinit" dir=in action=allow program="%DISTROFULL%\rootfs\usr\bin\kdeinit5" enable=yes > NUL

START /MIN /WAIT "KDE Patches for WSL1" "%DISTROFULL%\LxRunOffline.exe" "r" "-n" "%DISTRO%" "-c" "dpkg -i /tmp/kWSL/deb/libkf5activitiesstats1_5.75.0-0xneon+20.04+focal+wsl_amd64.deb ; dpkg -i /tmp/kWSL/deb/kactivitymanagerd_5.20.0-0xneon+20.04+focal+wsl_amd64.deb ; apt-mark hold libkf5activitiesstats1 kactivitymanagerd"
START /MIN "%DISTRO% Init" WSL ~ -u root -d %DISTRO% -e initwsl 2
ECHO Building RDP Connection file, Console link, Init system...
ECHO @WSLCONFIG /t %DISTRO% > "%DISTROFULL%\Init.cmd"
ECHO @WSL ~ -u root -d %DISTRO% -e initwsl 2 >> "%DISTROFULL%\Init.cmd"
ECHO @WSL ~ -u %XU% -d %DISTRO% > "%DISTROFULL%\%DISTRO% (%XU%) Console.cmd"
POWERSHELL -Command "Copy-Item '%DISTROFULL%\%DISTRO% (%XU%) Console.cmd' ([Environment]::GetFolderPath('Desktop'))"
POWERSHELL -Command "Copy-Item '%DISTROFULL%\%DISTRO% (%XU%) Desktop.rdp' ([Environment]::GetFolderPath('Desktop'))"
ECHO Building Uninstaller... [%DISTROFULL%\Uninstall %DISTRO%.cmd]
ECHO @COLOR 1F                                                                                                   >  "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @ECHO Uninstall %DISTRO%?                                                                                   >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @PAUSE                                                                                                      >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @COPY /Y "%DISTROFULL%\LxRunOffline.exe" "%TEMP%"                                                           >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @POWERSHELL -Command "Remove-Item ([Environment]::GetFolderPath('Desktop')+'\%DISTRO% (%XU%) Console.cmd')" >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @POWERSHELL -Command "Remove-Item ([Environment]::GetFolderPath('Desktop')+'\%DISTRO% (%XU%) Desktop.rdp')" >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @SCHTASKS /Delete /TN:%DISTRO% /F                                                                           >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @CLS                                                                                                        >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @CD ..                                                                                                      >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @ECHO Uninstalling %DISTRO%, please wait...                                                                 >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @WSLCONFIG /T %DISTRO%                                                                                      >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @"%TEMP%\LxRunOffline.exe" ur -n %DISTRO%                                                                   >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @RD /S /Q "%DISTROFULL%"                                                                                    >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO Building Scheduled Task...
POWERSHELL -C "$WAI = (whoami) ; (Get-Content .\rootfs\tmp\kWSL\kWSL.xml).replace('AAAA', $WAI) | Set-Content .\rootfs\tmp\kWSL\kWSL.xml"
POWERSHELL -C "$WAC = (pwd)    ; (Get-Content .\rootfs\tmp\kWSL\kWSL.xml).replace('QQQQ', $WAC) | Set-Content .\rootfs\tmp\kWSL\kWSL.xml"
SCHTASKS /Create /TN:%DISTRO% /XML .\rootfs\tmp\kWSL\kWSL.xml /F
ECHO:
ECHO:      Start: %RUNSTART%
ECHO:        End: %RUNEND%
%GO%  "echo -ne '   Packages:'\   ; dpkg-query -l | grep "^ii" | wc -l "
ECHO: 
ECHO:  - xRDP Server listening on port %RDPPRT% and SSHd on port %SSHPRT%.
ECHO: 
ECHO:  - Links for GUI and Console sessions have been placed on your desktop.
ECHO: 
ECHO:  - (Re)launch init from the Task Scheduler or by running the following command: 
ECHO:    schtasks /run /tn %DISTRO%
ECHO: 
ECHO: %DISTRO% Installation Complete!  GUI will start in a few seconds...  
PING -n 6 LOCALHOST > NUL 
START "Remote Desktop Connection" "MSTSC.EXE" "/V" "%DISTROFULL%\%DISTRO% (%XU%) Desktop.rdp"
CD ..
ECHO: 
:ENDSCRIPT
