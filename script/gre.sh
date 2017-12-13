#!/bin/bash
# In the namespace NS0, create veth0 and gre00
# Out of the namespace, create veth1 and gre11
# Ping in and out of namespace using ERSPAN protocol 

# Namespace0:
# - gre00 
# IP: 10.1.1.100
# local 192.16.1.100 remote 192.16.1.200
# - veth0
# IP: 172.16.1.100

# Out of namespace:
# - gre11 
# IP: 10.1.1.200
# local 172.16.1.200 remote 172.16.1.100
# - veth1
# IP: 172.16.1.200

set -ex
TYPE=gre
DEV_NS=gre00
DEV=gre11

function cleanup() {
	set +ex
	ip netns del ns0
	ip link del gre11
	ip link del veth1
}


function main() {
	trap cleanup 0 2 3 9

	ip netns add ns0
	ip link add veth0 type veth peer name veth1
	ip link set veth0 netns ns0
	ip netns exec ns0 ip addr add 172.16.1.100/24 dev veth0
	ip netns exec ns0 ip link set dev veth0 up

	# Tunnel
	ip netns exec ns0 ip link add dev $DEV_NS type $TYPE key 102 local 172.16.1.100 remote 172.16.1.200 
	ip netns exec ns0 ip addr add dev $DEV_NS 10.1.1.100/24
	ip netns exec ns0 ip link set dev $DEV_NS up

	# Linux
	ip link set dev veth1 up
	ip addr add dev veth1 172.16.1.200/24
	ip link add dev $DEV type $TYPE key 102 local 172.16.1.200 remote 172.16.1.100

	ip addr add dev $DEV 10.1.1.200/24
	ip link set dev $DEV up
}

main

# Ping from NS0
ip netns exec ns0 ping -c 3 10.1.1.200
ping -c 3 10.1.1.100
exit 0
