provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

resource "aws_instance" "web_server" {
  ami                         = "ami-0c24ee2a1e3b9df45"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [data.aws_security_group.ec2-sg.id]
  subnet_id                   = data.aws_subnet.subnet_1.id
  availability_zone           = "eu-west-1a"
  associate_public_ip_address = true
  user_data                   = <<-EOF
    #!/bin/bash
        sudo yum update -y
        sudo yum install -y git
        sudo yum install -y npm
        sudo git clone https://github.com/Romarionijim/simple-express-code.git
        cd simple-express-code
        npm ci
        node app.js
  EOF
  user_data_replace_on_change = true
  key_name                    = "ec2-lb"
}

data "aws_vpc" "dev_vpc" {
  tags = {
    Name = "dev-vpc"
  }
}

data "aws_subnet" "subnet_1" {
  tags = {
    Name = "public-subnet-1"
  }
}

data "aws_subnet" "subnet_2" {
  tags = {
    Name = "public-subnet-2"
  }
}

data "aws_security_group" "ec2-sg" {
  tags = {
    Name = "EC2-SG"
  }
}

data "aws_security_group" "alb-sg" {
  tags = {
    Name = "ALB-SG"
  }
}

resource "aws_alb" "alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.aws_security_group.alb-sg.id]
  subnets            = [data.aws_subnet.subnet_1.id, data.aws_subnet.subnet_2.id]
  tags = {
    Name = "dev-alb"
  }
}

resource "aws_alb_listener" "http_port_80" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb_listener" "https_port_443" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.certificate.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_1.arn
  }
}

resource "aws_lb_target_group" "target_group_1" {
  name             = "target-group-1"
  target_type      = "instance"
  protocol         = "HTTP"
  port             = 3000
  vpc_id           = data.aws_vpc.dev_vpc.id
  protocol_version = "HTTP1"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    interval            = 30
    port                = 3000
    matcher             = 200
  }
}

resource "aws_lb_target_group" "target_group_2" {
  name             = "target-group-2"
  target_type      = "instance"
  protocol         = "HTTP"
  port             = 3000
  vpc_id           = data.aws_vpc.dev_vpc.id
  protocol_version = "HTTP1"
  health_check {
    path                = "/about"
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    interval            = 30
    port                = 3000
    matcher             = 200
  }
}

resource "aws_lb_target_group" "target_group_3" {
  name             = "target-group-3"
  target_type      = "instance"
  protocol         = "HTTP"
  port             = 3000
  vpc_id           = data.aws_vpc.dev_vpc.id
  protocol_version = "HTTP1"
  health_check {
    path                = "/edit"
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    interval            = 30
    port                = 3000
    matcher             = 200
  }
}

resource "aws_alb_listener_rule" "rule_1" {
  listener_arn = aws_alb_listener.https_port_443.arn
  priority     = 1
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_1.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

resource "aws_alb_listener_rule" "rule_2" {
  listener_arn = aws_alb_listener.https_port_443.arn
  priority     = 2
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_2.arn
  }

  condition {
    path_pattern {
      values = ["/about"]
    }
  }
}

resource "aws_alb_listener_rule" "rule_3" {
  listener_arn = aws_alb_listener.https_port_443.arn
  priority     = 3
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_3.arn
  }

  condition {
    path_pattern {
      values = ["/edit"]
    }
  }
}

resource "aws_lb_target_group_attachment" "attachment_1" {
  target_group_arn = aws_lb_target_group.target_group_1.arn
  target_id        = aws_instance.web_server.id
  port             = 3000
  depends_on       = [aws_instance.web_server]
}

resource "aws_lb_target_group_attachment" "attachment_2" {
  target_group_arn = aws_lb_target_group.target_group_2.arn
  target_id        = aws_instance.web_server.id
  port             = 3000
  depends_on       = [aws_instance.web_server]

}

resource "aws_lb_target_group_attachment" "attachment_3" {
  target_group_arn = aws_lb_target_group.target_group_3.arn
  target_id        = aws_instance.web_server.id
  port             = 3000
  depends_on       = [aws_instance.web_server]

}

data "aws_acm_certificate" "certificate" {
  domain      = "testautomation-devops.net"
  statuses    = ["ISSUED"]
  most_recent = true
}
