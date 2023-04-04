provider "aws"{
    region = "us-west-2"
}

#Get latest AMI ID based on Filter - Here AMI created using packer

data "aws_ami" "packeramis"{
  owners= ["052784389769"]
  most_recent=true

  filter{
    name = "name"
    values=["packer-cf*"]
  }
}

#Provides an EC2 instance resource. 
resource aws_instance "provisionerTestVM"{
  ami=var.AMIS[var.AWS_REGION]
  instance_type="t2.micro"

  provisioner "local-exec"{
    command = "echo Instance Type=${self.instance_type},Instance ID=${self.id},Public DNS=${self.public_dns},AMI ID=${self.ami} >> allinstancedetails"
  }
}