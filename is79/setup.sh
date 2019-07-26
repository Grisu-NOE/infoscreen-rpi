#!/bin/bash

SRVPATH="www.bfkdo-tulln.at/is79"

# Retrieve the extension id for an addon from its install.rdf
# source: http://kb.mozillazine.org/Determine_extension_ID
get_extension_id_old() {
  unzip -qc $1 install.rdf | xmlstarlet sel \
    -N rdf=http://www.w3.org/1999/02/22-rdf-syntax-ns# \
    -N em=http://www.mozilla.org/2004/em-rdf# \
    -t -v \
    "//rdf:Description[@about='urn:mozilla:install-manifest']/em:id"
}

get_extension_id() {
  unzip -qc $1 manifest.json | \
    grep id | \
    cut -d ":" -f 2 | \
    cut -d "\"" -f 2
}


# ########################################

echo "###############################################"
echo "Installations-Script         Version 2019-07-26"
echo "###############################################"
echo "Infoscreen wird eingerichtet:"
echo "   Der Vorgang kann mehrere Minuten dauern, bitte um Geduld!"


# ########################################
# # entferne reboot eintrag damit waehrend konfiguration kein automatischer reboot erfolgt
grep -v iceweasel /etc/crontab | grep -v firefox > /tmp/crontab
cat /tmp/crontab > /etc/crontab
rm -f /tmp/crontab

# ########################################
# richte Zeitzone ein
echo "Europe/Vienna" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata > /dev/null 2> /dev/null
date +%Z | egrep -q "^CE(S){0,1}T$" > /dev/null 2> /dev/null && echo "- Zeitzone wurde eingerichtet." || echo "FEHLER: Zeitzone konnte nicht eingerichtet werden!"

# ########################################
# aktualisiere Systemzeit
# ... nicht mehr notwendig, es ist timedatectl von systemd in verwendung.

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

debfile[0]='libjsoncpp1_1.7.4-3_armhf.deb'
debfile[1]='firefox-esr_60.8.0esr-1~deb10u1+rpi1_armhf.deb'
debfile[2]='unclutter_8-18_armhf.deb'
debfile[3]='xmlstarlet_1.3.1-3_armhf.deb'
debname[0]='libjsoncpp1'
debname[1]='firefox-esr'
debname[2]='unclutter'
debname[3]='xmlstarlet'
debshasum[0]='bd6dcac84529ab80fad673eb49792e7cd3723e82'
debshasum[1]='5f818f1417da17a91f7986530b757c01c066dab3'
debshasum[2]='b74feaea4066c3e8b68bb2f8de8f437b35058f76'
debshasum[3]='53949bed99729d439062337c774c212e842b8dd4'
softwarecnt=${#debfile[@]}
i=0
while [ $i -lt $softwarecnt ]
do
	DEBPATH="/root/install-debs/${debfile[$i]}"
	wget --output-document=${DEBPATH} ${SRVPATH}/${debfile[$i]} > /dev/null 2> /dev/null
	if sha1sum ${DEBPATH} | grep ${debshasum[$i]} > /dev/null 2> /dev/null
	then
	    echo "- Paket \"${debname[$i]}\" wurde heruntergeladen."
	else
	    echo "FEHLER: Paket \"${debname[$i]}\" konnte nicht heruntergeladen werden!"
	    sha1sum $DEBPATH
	fi

	dpkg -i ${DEBPATH} > /dev/null 2> /dev/null
	dpkg -l ${debname[$i]} | grep ${debname[$i]} | cut -b 1-2 | grep "ii" > /dev/null 2> /dev/null && echo "- Paket \"${debname[$i]}\" wurde installiert." || echo "FEHLER: Paket \"${debname[$i]}\" konnte nicht installiert werden!"

	i=$(( $i + 1 ))
done

# ########################################
# schreibe lxde autostart config

mkdir -p /home/pi/.config/lxsession/LXDE-pi/
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
XPI="full_screen_multiple_monitor-1.9.4.9-fx.xpi"
XPIPATH="/root/${XPI}"

rm -f ${XPIPATH}
wget --output-document=${XPIPATH} ${SRVPATH}/${XPI} > /dev/null 2> /dev/null
if sha1sum ${XPIPATH} | grep 6ddd46afde067fee5250a356687265b45c0edfad > /dev/null 2> /dev/null
then
    echo "- Firefox extension wurde heruntergeladen."
else
    echo "FEHLER: Firefox extension konnte nicht heruntergeladen werden!"
    sha1sum $XPIPATH
fi

APPID=`get_extension_id ${XPIPATH}` 

#echo ${APPID}
cd "/usr/lib/firefox-esr/browser/extensions/"
rm -rf "${APPID}"
mkdir "${APPID}"
cp ${XPIPATH} "/usr/lib/firefox-esr/browser/extensions/${APPID}/."
cd "/usr/lib/firefox-esr/browser/extensions/${APPID}"
unzip ${XPI} > /dev/null 2> /dev/null
rm -rf ${XPI}

if sha1sum "/usr/lib/firefox-esr/browser/extensions/${APPID}/startup.js" | grep 62b2ba3c2181076b2b5aa440d85a82b1772ab1e3 > /dev/null 2> /dev/null
then
    echo "- Firefox extension wurde installiert."
else
    echo "FEHLER: Firefox extension konnte nicht installiert werden!"
fi

# ########################################
# Erstelle Firefox Profil-Verzeichnis und schreibe Firefox config

killall firefox-esr > /dev/null 2> /dev/null # beende firefox

cd /home/pi/
rm -rf .mozilla/

export DISPLAY=:0.0
sudo -u pi firefox -CreateProfile Infoscreen > /dev/null 2> /dev/null

cd /home/pi/.mozilla/firefox/
cd *Infoscreen/

echo 'user_pref("general.useragent.override", "Rpi-Infoscreen2.6");' >> prefs.js
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

mkdir -p browser-extension-data/${APPID}/
cd browser-extension-data/${APPID}/
echo '{"profiler":{"url":["https://infoscreen.florian10.info/"],"mode":false}}' > storage.js

# ########################################
# lade Desktop Hintergrund herunter
wget --output-document=/usr/share/infoscreen-bg.png ${SRVPATH}/wallpaper_2019-07-26.png > /dev/null 2> /dev/null
if md5sum /usr/share/infoscreen-bg.png | grep e85a044534a3bad7d3c376ccd8a4af76 > /dev/null 2> /dev/null
then
    echo "- Hintergrundbild wurde heruntergeladen."
else
    echo "FEHLER: Hintergrundbild konnte nicht heruntergeladen werden!"
fi

mkdir -p /home/pi/.config/pcmanfm/LXDE-pi/
cat << EOF > /home/pi/.config/pcmanfm/LXDE-pi/desktop-items-0.conf 
[*]
wallpaper_mode=fit
wallpaper_common=1
wallpaper=/usr/share/infoscreen-bg.png
desktop_bg=#d6d6d3d3dede
desktop_fg=#e8e8e8e8e8e8
desktop_shadow=#d6d6d3d3dede
desktop_font=Roboto Light 12
show_wm_menu=0
sort=mtime;ascending;
show_documents=0
show_trash=0
show_mounts=0
prefs_app=pipanel
EOF

if cat /home/pi/.config/pcmanfm/LXDE-pi/desktop-items-0.conf | grep "/usr/share/infoscreen-bg.png" > /dev/null 2> /dev/null
then
    echo "- Hintergrundbild wurde konfiguriert."
else
    echo "FEHLER: Hintergrundbild konnte nicht konfiguriert werden!"
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
*/5  *	* * *	root	pidof firefox-esr > /dev/null && echo "\`date\` - firefox-esr running" > /root/running.log || (echo "\`date\` - firefox-esr not running" >> /root/reboot.log; reboot )
0  5	5 1 *	root	echo "\`date\` - cleaned file" > /root/reboot.log;

#
EOF

if md5sum /etc/crontab | grep 2f1f23102c8aeb603a978067fdc4a84b > /dev/null 2> /dev/null
then
    echo "- Einstellungen fuer Neustart gespeichert."
else
    echo "FEHLER: Einstellungen fuer Neustart konnten nicht gespeichert werden!"
    md5sum /etc/crontab
fi

# ########################################
# schreibe Desktop-Verknuepfungen

cat << EOF > /home/pi/Desktop/firefox.desktop
[Desktop Entry]
Encoding=UTF-8
Name=Firefox
Exec=firefox-esr
Terminal=false
Type=Application
Icon=firefox-esr
StartupNotify=true
EOF

cat << EOF > /home/pi/Desktop/safemode.desktop
[Desktop Entry]
Encoding=UTF-8
Name=Firefox (safe-mode)
Exec=firefox-esr -safe-mode
Terminal=false
Type=Application
Icon=firefox-esr
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

