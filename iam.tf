# Jenkins administrators - IAM group
resource "aws_iam_group" "jenkins-administrators" {
    name = "jenkins-administrators"
}

# Jenkins users - IAM group
resource "aws_iam_group" "jenkins-users" {
    name = "jenkins-users"
}

#Jenkins-admin - IAM user
resource "aws_iam_user" "jenkins-admin" {
    name="jenkins-admin"
}

#jenkins-dev-team - IAM user
resource "aws_iam_user" "jenkins-dev-team"{
    name = "jenkins-dev-team"    
}

#jenkins-test-team - IAM user
resource "aws_iam_user" "jenkins-test-team" {
    name="jenkins-test-team"
}

# admin user assignment to group - manage IAM IAM Group membership for IAM users

resource "aws_iam_group_membership" "jenkins-administrators-users-assignment" {
    name = "jenkins-administrators-users"

    users = [
        aws_iam_user.jenkins-admin.id
    ]
    group = aws_iam_group.jenkins-administrators.id
}

# non-admin users assignment to group

resource "aws_iam_group_membership" "jenkins-users-assignment" {
    name = "jenkins-users"

    users = [
        aws_iam_user.jenkins-dev-team.id,
        aws_iam_user.jenkins-test-team.id
    ]
    group = aws_iam_group.jenkins-users.id
}

# Attaches a Managed IAM Policy to user(s), role(s), and/or group(s) - 
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment

resource "aws_iam_policy_attachment" "jenkins-administrators-policy"{
    name = "jenkins-administrators-policy"
    groups = [aws_iam_group.jenkins-administrators.id]
    policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_policy_attachment" "jenkins-users-policy"{
    name = "jenkins-users-policy"
    groups = [aws_iam_group.jenkins-users.id]
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}
