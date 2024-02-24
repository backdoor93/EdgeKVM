#!/bin/bash
# Script run immediately before the Fedora CoreOS installation starts

set -euo pipefail
sleep 10
echo "pre-hook"

# Skip if no extra disk required/specified
if [ -z "${IGN_EXTRA_DISK}" ]; then
	exit 0
fi

# Check extra disk presence
if [ ! -b "${IGN_EXTRA_DISK}" ]; then
	echo "Fatal error: unrecognized extra disk '${IGN_EXTRA_DISK}'" 1>&2
	exit 254
fi

# Configure extra disk
case ${IGN_EXTRA_DISK_STRATEGY} in
	part)
		# TODO: detect current partitions and create them if missing
		;;
	lvm)
		# Note: LVM is not natively supported

		# Note: default lvm.conf excludes all devices on Fedora CoreOS Live - overriding here
		sed -i -e '/^\s*filter\s*=\s*/s/r|/a|/' /etc/lvm/lvm.conf
		pvscan --cache -aay
		
		# Create expected LVM layout and related filesystems if the expected PV is not already used
		if ! pvs -q --noheadings -o pv_name | grep -qw "${IGN_EXTRA_DISK}" ; then
			dd if=/dev/zero of=${IGN_EXTRA_DISK} bs=1M count=10
			dd if=/dev/zero of=${IGN_EXTRA_DISK} bs=1M count=10 seek=$(($(blockdev --getsize64 ${IGN_EXTRA_DISK}) / (1024 * 1024) - 10))
			kpartx ${IGN_EXTRA_DISK}
			vgcreate -qq -s 32m vgextra "${IGN_EXTRA_DISK}"
			if echo "${IGN_LIBVIRT_FS_SIZE}" | grep -q '%' ; then
				libvirt_size_option="-l"
			else
				libvirt_size_option="-L"
			fi
			lvcreate -qq -a y ${libvirt_size_option} ${IGN_LIBVIRT_FS_SIZE} -n lvlibvirt vgextra
			mkfs -t xfs -L libvirt /dev/vgextra/lvlibvirt
			if echo "${IGN_CONTAINERS_FS_SIZE}" | grep -q '%' ; then
				containers_size_option="-l"
			else
				containers_size_option="-L"
			fi
			lvcreate -qq -a y ${containers_size_option} ${IGN_CONTAINERS_FS_SIZE} -n lvcontainers vgextra
			mkfs -t xfs -L containers /dev/vgextra/lvcontainers
		fi
		;;
	btrfs)
		# Note: btrfs subvolumes are not natively supported

		# TODO: detect current btrfs config and create if missing
		;;
	*)
		echo "Fatal error: unrecognized strategy '${IGN_EXTRA_DISK_STRATEGY}' for extra disk '${IGN_EXTRA_DISK}'" 1>&2
		exit 255
		;;
esac

