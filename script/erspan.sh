#!/bin/bash
# In the namespace NS0, create veth0 and erspan00
# Out of the namespace, create veth1 and erspan11
# Ping in and out of namespace using ERSPAN protocol 

# Namespace0:
# - erspan00 
# IP: 10.1.1.100
# local 192.16.1.100 remote 192.16.1.200
# - veth0
# IP: 172.16.1.100

# Out of namespace:
# - erspan11 
# IP: 10.1.1.200
# local 172.16.1.200 remote 172.16.1.100
# - veth1
# IP: 172.16.1.200

set -ex
TYPE=erspan
DEV_NS=erspan00
DEV=erspan11

function cleanup() {
	set +ex
	ip netns del ns0
	ip link del erspan11
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
	if [ "$1" == "v1" ]; then
		echo "create ERSPANv1 tunnel"
		ip netns exec ns0 \
		ip link add dev $DEV_NS type $TYPE key 102 seq \
			local 172.16.1.100 remote 172.16.1.200 \
			erspan 262144 erspan_ver 1
	else
		echo "create ERSPANv2 tunnel"
		ip netns exec ns0 \
		ip link add dev $DEV_NS type $TYPE key 102 seq \
			local 172.16.1.100 remote 172.16.1.200 \
			erspan_ver 2 erspan_dir egress erspan_hwid 48
	fi
	ip netns exec ns0 ip addr add dev $DEV_NS 10.1.1.100/24
	ip netns exec ns0 ip link set dev $DEV_NS up

	ip link set dev veth1 up
	ip addr add dev veth1 172.16.1.200/24

	if [ "$1" == "v1" ]; then
		ip link add dev $DEV type $TYPE key 102 seq \
			local 172.16.1.200 remote 172.16.1.100 \
			erspan 262144 erspan_ver 1
	else
		ip link add dev $DEV type $TYPE key 102 seq \
			local 172.16.1.200 remote 172.16.1.100 \
			erspan_ver 2 erspan_dir ingress erspan_hwid 48
	fi
	ip addr add dev $DEV 10.1.1.200/24
	ip link set dev $DEV up
}

main $1

# Ping from NS0
ip netns exec ns0 ping -c 300 10.1.1.200

# just fit 1514 B
#ip link set dev erspan11 mtu 1200
#ping -s 1422 -c 3 10.1.1.100 

#1422 + 8 + 20 = 1450  
#1464
