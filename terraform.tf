terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28.0"
    }
  }

  required_version = "= 1.14.3"
}

terraform {
  backend "s3" {
    bucket = "terraform-githubactions-practice"
    key    = "terraform.tfstate" # 保存するファイル名
    region = "ap-northeast-1"
  }
}