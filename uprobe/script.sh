#!/bin/bash

# requirements:
# install debuginfo and perf

set -e
set -x

#symbol in libofproto
ofproto_func="
 ofproto_dpif_flow_mod_init_for_learn
  ofproto_flow_mod_init
   add_flow_init
   modify_flows_init_loose
   modify_flow_init_strict
   delete_flows_init_loose
   delete_flows_init_strict

ofproto_flow_mod_learn
ofproto_flow_mod_learn_start
 ofproto_flow_mod_start
  add_flow_start
  modify_flows_start_loose
  modify_flow_start_strict
  delete_flows_start_loose
  delete_flow_start_strict

ofproto_flow_mod_learn_revert
 add_flow_revert
 modify_flows_revert
 delete_flows_revert

ofproto_flow_mod_learn_finish
 add_flow_finish
 modify_flows_finish
 delete_flows_finish

ofproto_flow_mod_learn_refresh
packet_xlate # packet-out
"

#symbol in libopenvswitch 
ovs_func="
vconn_send
vconn_recv
rconn_send
rconn_recv
cls_rule_init_from_minimatch
counter_miniflow_malloc
miniflow_alloc
miniflow_clone
miniflow_create
miniflow_equal
miniflow_equal_flow_in_minimask
miniflow_equal_in_minimask
miniflow_expand
miniflow_extract
miniflow_get_map_in_range
miniflow_hash_5tuple
miniflow_init
miniflow_malloc_count
miniflow_malloc_init_coverage
miniflow_map_init
minimask_combine
minimask_create
minimask_equal
minimask_expand
minimask_init
minimatch_clone
minimatch_destroy
minimatch_equal
minimatch_expand
minimatch_format
minimatch_init
minimatch_matches_flow
minimatch_move
minimatch_to_string
"

#symbol in ovs-vswitchd
vswitch_func="
bridge_run
"

# install debuginfo
LIBOVSDBG=/usr/lib/debug/usr/lib64/libopenvswitch.so.debug
LIBOFPDBG=/usr/lib/debug/usr/lib64/libofproto.so.debug
VSWITCHDBG=/usr/lib/debug/usr/sbin/ovs-vswitchd.debug
PERF=perf

uprobe_libofproto() {
    echo "ADD OFPROTO Uprobe"
    for func in $ofproto_func;
    do
        $PERF probe -x $LIBOFPDBG $func
    done
    echo 1 > /sys/kernel/debug/tracing/events/probe_libofproto/enable
}

uprobe_libopenvswitch() {
    echo "ADD LIBOPENVSWITCH Uprobe"
    for func in $ovs_func;
    do
        $PERF probe -x $LIBOVSDBG $func
    done
    echo 1 > /sys/kernel/debug/tracing/events/probe_libopenvswitch/enable
}

uprobe_vswitchd() {
    echo "ADD VSWITCHD Uprobe"
    for func in $vswitch_func;
    do
        $PERF probe -x $VSWITCHDBG $func
    done
    echo 1 > /sys/kernel/debug/tracing/events/probe_ovs/enable
}

uprobe_enable() {
    echo "Current Events"
    cat /sys/kernel/debug/tracing/uprobe_events
}

uprobe_disable() {
    echo "clear"
    echo 0 >  /sys/kernel/debug/tracing/events/enable
    echo > /sys/kernel/debug/tracing/uprobe_events
}

uprobe_disable
uprobe_libofproto
uprobe_libopenvswitch
uprobe_vswitchd
uprobe_enable

# cat /sys/kernel/debug/tracing/uprobe_profile

