#!/bin/bash
# In the namespace NS0, create veth0 and ip6erspan00
# Out of the namespace, create veth1 and ip6erspan11
# Ping in and out of namespace using ERSPAN protocol 

set -ex

#modprobe ip6_gre
#rmmod ip6_gre || true
#rmmod ip6_tunnel || true
#insmod net/ipv6/ip6_tunnel.ko
#insmod net/ipv6/ip6_gre.ko

function cleanup() {
	set +ex
	ip netns del ns0
	ip link del ip6erspan11
	ip link del veth1
}

function main() {
	trap cleanup 0 2 3 9

	ip netns add ns0
	ip link add veth0 type veth peer name veth1
	ip link set veth0 netns ns0

	# non-namespace
	ip addr add dev veth1 fc00:100::2/96

	if [ "$1" == "v1" ]; then
		echo "create IP6 ERSPAN v1 tunnel"
		ip link add dev ip6erspan11 type ip6erspan seq key 102 \
			local fc00:100::2 remote fc00:100::1 \
			erspan 123 erspan_ver 1
	else	
		echo "create IP6 ERSPAN v2 tunnel"
		ip link add dev ip6erspan11 type ip6erspan seq key 102 \
			local fc00:100::2 remote fc00:100::1 \
			erspan_ver 2 erspan_dir 1 erspan_hwid 17
	fi
	ip addr add dev ip6erspan11 fc00:200::2/96
	ip addr add dev ip6erspan11 10.10.200.2/24

	# namespace: ns0 
	ip netns exec ns0 ip addr add fc00:100::1/96 dev veth0

	if [ "$1" == "v1" ]; then
		ip netns exec ns0 \
		ip link add dev ip6erspan00 type ip6erspan seq key 102 \
			local fc00:100::1 remote fc00:100::2 \
			erspan 123 erspan_ver 1
	else
		ip netns exec ns0 \
		ip link add dev ip6erspan00 type ip6erspan seq key 102 \
			local fc00:100::1 remote fc00:100::2 \
			erspan_ver 2 erspan_dir 1 erspan_hwid 7
	fi

	ip netns exec ns0 ip addr add dev ip6erspan00 fc00:200::1/96
	ip netns exec ns0 ip addr add dev ip6erspan00 10.10.200.1/24

	ip link set dev veth1 up
	ip link set dev ip6erspan11 up
	ip netns exec ns0 ip link set dev ip6erspan00 up
	ip netns exec ns0 ip link set dev veth0 up
}

main $1

# Ping underlying
ping6 -c 1 fc00:100::1 || true

# ping overlay
ping -c 3 10.10.200.1
ping6 -c 3 fc00:200::1

# Ping overlay network from NS0
# ip netns exec ns0 ping6 -c 3 fc00:200::2 

# ip -6 route show
# ip -6 neigh show

# make C=1 CF="-Wsparse-all -D__CHECKER__ -D__CHECK_ENDIAN__ -Wbitwise" net/ipv6/
# scan-build make net/ipv6/ip6_gre.o
