terraform {
  backend "s3" {
    bucket = "terraformstateremotestoreishods27"
    key = "terraform.tfstate"
    region = "us-west-2"
    encrypt = true    
    dynamodb_table = "terraform-state-lock"
  }
}