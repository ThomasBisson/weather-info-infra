# Weather-info-be
The infra of the weather info web application. This application is made as a test for me by the Stack Labs company.

# How to install the project in local
This project pushes some resources to Amazon AWS using Terraform so you will need these 2 tools.

## Terraform CLI
Go to https://developer.hashicorp.com/terraform/install and install Terraform on your computer.
Use this command to be in the dev workspace:
```console
$ terraform workspace select dev
```

## AWS CLI
Go to https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html and install the aws cli on your computer.
Then fill your credential with:
```console
$ aws configure
```
To find AWS Access Key ID and AWS Secret Access Key you need to email me so I can give you some credentials.
The region name is **eu-west-1** for Irland and no need to fill the output format.

# Workspaces
This project contains 2 workspaces to handle different environments :
- dev
- prod

# Architecture
For the moment the project has everything put into the main file and no variable, the only reason for that is a lack of time. In the future, the architecture will be a bit better.
