run "check_vpc_cidr_block" {

  command = plan

  assert {
    condition     = aws_vpc.terraform_vpc.cidr_block == "10.0.0.0/16"
    error_message = "VPC cidr block did not match expected"
  }

}

run "check_subnets_config" {
  command = plan

  # すべてのサブネットをまとめてループでテストする
  assert {
    condition = alltrue([
      for key, sub in var.terraform_subnets : 
      aws_subnet.terraform_subnet[key].cidr_block == sub.cidr &&
      aws_subnet.terraform_subnet[key].availability_zone == sub.zone
    ])
    error_message = "サブネットの CIDR または AZ 設定が変数定義と一致しません。"
  }

}

run "check_ec2_availability_zone" {

  command = plan

  assert {
    condition     = aws_instance.terraform_ec2.availability_zone == "ap-northeast-1a"
    error_message = "Instance type did not match expected"
  }

}

run "check_ec2_instance_type" {

  command = plan

  assert {
    condition     = aws_instance.terraform_ec2.instance_type == "t3.micro"
    error_message = "Instance type did not match expected"
  }

}

run "check_rds_availability_zone" {

  command = plan

  assert {
    condition     = aws_db_instance.terraform_rds.availability_zone == "ap-northeast-1a"
    error_message = "Availability zone did not match expected"
  }

}

run "check_rds_instance_class" {

  command = plan

  assert {
    condition     = aws_db_instance.terraform_rds.instance_class == "db.t4g.micro"
    error_message = "Instance class did not match expected"
  }

}

run "check_rds_engine" {

  command = plan

  assert {
    condition     = aws_db_instance.terraform_rds.engine == "mysql"
    error_message = "Engine did not match expected"
  }

}
