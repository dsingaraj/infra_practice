#!/bin/bash
sudo yum update -y
sudo yum install nfs-utils

# Mount EFS Mount Access point
sudo mkdir /root/.jenkins
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-00cb946fe487f02ec.efs.us-west-2.amazonaws.com:/ /root/.jenkins 