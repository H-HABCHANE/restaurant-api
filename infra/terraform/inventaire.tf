# Terraform connaît l'IP du serveur : il écrit lui-même l'inventaire Ansible (fichier non versionné).
resource "local_file" "inventaire_ansible" {
  filename             = "${path.module}/../ansible/inventaire.ini"
  file_permission      = "0644"
  directory_permission = "0755"
  content              = <<-EOT
    # Généré par infra/terraform/inventaire.tf : ne pas modifier à la main.
    [serveurs]
    restaurant ansible_host=${aws_instance.serveur.public_ip}

    [serveurs:vars]
    ansible_user=ubuntu
    ansible_ssh_private_key_file=~/.ssh/cle-ansible
  EOT
}
