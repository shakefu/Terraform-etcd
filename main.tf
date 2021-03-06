provider "aws" {
  region  = "${var.adminregion}"
  profile = "${var.adminprofile}"
}

module "base" {
  source          = "./modules/base"
  adminregion     = "${var.adminregion}"
  key_name        = "${var.key_name}"
  public_key_path = "${var.public_key_path}"

  #Locking down Security Groups to your ip
  myip = "${var.myip}"

  vpc_cidr      = "${var.vpc_cidr}"
  private1_cidr = "${var.private1_cidr}"
  private2_cidr = "${var.private2_cidr}"
  public1_cidr  = "${var.public1_cidr}"
  public2_cidr  = "${var.public2_cidr}"

  subnetaz1 = "${var.subnetaz1}"
  subnetaz2 = "${var.subnetaz2}"
}

module "iam" {
  source = "./modules/iam"
}

module "etcd" {
  source = "./modules/etcd"

  #Template variables
  adminregion    = "${var.adminregion}"
  certauthbucket = "${var.certauthbucket}"
  cacertobject   = "${var.cacertobject}"
  etcdbucket     = "${var.etcdbucket}"
  etcdcertobject = "${var.etcdcertobject}"
  etcdkeyobject  = "${var.etcdkeyobject}"

  lc_name              = "${var.lc_name}"
  ownerid              = "${var.ownerid}"
  ami_name             = "${var.ami_name}"
  channel              = "${var.channel}"
  virtualization_type  = "${var.virtualization_type}"
  instance_type        = "${var.coresize}"
  iam_instance_profile = "${module.iam.worker_profile_name}"
  key_name             = "${var.key_name}"
  security_group       = "${module.base.aws_security_group.default.id}"
  userdata             = "Files/kubeetcd.yml.tpl"

  asg_name                        = "${var.asg_name}"
  asg_number_of_instances         = "${var.asg_number_of_instances}"
  asg_minimum_number_of_instances = "${var.asg_minimum_number_of_instances}"

  azs        = ["${lookup(var.subnetaz1, var.adminregion)}", "${lookup(var.subnetaz2, var.adminregion)}"]
  subnet_azs = ["${module.base.aws_subnet.private1.id}", "${module.base.aws_subnet.private2.id}"]

  # To have the etcd instances in public subnets:

  #subnet_azs = ["${module.base.aws_subnet.public1.id}", "${module.base.aws_subnet.public2.id}"]
}

module "etcdbastion" {
  source = "./modules/etcd-bastion"

  #Template variables
  adminregion    = "${var.adminregion}"
  certauthbucket = "${var.certauthbucket}"
  cacertobject   = "${var.cacertobject}"
  etcdbucket     = "${var.etcdbucket}"
  etcdcertobject = "${var.etcdcertobject}"
  etcdkeyobject  = "${var.etcdkeyobject}"

  lc_name              = "${var.bastion_lc_name}"
  ownerid              = "${var.ownerid}"
  ami_name             = "${var.ami_name}"
  channel              = "${var.channel}"
  virtualization_type  = "${var.virtualization_type}"
  instance_type        = "${var.coresize}"
  iam_instance_profile = "${module.iam.worker_profile_name}"
  key_name             = "${var.key_name}"
  security_group       = "${module.base.aws_security_group.default.id}"
  userdata             = "Files/bastion.yml.tpl"

  asg_name                        = "${var.bastion_asg_name}"
  asg_number_of_instances         = "${var.bastion_asg_number_of_instances}"
  asg_minimum_number_of_instances = "${var.bastion_asg_minimum_number_of_instances}"

  etcdasg = "${module.etcd.asg_id}"

  azs        = ["${lookup(var.subnetaz1, var.adminregion)}", "${lookup(var.subnetaz2, var.adminregion)}"]
  subnet_azs = ["${module.base.aws_subnet.public1.id}", "${module.base.aws_subnet.public2.id}"]

  # The etcd bastion(s) is spread between the public subnets
}

module "extractip" {
  source = "./modules/extract"
  ipfile = "Files/iplist.txt"
  asg    = "${module.etcd.asg_id}"
}

module "certauth" {
  source     = "./modules/tls/ca"
  capem      = "ca.pem"
  keypem     = "certauthkey.pem"
  iplistca   = "${split(",", module.extractip.ipcontent)}"
  bucketname = "${var.certauthbucket}"
  certobject = "${var.cacertobject}"
  keyobject  = "${var.cakeyobject}"
}

module "etcd-ca" {
  source             = "./modules/tls/etcd"
  capem              = "etcd.pem"
  keypem             = "etcdkey.pem"
  iplistca           = "${split(",", module.extractip.ipcontent)}"
  ca_cert_pem        = "${module.certauth.ca_cert_pem}"
  ca_private_key_pem = "${module.certauth.ca_private_key_pem}"
  bucketname         = "${var.etcdbucket}"
  certobject         = "${var.etcdcertobject}"
  keyobject          = "${var.etcdkeyobject}"
}
