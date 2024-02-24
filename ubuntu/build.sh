#!/bin/bash
cd $(dirname $0)
ARCH=amd64
VERSION=22.04.1
mkdir -p iso
wget -c https://releases.ubuntu.com/$VERSION/ubuntu-$VERSION-live-server-$ARCH.iso
#wget -c https://old-releases.ubuntu.com/releases/$VERSION/ubuntu-$VERSION-live-server-$ARCH.iso
7z x -aoa ubuntu-$VERSION-live-server-$ARCH.iso -x'![BOOT]' -oiso
cp -pr nocloud iso/
cp -pr ../libvirt-images iso/
cp -pr ../libvirt iso/
cp -pr files iso/
cp -p ../connect2peer.sh iso/files/
cp grub.cfg iso/boot/grub/grub.cfg

(cd iso; find '!' -name "md5sum.txt" '!' -path "./isolinux/*" -follow -type f -exec "$(which md5sum)" {} \; > md5sum.txt)

# Create Install ISO from extracted dir (Ubuntu):

# Adapt to new Ubuntu boot strategy
orig=ubuntu-$VERSION-live-server-$ARCH.iso
mbr=ubuntu-$VERSION-live-server-$ARCH.mbr
efi=ubuntu-$VERSION-live-server-$ARCH.efi

# Extract the MBR template
dd if="$orig" bs=1 count=446 of="$mbr"

# Extract EFI partition image
skip=$(/sbin/fdisk -u=sectors -l "$orig" | fgrep 'Appended2' | awk '{print $2}')
end=$(/sbin/fdisk -u=sectors -l "$orig" | fgrep 'Appended2' | awk '{print $3}')
size=$((end-skip+1))
dd if="$orig" bs=512 skip="$skip" count="$size" of="$efi"

xorriso -as mkisofs -r \
  -V Ubuntu\ custom\ amd64 \
  -J -joliet-long -l \
  -iso-level 3 \
  -partition_offset 16 \
  --grub2-mbr "$mbr" \
  --mbr-force-bootable \
  -append_partition 2 0xEF "$efi" \
  -appended_part_as_gpt \
  -c /boot.catalog \
  -b /boot/grub/i386-pc/eltorito.img \
  -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
  -eltorito-alt-boot \
  -e '--interval:appended_partition_2:all::' \
  -no-emul-boot \
  -o ubuntu-$VERSION-live-server-$ARCH-autoinstall.iso \
  iso
cd -
