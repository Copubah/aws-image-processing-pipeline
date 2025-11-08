# AWS Asynchronous Image Processing Pipeline

[![GitHub](https://img.shields.io/badge/GitHub-Repository-181717?logo=github)](https://github.com/Copubah/aws-image-processing-pipeline)
[![Terraform](https://img.shields.io/badge/Terraform-1.0+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python)](https://www.python.org/)

Production-ready serverless image processing pipeline on AWS using Terraform. Images uploaded to an S3 bucket are automatically resized and stored in a processed bucket with full monitoring and error handling.

**GitHub Repository:** https://github.com/Copubah/aws-image-processing-pipeline

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AWS Image Processing Pipeline                        │
└─────────────────────────────────────────────────────────────────────────────┘

                                                                                
    ┌──────────┐                                                                
    │  User    │                                                                
    └────┬─────┘                                                                
         │ Upload Image                                                         
         │                                                                      
         ▼                                                                      
┌─────────────────────┐                                                        
│   S3 Upload Bucket  │                                                        
│  ┌───────────────┐  │                                                        
│  │ Versioning    │  │                                                        
│  │ Encryption    │  │                                                        
│  │ Lifecycle     │  │                                                        
│  └───────────────┘  │                                                        
└──────────┬──────────┘                                                        
           │ S3 Event Notification                                             
           │                                                                    
           ▼                                                                    
┌─────────────────────┐         ┌──────────────────┐                          
│    SQS Queue        │────────▶│  Dead Letter     │                          
│  ┌───────────────┐  │ Failed  │  Queue (DLQ)     │                          
│  │ Encryption    │  │ After   │  ┌────────────┐  │                          
│  │ Long Polling  │  │ 3 tries │  │ Encryption │  │                          
│  │ Redrive Policy│  │         │  └────────────┘  │                          
│  └───────────────┘  │         └────────┬─────────┘                          
└──────────┬──────────┘                  │                                     
           │ Trigger                     │                                     
           │                             │                                     
           ▼                             ▼                                     
┌─────────────────────┐         ┌──────────────────┐                          
│  Lambda Function    │         │  CloudWatch      │                          
│  ┌───────────────┐  │         │  Alarm           │                          
│  │ Python 3.11   │  │────────▶│  ┌────────────┐  │                          
│  │ Pillow        │  │ Logs    │  │ DLQ Alert  │  │                          
│  │ X-Ray Tracing │  │         │  └────────────┘  │                          
│  │ Reserved      │  │         └──────────────────┘                          
│  │ Concurrency   │  │                                                        
│  └───────┬───────┘  │                                                        
└──────────┼──────────┘                                                        
           │                                                                    
           │ 1. Download Image                                                 
           │ 2. Resize (800x600)                                               
           │ 3. Optimize                                                       
           │ 4. Upload                                                         
           │                                                                    
           ▼                                                                    
┌─────────────────────┐                                                        
│ S3 Processed Bucket │                                                        
│  ┌───────────────┐  │                                                        
│  │ Versioning    │  │                                                        
│  │ Encryption    │  │                                                        
│  │ Lifecycle:    │  │                                                        
│  │  90d → IA     │  │                                                        
│  │  180d → Glacier│ │                                                        
│  └───────────────┘  │                                                        
└─────────────────────┘                                                        
           │                                                                    
           │                                                                    
           ▼                                                                    
    ┌──────────┐                                                               
    │  User    │                                                               
    │ Download │                                                               
    └──────────┘                                                               


┌─────────────────────────────────────────────────────────────────────────────┐
│                            Monitoring & Observability                        │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  CloudWatch      │    │  CloudWatch      │    │  CloudWatch      │
│  Dashboard       │    │  Alarms          │    │  Logs            │
│  ┌────────────┐  │    │  ┌────────────┐  │    │  ┌────────────┐  │
│  │ Lambda     │  │    │  │ Errors     │  │    │  │ Structured │  │
│  │ Metrics    │  │    │  │ Throttles  │  │    │  │ Logging    │  │
│  │ SQS Stats  │  │    │  │ DLQ Alert  │  │    │  │ 30d Retain │  │
│  │ S3 Objects │  │    │  └────────────┘  │    │  └────────────┘  │
│  └────────────┘  │    └──────────────────┘    └──────────────────┘
└──────────────────┘                                                 

┌─────────────────────────────────────────────────────────────────────────────┐
│                              IAM Security Model                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│  Lambda Execution Role (Least Privilege)                                 │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ - Read from Upload Bucket                                          │  │
│  │ - Write to Processed Bucket                                        │  │
│  │ - Receive/Delete SQS Messages                                      │  │
│  │ - Send to DLQ                                                      │  │
│  │ - Write CloudWatch Logs                                            │  │
│  │ - X-Ray Tracing                                                    │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
```

### Component Details

- Upload S3 Bucket: Receives user image uploads with versioning and encryption
- SQS Queue: Handles messages for new uploads with encryption and long polling
- Lambda Function: Processes images asynchronously with X-Ray tracing
- Processed S3 Bucket: Stores resized images with lifecycle policies
- Dead Letter Queue: Captures failed messages for investigation
- CloudWatch: Comprehensive monitoring, logging, and alerting

## Best Practices Implemented

### Security
- S3 bucket encryption at rest using AES256
- SQS encryption using AWS managed keys
- Public access blocked on all S3 buckets
- IAM roles with least privilege access
- Explicit SID statements for policy clarity
- X-Ray tracing for security auditing

### Reliability
- Dead Letter Queue for failed messages
- Batch item failures for partial batch processing
- Lambda reserved concurrency to prevent throttling
- SQS visibility timeout aligned with Lambda timeout
- Retry logic with configurable max receive count
- CloudWatch alarms for errors and throttles

### Performance
- SQS long polling to reduce empty receives
- Lambda memory optimization at 512MB
- Image optimization with progressive JPEG
- Efficient image format handling
- Concurrent execution controls

### Cost Optimization
- S3 lifecycle policies for automatic archival
- Intelligent tiering for processed images
- CloudWatch log retention policies
- Lambda reserved concurrency limits
- Automatic cleanup of old uploads

### Observability
- Structured logging with configurable levels
- CloudWatch dashboard for key metrics
- Metric filters for error tracking
- Alarms for DLQ messages
- X-Ray distributed tracing

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Python 3.11
- Bash shell for deployment scripts

## Quick Start

1. Copy and configure variables:
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit terraform.tfvars with your settings:
```bash
upload_bucket_name = "your-unique-upload-bucket-name"
processed_bucket_name = "your-unique-processed-bucket-name"
```

3. Deploy using the automated script:
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

Or manually:
```bash
cd lambda && pip install -r requirements.txt -t . && cd ..
terraform init
terraform plan
terraform apply
```

## Usage

### Upload Test Image
```bash
chmod +x scripts/test-upload.sh
./scripts/test-upload.sh path/to/image.jpg
```

### Monitor Processing
```bash
aws logs tail /aws/lambda/image-processor-function --follow
```

### Check Dead Letter Queue
```bash
chmod +x scripts/check-dlq.sh
./scripts/check-dlq.sh
```

### View Dashboard
Navigate to CloudWatch Console and open the image-processor-dashboard

## Configuration

### Core Settings
- image_width: Target width for resized images (default: 800)
- image_height: Target height for resized images (default: 600)
- upload_retention_days: Days to keep original uploads (default: 90)
- log_retention_days: CloudWatch log retention (default: 30)

### Performance Tuning
- lambda_reserved_concurrency: Max concurrent executions (default: 10)
- lambda_max_concurrency: SQS polling concurrency (default: 5)
- sqs_visibility_timeout: Processing timeout (default: 300s)

### Reliability
- dlq_max_receive_count: Retries before DLQ (default: 3)
- log_level: DEBUG, INFO, WARNING, or ERROR (default: INFO)

## Monitoring and Alerts

### CloudWatch Alarms
- Lambda errors exceeding threshold
- Lambda throttling events
- DLQ message presence
- Processing error rate

### Key Metrics
- Lambda invocations, errors, duration
- SQS messages sent, deleted, visible
- S3 object counts
- Processing error rate

### Logs
All Lambda logs are centralized in CloudWatch with structured logging:
```bash
aws logs tail /aws/lambda/image-processor-function --follow --format short
```

## Testing

Run unit tests:
```bash
cd lambda
python -m pytest test_handler.py -v
```

## Cleanup

Empty S3 buckets first:
```bash
aws s3 rm s3://your-upload-bucket-name --recursive
aws s3 rm s3://your-processed-bucket-name --recursive
```

Then destroy infrastructure:
```bash
terraform destroy
```

## Supported Image Formats

- JPEG/JPG with progressive encoding
- PNG with transparency handling
- GIF
- BMP
- WEBP

Maximum image size: 50MB

## Security Considerations

- All S3 buckets have public access blocked
- Encryption at rest enabled for S3 and SQS
- IAM policies follow least privilege principle
- Lambda function has no internet access by default
- X-Ray tracing enabled for audit trails

## Cost Optimization

### S3 Lifecycle Policies
- Upload bucket: Delete after 90 days
- Processed bucket: Move to IA after 90 days, Glacier after 180 days

### Lambda Optimization
- Right-sized memory allocation
- Reserved concurrency prevents runaway costs
- Efficient image processing reduces duration

### Monitoring Costs
- Log retention limited to 30 days
- Metric filters only for critical errors

## Troubleshooting

### Images not processing
1. Check CloudWatch logs for errors
2. Verify SQS queue has messages
3. Check Lambda function is not throttled
4. Ensure IAM permissions are correct

### High error rate
1. Check DLQ for failed messages
2. Review CloudWatch alarms
3. Verify image format is supported
4. Check image size is under 50MB

### Performance issues
1. Increase Lambda memory
2. Adjust reserved concurrency
3. Check X-Ray traces for bottlenecks
4. Review SQS visibility timeout

## Project Structure

```
.
├── provider.tf              # Terraform provider configuration
├── main.tf                  # Core infrastructure resources
├── monitoring.tf            # CloudWatch dashboards and alarms
├── variables.tf             # Input variables
├── outputs.tf               # Output values
├── terraform.tfvars.example # Example configuration
├── lambda/
│   ├── handler.py          # Lambda function code
│   ├── requirements.txt    # Python dependencies
│   └── test_handler.py     # Unit tests
└── scripts/
    ├── deploy.sh           # Automated deployment
    ├── test-upload.sh      # Test image upload
    └── check-dlq.sh        # Check DLQ messages
```
