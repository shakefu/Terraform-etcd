data "template_file" "kubebastion" {
  template = "${file("${path.module}/${var.userdata}")}"

  vars {
    etcdasg = "${var.etcdasg}"
  }
}

data "aws_ami" "coreos_bastion" {
  most_recent = true

  owners = ["${var.ownerid}"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["${var.virtualization_type}"]
  }

  filter {
    name   = "name"
    values = ["${var.ami_name}-${var.channel}-*"]
  }
}

resource "aws_launch_configuration" "launch_config" {
  name                 = "${var.lc_name}"
  image_id             = "${data.aws_ami.coreos_bastion.image_id}"
  instance_type        = "${var.instance_type}"
  iam_instance_profile = "${var.iam_instance_profile}"
  key_name             = "${var.key_name}"
  security_groups      = ["${var.security_group}"]
  user_data            = "${data.template_file.kubebastion.rendered}"
}

resource "aws_autoscaling_group" "bastion_asg" {
  depends_on = ["aws_launch_configuration.launch_config"]
  name       = "${var.asg_name}"

  availability_zones  = ["${var.azs}"]
  vpc_zone_identifier = ["${var.subnet_azs}"]

  launch_configuration = "${aws_launch_configuration.launch_config.id}"

  max_size                  = "${var.asg_number_of_instances}"
  min_size                  = "${var.asg_minimum_number_of_instances}"
  desired_capacity          = "${var.asg_number_of_instances}"
  health_check_grace_period = "${var.health_check_grace_period}"
  health_check_type         = "${var.health_check_type}"

  tag {
    key                 = "Name"
    value               = "bastion"
    propagate_at_launch = true
  }
}
