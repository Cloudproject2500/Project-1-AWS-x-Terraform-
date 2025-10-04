# Displays ID of the main bucket:
output "bucket_name" {
  description = "Name of the secure S3 bucket"
  value       = aws_s3_bucket.secure_bucket.id
}

# Displays the ARN of the main bucket:
output "bucket_arn" {
  description = "ARN of the secure S3 bucket"
  value       = aws_s3_bucket.secure_bucket.arn
}

# Displays the name of the log bucket:
output "log_bucket_name" {
  description = "Name of the logging bucket"
  value       = aws_s3_bucket.log_bucket.id
}

# Displays the AWS KMS key ID:
output "kms_key_id" {
  description = "AWS KMS key ID for encryption"
  value       = aws_kms_key.s3_key.id
}

# Displays the AWS KMS key ARN:
output "kms_key_arn" {
  description = "AWS KMS key ARN for encryption"
  value       = aws_kms_key.s3_key.arn
}

#---------------------------------------------------------------------------
# IAM Role Outputs
# Displays the ARNs of the IAM roles created
  # -> ARNs will be used when assigning roles to users or ec2 instances

output "s3_read_only_role_arn" {
  description = "ARN of the read-only IAM role"
  value       = aws_iam_role.s3_read_only.arn
}

output "s3_read_write_role_arn" {
  description = "ARN of the read-write IAM role"
  value       = aws_iam_role.s3_read_write.arn
}

output "s3_admin_role_arn" {
  description = "ARN of the admin IAM role"
  value       = aws_iam_role.s3_admin.arn
}
