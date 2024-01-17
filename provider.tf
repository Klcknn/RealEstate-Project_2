provider "aws" {
  region = var.aws_region
  # You can use access keys
  /* 
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  */
}

provider "github" {
  token = var.github_token
}
