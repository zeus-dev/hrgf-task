aws_region      = "ap-south-1"
cluster_name    = "nasa-eks"
cluster_version = "1.34"
vpc_cidr        = "10.0.0.0/16"
environment     = "production"

# Free tier optimized
instance_types = ["t3.small"]
desired_size   = 3
min_size       = 1
max_size       = 4

tags = {
  Terraform   = "true"
  Environment = "production"
  Project     = "nainika-store"
  ManagedBy   = "Terraform"
}