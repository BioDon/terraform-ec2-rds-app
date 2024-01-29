// The variable to set AWS region where all the resources will be created
variable "aws_region" {
  description = "AWS Region"
  default     = "eu-central-1"
}

// The variable to set VPC CIDR block
variable "vpc_cidr_block" {
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
  type        = string
}

// The variable to set the number of public subnets
variable "public_subnet_count" {
  description = "Number of public subnets to create"
  default     = 1
  type        = number
}

// The variable to set the number of private subnets
variable "private_subnet_count" {
  description = "Number of private subnets to create"
  default     = 2
  type        = number
}

variable "public_subnet_cidr_blocks" {
  description = "CIDR blocks for public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"]
  type        = list(string)
}

variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks for private subnets"
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24", "10.0.104.0/24"]
  type        = list(string)
}

variable "my_ip" {
  description = "Your IP Address"
  type        = string
  sensitive   = true
}

variable "settings" {
  description = "DB and EC2 Settings"
  type        = map(any)
  default = {
    "database" = {
      db_name             = "mydatabase"
      engine              = "mysql"
      engine_version      = "8.0.35"
      instance_class      = "db.t2.micro"
      allocated_storage   = "10"
      skip_final_snapshot = true # keep this true only for testing db. false for production.
    },
    "ec2" = {
      count         = 1
      instance_type = "t2.micro"
      ami           = "ami-09024b009ae9e7adf"
    }
  }
}

variable "db_username" {
  description = "DB Master User"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "DB Master Password"
  type        = string
  sensitive   = true
}