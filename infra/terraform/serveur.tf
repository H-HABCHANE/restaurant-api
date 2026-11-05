resource "aws_instance" "serveur" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.type_instance
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.serveur.id]
  key_name               = aws_key_pair.deploiement.key_name

  # Par défaut, une t3 est en crédits CPU « unlimited » : un usage soutenu au-delà des crédits est facturé.
  # « standard » : au pire la machine est ralentie, jamais de surplus sur la facture.
  credit_specification {
    cpu_credits = "standard"
  }

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
