
# [tfsec] Results
## Failed: 7 issue(s)
| # | ID | Severity | Title | Location | Description |
|---|----|----------|-------|----------|-------------|
| 1 | `aws-iam-no-policy-wildcards` | *HIGH* | _IAM policy should avoid use of wildcards and instead apply the principle of least privilege_ | `main.tf:388` | IAM policy document uses sensitive action 's3:*' on wildcarded resource '0cb4b928-befc-4442-b8f4-0fbcc419bf4a' |
| 2 | `aws-iam-no-policy-wildcards` | *HIGH* | _IAM policy should avoid use of wildcards and instead apply the principle of least privilege_ | `main.tf:388` | IAM policy document uses wildcarded action 's3:*' |
| 3 | `aws-iam-no-policy-wildcards` | *HIGH* | _IAM policy should avoid use of wildcards and instead apply the principle of least privilege_ | `main.tf:388` | IAM policy document uses wildcarded action 'kms:*' |
| 4 | `aws-iam-no-policy-wildcards` | *HIGH* | _IAM policy should avoid use of wildcards and instead apply the principle of least privilege_ | `main.tf:318` | IAM policy document uses sensitive action 's3:GetObject' on wildcarded resource '0cb4b928-befc-4442-b8f4-0fbcc419bf4a/*' |
| 5 | `aws-iam-no-policy-wildcards` | *HIGH* | _IAM policy should avoid use of wildcards and instead apply the principle of least privilege_ | `main.tf:252` | IAM policy document uses sensitive action 's3:GetObject' on wildcarded resource '0cb4b928-befc-4442-b8f4-0fbcc419bf4a/*' |
| 6 | `aws-s3-enable-bucket-logging` | *MEDIUM* | _S3 Bucket does not have logging enabled._ | `main.tf:152-160` | Bucket does not have logging enabled |
| 7 | `aws-s3-enable-versioning` | *MEDIUM* | _S3 Data should be versioned_ | `main.tf:152-160` | Bucket does not have versioning enabled |

