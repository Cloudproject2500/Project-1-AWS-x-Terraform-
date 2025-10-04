# Configuration for the AWS Provider:
terraform {
  required_providers {
    # AWS provider -> enables terraform to create & manage AWS resources
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Used random provider to generate unique name
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# AWS provider config: Configures the AWS with default settings:
provider "aws" {
  region = "us-east-1"
}

# Data source:
data "aws_caller_identity" "current" {}

# AWS KMS key:
resource "aws_kms_key" "s3_key" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation = true

  tags = {
    Name = "S3-Encryption-key"
    Environment = "Learning"
    ManagedBy   = "Terraform"
  }
}

# AWS KMS encryption:
resource "aws_kms_alias" "s3_key_alias" {
  name          = "alias/s3-bucket-key"     # Friendly name (must start with "alias/")
  target_key_id = aws_kms_key.s3_key.key_id # Links to the KMS key created above
}

# AWS KMS Key policy: 
# Will define who can use the KMS keys and their privileges.
# 2 permissions: 
    # 1. Root account can manage the key 
    # 2. S3 service can use key for encryption/decryption 
resource "aws_kms_key_policy" "s3_key_policy" {
  key_id = aws_kms_key.s3_key.id

  # Policy written in JSON format (AWS's policy language):
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Allows the AWS account to full control over the key:
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          # Grants permission to the root account:
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"      
        Resource = "*"          
      },
      # Allows S3 service to use the key for encryption/decryption:
      {
        Sid    = "Allow S3 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com" 
        }
        Action = [
          "kms:Decrypt",           # Decrypts data when reading from S3
          "kms:GenerateDataKey"    # Generates data keys for encrypting new files
        ]
        Resource = "*"
      }
    ]
  })
}

#----------------------------------------------------------------------

# Random suffix to ensure unique bucket name and does not confuse with other names:
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Main S3 Bucket = Bucket I need to secure:
resource "aws_s3_bucket" "secure_bucket" {
  bucket = "my-secure-bucket-${random_string.suffix.result}"
  
  # tags created to help organize and identify each resources in AWS
  tags = {
    Name        = "SecureBucket"
    Environment = "Learning"
    ManagedBy   = "Terraform"
  }
}

# Block all public access (FOR MAIN BUCKET):
resource "aws_s3_bucket_public_access_block" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning (Needed to keep multiple version of files & data recovery):
resource "aws_s3_bucket_versioning" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}


# Encryption for Main (secure) Bucket using AWS KMS key:
resource "aws_s3_bucket_server_side_encryption_configuration" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"                    
      kms_master_key_id = aws_kms_key.s3_key.arn    
    }
    bucket_key_enabled = true  # Reduces KMS costs by 99% (uses bucket level keys)
  }
}

# Encryption for the log bucket with the same KMS key:
resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_key.arn
    }
    bucket_key_enabled = true
  }
}

# Logging bucket for storing access logs (For security monitoring, incident investigation):
resource "aws_s3_bucket" "log_bucket" {
  bucket = "my-log-bucket-${random_string.suffix.result}"
  
  tags = {
    Name        = "LogBucket"
    Environment = "Learning"
    ManagedBy   = "Terraform"
  }
}

# Blocking public access for log bucket:
resource "aws_s3_bucket_public_access_block" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enabled logging for Main Bucket:
resource "aws_s3_bucket_logging" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id # <- Monitors the main bucket

  target_bucket = aws_s3_bucket.log_bucket.id # <- Store the logs
  target_prefix = "log/"
}

# Lifecycle policy (Automatically manages data lifecycle to save costs)
resource "aws_s3_bucket_lifecycle_configuration" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

# Rule 1: Deletes the old version after 90 days (Save costs)

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

# Rule 2: Moves older data to cheaper storage classes (e.g. AWS Glaciers)

  rule {
    id     = "transition-old-logs"
    status = "Enabled"

# Moves to "Standard" storage after 30 days:

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

# Moves to "Glacier" storage after 90 days

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}


#---------------------------------------------------------------------------
# IAM Policies & roles (Least privileges):

# For read-only access role:
resource "aws_iam_role" "s3_read_only" {
  name = "s3-bucket-read-only-role"
  description = "Read only access to S3 bucket"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "S3ReadOnlyRole"
    Environment = "Learning"
    ManagedBy   = "Terraform"
  }
}

# Permission policy for read only access:
resource "aws_iam_role_policy" "s3_read_only_policy" {
  name = "s3-read-only-policy"
  role = aws_iam_role.s3_read_only.id

  policy = jsonencode({
   Version = "2012-10-17"
   Statement = [
     {
      Sid = "ListBucket"
      Effect = "Allow"
      Action = [
        "s3:ListBucket", # Lets you see what file exists
        "s3:GetBucketLocation" # Lets you see the region of the bucket 
      ]
      Resource = aws_s3_bucket.secure_bucket.arn
     },
     {
       Sid = "ReadObjects"
       Effect = "Allow"
       Action = [
        "s3:GetObject", # Lets you read & download files
        "s3:GetObjectVersion" # Lets you read old versions
       ]
       Resource = "${aws_s3_bucket.secure_bucket.arn}/*"
     },
     {
       Sid = "DecryptWithKMS"
       Effect = "Allow"
       Action = [
        "kms:Decrypt", # Decrypts files
        "kms:DescribeKey" 
       ]
       Resource = aws_kms_key.s3_key.arn
     }
   ] 
  })
}

#-----------------------------------------#
# For read-write access role:

resource "aws_iam_role" "s3_read_write" {
  name = "s3-bucket-read-write-role"
  description = "Read and write access to secure S3 bucket (no delete)"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "S3ReadWriteRole"
    Environment = "Learning"
    ManagedBy   = "Terraform"
  }
}

# Permission policy for read-write access:
resource "aws_iam_role_policy" "s3_read_write_policy" {
  name = "s3-read-write-policy"
  role = aws_iam_role.s3_read_write.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "ListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket", 
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.secure_bucket.arn
      },
      {
        Sid = "ReadWriteObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject", 
          "s3:GetObjectVersion",
          "s3:PutObject", # Lets you upload new files
          "s3:PutObjectAcl" # Lets you set file permissions
        ]
        Resource = "${aws_s3_bucket.secure_bucket.arn}/*"
      },
      {
        Sid = "KMSOperations"
        Effect = "Allow"
        Action = [
          "kms:Decrypt", # Decrypts exisiting files
          "kms:GenerateDataKey", # Encrypt new uploaded files
          "kms:DescribeKey" 
        ]
        Resource = aws_kms_key.s3_key.arn
      }
    ]
  })
}

#-----------------------------------------#
# For admin access role:
  # Can delete, read, write, modify bucket settings

resource "aws_iam_role" "s3_admin" {
  name = "s3-bucket-admin-role"
  description = "Full ADMIN access to secure S3 bucket"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "S3AdminRole"
    Environment = "Learning"
    ManagedBy   = "Terraform"
  }
}

# Permission policy for admin access:
resource "aws_iam_role_policy" "s3_admin_policy" {
  name = "s3-admin-policy"
  role = aws_iam_role.s3_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "FullAccess"
        Effect = "Allow"
        Action = [
          "s3:*" # Gives all access to s3 actions
        ]
        Resource = [
          aws_s3_bucket.secure_bucket.arn,
          "${aws_s3_bucket.secure_bucket.arn}/*"
        ]
      },
      {
        Sid = "FullKMSAccess"
        Effect = "Allow"
        Action = [
          "kms:*" # Gives all access to kms actions
        ]
        Resource = aws_kms_key.s3_key.arn
      }
    ]
  })
}

#---------------------------------------------------------------------------
# Instance Profiles: Allows ec2 instances to assume the roles

resource "aws_iam_instance_profile" "s3_read_profile" {
  name = "s3-read-only-instance-profile"
  role = aws_iam_role.s3_read_only.name
}

resource "aws_iam_instance_profile" "s3_read_write_profile" {
  name = "s3-read-write-instance-profile"
  role = aws_iam_role.s3_read_write.name
}

resource "aws_iam_instance_profile" "s3_admin_profile" {
  name = "s3-admin-instance-profile"
  role = aws_iam_role.s3_admin.name
}
