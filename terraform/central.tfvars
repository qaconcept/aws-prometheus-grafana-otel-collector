project_name        = "sre-concepts"
region              = "us-east-1"
aws_region          = "us-east-1"
environment         = "dev"
vpc_cidr            = "10.0.0.0/16"
availability_zones  = ["us-east-1a", "us-east-1b"]
domain_name = "sreconcepts.com"
# Set to true to create a new ACM cert, false to use the existing one
create_ssl_cert = false
