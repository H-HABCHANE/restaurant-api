# Le videur : HTTP (l'API) pour tout le monde, SSH seulement depuis mon IP.
# Prometheus (9090) et Grafana (3000) ne sont PAS ouverts : accès par tunnel SSH.
resource "aws_security_group" "serveur" {
  name        = "restaurant-api"
  description = "API en HTTP public, SSH depuis mon IP"
  vpc_id      = aws_vpc.principal.id
  tags        = { Name = "restaurant-api" }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.serveur.id
  description       = "SSH depuis mon IP seulement"
  cidr_ipv4         = var.mon_ip
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.serveur.id
  description       = "API publique en HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "tout" {
  security_group_id = aws_security_group.serveur.id
  description       = "Sortie : paquets apt et images Docker" # pas d'accents : refusés par AWS ici
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Seule la clé PUBLIQUE part chez AWS ; la privée ne quitte jamais le PC.
resource "aws_key_pair" "deploiement" {
  key_name   = "restaurant-api"
  public_key = file(pathexpand("~/.ssh/cle-ansible.pub"))
}
