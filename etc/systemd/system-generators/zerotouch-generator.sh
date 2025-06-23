#!/bin/bash
if grep -qw zerotouch=1 /proc/cmdline; then
    ln -sf /etc/systemd/system/zerotouch-install.service "$1/multi-user.target.wants/zerotouch-install.service"
fi