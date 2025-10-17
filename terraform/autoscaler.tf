# Cluster Autoscaler IAM Role and Installation
# This enables automatic node scaling when pods are pending

# Create IAM role for cluster autoscaler
resource "aws_iam_role" "cluster_autoscaler" {
  name_prefix = "cluster-autoscaler-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = module.eks.eks_managed_node_groups["main"].iam_role_arn
        }
      }
    ]
  })

  tags = var.tags
}

# Create IAM policy for cluster autoscaler
resource "aws_iam_policy" "cluster_autoscaler" {
  name_prefix = "cluster-autoscaler-"
  description = "Policy for cluster autoscaler to manage EC2 Auto Scaling Groups"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

# Tag the ASG for cluster autoscaler discovery
resource "aws_autoscaling_group_tag" "cluster_autoscaler" {
  for_each = toset(
    try([module.eks.eks_managed_node_groups["main"].asg_name], [])
  )

  autoscaling_group_name = each.value

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = false
  }
}

# Output the role ARN for Helm installation
output "cluster_autoscaler_role_arn" {
  description = "ARN of the cluster autoscaler IAM role"
  value       = aws_iam_role.cluster_autoscaler.arn
}