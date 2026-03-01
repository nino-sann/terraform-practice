variable "terraform_subnets" {
  type = map(object({
    cidr      = string
    zone      = string
    launch    = bool # 文字列 "true" ではなく 真偽値 bool
    name      = string
    is_public = bool # 文字列 "true" ではなく 真偽値 bool
  }))

  default = {
    public-1a = {
      cidr      = "10.0.1.0/24"
      zone      = "ap-northeast-1a"
      launch    = true
      name      = "terraform-study-public-subnet1"
      is_public = true
    }
    public-1c = {
      cidr      = "10.0.3.0/24"
      zone      = "ap-northeast-1c"
      launch    = true
      name      = "terraform-study-public-subnet2"
      is_public = true
    }
    private-1a = {
      cidr      = "10.0.2.0/24"
      zone      = "ap-northeast-1a"
      launch    = false
      name      = "terraform-study-private-subnet1"
      is_public = false
    }
    private-1c = {
      cidr      = "10.0.4.0/24"
      zone      = "ap-northeast-1c"
      launch    = false
      name      = "terraform-study-private-subnet2"
      is_public = false
    }
  }
}

variable "key_pair_name" {
  description = "Name of an existing EC2 KeyPair to enable SSH access to the instance."
  type        = string
}

variable "CidrIp_From_Internet" {
  description = "CIDR IP range for allowing access from the internet"
  type        = string
  validation {
    condition     = can(regex("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\\/32)$", var.CidrIp_From_Internet))
    error_message = "IPアドレスは必ず 'x.x.x.x/32' の形式で入力してください。0.0.0.0/0は許可されていません。"
  }
}

variable "RDS_Master_User_Name" {
  description = "RDS Master User Name"
  type        = string
}
variable "RDS_Master_User_Password" {
  description = "RDS Master User Password"
  type        = string
  sensitive   = true
}

variable "My_Email_Address" {
  description = "Enter the email address for SNS subscription"
  type        = string
}