terraform {
  required_version = ">= 1.17"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.69.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5" # écrit l'inventaire Ansible
    }
  }
}

provider "aws" {
  region = var.region

  # Étiquettes ajoutées à toutes les ressources : on retrouve (et on détruit) facilement tout le projet.
  default_tags {
    tags = {
      Projet   = "restaurant-api"
      GereePar = "terraform"
    }
  }
}
