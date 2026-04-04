run "check_vpc_cidr_block" {

  command = plan

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC cidr block did not match expected"
  }

}

run "check_subnets_config" {
  command = plan

  # すべてのサブネットをまとめてループでテストする
  assert {
    condition = alltrue([
      for key, sub in var.terraform_subnets :
      aws_subnet.public_private[key].cidr_block == sub.cidr &&
      aws_subnet.public_private[key].availability_zone == sub.zone
    ])
    error_message = "サブネットの CIDR または AZ 設定が変数定義と一致しません。"
  }

}

run "check_ec2_availability_zone" {

  command = plan

  assert {
    condition     = aws_instance.web.availability_zone == "ap-northeast-1a"
    error_message = "Instance type did not match expected"
  }

}

run "check_ec2_instance_type" {

  command = plan

  assert {
    condition     = aws_instance.web.instance_type == "t3.micro"
    error_message = "Instance type did not match expected"
  }

}

run "check_rds_availability_zone" {

  command = plan

  assert {
    condition     = aws_db_instance.main.availability_zone == "ap-northeast-1a"
    error_message = "Availability zone did not match expected"
  }

}

run "check_rds_instance_class" {

  command = plan

  assert {
    condition     = aws_db_instance.main.instance_class == "db.t4g.micro"
    error_message = "Instance class did not match expected"
  }

}

run "check_rds_engine" {

  command = plan

  assert {
    condition     = aws_db_instance.main.engine == "mysql"
    error_message = "Engine did not match expected"
  }
}
