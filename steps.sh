#!/bin/bash

CHECKLIST="checklist"

get_value() {
    local key="$1"
    grep -E "^$key[[:space:]]*=" "$CHECKLIST" | head -n1 | cut -d= -f2- | xargs
}

MYUSERNM=$(get_value "USERNAME")
MYUSRPASSWD=$(get_value "USERPASSWORD")
RTPASSWD=$(get_value "ROOTPASSWORD")
MYHOSTNM=$(get_value "HOSTNAME")

rootuser () {
  if [[ "$EUID" = 0 ]]; then
    continue
  else
    echo "Please Run As Root"
    sleep 2
    exit
  fi
}

handlerror () {
clear
set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
}

cleanup () {
[[ -d ./dreleng ]] && rm -r ./dreleng
[[ -d ./work ]] && rm -r ./work
[[ -d ./out ]] && mv ./out ../
sleep 2
}

prepreqs () {
pacman -S --needed --noconfirm archiso mkinitcpio-archiso
}

cpdreleng () {
cp -r /usr/share/archiso/configs/releng/ ./dreleng
rm ./dreleng/airootfs/etc/motd
rm ./dreleng/airootfs/etc/mkinitcpio.d/linux.preset
rm ./dreleng/airootfs/etc/ssh/sshd_config.d/10-archiso.conf
rm -r ./dreleng/grub
rm -r ./dreleng/efiboot
rm -r ./dreleng/syslinux
rm -r ./dreleng/airootfs/etc/xdg
rm -r ./dreleng/airootfs/etc/mkinitcpio.conf.d
}

rmunitsd () {
rm -r ./dreleng/airootfs/etc/systemd/system/cloud-init.target.wants
rm -r ./dreleng/airootfs/etc/systemd/system/getty@tty1.service.d
rm ./dreleng/airootfs/etc/systemd/system/multi-user.target.wants/hv_fcopy_daemon.service
rm ./dreleng/airootfs/etc/systemd/system/multi-user.target.wants/hv_kvp_daemon.service
rm ./dreleng/airootfs/etc/systemd/system/multi-user.target.wants/hv_vss_daemon.service
rm ./dreleng/airootfs/etc/systemd/system/multi-user.target.wants/vmware-vmblock-fuse.service
rm ./dreleng/airootfs/etc/systemd/system/multi-user.target.wants/vmtoolsd.service
rm ./dreleng/airootfs/etc/systemd/system/multi-user.target.wants/sshd.service
rm ./dreleng/airootfs/etc/systemd/system/multi-user.target.wants/iwd.service
}

addnmlinks () {
mkdir -p ./dreleng/airootfs/etc/systemd/system/network-online.target.wants
mkdir -p ./dreleng/airootfs/etc/systemd/system/multi-user.target.wants
mkdir -p ./dreleng/airootfs/etc/systemd/system/printer.target.wants
mkdir -p ./dreleng/airootfs/etc/systemd/system/sockets.target.wants
mkdir -p ./dreleng/airootfs/etc/systemd/system/timers.target.wants
mkdir -p ./dreleng/airootfs/etc/systemd/system/sysinit.target.wants
ln -sf /usr/lib/systemd/system/NetworkManager-wait-online.service ./dreleng/airootfs/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service
ln -sf /usr/lib/systemd/system/NetworkManager-dispatcher.service ./dreleng/airootfs/etc/systemd/system/dbus-org.freedesktop.nm-dispatcher.service
ln -sf /usr/lib/systemd/system/NetworkManager.service ./dreleng/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service
ln -sf /usr/lib/systemd/system/haveged.service ./dreleng/airootfs/etc/systemd/system/sysinit.target.wants/haveged.service
ln -sf /usr/lib/systemd/system/cups.service ./dreleng/airootfs/etc/systemd/system/printer.target.wants/cups.service
ln -sf /usr/lib/systemd/system/cups.socket ./dreleng/airootfs/etc/systemd/system/sockets.target.wants/cups.socket
ln -sf /usr/lib/systemd/system/cups.path ./dreleng/airootfs/etc/systemd/system/multi-user.target.wants/cups.path
ln -sf /usr/lib/systemd/system/lightdm.service ./dreleng/airootfs/etc/systemd/system/display-manager.service
}

cpmyfiles () {
cp pacman.conf ./dreleng/
cp profiledef.sh ./dreleng/
cp packages.x86_64 ./dreleng/
cp -r grub/ ./dreleng/
cp -r efiboot/ ./dreleng/
cp -r syslinux/ ./dreleng/
cp -r etc/ ./dreleng/airootfs/
cp -r usr/ ./dreleng/airootfs/
cp checklist ./dreleng/airootfs/etc
mkdir -p ./dreleng/airootfs/etc/skel
ln -sf /usr/share/Distro_M ./dreleng/airootfs/etc/skel/Distro_M
}

sethostname () {
echo "${MYHOSTNM}" > ./dreleng/airootfs/etc/hostname
}

crtpasswd () {
echo "root:x:0:0:root:/root:/usr/bin/bash
${MYUSERNM}:x:1010:1010::/home/${MYUSERNM}:/usr/bin/bash" > ./dreleng/airootfs/etc/passwd
}

crtgroup () {
echo "root:x:0:root
sys:x:3:${MYUSERNM}
adm:x:4:${MYUSERNM}
wheel:x:10:${MYUSERNM}
log:x:18:${MYUSERNM}
network:x:90:${MYUSERNM}
floppy:x:94:${MYUSERNM}
scanner:x:96:${MYUSERNM}
power:x:98:${MYUSERNM}
uucp:x:810:${MYUSERNM}
audio:x:820:${MYUSERNM}
lp:x:830:${MYUSERNM}
rfkill:x:840:${MYUSERNM}
video:x:850:${MYUSERNM}
storage:x:860:${MYUSERNM}
optical:x:870:${MYUSERNM}
sambashare:x:880:${MYUSERNM}
users:x:985:${MYUSERNM}
${MYUSERNM}:x:1010:" > ./dreleng/airootfs/etc/group
}

crtshadow () {
user_hash=$(openssl passwd -6 "${MYUSRPASSWD}")
root_hash=$(openssl passwd -6 "${RTPASSWD}")
echo "root:${root_hash}:14871::::::
${MYUSERNM}:${user_hash}:14871::::::" > ./dreleng/airootfs/etc/shadow
}

crtgshadow () {
echo "root:!*::root
sys:!*::${MYUSERNM}
adm:!*::${MYUSERNM}
wheel:!*::${MYUSERNM}
log:!*::${MYUSERNM}
network:!*::${MYUSERNM}
floppy:!*::${MYUSERNM}
scanner:!*::${MYUSERNM}
power:!*::${MYUSERNM}
uucp:!*::${MYUSERNM}
audio:!*::${MYUSERNM}
lp:!*::${MYUSERNM}
rfkill:!*::${MYUSERNM}
video:!*::${MYUSERNM}
storage:!*::${MYUSERNM}
optical:!*::${MYUSERNM}
sambashare:!*::${MYUSERNM}
${MYUSERNM}:!*::" > ./dreleng/airootfs/etc/gshadow
}

runmkarchiso () {
mkarchiso -v -w ./work -o ./out ./dreleng
}

rootuser
handlerror
prepreqs
cleanup
cpdreleng
addnmlinks
rmunitsd
cpmyfiles
sethostname
crtpasswd
crtgroup
crtshadow
crtgshadow
runmkarchiso