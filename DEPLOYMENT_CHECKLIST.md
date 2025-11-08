# Pre-Deployment Checklist

## Prerequisites Verified
- [x] All Terraform files validated (no syntax errors)
- [x] Python Lambda code compiled successfully
- [x] Test suite created and ready
- [x] Deployment scripts created and executable
- [x] Documentation complete

## Before You Deploy

### 1. AWS Prerequisites
- [ ] AWS CLI installed and configured
- [ ] AWS credentials set up with appropriate permissions
- [ ] Terraform >= 1.0 installed
- [ ] Python 3.11 available

### 2. Configuration Steps

#### Create terraform.tfvars
```bash
cp terraform.tfvars.example terraform.tfvars
```

#### Edit terraform.tfvars with your values
Required changes:
- upload_bucket_name: Must be globally unique
- processed_bucket_name: Must be globally unique

Example:
```hcl
upload_bucket_name = "mycompany-image-uploads-prod-2024"
processed_bucket_name = "mycompany-processed-images-prod-2024"
```

Optional customizations:
- aws_region: Default is us-east-1
- image_width: Default is 800
- image_height: Default is 600
- upload_retention_days: Default is 90
- log_retention_days: Default is 30

### 3. Deployment Options

#### Option A: Automated Deployment (Recommended)
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

#### Option B: Manual Deployment
```bash
# Install Lambda dependencies
cd lambda
pip install -r requirements.txt -t .
cd ..

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan

# Apply changes
terraform apply
```

### 4. Post-Deployment Verification

#### Check outputs
```bash
terraform output
```

#### Test image upload
```bash
chmod +x scripts/test-upload.sh
./scripts/test-upload.sh path/to/test-image.jpg
```

#### Monitor processing
```bash
aws logs tail /aws/lambda/image-processor-function --follow
```

#### Check CloudWatch Dashboard
Navigate to AWS Console > CloudWatch > Dashboards > image-processor-dashboard

### 5. Cost Estimation

Estimated monthly costs (low usage):
- S3 Storage: $0.023 per GB
- Lambda: First 1M requests free, then $0.20 per 1M
- SQS: First 1M requests free, then $0.40 per 1M
- CloudWatch Logs: $0.50 per GB ingested

Typical small deployment: $5-20/month

### 6. Security Checklist
- [x] S3 buckets have encryption enabled
- [x] S3 buckets block public access
- [x] SQS queues use encryption
- [x] IAM roles follow least privilege
- [x] X-Ray tracing enabled for auditing
- [x] CloudWatch logging enabled

### 7. Monitoring Setup
- [x] CloudWatch dashboard created
- [x] Error alarms configured
- [x] DLQ alarms configured
- [x] Throttle alarms configured
- [x] Log retention policies set

## Deployment Validation

After deployment, verify:

1. S3 buckets created
```bash
aws s3 ls | grep image-processor
```

2. Lambda function deployed
```bash
aws lambda get-function --function-name image-processor-function
```

3. SQS queues created
```bash
aws sqs list-queues | grep image-processor
```

4. CloudWatch alarms active
```bash
aws cloudwatch describe-alarms --alarm-name-prefix image-processor
```

## Troubleshooting

### Bucket name already exists
S3 bucket names must be globally unique. Change the names in terraform.tfvars.

### Insufficient permissions
Ensure your AWS credentials have permissions for:
- S3 (CreateBucket, PutBucketPolicy, etc.)
- Lambda (CreateFunction, UpdateFunctionCode, etc.)
- SQS (CreateQueue, SetQueueAttributes, etc.)
- IAM (CreateRole, AttachRolePolicy, etc.)
- CloudWatch (PutMetricAlarm, CreateDashboard, etc.)

### Lambda deployment package too large
The Pillow library is large. Terraform handles this automatically via the archive_file data source.

### Terraform state management
For production, consider using remote state:
```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "image-processor/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## Cleanup

To remove all resources:

1. Empty S3 buckets first
```bash
aws s3 rm s3://your-upload-bucket-name --recursive
aws s3 rm s3://your-processed-bucket-name --recursive
```

2. Destroy infrastructure
```bash
terraform destroy
```

## Production Recommendations

1. Enable S3 bucket versioning (already configured)
2. Set up SNS notifications for CloudWatch alarms
3. Configure VPC for Lambda if accessing private resources
4. Use AWS Secrets Manager for sensitive configuration
5. Implement S3 bucket policies for additional access control
6. Enable AWS CloudTrail for audit logging
7. Set up AWS Backup for critical data
8. Use AWS Organizations for multi-account setup

## Support

For issues:
1. Check CloudWatch Logs for Lambda errors
2. Review CloudWatch Alarms for system issues
3. Check DLQ for failed messages
4. Verify IAM permissions
5. Ensure bucket names are unique

## Ready to Deploy?

If all prerequisites are met and configuration is complete:
```bash
./scripts/deploy.sh
```
