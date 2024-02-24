# uCPE-installer
This repo is the home of the build system of the ISO for the automatic installation of the Hypervisor/OS on the Dell Vep.

It supports two OS flavours, Ubuntu and Fedora Core OS, each living in its dedicated directory, ubuntu and fcos respectively.

# How to use
Simply run the script "build.sh" located in the os-dependent directory.

Put any KVM root image in the directory libvirt-images and it will be copied in "/var/lib/libvirt/images" of the installed system ready to be used to create VMs.
