# resource "aws_instance" "ec2_instance" {
#   ami=var.AMIS[var.AWS_REGION] 
#   instance_type = "t2.micro"
#   associate_public_ip_address = true

#   tags = {
#     Name = "Terraform_test_ec2"
#   }
# }
# output public_ip{
#   value=aws_instance.ec2_instance.public_ip
# }
# resource "aws_instance" "webserver" {
#   for_each = var.webservers
#     ami=var.AMIS[var.AWS_REGION] 
#     instance_type = "t2.micro"
#     associate_public_ip_address = true

#     tags = {
#       Name = each.value["name"]
#     }
# }

data "aws_availability_zones" "available"{}

# VPC Creation using CIDR block available in vars.tf

resource "aws_vpc" "provisionerVPC"{
    cidr_block = var.vpc_cidr
    enable_dns_hostnames=true
    enable_dns_support = true

    tags = {
        Name = "dev-terraform-vpc"
    }
}

# Public subnet public CIDR block available in vars.tf and provisionersVPC

resource "aws_subnet" "public_subnet"{
    cidr_block = var.public_cidr
    vpc_id = aws_vpc.provisionerVPC.id
    map_public_ip_on_launch = true
    availability_zone = data.aws_availability_zones.available.names[1]

    tags = {
        Name = "dev-public-subnet"
    }    
}

# To access EC2 instance inside a virtual private cloud we need an Internet Gateway and a routing table connecting the subnetto the Internet Gateway

# Creating Internet Gateway

resource "aws_internet_gateway" "gw"{
    vpc_id = aws_vpc.provisionerVPC.id

    tags = {
        Name = "dev-gw"
    }
}

# Public Route Table
resource "aws_route_table" "public_route"{
    vpc_id = aws_vpc.provisionerVPC.id

    route {
        cidr_block = var.cidr_blocks
        gateway_id = aws_internet_gateway.gw.id
    }
    tags = {
      Name = "dev-public-route"  
    }
}

# Associate Public Subnet with Public Route Table

resource "aws_route_table_association" "public_subnet_assoc"{
    count = 1
    route_table_id = aws_route_table.public_route.id
    subnet_id = aws_subnet.public_subnet.id
    depends_on = [aws_route_table.public_route,aws_subnet.public_subnet]    
}

# Security Group Creation for provisionerVPC

resource "aws_security_group" "dev_terraform_sg_allow_ssh_http"{
    name="dev-sg"
    vpc_id = aws_vpc.provisionerVPC.id
}

# Ingress Security Port 22 (Inbound)
resource "aws_security_group_rule" "ssh_ingress_access"{
    from_port = 22
    protocol = "tcp"
    security_group_id = aws_security_group.dev_terraform_sg_allow_ssh_http.id
    to_port = 22
    type = "ingress"
    cidr_blocks = [var.cidr_blocks]
}

# Ingress Security Port 80 (Inbound)
resource "aws_security_group_rule" "http_ingress_access"{
    from_port = 80
    protocol = "tcp"
    security_group_id = aws_security_group.dev_terraform_sg_allow_ssh_http.id
    to_port = 80
    type = "ingress"
    cidr_blocks = [var.cidr_blocks]
}

# All egress/outbound Access

resource "aws_security_group_rule" "all_egress_access"{
    from_port = 0
    protocol = "-1"
    security_group_id = aws_security_group.dev_terraform_sg_allow_ssh_http.id
    to_port = 0
    type = "egress"
    cidr_blocks = [var.cidr_blocks]
}

# Instance Configuration
resource "aws_instance" "provisioner-remoteVM"{
    ami = "ami-0d2017e886fc2c0ab"
    instance_type = var.instance_type
    key_name = "terraform"
    vpc_security_group_ids = [aws_security_group.dev_terraform_sg_allow_ssh_http.id]
    subnet_id = aws_subnet.public_subnet.id

    tags = {
        Name = "remote-instance"
    }

    provisioner "remote-exec"{
        inline = [
            "sudo yum update -y",
            "sudo yum install -y nginx",
            "sudo service nginx start"
        ]
        on_failure = continue
    }
    provisioner "local-exec"{

        #ami=data.aws_ami.packeramis.id
        #instance_type="t2.micro"
        #when = "destroy"
        command = "echo Instance Type=${self.instance_type},Instance ID=${self.id},Public DNS=${self.public_dns},AMI ID=${self.ami} >> allinstancedetails"
    }
    connection {
        type = "ssh"
        host = aws_instance.provisioner-remoteVM.public_ip
        user = "ec2-user"
        private_key=file("${path.module}/terraform.pem")
    }

}