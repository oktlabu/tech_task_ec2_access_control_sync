# tech_task_ec2_access_control_sync
Harden and automate network access to a public web server on AWS while preserving open SSH access for emergency use.

Simple bash script to sync EC2 Security Group HTTP (80) rules.

What it does:
- allows all Cloudflare IPv4 ranges
- allows my home IP (/32)
- removes any other IPs from port 80
- does not touch SSH or other ports

---

## How to run

```bash
chmod +x sync_sg.sh
./sync_sg.sh <your_home_ip>
```
Example:
./sync_sg.sh 91.185.26.179

## Tests
1. Access via Cloudflare
```bash
curl -I http://2bcloud.io
```

2. Direct access to origin
```bash

curl -I http://1.2.3.4 -H "Host: 2bcloud.io"  # public ip of your machine
```