data "aws_ami" "ami" {
  most_recent = true
  name_regex  = "centos-8-ansible-image"
  owners      = ["self"]
}

#data "template_file" "userdata" {
#  template = file("${path.module}/userdata.sh")
#  vars = {
#    component = var.component
#    env = var.env
#  }
#}

data "aws_caller_identity" "account" {}

data "aws_route53_zone" "domain" {
  name         = var.dns_domain
}