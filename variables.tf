variable "myami" {}

variable "mykeypair" {}

variable "aws_region" {}

variable "instance_type" {}

variable "tag" {}

variable "project_name" {}

variable "num" {}

variable "subnet_name" {}

variable "realestate-sg" {}

variable "user" {}
variable "allowed_ports" {}
variable "cidr_vpc" {}
variable "cidr_subnet" {}
variable "cidr_subnet_2" {}
variable "zones" {
   type    = list(string)
  default = ["a", "b"] 
}
variable "github_token" {}

/* 
variable "aws_access_key" {
  description = "AWS access key"
}

variable "aws_secret_key" {
  description = "AWS secret key"
}
*/
