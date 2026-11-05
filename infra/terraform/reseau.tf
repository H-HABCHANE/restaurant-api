# Réseau : un VPC, un sous-réseau public, une passerelle Internet.

resource "aws_vpc" "principal" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "vpc-restaurant" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.principal.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.zones.names[0]
  map_public_ip_on_launch = true # chaque serveur reçoit une IP publique
  tags                    = { Name = "subnet-public-restaurant" }
}

# La porte du VPC vers Internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.principal.id
  tags   = { Name = "igw-restaurant" }
}

# Le panneau indicateur : « tout ce qui ne va pas dans le VPC → la porte Internet »
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.principal.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "rt-public-restaurant" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
