#!/bin/bash
# In the namespace NS0, create veth0 and ip6gretap00
# Out of the namespace, create veth1 and ip6gretap11
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

#modprobe ip6_gre
#rmmod ip6_gre || true
#insmod net/ipv6/ip6_gre.ko

function cleanup() {
	set +ex
	ip netns del ns0
	ip link del ip6gre11
	ip link del veth1
}

function main() {
	trap cleanup 0 2 3 9

	ip netns add ns0
	ip link add veth0 type veth peer name veth1
	ip link set veth0 netns ns0

	# non-namespace
	ip link set dev veth1 up
	ip addr add dev veth1 fc00:100::2/96
	ip link add dev ip6gre11 type ip6gre key 102 \
		 local fc00:100::2 \
		remote fc00:100::1

	ip addr add dev ip6gre11 fc00:200::2/96
	ip addr add dev ip6gre11 10.10.200.2/24
	ip link set dev ip6gre11 up

	# namespace: ns0 
	ip netns exec ns0 ip addr add fc00:100::1/96 dev veth0

	# Tunnel
	ip netns exec ns0 ip link add dev ip6gre00 type ip6gre key 102 \
	     local fc00:100::1 \
	    remote fc00:100::2

	ip netns exec ns0 ip addr add dev ip6gre00 fc00:200::1/96
	ip netns exec ns0 ip addr add dev ip6gre00 10.10.200.1/24

	ip netns exec ns0 ip link set dev ip6gre00 up
	ip netns exec ns0 ip link set dev veth0 up
}

main

# Ping underlying
ping6 -c 3 fc00:100::1

# Ping overlay network from NS0
ping6 -c 3 fc00:200::1 
ping -c 333 10.10.200.1

# ip -6 route show
# ip -6 neigh show


