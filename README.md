# Nginx Monitoring Dashboad Generate for Grafana  
Automatically generate a Grafana dashboard to visualize Nginx metrics, including HTTP method counters status code(like GET(2xx,4xx,5xx), POST(2xx,4xx,5xx) and etc), response times (average, maximum, and minimum) for each domain served.  

## Features:  
* Extracts metrics from Nginx logs using a custom format  
* Generates a Grafana dashboard with panels for each domain  
* Displays key metrics:  
    * Method calls  
    * Response times (average, max, min)  
    * Status code counts  
* Integrates with Prometheus for data collection and storage  
## Requirements:  
* Nginx  
* Grafana  
* Prometheus  

## Installation:  
Clone this repository:  
```Bash
https://github.com/arashkhavari/generate_grafana_nginx_dashboard.git  
```
Use code with caution.  
Edit the ```.env``` file with your Nginx configuration paths and other settings.  
Run the setup script:  
```Bash
./nginx-build-monitoring.sh
```
Use code with caution.  
Import the generated dashboard.json file into Grafana.  
Configure Prometheus to scrape metrics from the script's endpoint:  

```YAML
- job_name: "nginx_script"
  static_configs:
    - targets: ["<ip_address>:4444"]
```
Use code with caution.  

## Usage:  
Access the Grafana dashboard to view the metrics.  
The dashboard will automatically update as new data is collected.  

## Additional Information:  
The scripts in this repository are compatible with Ubuntu and CentOS distributions.  
The xinetd service is used to expose the metrics endpoint for Prometheus.  
A log retention cron job is configured to keep the Nginx log file at a manageable size.  

## Contribution:  
Contributions and suggestions are welcome! Please feel free to open issues or pull requests.  
