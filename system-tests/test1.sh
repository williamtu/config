#!/bin/bash

#  datapath - ping between two ports
rm -f /usr/local/etc/openvswitch/conf.db
ovsdb-tool create /usr/local/etc/openvswitch/conf.db vswitchd/vswitch.ovsschema

ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
    --pidfile --detach


ovs-vsctl --no-wait init 
ovs-vswitchd  --detach --no-chdir --pidfile --log-file -vvconn -vofproto_dpif -vunixctl
ovs-vsctl -- add-br br0 -- set Bridge br0 protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,OpenFlow15 fail-mode=secure 
ovs-ofctl add-flow br0 "actions=normal"

ip netns add at_ns0 
ip netns add at_ns1 

ip link add p0 type veth peer name ovs-p0 
ip link set p0 netns at_ns0
ip link set dev ovs-p0 up
ovs-vsctl add-port br0 ovs-p0 -- \
                set interface ovs-p0 external-ids:iface-id="p0"

ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ip addr add "10.1.1.1/24" dev p0
ip link set dev p0 up
NS_EXEC_HEREDOC


ip link add p1 type veth peer name ovs-p1 
ip link set p1 netns at_ns1
ip link set dev ovs-p1 up
ovs-vsctl add-port br0 ovs-p1 -- \
                set interface ovs-p1 external-ids:iface-id="p1"

ip netns exec at_ns1 sh << NS_EXEC_HEREDOC
ip addr add "10.1.1.2/24" dev p1
ip link set dev p1 up
NS_EXEC_HEREDOC


ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ping -q -c 3 -i 0.3 -w 2 10.1.1.2 | grep "transmitted" | sed 's/time.*ms$/time 0ms/'
NS_EXEC_HEREDOC

ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ping -s 3200 -q -c 3 -i 0.3 -w 2 10.1.1.2 | grep "transmitted" | sed 's/time.*ms$/time 0ms/'
NS_EXEC_HEREDOC

ovs-appctl -t ovsdb-server exit
ovs-appctl -t ovs-vswitchd exit
ip netns del at_ns0
ip netns del at_ns1
ip link del ovs-p0
ip link del ovs-p1
