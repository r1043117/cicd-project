from flask import Flask, render_template, jsonify
import requests
import os
from datetime import datetime
import subprocess

app = Flask(__name__)

# Configuration
PROMETHEUS_URL = os.environ.get('PROMETHEUS_URL', 'http://localhost:9090')
APP_VERSION = os.environ.get('APP_VERSION', '2.0.0')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'production')

def query_prometheus(query):
    """Query Prometheus and return results"""
    try:
        url = f"{PROMETHEUS_URL}/api/v1/query"
        response = requests.get(url, params={'query': query}, timeout=5)
        data = response.json()
        if data['status'] == 'success' and data['data']['result']:
            return data['data']['result']
        return []
    except Exception as e:
        print(f"Prometheus query error: {e}")
        return []

def get_metric_value(result, default=0):
    """Extract value from Prometheus result"""
    try:
        if result and len(result) > 0:
            return float(result[0]['value'][1])
        return default
    except:
        return default

@app.route('/')
def index():
    """Main dashboard"""
    
    # Get VM metrics
    vm1_cpu = query_prometheus('100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle",instance="vm1-app-server"}[5m])) * 100)')
    vm1_memory = query_prometheus('(node_memory_MemTotal_bytes{instance="vm1-app-server"} - node_memory_MemAvailable_bytes{instance="vm1-app-server"}) / node_memory_MemTotal_bytes{instance="vm1-app-server"} * 100')
    vm1_disk = query_prometheus('(node_filesystem_size_bytes{instance="vm1-app-server",mountpoint="/"} - node_filesystem_free_bytes{instance="vm1-app-server",mountpoint="/"}) / node_filesystem_size_bytes{instance="vm1-app-server",mountpoint="/"} * 100')
    
    vm2_cpu = query_prometheus('100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle",instance="vm2-jenkins"}[5m])) * 100)')
    vm2_memory = query_prometheus('(node_memory_MemTotal_bytes{instance="vm2-jenkins"} - node_memory_MemAvailable_bytes{instance="vm2-jenkins"}) / node_memory_MemTotal_bytes{instance="vm2-jenkins"} * 100')
    vm2_disk = query_prometheus('(node_filesystem_size_bytes{instance="vm2-jenkins",mountpoint="/"} - node_filesystem_free_bytes{instance="vm2-jenkins",mountpoint="/"}) / node_filesystem_size_bytes{instance="vm2-jenkins",mountpoint="/"} * 100')
    
    # Get Docker container count
    containers = query_prometheus('count(container_last_seen{image!=""})')
    
    # Build metrics object
    metrics = {
        'vm1': {
            'cpu': round(get_metric_value(vm1_cpu), 1),
            'memory': round(get_metric_value(vm1_memory), 1),
            'disk': round(get_metric_value(vm1_disk), 1),
            'status': 'healthy' if vm1_cpu else 'unknown'
        },
        'vm2': {
            'cpu': round(get_metric_value(vm2_cpu), 1),
            'memory': round(get_metric_value(vm2_memory), 1),
            'disk': round(get_metric_value(vm2_disk), 1),
            'status': 'healthy' if vm2_cpu else 'unknown'
        },
        'containers': int(get_metric_value(containers, 0)),
        'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    }
    
    # Pipeline status
    pipeline = {
        'version': APP_VERSION,
        'environment': ENVIRONMENT,
        'deployed_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'github': 'Connected',
        'jenkins': 'Running',
        'ansible': 'Configured',
        'docker': 'Active'
    }
    
    return render_template('simple_dashboard.html', metrics=metrics, pipeline=pipeline)

@app.route('/api/metrics')
def api_metrics():
    """API endpoint for real-time metrics"""
    vm1_cpu = query_prometheus('100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle",instance="vm1-app-server"}[5m])) * 100)')
    vm1_memory = query_prometheus('(node_memory_MemTotal_bytes{instance="vm1-app-server"} - node_memory_MemAvailable_bytes{instance="vm1-app-server"}) / node_memory_MemTotal_bytes{instance="vm1-app-server"} * 100')
    
    vm2_cpu = query_prometheus('100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle",instance="vm2-jenkins"}[5m])) * 100)')
    vm2_memory = query_prometheus('(node_memory_MemTotal_bytes{instance="vm2-jenkins"} - node_memory_MemAvailable_bytes{instance="vm2-jenkins"}) / node_memory_MemTotal_bytes{instance="vm2-jenkins"} * 100')
    
    containers = query_prometheus('count(container_last_seen{image!=""})')
    
    return jsonify({
        'vm1': {
            'cpu': round(get_metric_value(vm1_cpu), 1),
            'memory': round(get_metric_value(vm1_memory), 1)
        },
        'vm2': {
            'cpu': round(get_metric_value(vm2_cpu), 1),
            'memory': round(get_metric_value(vm2_memory), 1)
        },
        'containers': int(get_metric_value(containers, 0)),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'version': APP_VERSION,
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=(ENVIRONMENT != 'production'))
