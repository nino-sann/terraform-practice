#あるととても便利
output "EC2_Instance" {
  description = "Instance Id of the web server"
  value       = aws_instance.terraform_ec2.id
}
# Ansible用のinventory.iniファイルを自動生成する
resource "local_file" "ansible_inventory" {
  # 生成するファイルのパス（ansibleフォルダの中に出力）
  filename = "${path.module}/ansible/inventory/inventory.ini"
  # ファイルの内容
  content = <<EOT
[web_servers]
${aws_instance.terraform_ec2.id}
EOT
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