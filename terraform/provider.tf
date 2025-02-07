provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = {
      Creator     = "Andrei Lesi",
      Environment = "Workshop"
      Project     = "ServerlessDeveloperExperience"
    }
  }
}

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}