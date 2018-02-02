#!/bin/bash

function cleanup() {
    set +e
    ovs-dpctl del-dp ovs-system 
    ovs-appctl -t ovsdb-server exit
    ovs-appctl -t ovs-vswitchd exit
}
cleanup

set -e
set -x

modprobe openvswitch
rm -f /usr/local/etc/openvswitch/conf.db
ovsdb-tool create /usr/local/etc/openvswitch/conf.db vswitchd/vswitch.ovsschema
ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
                     --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
                     --private-key=db:Open_vSwitch,SSL,private_key \
                     --certificate=db:Open_vSwitch,SSL,certificate \
                     --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert \
                     --pidfile --detach \
                     --log-file
ovs-vsctl --log-file --no-wait init
LOG=/root/ovs/ovs-vswitchd.log

if [ "$1" == "ker" ]; then
    ovs-vswitchd --no-chdir --pidfile --log-file=$LOG -vvconn -vofproto_dpif \
        -vunixctl --detach
    ovs-vsctl add-br br0 
    ovs-vsctl show
elif [ "$1" == "user" ]; then
    ovs-vswitchd --no-chdir --pidfile --log-file -vvconn -vofproto_dpif \
        -vunixctl --enable-dummy --disable-system --detach
    ovs-vsctl add-br br0 -- set bridge br0 datapath_type=dummy 
    ovs-vsctl show
elif [ "$1" == "valgrind" ]; then 
    valgrind --leak-check=full --show-leak-kinds=all \
        ovs-vswitchd --log-file=$LOG --pidfile --verbose=dbg

elif [ "$1" == "gdb" ]; then 
    gdb -ex=r --args ovs-vswitchd unix:/usr/local/var/run/openvswitch/db.sock \
        --pidfile --enable-dummy

elif [ "$1" == "build" ]; then 
    ./boot.sh
    ./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc --enable-ssl --with-linux=/lib/modules/`uname -r`/build
    make -j3
    make install
else
    echo "Invalid Option"
    cleanup 
fi

exit
#ovs-vswitchd --enable-dummy --disable-system  --detach --no-chdir --pidfile --log-file -vvconn -vofproto_dpif -vunixctl
#valgrind --leak-check=full --show-leak-kinds=all 
ovs-vswitchd --log-file=/root/ovs/ovs-vswitchd.log --pidfile --verbose=dbg --detach --enable-dummy --disable-system

valgrind --leak-check=full --show-leak-kinds=all \
    ovs-vswitchd --log-file=/root/ovs/ovs-vswitchd.log --pidfile --verbose=dbg 


ovs-vsctl add-br br0 # -- set bridge br0 datapath_type=dummy 

#-- set bridge br0 datapath_type=bpf
ovs-vsctl set bridge br0 protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,OpenFlow15,OpenFlow16


ovs-ofctl del-flows br0

#ovs-ofctl --protocols=OpenFlow15 add-flow br0 "table=0 actions=learn(table=0,delete_learned,cookie=0x123,result_dst=NXM_NX_REG6[0], NXM_OF_ETH_DST[]=NXM_OF_ETH_SRC[])"

#ovs-ofctl add-tlv-map br0 "{class=0xffff,type=0,len=4}->tun_metadata0"
ovs-ofctl --protocols=OpenFlow15 add-flow br0 "table=0 actions=set_field:0xeeff->reg7,set_field:0xabcdef01->metadata, resubmit(,1)"
ovs-ofctl --protocols=OpenFlow15 add-flow br0 "table=1 actions=learn(table=10,delete_learned,cookie=0x123,result_dst=NXM_NX_REG6[0], NXM_NX_REG7[0],NXM_OF_ETH_DST[]=NXM_OF_ETH_SRC[],OXM_OF_METADATA[])"

ovs-vsctl add-port br0 p1 -- set interface p1 type=dummy
ovs-vsctl add-port br0 p2 -- set interface p2 type=dummy

ovs-appctl netdev-dummy/receive p1 'in_port(1),eth(src=50:54:00:00:00:01,dst=50:54:00:00:00:ff),eth_type(0x1234)'
ovs-ofctl --protocols=OpenFlow15 dump-flows br0

ovs-appctl netdev-dummy/receive p1 'in_port(1),eth(src=50:54:00:00:00:02,dst=50:54:00:00:00:ff),eth_type(0x1234)'
ovs-appctl netdev-dummy/receive p1 'in_port(1),eth(src=50:54:00:00:00:03,dst=50:54:00:00:00:ff),eth_type(0x1234)'
ovs-appctl netdev-dummy/receive p1 'in_port(1),eth(src=50:54:00:00:00:04,dst=50:54:00:00:00:ff),eth_type(0x1234)'

ovs-ofctl del-flows br0 'table=1'

ovs-ofctl --protocols=OpenFlow15 dump-flows br0

#ifconfig br0 192.168.43.160

exit
ovs-ofctl del-flows br0

#ovs-ofctl -O OpenFlow13 add-flow br0 "actions=push_vlan:0x8100,set_vlan_vid:99,set_vlan_pcp:1,LOCAL,pop_vlan,LOCAL"
ovs-vsctl add-port br0 enp0s16


exit 0
ovs-ofctl -O OpenFlow13 add-flow br0 "actions=push_vlan:0x8100,pop_vlan,NORMAL"

ovs-vsctl -- --id=@eno16777736 get port eno16777736 -- --id=@veth1 get port veth1 -- --id=@m create mirror name=m
select_src_port=@eno16777736 output-port=@veth1 -- set Bridge br0 mirrors=@m

ovs-appctl ofproto/trace br0 in_port=LOCAL,dl_src=10:20:30:40:50:60

ovsdb/ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
       --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
       --private-key=db:Open_vSwitch,SSL,private_key \
       --certificate=db:Open_vSwitch,SSL,certificate \
       --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert \
       --pidfile --detach --log-file

