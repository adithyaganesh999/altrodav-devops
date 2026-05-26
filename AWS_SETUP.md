# AWS Setup & Deployment Guide
**Altrodav Technologies — DevOps Task 1**

---

## Architecture

```
User Browser
    │  HTTPS :443
    ▼
Application Load Balancer  ←── Public Subnets (10.0.1.0/24, 10.0.2.0/24)
    │  HTTP :3000 (internal)
    ▼
EC2 Instance (Node.js)     ←── Public Subnet (10.0.1.0/24)
    │  PostgreSQL :5432
    ▼
RDS PostgreSQL             ←── Private Subnets (10.0.3.0/24, 10.0.4.0/24)
                                NO internet route — fully isolated
```

CloudWatch monitors EC2 CPU, EC2 Memory, and RDS CPU. Alerts sent via SNS email.

---

## Prerequisites

| Tool | Install |
|---|---|
| AWS CLI v2 | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |
| Terraform ≥ 1.5 | https://developer.hashicorp.com/terraform/install |
| AWS Account | With admin or scoped IAM access |

---

## Step 1 — Configure AWS CLI

```bash
aws configure
# Enter your Access Key, Secret Key, region: ap-south-1, output: json

# Test it works
aws sts get-caller-identity
```

---

## Step 2 — Get an SSL Certificate (for HTTPS)

1. Go to AWS Console → Certificate Manager (ACM)
2. Click "Request a certificate" → Public certificate
3. Enter your domain name (e.g. app.example.com)
4. Choose DNS validation → click Request
5. Copy the Certificate ARN → paste into `terraform.tfvars`

---

## Step 3 — Fill in Your Values

```bash
# Edit terraform.tfvars
nano terraform/terraform.tfvars

# Set these 3 values:
# db_password         = "YourPassword123!"
# alert_email         = "you@gmail.com"
# acm_certificate_arn = "arn:aws:acm:ap-south-1:..."
```

---

## Step 4 — Run Terraform

```bash
cd terraform/

# Download AWS plugin (run once)
terraform init

# Preview what will be created (~25 resources)
terraform plan

# Build everything on AWS
terraform apply
# Type: yes

# Wait 15-20 minutes...
```

---

## Step 5 — Confirm Email Subscription

After apply finishes, AWS sends a confirmation email to your `alert_email`.
Click the **Confirm subscription** link — otherwise CloudWatch alerts won't reach you.

---

## Step 6 — Test Your App

```bash
# Terraform prints this after apply:
# loadbalancer_dns = "myalb-xxxxx.ap-south-1.elb.amazonaws.com"

# Test in browser or terminal:
curl http://<loadbalancer_dns>
# Should show: Altrodav Node App is Running!

curl http://<loadbalancer_dns>/health
# Should show: OK
```

---

## Step 7 — Tear Down (to save cost)

```bash
terraform destroy
# Type: yes
# All AWS resources deleted. No charges after this.
```
# Note
Route53 DNS configuration is outside scope for this assessment as it requires an owned domain. The ALB DNS name is used directly for testing.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `terraform init` fails | Check internet. Run `aws configure` first |
| ALB shows 502 | EC2 app not running. SSH in and check `pm2 status` |
| RDS connection refused | Normal — RDS only reachable from EC2, not internet |
| No alert emails | Confirm the SNS subscription in your email inbox |
| Certificate error | Make sure ACM cert is in ap-south-1 (same region) |
