#!/bin/bash
# Script run immediately after the Fedora CoreOS installation has been completed

set -euo pipefail
sleep 10
echo "post-hook"

# Detect OSTree installation path
mount /dev/disk/by-label/boot /mnt
ostree_path=$(grep -o 'ostree=[^[:space:]]*' /mnt/loader/entries/ostree-1-fedora-coreos.conf | sed -e 's>^ostree=>>')
umount /mnt

# Mount target installation
mount /dev/disk/by-label/root /mnt

# Create filesystem mount units and set proper source for embedded files copying
if [ -n "${IGN_EXTRA_DISK}" ]; then
	case ${IGN_EXTRA_DISK_STRATEGY} in
		part)
			# TODO: create mount units for partition-based filesystems
			;;
		lvm)
			libvirt_fs_device="/dev/vgextra/lvlibvirt"
			containers_fs_device="/dev/vgextra/lvcontainers"
			fs_type="xfs"
			;;
		btrfs)
			# TODO: create mount units for btrfs-based filesystems
			;;
		*)
			echo "Fatal error: unrecognized strategy '${IGN_EXTRA_DISK_STRATEGY}' for extra disk ${IGN_EXTRA_DISK}" 1>&2
			exit 255
			;;
	esac
	cat <<- EOF > /mnt/${ostree_path}/etc/systemd/system/var-lib-libvirt.mount
	[Unit]
	Description=Libvirt dedicated filesystem
	
	[Mount]
	What=${libvirt_fs_device}
	Where=/var/lib/libvirt
	Type=${fs_type}
	EOF
	cat <<- EOF > /mnt/${ostree_path}/etc/systemd/system/var-lib-containers.mount
	[Unit]
	Description=Containers dedicated filesystem
	
	[Mount]
	What=${containers_fs_device}
	Where=/var/lib/containers
	Type=${fs_type}
	EOF
else
	ln -s /dev/null /mnt/${ostree_path}/etc/systemd/system/var-lib-libvirt.mount
	ln -s /dev/null /mnt/${ostree_path}/etc/systemd/system/var-lib-containers.mount
fi

# Set system timezone
if [ -n "${IGN_TIMEZONE}" ]; then
	ln -sf ../usr/share/zoneinfo/${IGN_TIMEZONE} /mnt/${ostree_path}/etc/localtime
fi

# Set system hostname
if [ -n "${IGN_HOSTNAME_PREFIX}" ]; then
	echo -n "${IGN_HOSTNAME_PREFIX}-" > /mnt/${ostree_path}/etc/hostname
fi
tr -d " .,_-" < /sys/class/dmi/id/product_serial >> /mnt/${ostree_path}/etc/hostname

# Copy NetworkManager custom configuration files
for file in /run/media/iso/system-connections/*; do
	if [ -f "${file}" ]; then
		if [ ! -s /mnt/${ostree_path}/etc/NetworkManager/system-connections/$(basename ${file}) ]; then
			cp -f ${file} /mnt/${ostree_path}/etc/NetworkManager/system-connections/
			chown root:root /mnt/${ostree_path}/etc/NetworkManager/system-connections/$(basename ${file})
			chmod 600 /mnt/${ostree_path}/etc/NetworkManager/system-connections/$(basename ${file})
		fi
	fi
done

# Unmount target installation
umount /mnt

# Copy all Libvirt artefacts into installed system
if [ -n "${IGN_EXTRA_DISK}" ]; then
	mount ${libvirt_fs_device} /mnt
else
	mkdir -p /tmp/mnt
	mount /dev/disk/by-label/root /tmp/mnt
	mkdir -p /tmp/mnt/var/lib/libvirt
	mount -o bind /tmp/mnt/var/lib/libvirt /mnt
fi
mkdir -p /mnt/images
for file in /run/media/iso/libvirt-images/*; do
	if [ -f "${file}" ]; then
		if [ ! -s /mnt/images/$(basename ${file}) ]; then
			cp -f ${file} /mnt/images/
			chmod 644 /mnt/images/$(basename ${file})
		fi
	fi
done
# Copy Libvirt custom configuration files and peer connection script
if [ ! -d /mnt/setup ]; then
	mkdir -p /mnt/setup
	cp -r /run/media/iso/libvirt /mnt/setup
	cp /run/media/iso/connect2peer.sh /mnt/setup
fi
umount /mnt

# Copy all container artefacts into installed system
if [ -n "${IGN_EXTRA_DISK}" ]; then
	mount ${containers_fs_device} /mnt
else
	mkdir -p /tmp/mnt/var/lib/containers
	mount -o bind /tmp/mnt/var/lib/containers /mnt
fi
mkdir -p /mnt/images
for file in /run/media/iso/containers-images/*; do
	if [ -f "${file}" ]; then
		if [ ! -s /mnt/images/$(basename ${file}) ]; then
			cp -f ${file} /mnt/images/
			chmod 644 /mnt/images/$(basename ${file})
		fi
	fi
done
umount /mnt

# Unmount root partition if not using extra disk
if [ -z "${IGN_EXTRA_DISK}" ]; then
	umount /tmp/mnt
fi

# Conditionally reboot (may be inhibited to help debugging installation issues)
if ! grep -qw 'skip_reboot' /proc/cmdline ; then
	systemctl --no-block reboot
fi

