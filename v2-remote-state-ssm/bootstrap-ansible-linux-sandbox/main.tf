# main.tf

provider "aws" {
  region = "us-east-1"
}

# The S3 bucket for state management
resource "aws_s3_bucket" "terraform_state" {
  bucket = "ansible-linux-sandbox-terraform-state"
  lifecycle {
    prevent_destroy = true
  }
}

# Enable S3 bucket versioning
resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# The DynamoDB table for locking Terraform state
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
