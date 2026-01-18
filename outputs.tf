#あるととても便利
output "EC2_Instance" {
  description = "Instance Id of the web server"
  value       = aws_instance.terraform_ec2.id
}
output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.terraform_alb.dns_name
}
output "RDS_Instance" {
  description = "Endpoint of the RDS Instance"
  value       = aws_db_instance.terraform_rds.endpoint
}
output "Sns_Topic_EC2" {
  description = "ARN of the SNS Topic"
  value       = aws_sns_topic.sns_topic_ec2.arn
}

#あると便利
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.terraform_vpc.id
}
output "Web_ACL" {
  description = "ARN of the WebACL"
  value       = aws_wafv2_web_acl.terraform_alb_waf.arn
}