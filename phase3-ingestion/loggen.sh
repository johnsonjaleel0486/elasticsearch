#!/bin/sh
# Fake web-app access log: ~1 line/sec, ~20% 4xx/5xx, every 25th line corrupted on purpose.
i=0
while true; do
  i=$((i+1))
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  host="web0$((RANDOM % 3 + 1))"
  case $((RANDOM % 4)) in
    0) m=GET;  p=/api/orders ;;
    1) m=POST; p=/api/orders ;;
    2) m=GET;  p=/api/users ;;
    *) m=GET;  p=/health ;;
  esac
  r=$((RANDOM % 100))
  if   [ $r -lt 80 ]; then s=200; lat=$((RANDOM % 200 + 20))
  elif [ $r -lt 92 ]; then s=404; lat=$((RANDOM % 50 + 5))
  elif [ $r -lt 97 ]; then s=500; lat=$((RANDOM % 3000 + 500))
  else                     s=503; lat=$((RANDOM % 5000 + 1000)); fi
  case $((RANDOM % 3)) in 0) u=alice ;; 1) u=bob ;; *) u=carol ;; esac
  if [ $((i % 25)) -eq 0 ]; then
    echo "$ts $host ### corrupted line ###" >> /logs/app.log
  else
    echo "$ts $host $m $p $s ${lat}ms user=$u" >> /logs/app.log
  fi
  sleep 1
done
