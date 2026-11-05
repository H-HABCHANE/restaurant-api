resource "aws_instance" "serveur" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.type_instance
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.serveur.id]
  key_name               = aws_key_pair.deploiement.key_name

  metadata_options {
    http_tokens = "required" # IMDSv2 obligatoire
  }

  root_block_device {
    volume_size = 16 # système + images Docker (Grafana, Prometheus, API) + historique des métriques
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "restaurant-api" }

  lifecycle {
    ignore_changes = [ami] # une nouvelle image Ubuntu ne doit pas remplacer le serveur
  }
}
