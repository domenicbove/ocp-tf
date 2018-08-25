# https://access.redhat.com/documentation/en-us/reference_architectures/2018/html/deploying_and_managing_openshift_3.9_on_amazon_web_services/reference_architecture_summary

# in case if tf state is lost
# terraforming aws --tfstate --merge terraform.tfstate --overwrite
# terraforming sg --tfstate --merge terraform.tfstate --overwrite

provider "aws" {
  # access_key = ""
  # secret_key = ""
  region = "${var.region}"
}

output "aws_instance" {
  value = "${aws_instance.bastion.id}"
}
################
# load balancer 
################
resource "aws_lb" "apps" {
    name            = "tf-ocp-lb-apps"
    internal        = false
    load_balancer_type = "network"
    subnets         = ["${aws_subnet.public.*.id}"]
}

# port 80
resource "aws_lb_target_group" "80" {
  depends_on = ["aws_lb.apps"]

  name     = "tf-group-80"
  port     = 80
  protocol = "TCP"
  vpc_id   = "${aws_vpc.default.id}"
}

resource "aws_lb_target_group_attachment" "80" {
  count = 3
  depends_on = ["aws_lb_target_group.80"]

  target_group_arn = "${aws_lb_target_group.80.id}"
  target_id        = "${aws_instance.infras.*.id[count.index]}"
  port             = 80
}

resource "aws_lb_listener" "80" {
  depends_on = ["aws_lb_target_group.80"]

  load_balancer_arn = "${aws_lb.apps.arn}"
  port              = "80"
  protocol          = "TCP"
  default_action {
    target_group_arn = "${aws_lb_target_group.80.arn}"
    type             = "forward"
  }
}

# port 443
resource "aws_lb_target_group" "443" {
  depends_on = ["aws_lb.apps"]
  name     = "tf-group-443"
  port     = 443
  protocol = "TCP"
  vpc_id   = "${aws_vpc.default.id}"
}

resource "aws_lb_target_group_attachment" "443" {
  count = 3
  depends_on = ["aws_lb_target_group.443"]

  target_group_arn = "${aws_lb_target_group.443.id}"
  target_id        = "${aws_instance.infras.*.id[count.index]}"
  port             = 443
}

resource "aws_lb_listener" "443" {
  depends_on = ["aws_lb_target_group.443"]

  load_balancer_arn = "${aws_lb.apps.arn}"
  port              = "443"
  protocol          = "TCP"
  default_action {
    target_group_arn = "${aws_lb_target_group.443.arn}"
    type             = "forward"
  }
}

# port 8443
resource "aws_lb_target_group" "8443" {
  depends_on = ["aws_lb.apps"]
  name     = "tf-group-8443"
  port     = 8443
  protocol = "TCP"
  vpc_id   = "${aws_vpc.default.id}"
}

resource "aws_lb_target_group_attachment" "8443" {
  count = 3
  depends_on = ["aws_lb_target_group.8443"]

  target_group_arn = "${aws_lb_target_group.8443.id}"
  target_id        = "${aws_instance.masters.*.id[count.index]}"
  port             = 8443
}

resource "aws_lb_listener" "8443" {
  depends_on = ["aws_lb_target_group.8443"]

  load_balancer_arn = "${aws_lb.apps.arn}"
  port              = "8443"
  protocol          = "TCP"
  default_action {
    target_group_arn = "${aws_lb_target_group.8443.arn}"
    type             = "forward"
  }
}
#################
# security groups  
#################
resource "aws_security_group" "allowall" {
    name        = "allow_all"
    description = "Allow all traffic"
    vpc_id      = "${aws_vpc.default.id}"
    ingress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "allowssh" {
    name        = "allow_ssh"
    description = "Allow ssh and icmp"
    vpc_id      = "${aws_vpc.default.id}"
    ingress {
        from_port       = 22
        to_port         = 22
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }
    ingress {
        from_port       = 80
        to_port         = 80
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }
    ingress {
        from_port       = -1
        to_port         = -1
        protocol        = "icmp"
        cidr_blocks     = ["0.0.0.0/0"]
    }
    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }
}

##########
# Network 
########## 
resource "aws_vpc" "default" {
  cidr_block           = "10.0.0.0/20"
  enable_dns_hostnames = true

  tags {
    Name = "tf_ocp_vpc"
  }
}

resource "aws_subnet" "private" {
  count = 3
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "${element(var.private_subnets, count.index)}"
  availability_zone       = "${var.region}${element(var.zones, count.index)}"

  tags {
    Name = "tf_ocp_private_${element(var.zones, count.index)}"
  }
}

resource "aws_subnet" "public" {
  count = 3
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "${element(var.public_subnets, count.index)}"
  availability_zone       = "${var.region}${element(var.zones, count.index)}"

  tags {
    Name = "tf_ocp_public_${element(var.zones, count.index)}"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"

  tags {
    Name = "tf_ocp_gw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.default.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }
  tags {
    Name = "tf_ocp_public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.default.id}"
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.default.id}"
  }
  tags {
    Name = "tf_ocp_private"
  }
}

resource "aws_eip" "nat_gw" {
  vpc      = true
}

resource "aws_nat_gateway" "default" {
  depends_on = ["aws_subnet.public","aws_eip.nat_gw"]

  allocation_id = "${aws_eip.nat_gw.id}"
  subnet_id     = "${aws_subnet.public.*.id[count.index]}"

  tags {
    Name = "nat_gw"
  }
}

resource "aws_route_table_association" "private" {
  count = 3
  subnet_id      = "${aws_subnet.private.*.id[count.index]}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_route_table_association" "public" {
  count = 3
  subnet_id      = "${aws_subnet.public.*.id[count.index]}"
  route_table_id = "${aws_route_table.public.id}"
}

###########
# Instances  
###########
resource "aws_key_pair" "default" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.ssh_keys[1])}"
}

resource "aws_instance" "bastion" {
  depends_on = ["aws_security_group.allowssh"]

  ami = "${lookup(var.amis, var.region)}"
  instance_type = "t2.micro"
  availability_zone = "${var.region}${element(var.zones, count.index)}"
  ebs_optimized = false
  associate_public_ip_address = true
  subnet_id = "${aws_subnet.public.*.id[count.index]}"
  key_name = "${aws_key_pair.default.key_name}"
  vpc_security_group_ids = ["${aws_security_group.allowssh.id}"]
  tags = {
    Name = "bastion${count.index+1}${var.dns_prefix}"
    Type = "bastions"
  }
  root_block_device = {
    volume_type = "standard"
    volume_size = "20"
    delete_on_termination = true
  }
  lifecycle {
    prevent_destroy = true
  }  
  provisioner "remote-exec" {
    inline = [ "sudo subscription-manager unregister" ]
    when = "destroy"
    connection {
      type = "ssh"
      host = "${self.public_ip}"
      user = "${var.username}"
      private_key = "${file(var.private_key)}"
    }
    on_failure = "continue"
  }
}

resource "aws_instance" "masters" {
  count = 3
  depends_on = ["aws_security_group.allowall"]


  ami = "${lookup(var.amis, var.region)}"
  instance_type = "${var.instance_type}"
  availability_zone = "${var.region}${element(var.zones, count.index)}"
  ebs_optimized = false
  associate_public_ip_address = false
  subnet_id = "${aws_subnet.private.*.id[count.index]}"
  key_name = "${aws_key_pair.default.key_name}"
  vpc_security_group_ids = ["${aws_security_group.allowall.id}"]
  tags = {
    Name = "master${count.index+1}${var.dns_prefix}"
    Type = "masters"
  }
  root_block_device = {
    volume_type = "standard"
    volume_size = "20"
    delete_on_termination = true
  }
  provisioner "remote-exec" {
    inline = [ "sudo subscription-manager unregister" ]
    when = "destroy"
    connection {
      type = "ssh"
      host = "${self.public_ip}"
      user = "${var.username}"
      private_key = "${file(var.private_key)}"
    }
    on_failure = "continue"
  }
}

resource "aws_instance" "nodes" {
  count = 3
  depends_on = ["aws_security_group.allowall"]


  ami = "${lookup(var.amis, var.region)}"
  instance_type = "${var.instance_type}"
  availability_zone = "${var.region}${element(var.zones, count.index)}"
  ebs_optimized = false
  associate_public_ip_address = false
  subnet_id = "${aws_subnet.private.*.id[count.index]}"
  key_name = "${aws_key_pair.default.key_name}"
  vpc_security_group_ids = ["${aws_security_group.allowall.id}"]
  tags = {
    Name = "node${count.index+1}${var.dns_prefix}"
    Type = "nodes"
  }
  root_block_device = {
    volume_type = "standard"
    volume_size = "20"
    delete_on_termination = true
  }
  provisioner "remote-exec" {
    inline = [ "sudo subscription-manager unregister" ]
    when = "destroy"
    connection {
      type = "ssh"
      host = "${self.public_ip}"
      user = "${var.username}"
      private_key = "${file(var.private_key)}"
    }
    on_failure = "continue"
  }
}

resource "aws_instance" "infras" {
  count = 3
  depends_on = ["aws_security_group.allowall"]

  ami = "${lookup(var.amis, var.region)}"
  instance_type = "${var.instance_type}"
  availability_zone = "${var.region}${element(var.zones, count.index)}"
  ebs_optimized = false
  associate_public_ip_address = false
  subnet_id = "${aws_subnet.private.*.id[count.index]}"
  key_name = "${aws_key_pair.default.key_name}"
  vpc_security_group_ids = ["${aws_security_group.allowall.id}"]
  tags = {
    Name = "infra${count.index+1}${var.dns_prefix}"
    Type = "infras"
  }
  root_block_device = {
    volume_type = "standard"
    volume_size = "20"
    delete_on_termination = true
  }
  ebs_block_device = {
    volume_type = "gp2"
    volume_size = "100"
    delete_on_termination = true
    device_name = "/dev/sdb"
  }
  provisioner "remote-exec" {
    inline = [ "sudo subscription-manager unregister" ]
    when = "destroy"
    connection {
      type = "ssh"
      host = "${self.public_ip}"
      user = "${var.username}"
      private_key = "${file(var.private_key)}"
    }
    on_failure = "continue"
  }
}

#############
# DNS records
#############
resource "aws_route53_record" "bastion" {
  count = 1
  depends_on = ["aws_instance.bastion"]

  zone_id = "${var.zone_id}"
  name = "bastion${count.index+1}"
  type = "A"
  ttl = "300"
  records = ["${aws_instance.bastion.*.public_ip[count.index]}"]
}

resource "aws_route53_record" "console" {
  zone_id = "${var.zone_id}"
  name = "mgmt"
  type = "CNAME"
  ttl = "300"
  records = ["${aws_lb.apps.dns_name}"]
}

resource "aws_route53_record" "apps" {
  zone_id = "${var.zone_id}"
  name = "*.apps"
  type = "CNAME"
  ttl = "300"
  records = ["${aws_lb.apps.dns_name}"]
}

resource "aws_route53_record" "masters" {
  count = 3
  depends_on = ["aws_instance.masters"]

  zone_id = "${var.zone_id}"
  name = "master${count.index+1}"
  type = "A"
  ttl = "300"
  records = ["${aws_instance.masters.*.private_ip[count.index]}"]
}

resource "aws_route53_record" "nodes" {
  count = 3
  depends_on = ["aws_instance.nodes"]

  zone_id = "${var.zone_id}"
  name = "node${count.index+1}"
  type = "A"
  ttl = "300"
  records = ["${aws_instance.nodes.*.private_ip[count.index]}"]
}

resource "aws_route53_record" "infras" {
  count = 3
  depends_on = ["aws_instance.infras"]

  zone_id = "${var.zone_id}"
  name = "infra${count.index+1}"
  type = "A"
  ttl = "300"
  records = ["${aws_instance.infras.*.private_ip[count.index]}"]
}

