#                             -*- compilation -*-
echo "testing datapath - ping over ip6erspan v1 tunnel ..."

trap cleanup 0 2 3 9 

#rmmod openvswitch
#modprobe openvswitch

rm -f /usr/local/etc/openvswitch/conf.db
ovsdb-tool create /usr/local/etc/openvswitch/conf.db /root/ovs/vswitchd/vswitch.ovsschema

ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
    --pidfile --detach

ovs-vsctl --no-wait init 
ovs-vswitchd  --detach --no-chdir --pidfile --log-file=/root/ovs/ovs-vswitchd.log -vvconn -vofproto_dpif -vunixctl


ovs-vsctl -- add-br br0 -- set Bridge br0 protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,OpenFlow15 fail-mode=secure   
ovs-vsctl -- add-br br-underlay -- set Bridge br-underlay protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,OpenFlow15 fail-mode=secure   
ovs-ofctl add-flow br0 "actions=normal"
ovs-ofctl add-flow br-underlay "actions=normal"

ip netns add at_ns0
ip link add p0 type veth peer name ovs-p0
ip link set p0 netns at_ns0
ip link set dev ovs-p0 up
ovs-vsctl add-port br-underlay ovs-p0 -- \
                set interface ovs-p0 external-ids:iface-id="p0"

ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ip addr add dev p0 fc00:100::1/96
ip link set dev p0 up
NS_EXEC_HEREDOC

ip addr add dev br-underlay fc00:100::100/96
ip link set dev br-underlay up
ovs-vsctl add-port br0 at_erspan0 -- \
              set int at_erspan0 type=ip6erspan options:key=1 options:remote_ip=fc00:100::1 \
              options:erspan_ver=1 options:erspan_idx=0x7

ip addr add dev br0 10.1.1.100/24
ip link set dev br0 up
ip link set dev br0 mtu 1280

ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ip link add dev ns_erspan0 type ip6erspan local fc00:100::1 remote fc00:100::100 seq key 1 erspan_ver 1 erspan 7
ip addr add dev ns_erspan0 10.1.1.1/24
ip link set dev ns_erspan0 mtu 1280  up
ip link set dev ns_erspan0 mtu 1280
NS_EXEC_HEREDOC

ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ping6 -q -c 3 -i 0.3 -w 2 fc00::100 | grep "transmitted" | sed 's/time.*ms$/time 0ms/'
NS_EXEC_HEREDOC

ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ping -q -c 3 -i 0.3 -w 2 10.1.1.100 | grep "transmitted" | sed 's/time.*ms$/time 0ms/'
NS_EXEC_HEREDOC

