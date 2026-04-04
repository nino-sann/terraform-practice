#あるととても便利
output "EC2_Instance" {
  description = "Instance Id of the web server"
  value       = aws_instance.web.id
}
# Ansible用のinventory.iniファイルを自動生成する
resource "local_file" "ansible_inventory" {
  # 生成するファイルのパス（ansibleフォルダの中に出力）
  filename = "${path.module}/ansible/inventory/inventory.ini"
  # ファイルの内容
  content = <<EOT
[web_servers]
${aws_instance.web.id} ansible_aws_ssm_instance_id=${aws_instance.web.id}
EOT
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}
output "RDS_Instance" {
  description = "Endpoint of the RDS Instance"
  value       = aws_db_instance.main.endpoint
}
output "Sns_Topic_EC2" {
  description = "ARN of the SNS Topic"
  value       = aws_sns_topic.cpu_alarm.arn
}

#あると便利
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}
output "Web_ACL" {
  description = "ARN of the WebACL"
  value       = aws_wafv2_web_acl.web_application.arn
}