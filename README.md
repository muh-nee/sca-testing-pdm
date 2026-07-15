# Network overhead measurement

See https://datadoghq.atlassian.net/wiki/spaces/DSCVR/pages/4678811677 for an example of usage.

Run the `overhead.sh` on your target EC2 host. It will run the agent in
different configurations (the agent is assumed to be already installed) and run
the ApacheBench command above. Each configuration is tested multiple times.

Copy the logs directory to your local host and run the `overhead.py` script to
analyse the logs and generate graphs.

```
rsync -rav ubuntu@172.29.250.50:logs .
pdm install
pdm run overhead.py
```
