#!/bin/bash
set -x

./utilities/ovs-ctl stop
ovs-dpctl del-dp ovs-system
rmmod openvswitch

./utilities/ovs-ctl load-kmod
./utilities/ovs-ctl start
./utilities/ovs-ctl start

ovs-vsctl set open_vswitch . other_config:flow-restore-wait=false

#mac_of_ens160='"00:50:56:82:8e:95"'
#ovs-vsctl --may-exist add-br br0 -- \
#    --may-exist add-port br0 ens160 -- \
#        set interface br0 mac="$mac_of_ens160"; ip addr flush dev ens160;
ip link set dev br0 up
ip addr flush dev ens160
ip -6 addr flush dev ens160
dhclient br0 &

ip link set dev br1 up
ip addr add dev br1 192.168.100.1/24
#ip addr add dev br0 fc00:100::101/96
exit

#underlay
ovs-vsctl add-br br1
ovs-vsctl add-port br1 at_gre0 -- set int at_gre0 type=gre options:remote_ip=10.52.5.102

#ovs-vsctl add-port br1 at_ip6gre0 -- set int at_ip6gre0 type=ip6gre  \
#	options:remote_ip=fd00:100::102

ovs-vsctl add-port br0 at_erspan0 -- \
              set int at_erspan0 type=ip6erspan options:key=1 options:remote_ip=fc00:100::102 \
	               options:erspan_ver=1 options:erspan_idx=0x7


