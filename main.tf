terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "MainVPC"
  }
}

resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Publicsub1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "Publicsub2"
  }
}

resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "Privatesub1"
  }
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "Privatesub2"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "InternetGW"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public1.id
  depends_on    = [aws_internet_gateway.gw]
  tags = {
    Name = "nat-gateway"
  }
}

resource "aws_route_table" "Publicroute" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "PubRoute"
  }
}

resource "aws_route_table_association" "RTAPublic1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.Publicroute.id
}

resource "aws_route_table_association" "RTAPublic2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.Publicroute.id
}

resource "aws_route_table" "PrivateRoute" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "PrivateRoute"
  }
}

resource "aws_route_table_association" "RTAPrivate1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.PrivateRoute.id
}

resource "aws_route_table_association" "RTAPrivate2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.PrivateRoute.id
}

resource "aws_security_group" "alb" {
  name   = "alb-sg"
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "alb-sg"
  }
}

resource "aws_security_group" "ec2" {
  name   = "ec2-sg"
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ec2-sg"
  }
}

resource "aws_security_group" "rds" {
  name   = "rds-sg"
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "rds-sg"
  }
}

resource "aws_instance" "web" {
  ami                    = "ami-0f58b397bc5c1f2e8"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public1.id
  key_name               = "project"
  vpc_security_group_ids = [aws_security_group.ec2.id]
  user_data              = file("userdata.sh")
  tags = {
    Name = "WebServer"
  }
}

resource "aws_lb" "appalb" {
  name               = "appalb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets = [
    aws_subnet.public1.id,
    aws_subnet.public2.id
  ]
  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "tg" {
  name     = "tf-example-lb-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
  health_check {
    path = "/"
    port = "traffic-port"
  }
  tags = {
    Name = "AppTargetGroup"
  }
}

resource "aws_lb_target_group_attachment" "attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web.id
  port             = 3000
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.appalb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_db_subnet_group" "rds_subnet" {
  name = "rds-subnet-group"
  subnet_ids = [
    aws_subnet.private1.id,
    aws_subnet.private2.id
  ]
  tags = {
    Name = "RDSSubnetGroup"
  }
}

resource "aws_db_instance" "postgres" {
  allocated_storage       = 20
  engine                  = "postgres"
  engine_version          = "15"
  instance_class          = "db.t3.micro"
  db_name                 = "mydb"
  username                = "postgres"
  password                = var.db_password
  backup_retention_period = 1
  publicly_accessible     = false
  skip_final_snapshot     = true
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  tags = {
    Name = "PostgresRDS"
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "high-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EC2 CPU high"
  dimensions = {
    InstanceId = aws_instance.web.id
  }
}

output "alb_dns" {
  value = aws_lb.appalb.dns_name
}