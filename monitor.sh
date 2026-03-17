#!/bin/bash

# --- PVE 纯净版硬件监控脚本 ---
# 特点：零依赖、无报错、低资源占用

# 自动获取物理网卡名
NIC=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')
[ -z "$NIC" ] && NIC=$(ls /sys/class/net | grep -E '^(en|eth|vmbr)' | head -1)

# 获取初始流量数据
old_rx=$(cat /proc/net/dev | grep "$NIC" | awk '{print $2}')
old_tx=$(cat /proc/net/dev | grep "$NIC" | awk '{print $10}')

while true; do
  # 使用 tput 代替 clear 减少闪烁感
  tput cup 0 0
  now=$(date '+%Y-%m-%d %H:%M:%S')
  
  echo "========================================================"
  echo "         PVE 纯净监控环境 [ $now ]"
  echo "========================================================"

  # 1. CPU 信息 (核心负载与平均频率)
  load=$(cat /proc/loadavg | awk '{print $1" "$2" "$3}')
  cpu_freq=$(awk -F': ' '/cpu MHz/ {sum+=$2; count++} END {printf "%.2f GHz", sum/count/1000}' /proc/cpuinfo)
  echo "CPU 负载: $load | 核心均频: $cpu_freq"

  # 2. 硬件温度 (兼容多种传感器路径)
  echo -n "硬件温度: "
  for zone in /sys/class/thermal/thermal_zone*; do
    if [ -f "$zone/temp" ]; then
      type=$(cat "$zone/type")
      temp=$(cat "$zone/temp")
      printf "%s:%.1f°C " "$type" "$(echo "$temp/1000" | bc -l 2>/dev/null || echo "$((temp/1000))")"
    fi
  done | cut -c1-60
  echo -e "\n--------------------------------------------------------"

  # 3. 内存使用情况
  mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
  mem_avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
  mem_used=$((mem_total - mem_avail))
  mem_pct=$((mem_used * 100 / mem_total))
  
  # 简易进度条
  bar_size=$((mem_pct / 5))
  bar=$(printf "%${bar_size}s" | tr ' ' '#')
  space=$(printf "%$((20 - bar_size))s")
  printf "内存占用: [%s%s] %d%% (%s/%s)\n" "$bar" "$space" "$mem_pct" "$(free -h | awk '/^Mem:/ {print $3}')" "$(free -h | awk '/^Mem:/ {print $2}')"

  # 4. 磁盘读写活跃度 (纯内置读取)
  echo "磁盘 I/O (累计读/写数据量):"
  awk '{if($3 ~ /sd[a-z]|nvme[0-9]n[0-9]/) printf "  %-10s 读: %-8s 写: %-8s\n", $3, $6*512/1024/1024"MB", $10*512/1024/1024"MB"}' /proc/diskstats | head -n 3
  echo "--------------------------------------------------------"

  # 5. 网络流量速率
  new_rx=$(cat /proc/net/dev | grep "$NIC" | awk '{print $2}')
  new_tx=$(cat /proc/net/dev | grep "$NIC" | awk '{print $10}')
  
  rx_rate=$(( ($new_rx - $old_rx) / 3 / 1024 ))
  tx_rate=$(( ($new_tx - $old_tx) / 3 / 1024 ))
  echo "网络速率 ($NIC): 下载: ${rx_rate} KB/s | 上传: ${tx_rate} KB/s"
  old_rx=$new_rx; old_tx=$new_tx

  # 6. PVE 容器与虚拟机状态 (PVE自带命令)
  vms=$(qm list 2>/dev/null | grep -c "running")
  cts=$(pct list 2>/dev/null | grep -c "running")
  echo "资源统计: 运行中 VM: $vms | 运行中 CT: $cts"

  echo "========================================================"
  echo "提示: 按 [Ctrl+C] 退出监控"
  
  sleep 3
done
