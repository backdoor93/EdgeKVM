#!/bin/bash
# Script to prepare a custom Fedora CoreOS automated installation ISO

# User-controlled variables
ARCH="x86_64"
STREAM="stable"
VERSION="34.20211016.3.0"

# Self-derived variables
MAIN_VERSION=$(echo "${VERSION}" | sed -e 's/^\([^.]*\).*$/\1/')

# Get Fedora GPG keys and import them
if [ ! -s ./fedora-${MAIN_VERSION}.gpg ]; then
	curl -o ./fedora-${MAIN_VERSION}.gpg -C - https://getfedora.org/static/fedora.gpg
fi
gpg --import < ./fedora-${MAIN_VERSION}.gpg

# Get detached ISO signature
if [ ! -s ./fedora-coreos-${VERSION}-live.${ARCH}.iso.sig ]; then
	curl -O -C - https://builds.coreos.fedoraproject.org/prod/streams/${STREAM}/builds/${VERSION}/x86_64/fedora-coreos-${VERSION}-live.${ARCH}.iso.sig
fi

# Get and verify ISO image
while ! gpg --verify ./fedora-coreos-${VERSION}-live.${ARCH}.iso.sig ./fedora-coreos-${VERSION}-live.${ARCH}.iso > /dev/null 2>&1; do
	rm -f fedora-coreos-${VERSION}-live.${ARCH}.iso
	curl -O -C - https://builds.coreos.fedoraproject.org/prod/streams/${STREAM}/builds/${VERSION}/x86_64/fedora-coreos-${VERSION}-live.${ARCH}.iso
done

# Transpile the Ignition sources in proper dependency order
# Note: the following lines assume that you have the butane tool installed on the local system
butane -d files -s -p -o files/custom-install.ign custom-install.bu
butane -d files -s -p -o embedded.ign embedded.bu

# Prepare a temporary file in a safe area
# Note: the coreos-installer command cannot overwrite an existing file - using the unsafe -u option as a workaround
tmp_file=$(mktemp -u)

# Embed the Ignition file into the Fedora CoreOS ISO image and make sure that kernel commandline arguments are sane
# Note: the following lines assume that you have the coreos-installer tool installed on the local system
coreos-installer iso ignition embed -f -i embedded.ign -o ${tmp_file} ./fedora-coreos-${VERSION}-live.${ARCH}.iso
coreos-installer iso kargs reset ${tmp_file}

# Add extra dirs/files into the Fedora CoreOS custom ISO image created above
# Note: the following lines assume that you have the xorriso tool installed on the local system
# Note: the following commandline options have been deduced using: xorriso -report_about warning -indev fedora-coreos-${VERSION}-live.${ARCH}.iso.sig -report_system_area as_mkisofs
xorriso -dev ${tmp_file} -pathspecs as_mkisofs -add /libvirt-images=../libvirt-images /libvirt=../libvirt containers-images system-connections /connect2peer.sh=../connect2peer.sh -- -as mkisofs -isohybrid-mbr --interval:local_fs:0s-15s:zero_mbrpt,zero_gpt:"${tmp_file}" --mbr-force-bootable -iso_mbr_part_type 0x00 -c '/isolinux/boot.cat' -b '/isolinux/isolinux.bin' -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e '/images/efiboot.img' -no-emul-boot -boot-load-size 14116 -isohybrid-gpt-basdat

mv -f ${tmp_file} ./fedora-coreos-${VERSION}-live-custom.${ARCH}.iso

