#!/bin/bash

TPDEV=$(findmnt -n -o SOURCE /)

_findmount () {
  if
    [ -z "${TPDEV##*nvme*}" ]; then
    LRDEV=$(findmnt -n -o SOURCE / | cut -c1-12)
  else
    LRDEV=$(findmnt -n -o SOURCE / | cut -c1-8)
  fi
}

if [ -d "/sys/firmware/efi" ]; then
  grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=distrom --recheck
  grub-mkconfig -o /boot/grub/grub.cfg
else
  _findmount
  grub-install --target=i386-pc "${LRDEV}"
  grub-mkconfig -o /boot/grub/grub.cfg
fi