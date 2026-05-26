# Security Groups Documentation
**Altrodav Technologies — DevOps Task 1**

---

## Overview

Three security groups, one per tier. Zero-trust chain — each tier only accepts traffic from the tier directly above it.

```
Internet → [SG-ALB] → [SG-EC2] → [SG-RDS]
```

---

## SG-ALB — Application Load Balancer

| Direction | Port | Protocol | Source | Reason |
|---|---|---|---|---|
| Inbound | 80 | TCP | 0.0.0.0/0 | HTTP from internet (redirected to HTTPS) |
| Inbound | 443 | TCP | 0.0.0.0/0 | HTTPS from internet |
| Outbound | All | All | 0.0.0.0/0 | Forward traffic to EC2 |

---

## SG-EC2 — Node.js App Server

| Direction | Port | Protocol | Source | Reason |
|---|---|---|---|---|
| Inbound | 3000 | TCP | SG-ALB (reference) | App traffic from ALB only — not from internet |
| Inbound | 22 | TCP | 0.0.0.0/0 | SSH management access |
| Outbound | All | All | 0.0.0.0/0 | npm installs, AWS API calls |

> EC2 port 3000 is only reachable via the ALB. No one can hit EC2 directly from the internet.

---

## SG-RDS — PostgreSQL Database

| Direction | Port | Protocol | Source | Reason |
|---|---|---|---|---|
| Inbound | 5432 | TCP | SG-EC2 (reference) | PostgreSQL from EC2 only |
| Outbound | All | All | 0.0.0.0/0 | AWS maintenance |

> RDS has zero internet exposure:
> - `publicly_accessible = false` in Terraform
> - Lives in private subnets with no internet gateway route
> - SG only allows EC2 — no CIDR ranges, no 0.0.0.0/0

---

## Security Design Decisions

**Why SG references instead of IP addresses?**
Using `security_groups = [ec2_sg.id]` in RDS means only actual EC2 instances with that specific SG can connect. Even if someone is inside the VPC, they can't reach RDS unless they're the EC2.

**Why no SSH on EC2 in production?**
Port 22 open to 0.0.0.0/0 is kept for this assessment. In production, restrict to your office IP or use AWS SSM Session Manager (no SSH port needed at all).

**Why is HTTP (80) allowed on ALB?**
So the ALB can receive the request and redirect it to HTTPS with a 301. Without port 80 open, users who type `http://` would get a timeout instead of a redirect.

**Double isolation for RDS:**
Even if SG-RDS was misconfigured, the private subnet has no internet gateway entry — so there's literally no network path from the internet to the database. Defense in depth.
