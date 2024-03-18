#!/bin/bash

# Source environment variables
source .env

# Install required packages based on the operating system
if [ $(awk -F '=' '/PRETTY_NAME/ { print $2 }' /etc/os-release | awk '{print $1}' | tr -d '"') == "Ubuntu" ]; then
  apt install -y jq xinetd
  systemctl enable --now xinetd
elif [ $(awk -F '=' '/PRETTY_NAME/ { print $2 }' /etc/os-release | awk '{print $1}' | tr -d '"') == "Centos" ]; then
  yum install -y jq xinetd
else
  echo please install jq, xinetd
  systemctl enable --now xinetd
fi

# Add custom log format to nginx.conf if not exists
if grep -q 'log_format prometheus' $nginx_conf_path ; then
  echo log_format are exist
else
  get_line_number=$(cat -n $nginx_conf_path | grep 'http {' | awk '{print $1}')
  get_line_number=$(($get_line_number+1))
  sed -i ''${get_line_number}'i\    log_format prometheus \x27{"date":"$time_iso8601","domain":"$server_name","location":"$request_uri","status":"$status","method":"$request_method","resptime":"$request_time"}\x27;' $nginx_conf_path
fi

# Add custom log to nginx config paths
for i in $(find ${config_path} -name "*.conf" | grep -v default); do
  if [ $(cat $i | grep access_log | grep  prometheus | wc -l) -ne $(cat $i | grep 'location ' | wc -l) ]  ; then
    numb=1
    sed -i '/^    access_log.*prometheus;$/d' $i
    for j in $(cat -n $i | grep 'location ' | awk '{print $1}'); do
      get_line_number=$(($j+$numb))
      sed -i ''${get_line_number}'i\    access_log '${log_path_write}' prometheus;' $i
      numb=$(($numb+1))
    done
  fi
done

# Reload nginx configuration
$reload_command_nginx

# Adjust file paths in scripts
sed -i 's@  server = ./httpwrapper@  server = '$PWD'/httpwrapper@g' ./loadscript
sed -i "s@root='./'@root='$PWD/'@g" ./httpwrapper
sed -i "s@file='./nginx-script-wrapper.sh'@file='$PWD/nginx-script-wrapper.sh'@g" ./httpwrapper

# Copy loadscript to xinetd directory and restart xinetd service
cp ./loadscript /etc/xinetd.d/loadscript
systemctl restart xinetd

# Generate JSON files for Grafana dashboard
counter=1
y_counter=0
for i in $(find ${config_path} -name "*.conf" | grep -v default); do
  domain=$(grep -ir "server_name" $i | grep -v '#' | awk '{print $NF}' | sed 's/;//g' | grep -v localhost | uniq)
  cat dashboard/stscode_sample.json | sed 's/ID_SET_HERE/'${counter}'/g' | sed 's/DOMAIN_SET_HERE/'${domain}'/g' | sed 's/X_SET_HERE/0/g' | sed 's/Y_SET_HERE/'${y_counter}'/g' > status_code_${domain}.json
  let counter=$counter+1
  cat dashboard/response_sample.json | sed 's/ID_SET_HERE/'${counter}'/g' | sed 's/DOMAIN_SET_HERE/'${domain}'/g' | sed 's/X_SET_HERE/12/g' | sed 's/Y_SET_HERE/'${y_counter}'/g' > response_time_${domain}.json
  let counter=$counter+1
  let y_counter=$y_counter+8
done

# Concatenate JSON files into dashboard.json
cat dashboard/header.json response_time_* status_code_* dashboard/footer.json > dashboard.json
fixed_json=$(cat dashboard.json | wc -l)
let fixed_json=fixed_json-21
sed -i "${fixed_json}s/.*/    }/" dashboard.json
rm -rf status_code_*
rm -rf response_time_*

# Set up log retention cron job
echo '
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

'${log_truncate_cron}' root truncate -s 1024 '${log_path_read}'
' > /etc/cron.d/prometheus-nginx-log-retention

# Display setup instructions
echo '
#########
Upload dashboard.json in Grafana dashboard
#########
Set this configuration in prometheus.yml then restart prometheus service
  - job_name: "nginx_script"
    static_configs:
      - targets: ["<ip_address>:4444"]
#########
'
