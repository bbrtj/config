## Installation

- remove installation media after booting a kernel with it. That way setup program will not detect USB EFI as system EFI
- installation with encryption:
```
# based on https://www.tumfatig.net/2023/install-slackware-linux-with-full-disk-ecryption-on-a-uefi-system/
# create GPT disklabel (g)
# create EFI partition (64M absolute minimum, type 1)
# create LVM partition (the rest of the space, type 30)
fdisk /dev/DISK
mkfs.vfat /dev/EFI

# set up encryption
cryptsetup -y luksFormat /dev/LVM
cryptsetup luksOpen /dev/LMV slackerdisk

# virtual volumes
vgcreate slacker /dev/mapper/slackerdisk
lvcreate -L 16G -n swap slacker
lvcreate -L 84G -n root slacker
lvcreate -l 100%FREE -n home slacker

# setup
mkswap /dev/slacker/swap
setup

# after setup
chroot /mnt
/usr/share/mkinitrd/mkinitrd_command_generator.sh > initrd
sh initrd
eliloconfig

# tweaks:
# ' resume=/dev/slacker/swap' to /boot/efi/EFI/Slackware/elilo.conf ('append')
# '-h /dev/slacker/swap" -m "uhci-hcd:usbhid"' to initrd script
# '-T /dev/LVM' to initrd script (to allow fstrim on luks)
# 'radeon.cik_support=0 amdgpu.cik_support=1 amdgpu.dpm=1' for amdgpu
```
- installation media is also the rescue drive. `setup` (usually) mounts everything. Besides disks, `dev`, `sys` and `proc` must be mounted with `mount --rbind` into the `mnt` directory

## configuration

- performance cpu scaling! Especially before compiling stuff
- if the kernel was not blacklisted in slackpkg, new initrd and eliloconf must be generated with installation media, or efi disk must be mounted before installing it
- software can be taken from source mirrors to build it with different options, `source` directory. If the package was updated, use `patches/source` directory instead
- ntpd servers need to be configured in /etc/ntp.conf
- `chmod +x` to `/etc/rc.d/` services to enable them
- `cat /proc/acpi/wakeup`, `echo 'PNP0C0D:00' | sudo tee /sys/bus/acpi/drivers/button/unbind`

