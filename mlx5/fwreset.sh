#!/bin/bash
echo s > /proc/sysrq-trigger
rmmod mlx5_ib
rmmod mlx5_vdpa
rmmod mlx5_core
set -x
/workspace/cloud_tools/cloud_firmware_reset.sh --ips 10.234.230.9
/workspace/cloud_tools/cloud_setup_reset.sh --ips 10.234.230.9

