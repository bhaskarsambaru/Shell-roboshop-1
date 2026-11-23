
#!/bin/bash

set -e

ami_id="ami-0055977a6e828a4f4"
instance_type="t3.micro"
domain_name="chiguruorganics.store"
hosted_zone_id="Z00706201JH1HRHD8M1KR"

# Enter your existing security group IDs
common_sg_id="sg-REPLACE_COMMON"
mongodb_sg_id="sg-REPLACE_MONGODB"

for instance in "$@"
do
    echo "creating instance: $instance"

    instance_id=$(aws ec2 run-instances \
        --image-id "$ami_id" \
        --instance-type "$instance_type" \
        --security-group-ids "$common_sg_id" "$mongodb_sg_id" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=roboshop-$instance}]" \
        --query 'Instances[0].InstanceId' \
        --output text)

    echo "$instance instance ID: $instance_id"

    if [[ "$instance" != "frontend" ]]; then

        ip=$(aws ec2 describe-instances \
            --instance-ids "$instance_id" \
            --query 'Reservations[0].Instances[0].PrivateIpAddress' \
            --output text)

        r53_record="${instance}.${domain_name}"

    else

        ip=$(aws ec2 describe-instances \
            --instance-ids "$instance_id" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)

        r53_record="${domain_name}"

    fi

    echo "Record: ${r53_record}"
    echo "IP Address: ${ip}"

    aws route53 change-resource-record-sets \
        --hosted-zone-id "$hosted_zone_id" \
        --change-batch "{
            \"Changes\": [
                {
                    \"Action\": \"UPSERT\",
                    \"ResourceRecordSet\": {
                        \"Name\": \"$r53_record\",
                        \"Type\": \"A\",
                        \"TTL\": 60,
                        \"ResourceRecords\": [
                            {\"Value\": \"$ip\"}
                        ]
                    }
                }
            ]
        }"

    echo "updated r53 record for $instance"

done
