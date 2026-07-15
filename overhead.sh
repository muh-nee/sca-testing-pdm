#!/bin/bash -ex

set -o pipefail

# There are two version of yq, the default in Ubuntu is not mikefarah's
./yq --version | grep mikefarah || {
	wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O yq
	chmod +x yq
}
./yq --version | grep mikefarah
jq --version || sudo apt install jq
gron --version || sudo apt install gron

server=127.0.0.1

wait_for_npm() {
	while :; do
		curl http://127.0.0.1/
		if sudo curl -s --unix /opt/datadog-agent/run/sysprobe.sock http://unix/network_tracer/connections | gron | grep -m1 laddr; then
			break
		fi
		sleep 1
	done
}

wait_for_usm() {
	while :; do
		curl http://127.0.0.1/
		if sudo curl -s --unix /opt/datadog-agent/run/sysprobe.sock http://unix/network_tracer/debug/http_monitoring | gron | grep -m1 Method; then
			break
		fi
		sleep 1
	done
}

wait_for_discovery() {
	while :; do
		curl http://127.0.0.1/
		sudo curl -s --unix /opt/datadog-agent/run/sysprobe.sock http://unix/discovery/services || :
		if sudo curl -s --unix /opt/datadog-agent/run/sysprobe.sock http://unix/discovery/debug | gron | grep -m1 nginx.*worker; then
			break
		fi
		sleep 1
	done
}

wait_for_discovery_net() {
	while :; do
		curl http://127.0.0.1/
		sudo curl -s --unix /opt/datadog-agent/run/sysprobe.sock http://unix/discovery/services || :
		if sudo curl -s --unix /opt/datadog-agent/run/sysprobe.sock http://unix/discovery/debug | gron | grep rx_bytes | grep -v '= 0;$'; then
			break
		fi
		sleep 1
	done
}

# wait_for_usm

config() {
	opts=$1

	sudo systemctl stop datadog-agent.service
	sudo truncate -s0 /etc/datadog-agent/system-probe.yaml
	if [ ! -z "$opts" ]; then
		sudo ./yq -i "$opts" /etc/datadog-agent/system-probe.yaml
	fi
	sudo cat /etc/datadog-agent/system-probe.yaml
	sudo systemctl start datadog-agent.service
	sleep 10
}

cmd() {
	ab -n 1000 -c 100 http://127.0.0.1/ >/dev/null

	for i in $(seq 5); do
		ab -n 100000 -c 1000 http://127.0.0.1/
	done
}

mkdir -p logs

curl http://$server
curl -k https://$server

for round in $(seq 3); do
	sudo systemctl stop datadog-agent.service
	sleep 10
	cmd | tee -a logs/plain-noagent.txt

	config ''
	cmd | tee -a logs/plain-default.txt

	config '.network_config.enabled = true'
	cmd | tee -a logs/plain-npm.txt
	wait_for_npm
	
	config '.service_monitoring_config.enabled = true'
	wait_for_usm
	cmd | tee -a logs/plain-usm.txt

	config '.service_monitoring_config.enabled = false | .discovery.enabled = true | .discovery.network_stats.enabled = false'
	wait_for_discovery
	cmd | tee -a logs/plain-discovery-nonet.txt
	
	config '.service_monitoring_config.enabled = false | .discovery.enabled = true | .discovery.network_stats.period = "60s"'
	wait_for_discovery
	wait_for_discovery_net
	cmd | tee -a logs/plain-discovery-net.txt
done

sudo systemctl stop datadog-agent.service
