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

packet_xlate 
next_learn_with_delete
ofproto_flow_mod_init_for_learn
ofproto_flow_mod_learn_refresh
rev_mac_learning_count
rev_mac_learning_init_coverage
xlate_learn_action
xlate_mac_learning_update
"

#symbol in libopenvswitch 
ovs_func="
xmalloc
xcalloc
xrealloc
vconn_send
vconn_recv
rconn_send
rconn_recv
cls_rule_init_from_minimatch
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
classifier_count
classifier_destroy
classifier_find_match_exactly
classifier_find_rule_exactly
classifier_init
classifier_insert
classifier_is_empty
classifier_lookup
classifier_lookup__
classifier_remove
classifier_replace
classifier_rule_overlaps
classifier_set_prefix_fields
mac_learning_create
mac_learning_expire
mac_learning_expired_count
mac_learning_expired_init_coverage
mac_learning_flush
mac_learning_insert
mac_learning_learned_count
mac_learning_learned_init_coverage
mac_learning_lookup
mac_learning_may_learn
mac_learning_ref
mac_learning_run
mac_learning_set_flood_vlans
mac_learning_set_idle_time
mac_learning_set_max_entries
mac_learning_unref
mac_learning_update
mac_learning_wait
"

#symbol in ovs-vswitchd
vswitch_func="
bridge_run
bridge_run__
bridge_exit
bridge_get_memory_usage
bridge_init
bridge_wait
"

# install debuginfo
LIBOVSDBG=/usr/lib/debug/usr/lib64/libopenvswitch.so.debug
LIBOVS=/usr/lib64/libopenvswitch-2.8.so.0
LIBOFPDBG=/usr/lib/debug/usr/lib64/libofproto.so.debug
LIBOFP=/usr/lib64/libofproto-2.8.so.0
VSWITCHDBG=/usr/lib/debug/usr/sbin/ovs-vswitchd.debug
VSWITCH=/usr/sbin/ovs-vswitchd
PERF=perf

uprobe_libofproto() {
    echo "ADD OFPROTO Uprobe"
    for func in $ofproto_func;
    do
        $PERF probe -k $LIBOFPDBG -x $LIBOFP $func
    done
    echo 1 > /sys/kernel/debug/tracing/events/probe_libofproto/enable
}

uprobe_libopenvswitch() {
    echo "ADD LIBOPENVSWITCH Uprobe"
    for func in $ovs_func;
    do
        $PERF probe -k $LIBOVSDBG -x $LIBOVS $func
    done
    echo 1 > /sys/kernel/debug/tracing/events/probe_libopenvswitch/enable
}

uprobe_vswitchd() {
    echo "ADD VSWITCHD Uprobe"
    for func in $vswitch_func;
    do
        $PERF probe -k $VSWITCHDBG -x $VSWITCH $func
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
#uprobe_enable

# cat /sys/kernel/debug/tracing/uprobe_profile

