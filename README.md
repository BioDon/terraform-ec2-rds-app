# Terraform Infrastructure Setup for Web Application with VPC, EC2, and RDS

![Image Alt Text](/screenshots/Screenshot3.png)

## Background

Your team is actively developing a web application with a reliance on a database. Your specific responsibility involves configuring the VPC, EC2 instances, and RDS instances using Terraform. The architecture consists of EC2 instances for deploying the web application and MySQL RDS for the database.

## Requirements

- EC2 instances must be accessible globally via HTTP.
- SSH access to EC2 instances is restricted to designated users.
- RDS should reside in a private subnet and remain inaccessible from the internet.
- Only EC2 instances should have communication privileges with the RDS instance.

## Task Execution

1. **Create a VPC**
2. **Create an Internet Gateway and Attach it to the VPC**
3. **Establish 3 Subnets: 1 Public for EC2 and 2 Private for RDS**
4. **Set Up 2 Route Tables: 1 Public and 1 Private**
5. **Define 2 Security Groups: 1 for EC2 and 1 for RDS**
6. **Create the Database Subnet Group**
7. **Deploy the MySQL RDS Database**
8. **Provision the EC2 Instance**
9. **Verify the Correct Configuration of All Components**

## Prerequisites

Ensure the following prerequisites are met before proceeding:

- AWS CLI is installed and properly configured.
- Terraform is installed.

## Declaring Variables

To initiate the Terraform project, let's first compile the variables file:

1. Create a dedicated directory for the Terraform project.
2. Navigate to the created directory.

```bash
mkdir terraform-project && cd terraform-project
```

Create a file in the project directory called variables.tf

```bash
touch variables.tf
```

Open variables.tf in your editor and add the following:

```bash
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
```

## Creating our Secrets File

Now that the variables have been declared, let's go ahead and set up our secrets file.

- Create a file in the same directory called secrets.tfvars
- Open the file in your editor and add the following information:

```bash
// Links to the my_ip variable
my_ip = "Enter your IP address here"

// Links to the db_username variable
db_username = "admin"

// Links to the db_password variable
db_password = "Enter a Password here"
```

## Creating our Main Config File

Now that we have defined both the variables and secrets, let’s start creating our config file.

- Create a file in the same directory called main.tf
- Open the file in your editor and add the following information:

```bash
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.34.0"
    }
  }
  required_version = "1.7.1"
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}
```

# Step One — Creating the VPC

Now it’s time to begin setting up our AWS environment. We are going to be working in the main.tf file for the majority of this section.

- Go ahead and add the following code to your main.tf file

```bash
resource "aws_vpc" "project-vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true
}
```

# Step Two — Creating the Internet Gateway

Now that the VPC resource has been created, it’s time to create the Internet Gateway and attach it to the VPC.

- Go ahead and add the following code to your main.tf file

```bash
resource "aws_internet_gateway" "project-igw" {
  vpc_id = aws_vpc.project-vpc.id
}
```

# Step Three — Creating the Subnets

Time to create the subnets. In our case, we are going to need 1 public subnet and 2 private subnets.

Note: Since RDS requires 2 subnets for a database and our database is going to be in the private subnet, that is why we need 2 private subnets

## The Public Subnet

```bash
resource "aws_subnet" "project-public-subnet" {
  count             = var.public_subnet_count
  vpc_id            = aws_vpc.project-vpc.id
  cidr_block        = var.public_subnet_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "project-public-subnet-${count.index}"
  }
}
```

## The Private Subnets

```bash
resource "aws_subnet" "project-private-subnet" {
  count             = var.private_subnet_count
  vpc_id            = aws_vpc.project-vpc.id
  cidr_block        = var.private_subnet_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "project-private-subnet-${count.index}"
  }
}
```

# Step Four — Creating the Route Tables

Now that the subnets have been created, we can go ahead and create the route tables. We are going to be creating a public and a private route table.

## The Public Route Table

```bash
resource "aws_route_table" "project-public-route-table" {
  vpc_id = aws_vpc.project-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.project-igw.id
  }
}

resource "aws_route_table_association" "project-public-route-table-association" {
  count          = var.public_subnet_count // the number of subnets we want to associate with the route table
  subnet_id      = aws_subnet.project-public-subnet[count.index].id
  route_table_id = aws_route_table.project-public-route-table.id
}
```

## The Private Route Table

```bash
resource "aws_route_table" "project-private-route-table" {
  vpc_id = aws_vpc.project-vpc.id
  // no route defined because we don't want to allow internet access to private subnets
}

resource "aws_route_table_association" "project-private-route-table-association" {
  count          = var.private_subnet_count // the number of subnets we want to associate with the route table
  subnet_id      = aws_subnet.project-private-subnet[count.index].id
  route_table_id = aws_route_table.project-private-route-table.id
}
```

# Step Five — Creating the Security Groups

Time to create the security groups! We are going to be creating a security group for the web application (EC2) and one for the database (RDS). Now, remember we need to meet the requirements that were set in the beginning. Here they are again:

- EC2 instances must be accessible globally via HTTP.
- SSH access to EC2 instances is restricted to designated users.
- RDS should reside in a private subnet and remain inaccessible from the internet.
- Only EC2 instances should have communication privileges with the RDS instance.

## The EC2 Security Group

```bash
resource "aws_security_group" "project-ec2-sg" {
  name        = "project-ec2-sg"
  description = "Allow inbound traffic from port 22 and 80"
  vpc_id      = aws_vpc.project-vpc.id
  ingress {
    description = "Allow all traffic through HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow SSH from my computer"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

## The RDS Security Group

```bash
  resource "aws_security_group" "project-db-sg" {
  name        = "project-db-sg"
  description = "Security Group for Project DB"
  vpc_id      = aws_vpc.project-vpc.id
  ingress {
    description     = "Allow DB traffic only from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.project-ec2-sg.id]
  }
}
```

# Step Six — Creating the DB Subnet Group

Now that the security groups are done, let’s move over to RDS. The first thing we need to do is create the DB subnet group.

```bash
// Creating DB Subnet Group before creating MySQL RDS instance
resource "aws_db_subnet_group" "project-db-subnet-group" {
  name        = "project-db-subnet-group"
  description = "DB Subnet Group for Project DB"
  subnet_ids  = aws_subnet.project-private-subnet[*].id
}
```

# Step Seven — Creating the MySQL RDS Database

After the DB subnet group has been created, we can now create the database. We will be using MySQL RDS for the database.

```bash
resource "aws_db_instance" "projectdatabase" {
  db_name             = var.settings.database.db_name
  engine              = var.settings.database.engine
  engine_version      = var.settings.database.engine_version
  instance_class      = var.settings.database.instance_class
  allocated_storage   = var.settings.database.allocated_storage
  skip_final_snapshot = var.settings.database.skip_final_snapshot

  vpc_security_group_ids = [aws_security_group.project-db-sg.id]            # Security group for the datatbase
  db_subnet_group_name   = aws_db_subnet_group.project-db-subnet-group.name # DB subnet group name
  username               = var.db_username
  password               = var.db_password
}
```

# Step Eight — Creating the EC2 Instance

Now that everything else has been set up, we are ready to set up the EC2 instance. This is going to contain 3 parts:

- Creating the key pair
- Creating the EC2 instance
- Creating an Elastic IP and attaching it to the EC2 instance

Tip: Use Elastic IP on EC2 instances where you need to have a static public IP address

## Creating the Key Pair

We will be creating a new key pair in our terraform directory. Run the following command:

```bash
ssh-keygen -t rsa -b 4096 -m pem -f terraform-project.pem && chmod 400 terraform-project.pem
```

Now we will need to take this key and make it an AWS key pair. Open up the main.tf file and add the following code:

```bash
// Create a key pair named "terraform-project"
resource "aws_key_pair" "terraform-project" {
  key_name   = "terraform-project"
  public_key = file("terraform-project.pem.pub")
}
```

## Creating the EC2 Instance

```bash
resource "aws_instance" "project-web" {
  count                  = var.settings.ec2.count
  ami                    = var.settings.ec2.ami
  instance_type          = var.settings.ec2.instance_type
  subnet_id              = aws_subnet.project-public-subnet[count.index].id
  vpc_security_group_ids = [aws_security_group.project-ec2-sg.id]
  key_name               = aws_key_pair.terraform-project.key_name
  tags = {
    Name = "project-web-${count.index}"
  }
}
```

## Creating the Elastic IP and attaching it to the EC2 instance

Now that the EC2 instance has been created, we can create the Elastic IP and attach it to the EC2 instance.

```bash
resource "aws_eip" "project-eip" {
  domain   = "vpc"
  instance = aws_instance.project-web[count.index].id
  count    = var.settings.ec2.count
}
```

## Outputs

Alright, ONE more thing before we finish up here. Let’s go ahead and create some outputs.

- Create a file called outputs.tf and open it in your editor
- Add the following to the outputs file:

```bash
output "webserver_ips" {
  description = "The Public IP address(es) of the EC2 Instance(s)"
  value       = aws_instance.project-web[0].public_ip
  depends_on  = [aws_instance.project-web]
}

output "web_public_dns" {
  description = "The Public DNS name(s) of the EC2 Instance(s)"
  value       = aws_instance.project-web[0].public_dns
  depends_on  = [aws_instance.project-web]
}

output "db_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.projectdatabase.address
  depends_on  = [aws_db_instance.projectdatabase]
}

output "db_port" {
  description = "The port of the database"
  value       = aws_db_instance.projectdatabase.port
}
```

# Step Nine — Verification

Woo! Alright, now that our main config file and outputs are finished, let’s run our configuration and make sure everything works correctly. On the command line, run the following commands:

```bash
terraform init
terraform apply -var-file="secrets.tfvars"
```

When prompted for a value, enter: yes

It will take a few minutes for Terraform to apply the configuration. When it is done, you should see something similar to this:

![Image Alt Text](/screenshots/Screenshot1.png)

Now let’s verify that we can SSH into the EC2 instance and that we can communicate with RDS from inside the EC2 instance. Make note of database_endpoint and database_port, we will need those once we are inside the EC2 instance.

```bash
ssh -i "terraform-project.pem" ec2-user@$(terraform output -raw web_public_dns)
```

If you are facing an error due to running the commands in WSL (Windows Subsystem for Linux), try the below instead: 
(skip this step if you already see Amazon Linux 2023)

```bash
mv terraform-project.pem ~/
chmod 400 ~/terraform-project.pem
ssh -i "~/terraform-project.pem" ec2-user@$(terraform output -raw web_public_dns)
```

Once connected to the EC2 instance, let’s try connecting to the RDS instance. First, we will need to install the MySQL client. Run the following command:

```bash
sudo dnf update
wget https://dev.mysql.com/get/mysql80-community-release-el9-3.noarch.rpm
sudo dnf install mysql-community-server
sudo systemctl start mysqld
sudo systemctl enable mysqld
```

Once that MySQL client is installed, let’s try connecting to the RDS instance.

- The <database-endpoint> is going to be your database_endpoint from the terraform output
- The <database-port> is going to be your database_port from the terraform output
- The <db-username> is going to be your DB username, which was the db_username that you created in your secrets

```bash
mysql -h <database-endpoint> -P <database-port> -u <db-username> -p
```

When prompted, enter the password of the DB user. This was the db_password you created in your secrets file. 
We are connected to the MySQL RDS database. Let's see if our database was created. Run the following command in the MySQL terminal:

```bash
show DATABASES;
```

![Image Alt Text](/screenshots/Screenshot2.png)

Congratulations! The database that we declared in our variable settings.database.db_name is there!

To avoid any unnecessary charges in AWS, let’s use terraform to destroy everything that we have created. Enter the following command:

```bash
terraform destroy -var-file="secrets.tfvars"
```

When prompted, enter: yes

It will take a few minutes to destroy everything. When it is finished, you should see a success message.

## Credits

This tutorial draws inspiration from an insightful article authored by Matt Little, with specific modifications, notably the adoption of Amazon Linux 2023 as the base image for EC2, deviating from the original Ubuntu choice.

As of January 2024, rigorous testing has been conducted to validate the efficacy of the provided tutorial. For the original article and a deeper exploration of the subject matter, please consult the following authoritative source:

[Original Article by Matt Little](https://medium.com/strategio/using-terraform-to-create-aws-vpc-ec2-and-rds-instances-c7f3aa416133)









