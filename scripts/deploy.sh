#!/bin/bash
set -e

echo "Starting deployment..."

if [ ! -f "terraform.tfvars" ]; then
    echo "Error: terraform.tfvars not found"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and configure it"
    exit 1
fi

echo "Installing Lambda dependencies..."
cd lambda
pip install -r requirements.txt -t . --upgrade
cd ..

echo "Initializing Terraform..."
terraform init

echo "Validating Terraform configuration..."
terraform validate

echo "Planning Terraform changes..."
terraform plan -out=tfplan

read -p "Do you want to apply these changes? (yes/no): " confirm
if [ "$confirm" = "yes" ]; then
    echo "Applying Terraform changes..."
    terraform apply tfplan
    rm tfplan
    echo "Deployment complete!"
else
    echo "Deployment cancelled"
    rm tfplan
    exit 0
fi
