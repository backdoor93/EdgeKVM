#!/bin/bash
cd $(dirname $0)
echo "Please insert the Velocloud Edge activation code:"
read ACTIVATION_CODE
regex='[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}'
if ! [[ $ACTIVATION_CODE =~ $regex ]] ;
then
  echo "Invalid activation code, must match $regex"
  exit 1
fi
SERIALNO=$(dmidecode -s system-serial-number)
echo "instance-id: vce-$SERIALNO
local-hostname: vce-$SERIALNO
network-interfaces:
      GE1:
         type: dhcp
      GE2:
         type: dhcp
      GE3:
         type: dhcp
      GE4:
         type: dhcp
      GE5:
         type: dhcp" > meta-data
echo "#cloud-config 
password: velocloud 
chpasswd: { expire: False }
ssh_pwauth: True
velocloud:
      vce: 
            vco: sdwanvco.saipem.com
            activation_code: $ACTIVATION_CODE
            vco_ignore_cert_errors: true" > user-data

genisoimage -output /var/lib/libvirt/images/cloud-init-vedge.iso -volid cidata -joliet -rock user-data meta-data
gunzip -k /var/lib/libvirt/images/edge-VC_KVM_GUEST-x86_64-4.5.1-330-R451-20230112-GA-87923-56811f7b8e-updatable-ext4.qcow2.gz
chmod 600 /var/lib/libvirt/images/edge-VC_KVM_GUEST-x86_64-4.5.1-330-R451-20230112-GA-87923-56811f7b8e-updatable-ext4.qcow2.gz
virsh define vedge.xml
virsh start vedge
virsh autostart vedge
virsh attach-device --domain vedge --file eth0.xml --persistent 
virsh attach-device --domain vedge --file eth1.xml --persistent 
virsh attach-device --domain vedge --file eth2.xml --persistent
virsh attach-device --domain vedge --file eth3.xml --persistent
virsh attach-device --domain vedge --file eth4.xml --persistent
cd -
