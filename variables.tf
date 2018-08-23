variable "amis" {
  description = "ami for RHEL 7.5 in different regions"
  default = {
    "us-west-1" = "ami-18726478"
    "us-west-2" = "ami-28e07e50"
    "us-east-1" = "ami-6871a115"
    "us-east-2" = "ami-03291866"
  }
}

variable "zone_id" {
  default = "ZG1LSIRFXEMSJ"
}

variable "dns_prefix" {
  description = "DNS prefix for instances"
  default = ".demo.li9.com"  
}

variable "instance_type" {
  # default = "t2.micro"
  # default = "t2.medium"
  default = "t2.large"
  # default = "t2.2xlarge"
}

variable "region" {
  default = "us-west-2"
}

variable "zones" {
  default = ["a", "b", "c"]
}

variable "private_subnets" {
  default = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnets" {
  default = ["10.0.3.0/24","10.0.4.0/24","10.0.5.0/24"]
}

variable "key_name" {
  default = "ocp-keys"
}

variable "ssh_keys" {
  default = ["~/.ssh/id_rsa","~/.ssh/id_rsa.pub"]
}

variable "username" {
  default = "ec2-user"
}
