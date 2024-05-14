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
apt-get install jq -y

# create a key pair
aws ec2 create-key-pair --key-name NW_Pair --query 'KeyMaterial' --output text > NW_KeyPair.pem

echo "****"
cat NW_KeyPair.pem
echo "****"

# get vpcid
VPC_ID=$(aws ec2 describe-vpcs | jq -e -r ".Vpcs[0].VpcId")

# get first subnet associated with VPC_ID

SUBNET_ID=$(aws ec2 describe-subnets --filter="Name=vpc-id,Values=${VPC_ID}" |  jq -e -r ".Subnets[0].SubnetId")

# hardcode the AMI id for now
AMI_ID=ami-0506d6d51f1916a96

# Create a security group
aws ec2 create-security-group \
    --group-name nw-sg \
    --description "AWS ec2 CLI NW SG" \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=nw-sg}]' \
    --vpc-id "${VPC_ID}"

# get the security group id

SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filter="Name=group-name,Values=nw-sg" | jq -e -r ".SecurityGroups[0].GroupId")

# create an ingress rule for ssh access
aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP_ID} \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

# launch the instance
aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --count 1 \
  --instance-type t3.micro \
  --key-name NW_Pair \
  --security-group-ids ${SECURITY_GROUP_ID} \
  --subnet-id ${SUBNET_ID} \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=tektontest}]'

  # test the copying of a script to new instance

  echo "#!/bin/bash" >> testscript.sh
  echo "echo \$(hostname)" >> testscript.sh
  chmod 755 testscript.sh

  # install scp
  apt-get install openssh-client -y

  # get the instanceID

  INSTANCE_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=tektontest Name=instance-state-name,Values=running | jq -e -r ".Reservations[].Instances[].InstanceId")

  # get the instance PublicDNS
  PUBLIC_DNS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --query 'Reservations[].Instances[].PublicDnsName' | jq -e -r ".[]")

  #sleep for 20 secs, looks like it takes a while for the security group rule to activate
  echo "sleeping for 20 secs"
  sleep 20

  # reduce permissions on .pem file
  chmod 400 NW_KeyPair.pem

  # scp file over to new instance and execute it
  
  scp  -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i NW_KeyPair.pem -r ./testscript.sh admin@${PUBLIC_DNS}:~/

  ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i NW_KeyPair.pem admin@${PUBLIC_DNS} './testscript.sh'





