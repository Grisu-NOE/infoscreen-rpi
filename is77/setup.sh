#!/bin/bash

# Retrieve the extension id for an addon from its install.rdf
# source: http://kb.mozillazine.org/Determine_extension_ID
get_extension_id() {
  unzip -qc $1 install.rdf | xmlstarlet sel \
    -N rdf=http://www.w3.org/1999/02/22-rdf-syntax-ns# \
    -N em=http://www.mozilla.org/2004/em-rdf# \
    -t -v \
    "//rdf:Description[@about='urn:mozilla:install-manifest']/em:id"
}

# ########################################

echo "###############################################"
echo "Installations-Script         Version 2016-08-07"
echo "###############################################"
echo "Infoscreen wird eingerichtet:"
echo "   Der Vorgang kann mehrere Minuten dauern, bitte um Geduld!"


# ########################################
# # entferne reboot eintrag damit waehrend konfiguration kein automatischer reboot erfolgt
grep -v iceweasel /etc/crontab > /tmp/crontab
cat /tmp/crontab > /etc/crontab
rm -f /tmp/crontab

# ########################################
# richte Zeitzone ein
echo "Europe/Vienna" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata > /dev/null 2> /dev/null
date +%Z | egrep -q "^CE(S){0,1}T$" > /dev/null 2> /dev/null && echo "- Zeitzone wurde eingerichtet." || echo "FEHLER: Zeitzone konnte nicht eingerichtet werden!"

# ########################################
# aktualisiere Systemzeit
sed -i 's/server 0.debian.pool.ntp.org iburst/server ts1.univie.ac.at/g' /etc/ntp.conf
sed -i 's/server 1.debian.pool.ntp.org iburst//g' /etc/ntp.conf
sed -i 's/server 2.debian.pool.ntp.org iburst//g' /etc/ntp.conf
sed -i 's/server 3.debian.pool.ntp.org iburst//g' /etc/ntp.conf
systemctl stop ntp.service > /dev/null 2> /dev/null
ntpd -gqx > /dev/null 2> /dev/null
systemctl start ntp.service > /dev/null 2> /dev/null && echo "- Systemzeit wurde aktualisiert." || echo "FEHLER: Systemzeit konnte nicht aktualisiert werden!"

# ########################################
# richte Sprache ein
#sed -i 's/en_GB.UTF-8 UTF-8/# en_GB.UTF-8 UTF-8/g' /etc/locale.gen
sed -i 's/# de_AT.UTF-8 UTF-8/de_AT.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen > /dev/null 2> /dev/null
update-locale LANG=de_AT.UTF-8 LANGUAGE=de_AT:de > /dev/null 2> /dev/null && echo "- Sprache wurde eingerichtet." || echo "FEHLER: Sprache konnte nicht eingerichtet werden!"

# ########################################
# richte Tastaturlayout ein (Danke an https://github.com/shamiao/TRUNCATED-raspbian-zhcn-customized/blob/master/construct.sh)
sed -i 's/XKBLAYOUT="gb"/XKBLAYOUT="de"/g' /etc/default/keyboard
dpkg-reconfigure --frontend=noninteractive keyboard-configuration > /dev/null 2> /dev/null
invoke-rc.d keyboard-setup start > /dev/null 2> /dev/null
debconf-get-selections | grep "xkb-keymap" | grep "de" > /dev/null 2> /dev/null && echo "- Tastaturlayout wurde eingerichtet." || echo "FEHLER: Tastaturlayout konnte nicht eingerichtet werden!"

# ########################################
# installiere notwendige Software

mkdir -p "/root/install-debs/"

debfile[0]='iceweasel_31.8.0esr-1~deb7u1+rpi1_armhf.deb'
debfile[1]='unclutter_8-18_armhf.deb'
debfile[2]='xmlstarlet_1.3.1-3_armhf.deb'
debname[0]='iceweasel'
debname[1]='unclutter'
debname[2]='xmlstarlet'
debmdsum[0]='fe2fd900f7977b5944adda5fc8d90a34'
debmdsum[1]='b6bb0d1282649e70aa5903f2e29fb173'
debmdsum[2]='5b0155f08e13369ffc1eb1e8c5de7e68'
softwarecnt=${#debfile[@]}
i=0
while [ $i -lt $softwarecnt ]
do
	DEBFILE="iceweasel_31.8.0esr-1~deb7u1+rpi1_armhf.deb"
	DEBPATH="/root/install-debs/${debfile[$i]}"
	wget --output-document=${DEBPATH} www.bfkdo-tulln.at/is77/${debfile[$i]} > /dev/null 2> /dev/null
	if md5sum ${DEBPATH} | grep ${debmdsum[$i]} > /dev/null 2> /dev/null
	then
	    echo "- Paket \"${debname[$i]}\" wurde heruntergeladen."
	else
	    echo "FEHLER: Paket \"${debname[$i]}\" konnte nicht heruntergeladen werden!"
	    md5sum $DEBPATH
	fi

	dpkg -i ${DEBPATH} > /dev/null 2> /dev/null
	dpkg -l ${debname[$i]} | grep ${debname[$i]} | cut -b 1-2 | grep "ii" > /dev/null 2> /dev/null && echo "- Paket \"${debname[$i]}\" wurde installiert." || echo "FEHLER: Paket \"${debname[$i]}\" konnte nicht installiert werden!"

	i=$(( $i + 1 ))
done

# ########################################
# schreibe lxde autostart config

cat << EOF > /home/pi/.config/lxsession/LXDE-pi/autostart
@lxpanel --profile LXDE-pi
@pcmanfm --desktop --profile LXDE-pi
#@xscreensaver -no-splash

@xset s off
@xset -dpms
@xset s noblank

@firefox

@unclutter -idle 0.1 -root
EOF

if md5sum /home/pi/.config/lxsession/LXDE-pi/autostart | grep 4f939844d45fd2a09c143f3a74a21da4 > /dev/null 2> /dev/null
then
    echo "- Browser wurde in Autostart eingetragen."
else
    echo "FEHLER: Browser konnte nicht in Autostart eingetragen werden!"
    md5sum /etc/xdg/lxsession/LXDE-pi/autostart
fi

# ########################################
# Installiere Firefox extension
XPI="r_kiosk-0.9.0-fx_signed.xpi"
XPIPATH="/root/${XPI}"

rm -f ${XPIPATH}
wget --output-document=${XPIPATH} www.bfkdo-tulln.at/is77/${XPI} > /dev/null 2> /dev/null
if md5sum ${XPIPATH} | grep cf780b3847453c3c899ee5109a083d9d > /dev/null 2> /dev/null
then
    echo "- Firefox extension wurde heruntergeladen."
else
    echo "FEHLER: Firefox extension konnte nicht heruntergeladen werden!"
    md5sum $XPIPATH
fi

APPID=`get_extension_id ${XPIPATH}` 

#echo ${APPID}
cd "/usr/lib/iceweasel/browser/extensions/"
rm -rf "${APPID}"
mkdir "${APPID}"
cp ${XPIPATH} "/usr/lib/iceweasel/browser/extensions/${APPID}/."
cd "/usr/lib/iceweasel/browser/extensions/${APPID}"
unzip ${XPI} > /dev/null 2> /dev/null
rm -rf ${XPI}

if md5sum "/usr/lib/iceweasel/browser/extensions/${APPID}/content/rkioskbrowser.js" | grep fdc175e > /dev/null 2> /dev/null
then
    echo "- Firefox extension wurde installiert."
else
    echo "FEHLER: Firefox extension konnte nicht installiert werden!"
    md5sum $XPIPATH
fi

# ########################################
# Erstelle Firefox Profil-Verzeichnis und schreibe Firefox config

killall iceweasel > /dev/null 2> /dev/null # beende firefox

cd /home/pi/
rm -rf .mozilla/

export DISPLAY=:0.0
sudo -u pi firefox -CreateProfile Infoscreen > /dev/null 2> /dev/null

cd /home/pi/.mozilla/firefox/
cd *Infoscreen/

echo 'user_pref("general.useragent.override", "Rpi-Infoscreen2.4");' >> prefs.js
echo 'user_pref("browser.startup.homepage", "https://infoscreen.florian10.info/");' >> prefs.js
echo 'user_pref("browser.cache.disk.capacity", 0);' >> prefs.js
echo 'user_pref("app.update.enabled", false);' >> prefs.js
echo 'user_pref("browser.sessionstore.enabled", true);' >> prefs.js
echo 'user_pref("browser.sessionstore.resume_from_crash", false);' >> prefs.js
echo 'user_pref("browser.sessionstore.browser.sessionstore.max_resumed_crashes", 0);' >> prefs.js

#chmod -R 644 /home/pi/.mozilla/
#chown -R pi:pi /home/pi/.mozilla/

if cat /home/pi/.mozilla/firefox/*Infoscreen/prefs.js | grep florian10 > /dev/null 2> /dev/null
then
    echo "- Browsereinstellungen wurden konfiguriert."
else
    echo "FEHLER: Browsereinstellungen konnten nicht konfiguriert werden!"
fi

# ########################################
# lade Desktop Hintergrund herunter
wget --output-document=/usr/share/raspberrypi-artwork/raspberry-pi-logo-small.png www.bfkdo-tulln.at/is77/wallpaper_2016-08-07.png > /dev/null 2> /dev/null
if md5sum /usr/share/raspberrypi-artwork/raspberry-pi-logo-small.png | grep 7a561e1f4804df8cadc5828a5a634bbb > /dev/null 2> /dev/null
then
    echo "- Hintergrund wurde heruntergeladen."
else
    echo "FEHLER: Hintergrund konnte nicht heruntergeladen werden!"
fi

# ########################################
# schreibe crontab fuer taeglichen reboot

cat << EOF > /etc/crontab
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# m h dom mon dow user	command
17 *	* * *	root    cd / && run-parts --report /etc/cron.hourly
25 6	* * *	root	test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.daily )
47 6	* * 7	root	test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.weekly )
52 6	1 * *	root	test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.monthly )

7  4	* * *	root	echo "\`date\` - periodic reboot" >> /root/reboot.log; reboot 
*/5  *	* * *	root	pidof iceweasel > /dev/null && echo "\`date\` - iceweasel running" > /root/running.log || (echo "\`date\` - iceweasel not running" >> /root/reboot.log; reboot )
0  5	5 1 *	root	echo "\`date\` - cleaned file" > /root/reboot.log;

#
EOF

if md5sum /etc/crontab | grep 3f6dd26232e5d18b82dd673eeb81ea17 > /dev/null 2> /dev/null
then
    echo "- Einstellungen fuer Neustart gespeichert."
else
    echo "FEHLER: Einstellungen fuer Neustart konnten nicht gespeichert werden!"
    md5sum /etc/crontab
fi

# ########################################
# schreibe Desktop-Verknuepfungen

cat << EOF > /home/pi/Desktop/iceweasel.desktop
[Desktop Entry]
Encoding=UTF-8
Name=Iceweasel
Exec=iceweasel
Terminal=false
Type=Application
Icon=iceweasel
Categories=Network;WebBrowser;
StartupWMClass=Iceweasel
StartupNotify=true
EOF

cat << EOF > /home/pi/Desktop/safemode.desktop
[Desktop Entry]
Encoding=UTF-8
Name=Iceweasel (safe-mode)
Exec=iceweasel -safe-mode
Terminal=false
Type=Application
Icon=iceweasel
Categories=Network;WebBrowser;
StartupWMClass=Iceweasel
StartupNotify=true
EOF

chown pi:pi /home/pi/Desktop/*.desktop

# ########################################
# ersetze xserver-command (teilweise notwendig um DPMS zu deaktivieren)

sed -i 's/#xserver-command=X/xserver-command=X -s 0 -dpms/g' /etc/lightdm/lightdm.conf
if cat /etc/lightdm/lightdm.conf | grep "xserver-command=X -s 0 -dpms" > /dev/null 2> /dev/null
then
    echo "- Einstellungen fuer Bildschirm-Standby gespeichert."
else
    echo "FEHLER: Einstellungen fuer Bildschirm-Standby konnten nicht gespeichert werden!"
fi

# ########################################

echo "Fertig."
echo "###############################################"

