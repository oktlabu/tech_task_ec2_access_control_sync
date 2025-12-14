# tech_task_ec2_access_control_sync
Harden and automate network access to a public web server on AWS while preserving open SSH access for emergency use.

Simple bash script to sync EC2 Security Group HTTP (80) rules.

What it does:
- allows all Cloudflare IPv4 ranges
- allows my home IP (/32)
- removes any other IPs from port 80
- does not touch SSH or other ports

---

## EC2 metadata

The script uses the EC2 Instance Metadata Service (IMDSv2) at `169.254.169.254`
to automatically detect runtime information:

- AWS region
- instance identity
- IAM role credentials (via STS)

This avoids hardcoding region or credentials and allows the script
to run on any EC2 instance with the required IAM permissions.

---

## How to run

```bash
chmod +x sync_sg.sh
./sync_sg.sh <your_home_ip>
```
Example:

I retrieved my current public IP by querying an external service (api.ipify.org) that returns the source IP of the request.

```bash
# on your pc/laptop
curl -s https://api.ipify.org
```
```bash
./sync_sg.sh 12.123.12.123
```

## Tests
1. Access via Cloudflare
```bash
curl -I http://2bcloud.io
```

2. Direct access to origin
```bash
# on your pc/laptop
curl -I http://1.2.3.4 -H "Host: 2bcloud.io"  # public ip of your machine
```