#!/bin/sh
# $#: number of args passed

# enable sparse checking
CF="-Wsparse-all -D__CHECKER__ -D__CHECK_ENDIAN__ -Wbitwise"
LOCALVERSION=$(git branch | sed -n -e "s/* \(.*\)/\1/p" | sed -e "s/_/-/g")
TARGET=bindeb-pkg
# or binrpm-pkg

if [ $# -gt 1 ]; then
	echo "usage: %0 [localversion]"
	exit 1
elif [ $# -eq 1 ]; then
	LOCALVERSION=$1
fi

# create new branch
git checkout -b $LOCALVERSION
make olddefconfig

# check
NPROC=$(getconf _NPROCESSORS_ONLN)
NPROC1=$(($NPROC - 1))
make -j"$NPROC" C=1 CF="$CF" LOCALVERSION="-$LOCALVERSION" $TARGET

#example
# make C=1 CF="-Wsparse-all -D__CHECKER__ -D__CHECK_ENDIAN__ -Wbitwise" net/ipv6/
# scan-build make net/ipv6/ip6_gre.o

# noinline
# -fno-inline-small-functions
