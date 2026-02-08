#リージョン指定
provider "aws" {
  region = "ap-northeast-1"
}

#VPC
resource "aws_vpc" "terraform_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name = "terraform-study-vpc"
  }
}
#Internet GateWay
resource "aws_internet_gateway" "terraform_gw" {
  vpc_id = aws_vpc.terraform_vpc.id

  tags = {
    Name = "terraform-study-ig"
  }
}
#Subnet
resource "aws_subnet" "terraform_subnet" {
  vpc_id = aws_vpc.terraform_vpc.id

  for_each = var.terraform_subnets

  availability_zone       = each.value.zone
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = each.value.launch

  tags = {
    Name = each.value.name
  }
}
#Route Table
resource "aws_route_table" "terraform_practice_routetable_public" {
  vpc_id = aws_vpc.terraform_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform_gw.id
  }

  tags = {
    Name = "terraform-study-routetable-public"
  }
}
resource "aws_route_table" "terraform_practice_routetable_private" {
  vpc_id = aws_vpc.terraform_vpc.id

  tags = {
    Name = "terraform-study-routetable-private"
  }
}
#ルートテーブルとサブネットを関連付け
resource "aws_route_table_association" "terraform_association" {
  for_each = var.terraform_subnets # サブネットと同じ数だけループを回す

  # each.key は "public-1a" などが入る
  subnet_id = aws_subnet.terraform_subnet[each.key].id # 作成したサブネットの ID を取得

  # 三項演算子でルートテーブルを切り替える
  # 条件式 ? true_value : false_value
  route_table_id = each.value.is_public ? aws_route_table.terraform_practice_routetable_public.id : aws_route_table.terraform_practice_routetable_private.id
}

#EC2 Security Group
resource "aws_security_group" "terraform_ec2_sg" {
  description = "Security Group for EC2"
  name        = "EC2-SG"
  vpc_id      = aws_vpc.terraform_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.CidrIp_From_Internet]
  }
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.terraform_alb_sg.id] #ALB用のセキュリティグループ
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-study-ec2-sg"
  }
}
#EC2
data "aws_ssm_parameter" "amazonlinux_2" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
resource "aws_instance" "terraform_ec2" {
  availability_zone       = "ap-northeast-1a"
  ami                     = data.aws_ssm_parameter.amazonlinux_2.value
  disable_api_termination = false
  instance_type           = "t3.micro"
  key_name                = var.key_pair_name
  monitoring              = false
  subnet_id               = aws_subnet.terraform_subnet["public-1a"].id
  vpc_security_group_ids  = [aws_security_group.terraform_ec2_sg.id]

  tags = {
    Name = "terraform-study-ec2"
  }
}

resource "aws_instance" "terraform_ec2_2" {
  availability_zone       = "ap-northeast-1a"
  ami                     = data.aws_ssm_parameter.amazonlinux_2.value
  disable_api_termination = false
  instance_type           = "t3.micro"
  key_name                = var.key_pair_name
  monitoring              = false
  subnet_id               = aws_subnet.terraform_subnet["public-1a"].id
  vpc_security_group_ids  = [aws_security_group.terraform_ec2_sg.id]

  tags = {
    Name = "terraform-study-ec2-2"
  }
}

#ALB Security Group
resource "aws_security_group" "terraform_alb_sg" {
  description = "Security Group for ALB"
  name        = "ALB-SG"
  vpc_id      = aws_vpc.terraform_vpc.id

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
    Name = "terraform-study-alb-sg"
  }
}
#ALB
resource "aws_lb" "terraform_alb" {
  name               = "aws-study-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.terraform_alb_sg.id]
  subnets            = [aws_subnet.terraform_subnet["public-1a"].id, aws_subnet.terraform_subnet["public-1c"].id]
  ip_address_type    = "ipv4"

  tags = {
    Name = "terraform-study-alb"
  }
}
#ALB Target Group
resource "aws_lb_target_group" "terraform_alb_tg" {
  name        = "aws-study-alb-tg"
  target_type = "instance"
  port        = 8080
  protocol    = "HTTP"

  vpc_id = aws_vpc.terraform_vpc.id

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
#Targets
resource "aws_lb_target_group_attachment" "terraform_target_ec2" {
  target_group_arn = aws_lb_target_group.terraform_alb_tg.arn
  target_id        = aws_instance.terraform_ec2.id
  port             = 8080
}
#ALB Listener
resource "aws_lb_listener" "terraform_alb_listener" {
  load_balancer_arn = aws_lb.terraform_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terraform_alb_tg.arn
  }
}

#RDS Subnet Group
resource "aws_db_subnet_group" "terraform_db_subnet_group" {
  name       = "terraform-study-db-subnet-group"
  subnet_ids = [aws_subnet.terraform_subnet["private-1a"].id, aws_subnet.terraform_subnet["private-1c"].id]

  tags = {
    Name = "terraform-study-db-subnet-group"
  }
}
#RDS Security Group
resource "aws_security_group" "terraform_rds_sg" {
  description = "Security Group for RDS"
  name        = "RDS-SG"
  vpc_id      = aws_vpc.terraform_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.terraform_ec2_sg.id]
  }

  tags = {
    Name = "terraform-study-rds-sg"
  }
}
#RDS
resource "aws_db_instance" "terraform_rds" {
  allocated_storage           = 20
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  availability_zone           = "ap-northeast-1a"
  backup_retention_period     = 1
  db_name                     = "rdsstudy"
  db_subnet_group_name        = aws_db_subnet_group.terraform_db_subnet_group.name
  engine                      = "mysql"
  engine_version              = "8.0.43"
  instance_class              = "db.t4g.micro"
  username                    = var.RDS_Master_User_Name
  password                    = var.RDS_Master_User_Password
  publicly_accessible         = false
  storage_type                = "gp2"
  vpc_security_group_ids      = [aws_security_group.terraform_rds_sg.id]
  skip_final_snapshot         = true

  tags = {
    Name = "terraform-study-rds"
  }
}

#SNS Topic
resource "aws_sns_topic" "sns_topic_ec2" {
  display_name = "EC2 Monitoring Notifications"
  name         = "EC2-CPU-Alarm-Topic"
}
#SNS Subscription
resource "aws_sns_topic_subscription" "sns_subscription_ec2" {
  topic_arn = aws_sns_topic.sns_topic_ec2.arn
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
    InstanceId = aws_instance.terraform_ec2.id
  }
  actions_enabled = true
  alarm_actions   = [aws_sns_topic.sns_topic_ec2.arn]
}

#WAF
resource "aws_wafv2_web_acl" "terraform_alb_waf" {
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
  resource_arn = aws_lb.terraform_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.terraform_alb_waf.arn
}

#WAF Log
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "aws-waf-logs-alb-alc"
  retention_in_days = 1
}
resource "aws_wafv2_web_acl_logging_configuration" "waf_log_config" {
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.terraform_alb_waf.arn
}

