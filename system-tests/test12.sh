#                             -*- compilation -*-
#testing datapath - ping over geneve tunnel ...

rm -f /usr/local/etc/openvswitch/conf.db
ovsdb-tool create /usr/local/etc/openvswitch/conf.db /root/ovs/vswitchd/vswitch.ovsschema

ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
    --pidfile --detach

ovs-vsctl --no-wait init 
ovs-vswitchd  --detach --no-chdir --pidfile --log-file -vvconn -vofproto_dpif -vunixctl

ovs-vsctl -- add-br br0 -- set Bridge br0 protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,OpenFlow15 fail-mode=secure 
ovs-vsctl -- add-br br-underlay -- set Bridge br0 protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,OpenFlow15 fail-mode=secure

ovs-ofctl add-flow br0 "actions=normal"
ovs-ofctl add-flow br-underlay "actions=normal"

ip netns add at_ns0 
ip link add p0 type veth peer name ovs-p0
ip link set p0 netns at_ns0
ip link set dev ovs-p0 up
ovs-vsctl add-port br-underlay ovs-p0 -- \
                set interface ovs-p0 external-ids:iface-id="p0"

ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ip addr add "172.31.1.1/24" dev p0
ip link set dev p0 up
NS_EXEC_HEREDOC

ip addr add dev br-underlay "172.31.1.100/24"
ip link set dev br-underlay up
ovs-vsctl add-port br0 at_gnv0 -- \
              set int at_gnv0 type=geneve options:remote_ip=172.31.1.1 

ip addr add dev br0 10.1.1.100/24
ip link set dev br0 up
ip link set dev br0 mtu 1450

ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ip link add dev ns_gnv0 type geneve remote 172.31.1.100 vni 0
ip addr add dev ns_gnv0 10.1.1.1/24
ip link set dev ns_gnv0 mtu 1450  up
NS_EXEC_HEREDOC

ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ping -q -c 3 -i 0.3 -w 2 172.31.1.100 | grep "transmitted" | sed 's/time.*ms$/time 0ms/'
NS_EXEC_HEREDOC

ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ping -q -c 3 -i 0.3 -w 2 10.1.1.100 | grep "transmitted" | sed 's/time.*ms$/time 0ms/'
NS_EXEC_HEREDOC

ovs-appctl -t ovsdb-server exit
ovs-appctl -t ovs-vswitchd exit
ip netns del at_ns0
ip link del ovs-p0


ovs-appctl -t ovsdb-server exit
ovs-appctl -t ovs-vswitchd exit
ip netns del at_ns0
ip link del ovs-p0

