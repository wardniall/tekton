#!/bin/bash


# the purpose of this script is to install the AWS CLI


AWS_ACCESS_KEY_ID=''
AWS_SECRET_ACCESS_KEY=''

showHelp () {
        cat << EOF
        Usage: ./installAWSCLI.sh [-h|--help -i|--aws_access_key_id=<IAM KEY ID> -s|--aws_secret_access_key=<IAM_SECRET_KEY]
Helper script to deploy the AWS CLI
-h, --help                                      Display help
-i, --aws_access_key_id                         IAM access key ID
-s, --aws_secret_access_key                     IAM secret access key
EOF
}

options=$(getopt -l "help,aws_secret_access_key:,aws_secret_access_key:" -o "h,i:,s:" -a -- "$@")
eval set -- "${options}"
while true; do
        case ${1} in
        -h|--help)
                showHelp
                exit 0
                ;;
        -i|--aws_access_key_id)
                shift
                AWS_ACCESS_KEY_ID="${1}"
                ;;
        -s|--aws_secret_access_key)
                shift
                AWS_SECRET_ACCESS_KEY="${1}"
                ;;
        --)
                shift
                break
                ;;
        esac
shift
done

if [ -e ~/.aws ]; then
  rm -rf ~/.aws
  mkdir ~/.aws
else
  mkdir ~/.aws
fi

echo "[default]" >> ~/.aws/credentials
echo "aws_access_key_id = ${AWS_ACCESS_KEY_ID}" >> ~/.aws/credentials
echo "aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}" >> ~/.aws/credentials

echo "[default]" >> ~/.aws/config
echo "region = eu-north-1" >> ~/.aws/config

# install aws cli

apt update
apt install curl -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt install unzip -y
unzip awscliv2.zip
./aws/install
apt install groff less -y

# list vms
aws ec2 describe-instances

# install jq
apt-get install jq

# create a key pair
aws ec2 create-key-pair --key-name NW_Pair --query 'KeyMaterial' --output text > NW_KeyPair.pem

# get vpcid
VPC-ID=$(aws ec2 describe-vpcs | jq -e ".Vpcs[0].VpcId")

# get first subnet associated with VPC_ID

SUBNET-ID=$(aws ec2 describe-subnets --filter="Name=vpc-id,Values=${VPC-ID}" |  jq -e ".Subnets[0].SubnetId")

# hardcode the AMI id for now
AMI-ID=ami-0506d6d51f1916a96

# Create a security group
aws ec2 create-security-group \
    --group-name nw-sg \
    --description "AWS ec2 CLI NW SG" \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=nw-sg}]' \
    --vpc-id "${VPC-ID}"

# get the security group id

SECURITY-GROUP-ID=$(aws ec2 describe-security-groups --filter="Name=group-name,Values=nw-sg" | jq -e ".SecurityGroups[0].GroupId")

# launch the instance
aws ec2 run-instances --image-id ${AMI-ID} --count 1 --instance-type t2.micro --key-name NW_Pair --security-group-ids ${SECURITY-GROUP-ID} --subnet-id ${SUBNET-ID}





