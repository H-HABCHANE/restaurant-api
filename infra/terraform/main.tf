# Lectures seules (data sources) : identité, zones, image Ubuntu.

# Qui suis-je ? (même information que « aws sts get-caller-identity »)
data "aws_caller_identity" "moi" {}

# Les zones de disponibilité de la région (des datacenters séparés)
data "aws_availability_zones" "zones" {
  state = "available"
}

# La dernière image Ubuntu 24.04 officielle (publiée par Canonical, compte 099720109477)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}
