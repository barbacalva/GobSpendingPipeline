terraform {
  backend "s3" {
    bucket         = "tfstate-gob-spending-pipeline"
    key            = "dev/terraform.tfstate"
    region         = "eu-west-1"
    use_lockfile = true
    encrypt      = true
    profile = "barbacalva"
  }
}