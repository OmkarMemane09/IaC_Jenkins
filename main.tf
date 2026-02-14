
# Change region if needed
provider "aws" {
  region = "us-east-1" 
}

# ---------------- Launch Templates ----------------
# Change imagi_id ,vpc security group id 
resource "aws_launch_template" "lt-home" {
  name                   = "home"
  image_id               = "ami-0ecb62995f68bb549"
  instance_type          = "t3.micro"
  vpc_security_group_ids = ["sg-09a08028b02863dc8"]

  user_data = base64encode(<<-EOF
#!/bin/bash
apt update -y
apt install -y nginx

cat <<HTML > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
  <title>Home Page</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      background: #f4f6f8;
      margin: 0;
    }
    header {
      background: #1e293b;
      color: white;
      padding: 20px;
      text-align: center;
    }
    section {
      padding: 40px;
      text-align: center;
    }
    .card {
      background: white;
      padding: 20px;
      margin: 20px auto;
      width: 300px;
      box-shadow: 0 4px 10px rgba(0,0,0,0.1);
      border-radius: 10px;
    }
  </style>
</head>
<body>
  <header>
    <h1>🏠 Home Service</h1>
    <p>Welcome to Home Application</p>
  </header>

  <section>
    <div class="card">
      <h3>Section 1</h3>
      <p>This page is served via ALB + ASG</p>
    </div>
    <div class="card">
      <h3>Section 2</h3>
      <p>Infrastructure created using Terraform</p>
    </div>
  </section>
</body>
</html>
HTML

systemctl restart nginx
systemctl enable nginx
EOF
)


  tags = {
    Name = "home"
  }
}
# Change image_id ,vpc security group id 
resource "aws_launch_template" "lt-cloth" {
  name                   = "cloth"
  image_id               = "ami-0ecb62995f68bb549"
  instance_type          = "t3.micro"
  vpc_security_group_ids = ["sg-09a08028b02863dc8"]

  user_data = base64encode(<<-EOF
#!/bin/bash
apt update -y
apt install -y nginx
mkdir -p /var/www/html/cloth

cat <<HTML > /var/www/html/cloth/index.html
<!DOCTYPE html>
<html>
<head>
  <title>Cloth Store</title>
  <style>
    body {
      font-family: Arial;
      background: #fff7ed;
      margin: 0;
    }
    header {
      background: #9a3412;
      color: white;
      padding: 20px;
      text-align: center;
    }
    .products {
      display: flex;
      justify-content: center;
      gap: 20px;
      padding: 40px;
    }
    .product {
      background: white;
      padding: 20px;
      border-radius: 10px;
      width: 200px;
      box-shadow: 0 4px 10px rgba(0,0,0,0.15);
    }
  </style>
</head>
<body>
  <header>
    <h1>👕 Cloth Store</h1>
    <p>Path based routing demo</p>
  </header>

  <div class="products">
    <div class="product">T-Shirt</div>
    <div class="product">Jeans</div>
    <div class="product">Jacket</div>
  </div>
</body>
</html>
HTML

systemctl restart nginx
systemctl enable nginx
EOF
)


  tags = {
    Name = "cloth"
  }
}

# ---------------- Target Groups (with health checks) ----------------
# Change vpc security group id 
resource "aws_lb_target_group" "home-tg" {
  name        = "home-tg"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "vpc-0c8f87c489844e32e"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    interval            = 30
    timeout             = 5
  }
}
# Change vpc security group id 
resource "aws_lb_target_group" "cloth-tg" {
  name        = "cloth-tg"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "vpc-0c8f87c489844e32e"

  health_check {
    # /cloth/ serves index.html created by user-data
    path                = "/cloth/"
    protocol            = "HTTP"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    interval            = 30
    timeout             = 5
  }
}

# ---------------- Application Load Balancer ----------------
# Change vpc security group id ,also give subnets.
resource "aws_lb" "alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["sg-09a08028b02863dc8"]
  subnets = [
    "subnet-062f4a2fe317e3572",
    "subnet-0022322b5ca2dd58e",
    "subnet-0c9de33756c540f6c",
    "subnet-079207882cef10e8e"
  ]
}

resource "aws_lb_listener" "alb-listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.home-tg.arn
  }
}

resource "aws_lb_listener_rule" "rule-cloth" {
  listener_arn = aws_lb_listener.alb-listener.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cloth-tg.arn
  }

  condition {
    path_pattern {
      values = ["/cloth/*"]
    }
  }
}

# ---------------- Auto Scaling Groups ----------------
# Use AZs known to support t3.micro in your account (avoid us-east-1e)
resource "aws_autoscaling_group" "asg-home" {
  name                      = "asg-home"
  availability_zones        = ["us-east-1a", "us-east-1b", "us-east-1c"]
  desired_capacity          = 1
  max_size                  = 1
  min_size                  = 1
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.lt-home.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.home-tg.arn]

  tag {
    key                 = "Name"
    value               = "home"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "asg-cloth" {
  name                      = "asg-cloth"
  availability_zones        = ["us-east-1a", "us-east-1b", "us-east-1c"]
  desired_capacity          = 1
  max_size                  = 1
  min_size                  = 1
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.lt-cloth.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.cloth-tg.arn]

  tag {
    key                 = "Name"
    value               = "cloth"
    propagate_at_launch = true
  }
}

# ---------------- Scaling Policies & Alarms ----------------
resource "aws_autoscaling_policy" "home_scale_down" {
  name                   = "home-scale-down"
  autoscaling_group_name = aws_autoscaling_group.asg-home.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 120
  depends_on             = [aws_autoscaling_group.asg-home]
}

resource "aws_cloudwatch_metric_alarm" "home_scale_down" {
  alarm_description   = "Monitors CPU utilization"
  alarm_actions       = [aws_autoscaling_policy.home_scale_down.arn]
  alarm_name          = "home-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  threshold           = 25
  evaluation_periods  = 5
  period              = 30
  statistic           = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg-home.name
  }
}

resource "aws_autoscaling_policy" "cloth_scale_down" {
  name                   = "cloth-scale-down"
  autoscaling_group_name = aws_autoscaling_group.asg-cloth.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 120
  depends_on             = [aws_autoscaling_group.asg-cloth]
}

resource "aws_cloudwatch_metric_alarm" "cloth_scale_down" {
  alarm_description   = "Monitors CPU utilization"
  alarm_actions       = [aws_autoscaling_policy.cloth_scale_down.arn]
  alarm_name          = "cloth-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  threshold           = 25
  evaluation_periods  = 5
  period              = 30
  statistic           = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg-cloth.name
  }
}
