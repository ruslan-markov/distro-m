#!/usr/bin/env bash

set -euo pipefail

find_checklist() {
    if [[ -n "${CHECKLIST:-}" && -f "$CHECKLIST" ]]; then
        echo "$CHECKLIST"
        return
    fi
    for path in \
        "./checklist" \
        "/checklist" \
        "/root/checklist" \
        "/etc/checklist" \
        "/mnt/root/checklist" \
        "$(dirname "$0")/checklist"
    do
        if [[ -f "$path" ]]; then
            echo "$path"
            return
        fi
    done
    echo "Checklist file not found!" >&2
    exit 1
}

CHECKLIST=$(find_checklist)
DISK="/dev/sda" # <--- Обязательно укажите необходимый диск для установки, например, /dev/sda или /dev/nvme0n1   

get_value() {
    local key="$1"
    local value
    value=$(grep -E "^$key[[:space:]]*=" "$CHECKLIST" | head -n1 | cut -d= -f2- | xargs || true)
    echo "$value"
}

log() {
    echo -e "\e[1;32m==> $*\e[0m"
}

MYUSERNM=$(get_value "USERNAME")
if [[ -z "$MYUSERNM" ]]; then
    MYUSERNM="user"
fi

MYUSRPASSWD=$(get_value "USERPASSWORD")
if [[ -z "$MYUSRPASSWD" ]]; then
    MYUSRPASSWD="password"
fi

RTPASSWD=$(get_value "ROOTPASSWORD")
if [[ -z "$RTPASSWD" ]]; then
    RTPASSWD="root"
fi

MYHOSTNM=$(get_value "HOSTNAME")
if [[ -z "$MYHOSTNM" ]]; then
    MYHOSTNM="archlinux"
fi

detect_and_set_de() {
    log "Evaluating computer performance..."
    CPU_CORES=$(nproc)
    RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    log "CPU cores: $CPU_CORES, RAM: ${RAM_MB}MB"
    if [[ $CPU_CORES -ge 4 && $RAM_MB -ge 8192 ]]; then
        DE="kde"
        log "Selected desktop environment: KDE Plasma"
    else
        DE="xfce"
        log "Selected desktop environment: XFCE"
    fi
}

partition_disk() {
    log "Partitioning and formatting $DISK"
    parted -s "$DISK" mklabel gpt
    parted -s "$DISK" mkpart primary fat32 1MiB 513MiB
    parted -s "$DISK" set 1 esp on
    parted -s "$DISK" mkpart primary ext4 513MiB 100%
    mkfs.fat -F32 "${DISK}1"
    mkfs.ext4 -F "${DISK}2"
}

mount_partitions() {
    log "Mounting partitions"
    mount "${DISK}2" /mnt
    mkdir -p /mnt/boot
    mount "${DISK}1" /mnt/boot
    mkdir -p /mnt/etc
    cp /etc/pacman.conf /mnt/etc/pacman.conf
}

install_base() {
    log "Installing base system"
    pacstrap -c /mnt base linux-lts linux-firmware sudo networkmanager --config /etc/pacman.conf
}

generate_fstab() {
    log "Generating fstab"
    genfstab -U /mnt >> /mnt/etc/fstab
}

copy_checklist() {
    cp "$CHECKLIST" /mnt/root/checklist
    echo "$MYUSERNM" > /mnt/root/zerotouch_user
    echo "$MYUSRPASSWD" > /mnt/root/zerotouch_userpass
    echo "$RTPASSWD" > /mnt/root/zerotouch_rootpass
    echo "$MYHOSTNM" > /mnt/root/zerotouch_hostname
}

configure_system() {
    log "Configuring system in chroot"
    echo "$DE" > /mnt/root/zerotouch_de
    arch-chroot /mnt /bin/bash <<'EOF'
set -euo pipefail

CHECKLIST="/root/checklist"
DE=$(cat /root/zerotouch_de)
MYUSERNM=$(cat /root/zerotouch_user)
MYUSRPASSWD=$(cat /root/zerotouch_userpass)
RTPASSWD=$(cat /root/zerotouch_rootpass)
MYHOSTNM=$(cat /root/zerotouch_hostname)

function get_value {
    local key="$1"
    local value
    value=$(grep -E "^$key[[:space:]]*=" "$CHECKLIST" | head -n1 | cut -d= -f2- | xargs || true)
    echo "$value"
}


locale=$(get_value "LOCALE")
if [[ -z "$locale" ]]; then
    locale="en_US.UTF-8"
fi

lang=$(get_value "LANG")
if [[ -z "$lang" ]]; then
    lang="en_US.UTF-8"
fi

keymap=$(get_value "KEYMAP")
if [[ -z "$keymap" ]]; then
    keymap="us"
fi

echo "$locale UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$lang" > /etc/locale.conf
echo "KEYMAP=$keymap" > /etc/vconsole.conf

timezone=$(get_value "TIMEZONE")
if [[ -z "$timezone" ]]; then
    timezone="UTC"
fi
ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
hwclock --systohc

if [[ -n "$MYHOSTNM" ]]; then
    echo "$MYHOSTNM" > /etc/hostname
fi

if [[ -n "$RTPASSWD" ]]; then
    echo "root:$RTPASSWD" | chpasswd
fi

systemctl enable NetworkManager

if [[ -n "$MYUSERNM" && -n "$MYUSRPASSWD" ]]; then
    if ! id "$MYUSERNM" &>/dev/null; then
        useradd -m -G wheel "$MYUSERNM"
        echo "$MYUSERNM:$MYUSRPASSWD" | chpasswd
        echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/zerotouch
    fi
fi

layout=$(get_value "LAYOUT")
if [[ -z "$layout" ]]; then
    layout="us"
fi

main_layout=$(get_value "MAIN_LAYOUT")
if [[ -z "$main_layout" ]]; then
    main_layout="us"
fi

mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf <<EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "$layout"
    Option "XkbOptions" "grp:alt_shift_toggle"
    Option "XkbModel" "pc105"
EndSection
EOF

pkgs=$(get_value "PACKAGES")
if [[ -z "$pkgs" ]]; then
    pkgs=""
fi

if [[ "$DE" == "kde" ]]; then
    de_pkgs="plasma kde-applications sddm xorg-server xorg-xinit konsole dolphin firefox"
elif [[ "$DE" == "xfce" ]]; then
    de_pkgs="xfce4 xfce4-goodies lightdm lightdm-gtk-greeter xorg-server xorg-xinit mousepad thunar firefox"
else
    de_pkgs=""
fi

if [[ -n "$de_pkgs" || -n "$pkgs" ]]; then
    pacman -Sy --noconfirm $de_pkgs $pkgs
fi

if [[ "$DE" == "kde" ]]; then
    systemctl enable sddm
elif [[ "$DE" == "xfce" ]]; then
    systemctl enable lightdm
fi

bootctl --path=/boot install
cat > /boot/loader/loader.conf <<EOF
default arch
timeout 3
EOF
cat > /boot/loader/entries/arch.conf <<EOF
title   Distro M
linux   /vmlinuz-linux-lts
initrd  /initramfs-linux-lts.img
options root=PARTUUID=$(blkid -s PARTUUID -o value ${DISK}2) rw
EOF

network=$(get_value "NETWORK")
if [[ -z "$network" ]]; then
    network="auto"
fi

if [[ "$network" == "manual" ]]; then
    ipaddr=$(get_value "IPADDR")
    netmask=$(get_value "NETMASK")
    gateway=$(get_value "GATEWAY")
    dns1=$(get_value "DNS1")
    dns2=$(get_value "DNS2")

    if [[ -n "$ipaddr" && -n "$netmask" && -n "$gateway" && -n "$dns1" ]]; then
        prefix=$(ipcalc -p "$ipaddr" "$netmask" | awk -F= '{print $2}')

        cat > /etc/NetworkManager/system-connections/wired.nmconnection <<ENM
[connection]
id=Manual Wired
type=ethernet
interface-name=en*

[ipv4]
method=manual
addresses=$ipaddr/$prefix
gateway=$gateway
dns=$dns1;$dns2;
never-default=false

[ipv6]
method=ignore
ENM

        chmod 600 /etc/NetworkManager/system-connections/wired.nmconnection
        systemctl enable NetworkManager
        nmcli connection reload
    fi
fi

domain=$(get_value "DOMAIN")
domain_type=$(get_value "DOMAIN_TYPE")
domain_user=$(get_value "DOMAIN_USER")
domain_pass=$(get_value "DOMAIN_PASS")
domain_ou=$(get_value "DOMAIN_OU")
if [[ -n "$domain" && "$domain_type" == "ad" && -n "$domain_user" && -n "$domain_pass" ]]; then
    pacman -Sy --noconfirm realmd adcli sssd
    echo "$domain_pass" | realm join --user="$domain_user" "$domain" ${domain_ou:+--computer-ou="$domain_ou"}
fi

EOF
}

finish() {
    log "Installation complete. Rebooting in 5 seconds..."
    sleep 5
    umount -R /mnt
    reboot
}

main() {
    detect_and_set_de
    partition_disk
    mount_partitions
    install_base
    generate_fstab
    copy_checklist
    configure_system
    finish
}

main