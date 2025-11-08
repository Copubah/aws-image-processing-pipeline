#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: ./test-upload.sh <image-file>"
    exit 1
fi

IMAGE_FILE=$1

if [ ! -f "$IMAGE_FILE" ]; then
    echo "Error: File $IMAGE_FILE not found"
    exit 1
fi

UPLOAD_BUCKET=$(terraform output -raw upload_bucket_name)

if [ -z "$UPLOAD_BUCKET" ]; then
    echo "Error: Could not get upload bucket name from Terraform"
    exit 1
fi

echo "Uploading $IMAGE_FILE to $UPLOAD_BUCKET..."
aws s3 cp "$IMAGE_FILE" "s3://$UPLOAD_BUCKET/"

echo "Upload complete. Check CloudWatch logs for processing status."
echo "View logs with: aws logs tail /aws/lambda/image-processor-function --follow"
