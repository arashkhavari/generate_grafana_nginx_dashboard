#!/bin/bash

# Source environment variables
source .env

# Function to retrieve unique HTTP methods used by a specific domain in the last minute
method_list () {
  cat $log_path_read | grep $(date -d "1 minute ago" +"%Y-%m-%dT%H:%M") | jq '. | select(.domain=="'$1'")' | jq -r .method | sort | uniq
}

# Function to analyze HTTP status codes for a specific domain in the last minute
status_code () {
  for i in $(method_list $1); do
    cat $log_path_read | grep $(date -d "1 minute ago" +"%Y-%m-%dT%H:%M") | jq '. | select((.domain=="'$1'") and (.method=="'$i'"))' | jq -r .status | sort -n | uniq -c | while IFS=" " read -r count stscde
    do
      echo 'nginx_monitoring{domain="'$1'",method="'$i'",statuscode="'${stscde}'"}' $count
    done
  done
}

# Function to analyze response times for a specific domain in the last minute
response () {
  cat $log_path_read | grep $(date -d "1 minute ago" +"%Y-%m-%dT%H:%M") | jq '. | select(.domain=="'$1'")' | jq -r .resptime | awk '{sum += $1; array[NR] = $1; if (max < $1) max = $1; if (min == 0 || min > $1) min = $1} END {avg = sum / NR; print max, min, avg}' | while IFS=" " read -r max min avg
  do
    echo 'nginx_monitoring{domain="'$1'",response="max"}' $max
    echo 'nginx_monitoring{domain="'$1'",response="min"}' $min
    echo 'nginx_monitoring{domain="'$1'",response="avg"}' $avg
  done
}

# Loop through server configuration files (excluding default)
for i in $(find ${config_path} -name "*.conf" | grep -v default); do
  domain=$(grep -ir "server_name" $i | grep -v '#' | awk '{print $NF}' | sed 's/;//g' | grep -v localhost | uniq)
  status_code $domain 2>/dev/null
  response $domain 2>/dev/null
done

