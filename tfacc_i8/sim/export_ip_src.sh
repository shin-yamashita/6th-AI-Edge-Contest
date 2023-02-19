#!/bin/bash
#
# export p_user_files
# generated files 
#  .ip_user_files/ip/*/sim/*   simulation model
#

source xilinx_env.sh

vivado -mode tcl << 'EOF'
create_project -in_memory -part xczu3eg-sbva484-1-i
set_property board_part avnet.com:ultra96v2:part0:1.2 [current_project]
set_property source_mgmt_mode All [current_project]
set ips [list rdbuf32k rdbuf16k rdbuf8k rdbuf4k rdbuf2k axi_ic dpram32kB axi_apb_bridge_0 rv32_core_0 ila_0 sysmon_0]
foreach ip $ips {
        puts "****** read and export ip ($ip)"
        read_ip ../ip/$ip.xcix
        export_ip_user_files -of_objects [get_ips $ip]
 }

exit
EOF

