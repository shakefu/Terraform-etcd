# Terraform scripts for a HA etcd Cluster
### This script creates:

- 3 x t2.micro CoreOS EC2 instances - etcd servers - private subnet
- 1 x t2.micro CoreOS EC2 instances - bastion (etcd proxy) - public subnet
- A VPC that spans 2 AZs.
- 4 Subnets (2 private, 2 public. 1 of each per AZ) - the etcd instances = private subnets, etcd proxy = public
- An autoscaling group and launch configuration.
- Launch config utlizes EC2 userdata template
- EC2 userdata = cloud-init + etcd discovery via Monsanto method (referenced below) + etcd certs via aws s3getobject container
- EC2 security groups, egress = all traffic, ingress locked internally to VPC and variable "myip" (default == 0.0.0.0/0 in tfvars)
- An IAM role for the etcd instances.
- An S3 bucket for the certificate authority cert (ca.pem)
- An S3 bucket for the etcd locally signed cert and key (etcd.pem, etcdkey.pem)
- All S3 objects are KMS encrypted with the keypolicy only allowing decryption by the terraform user and by the instances
- Due to bug in IAM and keypolicy dependencies, local-exec, jq and AWScli are used to retrive the role ARNs for the keypolicy.json

### To Improve:
- I am currently waiting on module dependencies to be implemented: https://github.com/hashicorp/terraform/issues/10462

### To use:

Pre-requisites: Terraform, jq, AWS CLI and SSH Keys

```
1. Modify terraform.tfvars as you wish
2. terraform get && terraform plan
3. terraform apply
```

### To check if its function correctly:

```
1. SSH into the bastion
2. Run "etcdctl cluster-health"
3. If 3 nodes show as healthy, you're good to go, else destroy and retry
```


### Extra steps:

Change "myip" in tfvars to your ip to lockdown public instance IPs

Change etcd cluster size by modifying terraform.tfvars:
- asg_number_of_instances = "3"
- asg_minimum_number_of_instances = "3"

Note: cluster size must be an odd number

###Version info:

 Working and Tested as of 10/01/17
 Terraform version: 0.8.3

### Features to implement in the future:

Integrate with Kubernetes - Terraform scripts

Use a dynamic method of regenerating the SSL certificate on each new node

Improve documentation

### References

- https://github.com/Capgemini/kubeform
- http://engineering.monsanto.com/2015/06/12/etcd-clustering/
- https://coreos.com/etcd/docs/latest/v2/clustering.html
- Kelsey Hightower's stuff
