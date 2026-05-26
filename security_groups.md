# Security Groups — Altrodav DevOps Assignment
## AWS Region: ap-south-1 (Mumbai)

---

## 1. ALB Security Group (alb-sg)
**Purpose:** Controls traffic to the Application Load Balancer

| Type    | Protocol | Port | Source      | Description          |
|---------|----------|------|-------------|----------------------|
| Ingress | TCP      | 80   | 0.0.0.0/0   | HTTP from internet   |
| Egress  | All      | All  | 0.0.0.0/0   | All outbound traffic |

---

## 2. EC2 Security Group (ec2-sg)
**Purpose:** Controls traffic to the WebServer EC2 instance

| Type    | Protocol | Port | Source        | Description                  |
|---------|----------|------|---------------|------------------------------|
| Ingress | TCP      | 3000 | alb-sg        | App traffic from ALB only    |
| Ingress | TCP      | 22   | 0.0.0.0/0     | SSH access for management    |
| Egress  | All      | All  | 0.0.0.0/0     | All outbound traffic         |

---

## 3. RDS Security Group (rds-sg)
**Purpose:** Controls traffic to the PostgreSQL RDS instance

| Type    | Protocol | Port | Source   | Description                    |
|---------|----------|------|----------|--------------------------------|
| Ingress | TCP      | 5432 | ec2-sg   | PostgreSQL from EC2 only       |
| Egress  | All      | All  | 0.0.0.0/0| All outbound traffic           |

---

## Security Design Principles

- **ALB** accepts HTTP traffic on port 80 from the public internet only
- **EC2** accepts app traffic on port 3000 from ALB security group only (not public)
- **RDS** accepts database traffic on port 5432 from EC2 security group only (not public)
- **RDS** is placed in a private subnet with no public IP — completely isolated from internet
- **No direct public access** to EC2 app port or RDS from internet
- Security groups reference each other (not CIDR blocks) for tighter control

---

## Traffic Flow

```
Internet
    |
    | HTTP :80
    v
ALB (alb-sg) — public subnet
    |
    | HTTP :3000
    v
EC2 (ec2-sg) — public subnet
    |
    | PostgreSQL :5432
    v
RDS (rds-sg) — private subnet (isolated)
```

---

## Resource Details

| Resource | Security Group | VPC            | Subnet Type |
|----------|---------------|----------------|-------------|
| ALB      | alb-sg        | MainVPC        | Public      |
| EC2      | ec2-sg        | MainVPC        | Public      |
| RDS      | rds-sg        | MainVPC        | Private     |

---

## Notes
- RDS is **not publicly accessible** (`publicly_accessible = false`)
- RDS resides in **private subnets** (10.0.3.0/24, 10.0.4.0/24)
- EC2 can only receive app traffic through ALB — direct access blocked
- All resources share the same VPC (10.0.0.0/16) for internal communication
