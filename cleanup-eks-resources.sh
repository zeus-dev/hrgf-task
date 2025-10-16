#!/bin/bash

# Script to clean up AWS resources created by EKS Terraform
# Run with: bash cleanup-eks-resources.sh

set -e

REGION="ap-south-1"
CLUSTER_NAME="nasa-eks"
VPC_NAME="${CLUSTER_NAME}-vpc"

echo "Starting cleanup of EKS resources..."

# Function to delete resources
delete_resource() {
    local resource_type=$1
    local resource_id=$2
    local delete_command=$3

    if [ -n "$resource_id" ]; then
        echo "Deleting $resource_type: $resource_id"
        eval "$delete_command" || echo "Failed to delete $resource_type: $resource_id"
    fi
}

# 1. Delete Load Balancers
echo "Checking for Load Balancers..."
LB_ARNS=$(aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?contains(LoadBalancerName, `nasa-eks`)].LoadBalancerArn' --output text)
for LB_ARN in $LB_ARNS; do
    delete_resource "Load Balancer" "$LB_ARN" "aws elbv2 delete-load-balancer --load-balancer-arn $LB_ARN --region $REGION"
done

# 2. Delete Target Groups
TG_ARNS=$(aws elbv2 describe-target-groups --region $REGION --query 'TargetGroups[?contains(TargetGroupName, `nasa-eks`)].TargetGroupArn' --output text)
for TG_ARN in $TG_ARNS; do
    delete_resource "Target Group" "$TG_ARN" "aws elbv2 delete-target-group --target-group-arn $TG_ARN --region $REGION"
done

# 3. Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=$VPC_NAME --region $REGION --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    echo "Found VPC: $VPC_ID"

    # 4. Delete NAT Gateways
    NAT_IDS=$(aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=$VPC_ID --region $REGION --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text)
    for NAT_ID in $NAT_IDS; do
        # Delete NAT Gateway
        delete_resource "NAT Gateway" "$NAT_ID" "aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID --region $REGION"
    done

    # Wait for NAT gateways to be deleted
    echo "Waiting for NAT gateways to be deleted..."
    aws ec2 wait nat-gateways-deleted --nat-gateway-ids $NAT_IDS --region $REGION 2>/dev/null || true

    # 5. Delete Internet Gateway
    IGW_ID=$(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$VPC_ID --region $REGION --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || echo "")
    if [ -n "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
        # Detach IGW
        aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION || true
        delete_resource "Internet Gateway" "$IGW_ID" "aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION"
    fi

    # 6. Delete Subnets
    SUBNET_IDS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID --region $REGION --query 'Subnets[].SubnetId' --output text)
    for SUBNET_ID in $SUBNET_IDS; do
        delete_resource "Subnet" "$SUBNET_ID" "aws ec2 delete-subnet --subnet-id $SUBNET_ID --region $REGION"
    done

    # 7. Delete Security Groups (except default)
    SG_IDS=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC_ID Name=group-name,Values='*nasa-eks*' --region $REGION --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)
    for SG_ID in $SG_IDS; do
        delete_resource "Security Group" "$SG_ID" "aws ec2 delete-security-group --group-id $SG_ID --region $REGION"
    done

    # 8. Delete VPC
    delete_resource "VPC" "$VPC_ID" "aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION"
else
    echo "No VPC found with name: $VPC_NAME"
fi

# 9. Delete IAM Policies
POLICY_ARNS=$(aws iam list-policies --scope Local --region $REGION --query 'Policies[?contains(PolicyName, `nasa-eks`)].Arn' --output text 2>/dev/null || echo "")
for POLICY_ARN in $POLICY_ARNS; do
    delete_resource "IAM Policy" "$POLICY_ARN" "aws iam delete-policy --policy-arn $POLICY_ARN"
done

# 10. Delete IAM Roles
ROLE_NAMES=$(aws iam list-roles --query 'Roles[?contains(RoleName, `nasa-eks`)].RoleName' --output text 2>/dev/null || echo "")
for ROLE_NAME in $ROLE_NAMES; do
    # Detach policies first
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name $ROLE_NAME --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo "")
    for POLICY_ARN in $ATTACHED_POLICIES; do
        aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn $POLICY_ARN || true
    done

    # Delete instance profiles
    INSTANCE_PROFILES=$(aws iam list-instance-profiles-for-role --role-name $ROLE_NAME --query 'InstanceProfiles[].InstanceProfileName' --output text 2>/dev/null || echo "")
    for PROFILE_NAME in $INSTANCE_PROFILES; do
        aws iam remove-role-from-instance-profile --instance-profile-name $PROFILE_NAME --role-name $ROLE_NAME || true
        aws iam delete-instance-profile --instance-profile-name $PROFILE_NAME || true
    done

    delete_resource "IAM Role" "$ROLE_NAME" "aws iam delete-role --role-name $ROLE_NAME"
done

# 11. Delete KMS Keys (be careful - this permanently deletes keys)
KMS_ALIASES=$(aws kms list-aliases --region $REGION --query 'Aliases[?contains(AliasName, `eks/nasa-eks`)].AliasName' --output text 2>/dev/null || echo "")
for ALIAS in $KMS_ALIASES; do
    KEY_ID=$(aws kms describe-key --key-id alias/$ALIAS --region $REGION --query 'KeyMetadata.KeyId' --output text 2>/dev/null || echo "")
    if [ -n "$KEY_ID" ]; then
        # Schedule deletion (minimum 7 days)
        aws kms schedule-key-deletion --key-id $KEY_ID --pending-window-in-days 7 --region $REGION || true
        echo "Scheduled deletion of KMS key: $KEY_ID (alias: $ALIAS)"
    fi
done

# 12. Delete CloudWatch Log Groups
LOG_GROUPS=$(aws logs describe-log-groups --log-group-name-prefix "/aws/eks/$CLUSTER_NAME" --region $REGION --query 'logGroups[].logGroupName' --output text 2>/dev/null || echo "")
for LOG_GROUP in $LOG_GROUPS; do
    delete_resource "CloudWatch Log Group" "$LOG_GROUP" "aws logs delete-log-group --log-group-name $LOG_GROUP --region $REGION"
done

echo "Cleanup completed!"
echo "Note: Some resources may take time to delete completely."
echo "KMS keys are scheduled for deletion in 7 days."
echo "Check AWS console for any remaining resources."