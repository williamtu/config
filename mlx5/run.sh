#!/bin/bash
set -x
#echo 1 > /sys/module/mlx5_core/parameters/debug_mask
echo s > /proc/sysrq-trigger
set -e

old_setup() {
PF1=enp8s0f0
VFREP1=enp8s0f0_0
VFREP2=enp8s0f0_1
VFREP3=enp8s0f0_2
VFREP4=enp8s0f0_3
VF1=eth2
VF2=eth3
VF3=eth4
VF4=eth5
}

PF1=eth2
VFREP1=eth4
VFREP2=eth5
VF1=eth6
VF2=eth7

NS1=ns1
NS2=ns2
NS3=ns3
NS4=ns4

SF1=enp8s0f0s88
SF2=enp8s0f0s99
SFREP1=en8f0pf0sf88
SFREP2=en8f0pf0sf99

setup_dev_ns()
{
	ns=$1
	vfdev=$2
	ip=$3

	ip netns del $ns || true
	ip netns add $ns
	ip link set dev $vfdev netns $ns
	ip netns exec $ns ifconfig $vfdev ${ip}/24 up
	ip netns exec $ns iperf -s -u  -D
}

setup_ovs()
{
#	devlink dev eswitch set pci/0000:08:00.0 mode switchdev
	/usr/share/openvswitch/scripts/ovs-ctl stop
	rm -f /etc/openvswitch/conf.db
	echo 2 > /sys/class/net/$PF1/device/sriov_numvfs
	python2 /usr/bin/mlx_fs_dump -d 0000:08:00.0 > /root/net-next/fdb.txt

	/usr/share/openvswitch/scripts/ovs-ctl start
#	ovs-vsctl set Open_vSwitch . other_config:hw-offload=false


	ovs-vsctl add-br ovsbr0
	ovs-vsctl add-port ovsbr0 $VFREP1
	ovs-vsctl add-port ovsbr0 $VFREP2

	ip link set dev $VFREP1 up
	ip link set dev $VFREP2 up

	setup_dev_ns $NS1 $VF1 192.167.111.1
	setup_dev_ns $NS2 $VF2 192.167.111.2

	ip netns exec $NS1 ping -i .2 -c30 192.167.111.2
	ip netns exec $NS2 ping -i .2 -c30 192.167.111.1
	ip netns exec $NS1 iperf -u -b10M -c 192.167.111.2 -t3 -i1
}

enable_rmp()
{
	devlink dev param set pci/0000:08:00.0 name esw_rq_rmp value true cmode runtime
	devlink dev eswitch set pci/0000:08:00.0 mode switchdev
}
disable_rmp()
{
	devlink dev param set pci/0000:08:00.0 name esw_rq_rmp value false cmode runtime
	devlink dev eswitch set pci/0000:08:00.0 mode switchdev
}
add_vf()
{
	echo 2 > /sys/class/net/$PF1/device/sriov_numvfs
}
del_vf()
{
	echo 0 > /sys/class/net/$PF1/device/sriov_numvfs
}

setup_br_and_test()
{
#	ethtool -L eth2 combined 4
	ip link set dev $VFREP1 up #
	ip link set dev $VFREP2 up #

#	ethtool -L eth4 combined 4
#	ethtool -L eth5 combined 4

	brctl addbr br1
	brctl addif br1 $VFREP1
	brctl addif br1 $VFREP2
	ip link set dev br1 up

	ip netns add $NS1
	ip link set dev $VF1 netns $NS1
	ip netns exec $NS1 ifconfig $VF1 192.168.111.6/24 up

	ip netns add $NS2
	ip link set dev $VF2 netns $NS2
	ip netns exec $NS2 ifconfig $VF2 192.168.111.7/24 up

	ip netns exec $NS1 ping -i .2 -c10 192.168.111.7
	ip netns exec $NS2 ping -i .2 -c10 192.168.111.6
	ip netns exec $NS1 iperf -s -D
	ip netns exec $NS2 iperf -c 192.168.111.6 -t5 -i1
}

cleanup_br()
{
	ip link set dev br1 down; brctl delbr br1
	ip netns del $NS1
	ip netns del $NS2
}

test_rmp()
{
	cleanup_br
	del_vf
	echo s > /proc/sysrq-trigger
	ip link set dev $PF1 up
	sleep 1
	enable_rmp
	add_vf
	setup_br_and_test
	cleanup_br
	del_vf
}

test_no_rmp()
{
	cleanup_br
	del_vf
	echo s > /proc/sysrq-trigger
	ip link set dev $PF1 up
	sleep 1
	disable_rmp
	add_vf
	setup_br_and_test
	cleanup_br
	del_vf
}

add_sf()
{
	devlink port add pci/0000:08:00.0 flavour pcisf pfnum 0 sfnum 88
	devlink port function set pci/0000:08:00.0/32768 hw_addr 00:00:00:00:88:88
	devlink port function set pci/0000:08:00.0/32768 state active
	sleep 0.5
	devlink dev param set auxiliary/mlx5_core.sf.2 name enable_eth value 1 cmode driverinit
	devlink dev reload auxiliary/mlx5_core.sf.2

	devlink port add pci/0000:08:00.0 flavour pcisf pfnum 0 sfnum 99
	devlink port function set pci/0000:08:00.0/32769 hw_addr 00:00:00:00:88:99
	devlink port function set pci/0000:08:00.0/32769 state active
	sleep 0.5
	devlink dev param set auxiliary/mlx5_core.sf.3 name enable_eth value 1 cmode driverinit
	devlink dev reload auxiliary/mlx5_core.sf.3
#tree -l -L 3 -P "mlx5_core.sf." /sys/bus/auxiliary/devices/
#devlink port show en8f0pf0sf88 -jp
}

del_sf()
{
	devlink port function set pci/0000:08:00.0/32768 state inactive
	devlink port del pci/0000:08:00.0/32768

	devlink port function set pci/0000:08:00.0/32769 state inactive
	devlink port del pci/0000:08:00.0/32769
}

# SF: enp8s0f0s88 rep-SF: en8f0pf0sf88
# SF: enp8s0f0s99 rep-SF: en8f0pf0sf99
#
setup_br_and_test_sf()
{
	ip link set dev $SFREP1 up
	ip link set dev $SFREP2 up

#	ethtool -L eth4 combined 4
#	ethtool -L eth5 combined 4

	brctl addbr br1
	brctl addif br1 $SFREP1
	brctl addif br1 $SFREP2
	ip link set dev br1 up

#FIXME
SF1=eth2
SF2=eth3
	ip netns add $NS1
	ip link set dev $SF1 netns $NS1
	ip netns exec $NS1 ifconfig $SF1 192.168.111.6/24 up

	ip netns add $NS2
	ip link set dev $SF2 netns $NS2
	ip netns exec $NS2 ifconfig $SF2 192.168.111.7/24 up

	ip netns exec $NS1 ping -i .2 -c10 192.168.111.7
	ip netns exec $NS2 ping -i .2 -c10 192.168.111.6
	ip netns exec $NS1 iperf -s -D
	ip netns exec $NS2 iperf -c 192.168.111.6 -t5 -i1
}

cleanup_br_sf()
{
	ip link set dev br1 down; brctl delbr br1
	ip netns del $NS1
	ip netns del $NS2
}

test_rmp_sf()
{
	enable_rmp
	ip link set dev $PF1 up
	add_sf
	setup_br_and_test_sf
	cleanup_br_sf
	del_sf
}

test_no_rmp_sf()
{
	disable_rmp
	add_sf
	setup_br_and_test_sf
	cleanup_br_sf
	del_sf
}

# udev file /etc/udev/rules.d/83-mlnx-sf-name.rules
# ethtool -g eth2

make -j8 -C . M=drivers/net/ethernet/mellanox/mlx5/core/
set +e
rmmod mlx5_ib
rmmod mlx5_vdpa
rmmod mlx5_core
#insmode drivers/infiniband/hw/mlx5/mlx5_ib.ko
insmod drivers/net/ethernet/mellanox/mlx5/core/mlx5_core.ko

#insmod /root/mlx5_core.ko; echo "LOADING Default MLX5"
devlink dev param set pci/0000:08:00.0 name flow_steering_mode value dmfs cmode runtime
devlink dev eswitch set pci/0000:08:00.0 mode switchdev
exit
python2 /usr/bin/mlx_fs_dump -d 0000:08:00.0 > /root/net-next/fdb.txt
setup_ovs

exit
#ethtool -K eth2 ntuple on
#echo 4 > /sys/class/net/eth2/device/sriov_numvfs
# ovs-vsctl get Open_vSwitch . other_config:hw-offload

#test_no_rmp_sf
#exit
#test_rmp
test_no_rmp
exit
test_no_rmp_sf
test_rmp_sf

exit

# WIP area
devlink dev param set pci/0000:08:00.1 name esw_rmp_size value 2048 cmode driverinit
devlink dev reload pci/0000:08:00.1
devlink dev param show

devlink dev param set pci/0000:08:00.0 name flow_steering_mode value dmfs cmode runtime
