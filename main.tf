#リージョン指定
provider "aws" {
  region = "ap-northeast-1"
}

#VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name = "terraform-study-vpc"
  }
}
#Internet GateWay
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-study-ig"
  }
}
#Subnet
resource "aws_subnet" "public_private" {
  vpc_id = aws_vpc.main.id

  for_each = var.terraform_subnets

  availability_zone       = each.value.zone
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = each.value.launch

  tags = {
    Name = each.value.name
  }
}
#Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "terraform-study-routetable-public"
  }
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-study-routetable-private"
  }
}
#ルートテーブルとサブネットを関連付け
resource "aws_route_table_association" "public_private" {
  for_each = var.terraform_subnets # サブネットと同じ数だけループを回す

  # each.key は "public-1a" などが入る
  subnet_id = aws_subnet.public_private[each.key].id # 作成したサブネットの ID を取得

  # 三項演算子でルートテーブルを切り替える
  # 条件式 ? true_value : false_value
  route_table_id = each.value.is_public ? aws_route_table.public.id : aws_route_table.private.id
}

#EC2 Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "Security Group for EC2"
  description = "EC2-SG"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "terraform-study-ec2-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.ec2_sg.id

  cidr_ipv4   = var.CidrIp_From_Internet
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "allow_springboot" {
  security_group_id = aws_security_group.ec2_sg.id

  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb_sg.id #ALB用のセキュリティグループ
}
resource "aws_vpc_security_group_egress_rule" "allow_all_ec2" {
  security_group_id = aws_security_group.ec2_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# AnsibleがSSM（Systems Manager）経由でEC2を操作するために必要なIAM設定
# 1.EC2がこのロールを使えるようにする「信頼関係」の設定
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2_ssm_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}
# 2. AWSが用意しているSSM用の標準ポリシーをロールに紐付ける
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# 3. EC2インスタンスにロールを付与するための「プロフィール」作成
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}
#EC2
data "aws_ssm_parameter" "amazonlinux_2" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
resource "aws_instance" "web" {
  availability_zone       = "ap-northeast-1a"
  ami                     = data.aws_ssm_parameter.amazonlinux_2.value
  disable_api_termination = false
  instance_type           = "t3.micro"
  key_name                = var.key_pair_name
  monitoring              = false
  subnet_id               = aws_subnet.public_private["public-1a"].id
  vpc_security_group_ids  = [aws_security_group.ec2_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

  tags = {
    Name = "terraform-study-ec2"
  }
}

#ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "Security Group for ALB"
  description = "ALB-SG"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "terraform-study-alb-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.alb_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "allow_all_alb" {
  security_group_id = aws_security_group.alb_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
#ALB
resource "aws_lb" "main" {
  name               = "aws-study-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_private["public-1a"].id, aws_subnet.public_private["public-1c"].id]
  ip_address_type    = "ipv4"

  tags = {
    Name = "terraform-study-alb"
  }
}
#ALB Target Group
resource "aws_lb_target_group" "web" {
  name        = "aws-study-alb-tg"
  target_type = "instance"
  port        = 8080
  protocol    = "HTTP"

  vpc_id = aws_vpc.main.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200,300,301"
  }

  tags = {
    Name = "terraform-study-alb-tg"
  }
}
#ALBとTargetを紐付ける
resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web.id
  port             = 8080
}
#ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

#RDS Subnet Group
resource "aws_db_subnet_group" "this" {
  name       = "terraform-study-db-subnet-group"
  subnet_ids = [aws_subnet.public_private["private-1a"].id, aws_subnet.public_private["private-1c"].id]

  tags = {
    Name = "terraform-study-db-subnet-group"
  }
}
#RDS Security Group
resource "aws_security_group" "rds_sg" {
  name        = "Security Group for RDS"
  description = "RDS-SG"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "terraform-study-rds-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "allow_ec2_sg" {
  security_group_id = aws_security_group.rds_sg.id

  referenced_security_group_id = aws_security_group.ec2_sg.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}
#RDS
resource "aws_db_instance" "main" {
  allocated_storage           = 20
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  availability_zone           = "ap-northeast-1a"
  backup_retention_period     = 1
  db_name                     = "rdsstudy"
  db_subnet_group_name        = aws_db_subnet_group.this.name
  engine                      = "mysql"
  engine_version              = "8.0.43"
  instance_class              = "db.t4g.micro"
  username                    = var.RDS_Master_User_Name
  password                    = var.RDS_Master_User_Password
  publicly_accessible         = false
  storage_type                = "gp2"
  vpc_security_group_ids      = [aws_security_group.rds_sg.id]
  skip_final_snapshot         = true

  tags = {
    Name = "terraform-study-rds"
  }
}

#SNS Topic
resource "aws_sns_topic" "cpu_alarm" {
  display_name = "EC2 Monitoring Notifications"
  name         = "EC2-CPU-Alarm-Topic"
}
#SNS Subscription
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.cpu_alarm.arn
  protocol  = "email"
  endpoint  = var.My_Email_Address
}
#Cloud Watch Alarm
resource "aws_cloudwatch_metric_alarm" "ALERT_EC2_CPUUtilization" {
  alarm_name          = "EC2-CPUUtilization-Alarm"
  alarm_description   = "Alarm when CPU usage exceeds 70%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  unit                = "Percent"
  dimensions = {
    InstanceId = aws_instance.web.id
  }
  actions_enabled = true
  alarm_actions   = [aws_sns_topic.cpu_alarm.arn]
}

#WAF
resource "aws_wafv2_web_acl" "web_application" {
  name  = "terraform-study-alb-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "aws-study-alb-waf"
    sampled_requests_enabled   = true
  }
}
#ALBにWAFを関連付ける
resource "aws_wafv2_web_acl_association" "alb_waf_attach" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.web_application.arn
}

#WAF Log
resource "aws_cloudwatch_log_group" "web_application_waf" {
  name              = "aws-waf-logs-alb-alc"
  retention_in_days = 1
}
resource "aws_wafv2_web_acl_logging_configuration" "web_application" {
  log_destination_configs = [aws_cloudwatch_log_group.web_application_waf.arn]
  resource_arn            = aws_wafv2_web_acl.web_application.arn
}

resource "aws_s3_bucket" "ansible_ssm_bucket" {
  bucket = "ansible-ssm-practice-raisetech"
}

