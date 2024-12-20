#!/bin/bash

# Package Lambda1
cd lambda1
zip ../lambda1.zip lambda1.py
cd ..

# Package Lambda2
cd lambda2
zip ../lambda2.zip lambda2.py
cd ..

# Deploy with Terraform
terraform init
terraform apply -auto-approve
