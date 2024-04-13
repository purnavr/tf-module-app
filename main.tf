resource "aws_launch_template" "main" {
  name = "${var.component}-${var.env}"

  iam_instance_profile {
    name = aws_iam_instance_profile.main.name
  }

  image_id = data.aws_ami.ami.id

  instance_market_options {
    market_type = "spot"
  }

  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.main.id]


  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.tags,
      { Name = "${var.component}-${var.env}", monitor = "yes" }
    )
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    component = var.component
    env = var.env
  } ))
}

resource "aws_autoscaling_group" "main" {
  name = "${var.component}-${var.env}"
  desired_capacity   = var.desired_capacity
  max_size           = var.max_size
  min_size           = var.min_size
  vpc_zone_identifier = var.subnets
  target_group_arns = [aws_lb_target_group.main.arn]

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    propagate_at_launch = false
    value               = "${var.component}-${var.env}"
  }
}

resource "aws_security_group" "main" {
  name        = "${var.component}-${var.env}"
  description = "${var.component}-${var.env}"
  vpc_id      = var.vpc_id

  ingress {
    description = "APP"
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = var.allow_app_to
  }

  ingress {
    description = "PROMETHEUS"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = var.monitoring_nodes
  }

  tags = merge(
    var.tags,
    { Name = "${var.component}-${var.env}" }
  )
}

resource "aws_vpc_security_group_ingress_rule" "ingress" {
  security_group_id = aws_security_group.main.id
  cidr_ipv4         = var.bastion_cidr
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  description = "SSH"
}


#resource "aws_vpc_security_group_ingress_rule" "ingress2" {
#  security_group_id = aws_security_group.main.id
#  cidr_ipv4         = var.allow_app_to
#  from_port         = var.port
#  ip_protocol       = "tcp"
#  to_port           = var.port
#  description = "APP"
#}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.main.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_lb_target_group" "main" {
  name     = "${var.component}-${var.env}"
  port     = var.port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    enabled = true
    healthy_threshold = 2
    unhealthy_threshold = 2
    interval = 5
    timeout = 4
    path = "/health"
  }
  tags = merge(
    var.tags,
    { Name = "${var.component}-${var.env}" }
  )
}

resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = local.dns_name
  type    = "CNAME"
  ttl     = 30
  records = [var.alb_dns_name]
}

resource "aws_lb_listener_rule" "listener" {
  listener_arn = var.listener_arn
  priority     = var.listener_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    host_header {
      values = [local.dns_name]
    }
  }
}

