#!/bin/bash

# PVE 硬件状态监控脚本
# 建议保存为 monitor.sh 并赋予执行权限：chmod +x monitor.sh

while true; do 
  clear; 
  echo "========================================================"
  echo "--- PVE 硬件状态监控 [$(date '+%Y-%m-%d %H:%M:%S')] ---"
  echo "========================================================"
  
  # 1. 显示 CPU 负载
  # loadavg 分别对应 1分钟、5分钟、15分钟的系统负载
  echo "CPU 负载 (1/5/15min): $(cat /proc/loadavg | cut -d' ' -f1-3)"
  echo "--------------------------------------------------------"
  
  # 2. 显示 CPU/系统温度
  # 遍历 thermal_zone 目录，读取类型和温度（除以1000得到摄氏度）
  echo "温度状态:"
  paste <(cat /sys/class/thermal/thermal_zone*/type) <(cat /sys/class/thermal/thermal_zone*/temp) | \
  column -s $'\t' -t | \
  sed 's/\([0-9]\{2\}\)\([0-9]\{3\}\)$/\1.\2°C/'
  
  echo "--------------------------------------------------------"
  
  # 3. (可选补充) 显示内存使用率，方便闭环监控
  echo "内存使用: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
  
  echo "--------------------------------------------------------"
  echo "操作提示: 按 [Ctrl+C] 停止监控"
  
  # 刷新频率：每 3 秒更新一次
  sleep 3; 
done
