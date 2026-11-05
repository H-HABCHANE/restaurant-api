output "compte" {
  description = "Identité utilisée par Terraform"
  value       = data.aws_caller_identity.moi.arn
}

output "ip_publique" {
  description = "Adresse publique du serveur"
  value       = aws_instance.serveur.public_ip
}

output "api" {
  description = "URL publique de l'API"
  value       = "http://${aws_instance.serveur.public_ip}/health"
}

output "tunnel_supervision" {
  description = "Tunnel SSH vers Grafana (localhost:3000) et Prometheus (localhost:9090)"
  value       = "ssh -i ~/.ssh/cle-ansible -N -L 3000:localhost:3000 -L 9090:localhost:9090 ubuntu@${aws_instance.serveur.public_ip}"
}
