project_name        = "sre-concepts"
region              = "us-east-1"
aws_region          = "us-east-1"
environment         = "dev"
vpc_cidr            = "10.0.0.0/16"
availability_zones  = ["us-east-1a", "us-east-1b"]
domain_name = "sreconcepts.com"
# this will check if the cert already exists and only create it if it doesn't, which is helpful for iterative development. 
# My srecncepts.com certificate already exists with top level domain for (sreconcepts.com and *.sreconcepts.com)
create_ssl_cert = false
