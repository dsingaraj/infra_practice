# provider "aws"{
#     region = var.apac_region
# }

# Query all available Availability Zone; we will use specific availability zone using index - The Availability Zones data source
# provides access to the list of AWS availabililty zones which can be accessed by an AWS account specific to region configured in the provider. 

data "aws_availability_zones" "devVPC_available"{}

#Get latest AMI ID based on Filter - Here AMI created using packer
data "aws_ami" "packeramisjenkins"{
  owners= ["052784389769"]
  most_recent=true

  filter{
    name = "name"
    values=["packer-jenkins*"]
  }
}

#Get latest AMI ID based on Filter - Here AMI created using packer
data "aws_ami" "packeramisnginx"{
  owners= ["052784389769"]
  most_recent=true

  filter{
    name = "name"
    values=["packer-cf*"]
  }
}

#Get latest AMI ID based on Filter - Here AMI created using packer
data "aws_ami" "packergenericamisjenkins"{
  owners= ["052784389769"]
  most_recent=true

  filter{
    name = "name"
    values=["packer-jenkins-generic*"]
  }
}

# Providers a VPC resource

resource "aws_vpc" "devVPC"{
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames=true
    enable_dns_support = true

    tags = {
        Name = "dev_terraform_vpc"
    }
}

# Public subnet public CIDR block available in vars.tf and provisionersVPC

resource "aws_subnet" "devVPC_public_subnet"{
    cidr_block = "10.0.1.0/28"
    vpc_id = aws_vpc.devVPC.id
    map_public_ip_on_launch = true
    availability_zone = data.aws_availability_zones.devVPC_available.names[1]

    tags = {
        Name = "dev_terraform_vpc_public_subnet"
    }    
}

resource "aws_subnet" "private_subnet"{
    cidr_block = "10.0.2.0/28"
    vpc_id = aws_vpc.devVPC.id
    map_public_ip_on_launch = false
    availability_zone = data.aws_availability_zones.devVPC_available.names[1]

    tags = {
        Name = "dev_terraform_vpc_private_subnet"
    }    
}

# To access EC2 instance inside a Virtual Private Cloud (VPC) we need an Internet Gateway 
# and a routing table Connecting the subnet to the Internet Gateway

# Creating Internet Gateway
# Provides a resource to create a VPC Internet Gateway

resource "aws_internet_gateway" "devVPC_IGW"{
    vpc_id = aws_vpc.devVPC.id

    tags = {
        Name = "dev_terraform_vpc_igw"
    }
}

# Provides a resource to create a VPC routing table
resource "aws_route_table" "devVPC_public_route"{
    vpc_id = aws_vpc.devVPC.id

    route{
        cidr_block = var.cidr_blocks
        gateway_id = aws_internet_gateway.devVPC_IGW.id
    }
    tags = {
        Name = "dev_terraform_vpc_public_route"
    }
}

# Provides a resource to create an association between a Public Route Table and a Public Subnet

resource "aws_route_table_association" "public_subnet_association" {
    route_table_id = aws_route_table.devVPC_public_route.id
    subnet_id = aws_subnet.devVPC_public_subnet.id

    depends_on = [aws_route_table.devVPC_public_route, aws_subnet.devVPC_public_subnet]
}

# Provides a security group resource - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group

resource "aws_security_group" "devVPC_sg_allow_ssh_http"{
    vpc_id = aws_vpc.devVPC.id
    name = "devVPC_terraform_vpc_allow_ssh_http"

    tags = {
        Name = "devVPC_terraform_sg_allow_ssh_http"
    }
}

# Ingress Security Port 22 (Inbound) - Provides a security group rule resource (https://registry.terraform.io.providers/hashicorp/aws/latest/docs/resources/security_group_rule)

resource "aws_security_group_rule" "devVPC_ssh_ingress_access"{
    from_port = 22
    protocol = "tcp"
    security_group_id = aws_security_group.devVPC_sg_allow_ssh_http.id
    to_port = 22
    type = "ingress"
    cidr_blocks = [var.cidr_blocks]    
}

# Ingress Security Port 80 (Inbound)
resource "aws_security_group_rule" "devVPC_http_ingress_access"{
    from_port = 80 
    protocol = "tcp"
    security_group_id = aws_security_group.devVPC_sg_allow_ssh_http.id
    to_port= 80
    type = "ingress"
    cidr_blocks = [var.cidr_blocks]
}

# Ingress Security Port 8080 (Inbound)
resource "aws_security_group_rule" "devVPC_http8080_ingress_access"{
    from_port = 8080 
    protocol = "tcp"
    security_group_id = aws_security_group.devVPC_sg_allow_ssh_http.id
    to_port= 8080
    type = "ingress"
    cidr_blocks = [var.cidr_blocks]
}

# Egress Security (Outbound)

resource "aws_security_group_rule" "devVPC_egress_access" {
    from_port = 0
    protocol = "-1"
    security_group_id = aws_security_group.devVPC_sg_allow_ssh_http.id
    to_port = 0
    type = "egress"
    cidr_blocks = [var.cidr_blocks]    
}

# Create an Instance using latest Packer AMI and apply Usaer Data
# This allows instances to be created, updated and deleted 
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance

resource "aws_instance" "jenkins-instance"{
    ami=data.aws_ami.packergenericamisjenkins.id
    instance_type=var.instance_type
    key_name= "terraform"
    vpc_security_group_ids = [aws_security_group.devVPC_sg_allow_ssh_http.id]
    subnet_id = aws_subnet.devVPC_public_subnet.id
    user_data = data.template_file.init.rendered
    tags = {
        Name = "dev_terraform_jenkins_instance"
    }
}

# Ingress Security Port 2049 (Inbound)
resource "aws_security_group" "sg_jenkins_efs"{
    name_prefix = "sg_jenkins_efs"
    vpc_id = aws_vpc.devVPC.id

    ingress{
        from_port = 2049
        to_port = 2049
        protocol = "tcp"

        cidr_blocks = [var.cidr_blocks]
    }
}

# Provides an Elastic File System (EFS) File System resource to store JENKINS_HOME

resource "aws_efs_file_system" "jenkins_home_efs"{
    creation_token = "jenkins_home_efs"

    tags= {
        Name = "dev_terraform_jenkins_home"
    }
}

# Provides an Elastic File System (EFS) mount target
resource "aws_efs_mount_target" "jenkins_mount_target" {
    file_system_id = aws_efs_file_system.jenkins_home_efs.id
    subnet_id = aws_subnet.devVPC_public_subnet.id
    security_groups = [aws_security_group.sg_jenkins_efs.id]
}

# Provides an Elastic File System (EFS) access point

resource "aws_efs_access_point" "jenkins_access_point" {
    file_system_id = aws_efs_file_system.jenkins_home_efs.id
    
    root_directory {
        path = "/"
    }
}

# The template file data source usually loaded from an external file.

data "template_file" "init" {
    template = file("${path.module}/userdata.tpl")
}



