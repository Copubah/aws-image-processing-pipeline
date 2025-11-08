#!/bin/bash
set -e

DLQ_URL=$(terraform output -raw dlq_url)

if [ -z "$DLQ_URL" ]; then
    echo "Error: Could not get DLQ URL from Terraform"
    exit 1
fi

echo "Checking Dead Letter Queue..."
aws sqs get-queue-attributes \
    --queue-url "$DLQ_URL" \
    --attribute-names ApproximateNumberOfMessages

echo ""
echo "Receiving messages from DLQ..."
aws sqs receive-message \
    --queue-url "$DLQ_URL" \
    --max-number-of-messages 10 \
    --output json
