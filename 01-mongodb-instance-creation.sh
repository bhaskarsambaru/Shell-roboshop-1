
#!/bin/bash

set -euo pipefail

# ==========================================
# RoboShop MongoDB EC2 Instance Creation
# ==========================================

# AWS Configuration
REGION="us-east-1"
AMI_ID="ami-0055977a6e828a4f4"
INSTANCE_TYPE="t3.micro"

# Existing security groups (created manually)
# Replace these placeholders with actual SG IDs
COMMON_SG_ID="sg-REPLACE_COMMON"
MONGODB_SG_ID="sg-REPLACE_MONGODB"

# Route 53 Configuration
DOMAIN_NAME="chiguruorganics.store"
HOSTED_ZONE_ID="Z00706201JH1HRHD8M1KR"

# ==========================================
# Validate arguments and configuration
# ==========================================

if [[ $# -eq 0 ]]; then
    echo "Usage: bash $0 mongodb"
    exit 1
fi

if [[ "$COMMON_SG_ID" == *REPLACE* ||
      "$MONGODB_SG_ID" == *REPLACE* ]]; then
    echo "ERROR: Please configure security group IDs."
    exit 1
fi

# ==========================================
# Create EC2 instance
# ==========================================

for instance in "$@"
do
    if [[ "$instance" != "mongodb" ]]; then
        echo "ERROR: Only mongodb is supported."
        exit 1
    fi

    echo "Creating instance: $instance"

    INSTANCE_ID=$(aws ec2 run-instances \
        --region "$REGION" \
        --image-id "$AMI_ID" \
        --instance-type "$INSTANCE_TYPE" \
        --security-group-ids "$COMMON_SG_ID" "$MONGODB_SG_ID" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=roboshop-$instance}]" \
        --query 'Instances[0].InstanceId' \
        --output text)

    if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
        echo "ERROR: Instance creation failed."
        exit 1
    fi

    echo "EC2 Instance ID: $INSTANCE_ID"

    # Wait until EC2 is running
    echo "Waiting for instance to start..."

    aws ec2 wait instance-running \
        --region "$REGION" \
        --instance-ids "$INSTANCE_ID"

    echo "Instance is running."

    # ======================================
    # Retrieve private IP
    # ======================================

    PRIVATE_IP=$(aws ec2 describe-instances \
        --region "$REGION" \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text)

    if [[ -z "$PRIVATE_IP" || "$PRIVATE_IP" == "None" ]]; then
        echo "ERROR: Private IP not found."
        exit 1
    fi

    echo "Private IP: $PRIVATE_IP"

    # ======================================
    # Route 53 DNS Record
    # ======================================

    RECORD_NAME="${instance}.${DOMAIN_NAME}"

    echo "Updating DNS record: $RECORD_NAME"

    aws route53 change-resource-record-sets \
        --hosted-zone-id "$HOSTED_ZONE_ID" \
        --change-batch "{
            \"Changes\": [
                {
                    \"Action\": \"UPSERT\",
                    \"ResourceRecordSet\": {
                        \"Name\": \"$RECORD_NAME\",
                        \"Type\": \"A\",
                        \"TTL\": 60,
                        \"ResourceRecords\": [
                            {
                                \"Value\": \"$PRIVATE_IP\"
                            }
                        ]
                    }
                }
            ]
        }"

    echo "Route 53 record updated successfully."
    echo "----------------------------------------"
    echo "Instance Name : roboshop-$instance"
    echo "Instance ID   : $INSTANCE_ID"
    echo "Private IP    : $PRIVATE_IP"
    echo "DNS Record    : $RECORD_NAME"
    echo "----------------------------------------"

done

echo "MongoDB EC2 automation completed."
