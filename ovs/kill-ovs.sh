#!/bin/bash

ovs-dpctl del-dp ovs-system 
ovs-appctl -t ovsdb-server exit
ovs-appctl -t ovs-vswitchd exit
