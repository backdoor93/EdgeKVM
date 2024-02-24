#!/bin/bash
cd $(dirname $0)
virsh net-undefine --network default
virsh pool-define --file pool.xml
virsh pool-start --pool default
virsh pool-autostart --pool default
cd -
