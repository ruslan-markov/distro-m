#!/usr/bin/env bash
iso_name="DistroM"
iso_label="Distro_M_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%y%m%d)"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%y%m%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-ia32.grub.esp' 'uefi-x64.grub.esp'
           'uefi-ia32.grub.eltorito' 'uefi-x64.grub.eltorito')
arch="x86_64"
pacman_conf="./pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-b' '1M')
bootstrap_tarball_compression=(zstd)
file_permissions=(
  ["/etc/shadow"]="0:0:0400"
  ["/etc/gshadow"]="0:0:0400"
  ["/etc/sudoers"]="0:0:0440"
  ["/root"]="0:0:750"
  ["/usr/local/bin/grubinstall.sh"]="0:0:755"
  ["/usr/local/bin/distro.bios"]="0:0:755"
  ["/usr/local/bin/distro.uefi"]="0:0:755"
)





