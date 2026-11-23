#!/bin/bash

ami_id="ami-0055977a6e828a4f4"
instance_type="t3.micro"
domain_name="chiguruorganics.store"
hosted_zone_id="Z00706201JH1HRHD8M1KR"

for instane in "$@"
do
  echo "creating instance: $instance"
  instance_id=$(aws ec2 run-instances \
    --image-id ami-0055977a6e828a4f4 \
    --instance-type t3.micro \
    --security-groups "roboshop-common" "roboshop-$instance" \
	--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=roboshop-$instance}]' \
	--query 'Instance [0].Instance id' \
	--output text
    )

    echo "$instance instance ID: $instance_id"
    if [[ "$instance" != "frontend" ]]; then
       ip=$( aws ec2 describe-instances \
            --instance-id $instance_id \
            --query 'Reservations[].Instance[].PrivateIpAddress' \
            --output text
            )

    r53_record="${instance}.${domain_name}"
    else  
        ip=$( aws ec2 describe-instance \
            --instance-ids $instance_id \
            --query 'Reservations[].Instance[].PublicIpAddress' \
            --output text
            )  
    r53_record="${domain_name}"
    fi

    #update R53 Record

    echo "Record:${r53_record}"
    aws route53 change-resource-record-sets \
        --hosted-zone-id $hosted_zone_id \
        --change-batch '{
            "changes": [
                 {
                  "Action: "UPSERT"
                  "ResourceRecordset": {
                  "name": "'$r53_record'",
                  "type": "A",
                  "TTL": 1,
                  "ResourceRecords": [{"value": "'$IP'"}]
                  }
                }
            ]
           }'
    echo "updated r53 record for $instance"

  done

  #THE END