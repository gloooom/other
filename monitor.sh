#!/bin/bash

# --- PVE 全能监控脚本  ---
# 包含：CPU 频率/负载/温度、内存/Swap、磁盘空间/IO、网络速率/丢包、VM/LXC 运行状态

# 自动获取默认网卡名（兼容 eth0, enp1s0, vmbr0 等）
NIC=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
old_rx=$(cat /proc/net/dev | grep "$NIC" | awk '{print $2}')
old_tx=$(cat /proc/net/dev | grep "$NIC" | awk '{print $10}')

while true; do
  clear
  now=$(date '+%Y-%m-%d %H:%M:%S')
  echo "========================================================"
  echo "         PVE 全能监控中心 [ $now ]"
  echo "========================================================"

  # 1. CPU 与 核心频率 (显示所有核心平均频率)
  avg_freq=$(awk '/cpu MHz/ {sum+=$4} END {printf "%.2f GHz", sum/NR/1000}' /proc/cpuinfo)
  load=$(cat /proc/loadavg | cut -d' ' -f1-3)
  echo "CPU 负载: $load | 平均主频: $avg_freq"
  
  # 2. 温度监控
  echo -n "硬件温度: "
  paste <(cat /sys/class/thermal/thermal_zone*/type) <(cat /sys/class/thermal/thermal_zone*/temp) | \
  awk '{printf "%s:%.1f°C  ", $1, $2/1000}' | cut -c1-60
  echo -e "\n--------------------------------------------------------"

  # 3. 内存与 Swap (百分比条状图显示)
  mem_info=$(free | grep Mem)
  mem_total=$(echo $mem_info | awk '{print $2}')
  mem_used=$(echo $mem_info | awk '{print $3}')
  mem_pct=$(( mem_used * 100 / mem_total ))
  printf "内存占用: [%-20s] %d%%\n" $(printf "#%.0s" $(seq 1 $((mem_pct/5)))) $mem_pct

  # 4. 磁盘 I/O 简易监控 (查看是否有高延迟)
  echo "磁盘状态 (读/写速度):"
  iostat -d -k 1 1 | grep -E '^[a-z]da|^nvme' | awk '{printf "  %-10s 读: %-8s 写: %-8s\n", $1, $3"KB/s", $4"KB/s"}' 2>/dev/null || echo "  (需安装 sysstat 以查看 IO)"
  
  # 5. 网络流量与丢包 (自动适配网卡: $NIC)
  new_rx=$(cat /proc/net/dev | grep "$NIC" | awk '{print $2}')
  new_tx=$(cat /proc/net/dev | grep "$NIC" | awk '{print $10}')
  err_rx=$(cat /proc/net/dev | grep "$NIC" | awk '{print $4}')
  
  rx_rate=$(( ($new_rx - $old_rx) / 3 / 1024 ))
  tx_rate=$(( ($new_tx - $old_tx) / 3 / 1024 ))
  echo "网络 ($NIC): 下载: ${rx_rate}KB/s | 上传: ${tx_rate}KB/s | 丢包: $err_rx"
  old_rx=$new_rx; old_tx=$new_tx
  echo "--------------------------------------------------------"

  # 6. PVE 虚拟机/容器状态统计
  vm_running=$(qm list | grep running | wc -l)
  vm_total=$(qm list | iostat -d | grep -v "VMID" | wc -l)
  ct_running=$(pct list | grep running | wc -l)
  echo "资源统计: 运行中 VM: $vm_running | 运行中 CT: $ct_running"
  
  # 7. 占用 CPU 最高的进程 (前 3 名)
  echo "高负载进程:"
  ps -eo pcpu,pmem,comm --sort=-pcpu | head -n 4 | tail -n 3 | awk '{printf "  %-15s CPU: %s%%  MEM: %s%%\n", $3, $1, $2}'

  echo "========================================================"
  echo "提示: 按 [Ctrl+C] 退出 | 刷新频率: 3s"
  sleep 3
done
