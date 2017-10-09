#!/bin/bash

# at receiver
# nc -u -l 1234

insmod drivers/net/netconsole.ko \
 netconsole=4444@192.168.218.142/enp0s16,1234@192.168.218.1/00:50:56:c0:00:08

