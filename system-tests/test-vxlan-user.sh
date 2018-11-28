#!/bin/bash
# testing datapath - ping over gre tunnel ...

trap cleanup 0 2 3 9

#rmmod openvswitch
#modprobe openvswitch

rm -f /usr/local/etc/openvswitch/conf.db
ovsdb-tool create /usr/local/etc/openvswitch/conf.db /root/ovs/vswitchd/vswitch.ovsschema

ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
    --pidfile --detach

ovs-vsctl --no-wait init 
ovs-vswitchd --disable-system --detach --no-chdir --pidfile --log-file=/root/ovs/ovs-vswitchd.log -vvconn -vofproto_dpif -vunixctl

ovs-vsctl add-br br0 -- set Bridge br0 datapath_type="netdev" protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,OpenFlow15 fail-mode=secure
ovs-vsctl -- add-br br-underlay -- set Bridge br-underlay protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,OpenFlow15 fail-mode=secure datapath_type="netdev"

ovs-ofctl add-flow br0 "actions=normal"
ovs-ofctl add-flow br-underlay "actions=normal"

ovs-appctl vlog/set dbg

ip netns add at_ns0
ip link add p0 type veth peer name ovs-p0
ethtool -K p0 tx off
ethtool -K p0 rxvlan off
ethtool -K p0 txvlan off

ip link set p0 netns at_ns0
ip link set dev ovs-p0 up

ovs-vsctl add-port br-underlay ovs-p0 -- \
                set interface ovs-p0 external-ids:iface-id="p0" type="afxdp"

ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ip addr add "172.31.1.1/24" dev p0
ip link set dev p0 up
NS_EXEC_HEREDOC


ip addr add dev br-underlay "172.31.1.100/24"
ip link set dev br-underlay up
ovs-vsctl add-port br0 at_vxlan0 -- \
              set int at_vxlan0 type=vxlan options:remote_ip=172.31.1.1 

ip addr add dev br0 10.1.1.100/24
ip link set dev br0 up
ip link set dev br0 mtu 1450

ovs-appctl ovs/route/add 10.1.1.100/24 br0
ovs-appctl ovs/route/add 172.31.1.92/24 br-underlay
ovs-appctl ovs/route/show


#underlay
ping -c 2 172.31.1.1

ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ip link add dev at_vxlan1 type vxlan remote 172.31.1.100 id 0 dstport 4789
ip addr add dev at_vxlan1 10.1.1.1/24
ip link set dev at_vxlan1 mtu 1450  up
ping -q -c 3 -i 0.3 -w 2 172.31.1.100 | grep "transmitted" | sed 's/time.*ms$/time 0ms/'
ping -q -c 3 -i 0.3 -w 2 10.1.1.100 | grep "transmitted" | sed 's/time.*ms$/time 0ms/'
ping -s 1600 -q -c 3 -i 0.3 -w 2 10.1.1.100 | grep "transmitted" | sed 's/time.*ms$/time 0ms/'
NS_EXEC_HEREDOC

ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ping -c 60 10.1.1.100
ping -q -c 3 -i 0.3 -w 2 172.31.1.100 | grep "transmitted" | sed 's/time.*ms$/time 0ms/'
NS_EXEC_HEREDOC

function cleanup() {
    ovs-appctl -t ovsdb-server exit
    ovs-appctl -t ovs-vswitchd exit
    ip netns del at_ns0
    ip link del ovs-p0
    ip link del ovs-netdev
    ip link del br0
    ip link del br-underlay
}
cleanup
