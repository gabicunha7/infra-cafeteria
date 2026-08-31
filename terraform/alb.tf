# ALB publico front-a e front-b 
resource "aws_lb" "public" {
  name               = "${var.project_name}-alb-public"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_public.id]
  subnets            = [aws_subnet.public_front_a.id, aws_subnet.public_front_b.id]

  tags = { Name = "${var.project_name}-alb-public" }
}

resource "aws_lb_target_group" "front" {
  name     = "${var.project_name}-tg-front"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "${var.project_name}-tg-front" }
}

resource "aws_lb_target_group_attachment" "front_a" {
  target_group_arn = aws_lb_target_group.front.arn
  target_id        = aws_instance.front_a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "front_b" {
  target_group_arn = aws_lb_target_group.front.arn
  target_id        = aws_instance.front_b.id
  port             = 80
}

resource "aws_lb_listener" "public_http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front.arn
  }
}

# ALB interno roteia entre backend-a e backend-b 
resource "aws_lb" "internal" {
  name               = "${var.project_name}-alb-backend"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_internal.id]
  subnets            = [aws_subnet.private_backend_a.id, aws_subnet.private_backend_b.id]

  tags = { Name = "${var.project_name}-alb-backend" }
}

resource "aws_lb_target_group" "backend" {
  name     = "${var.project_name}-tg-backend"
  port     = var.backend_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399" 
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "${var.project_name}-tg-backend" }
}

resource "aws_lb_target_group_attachment" "backend_a" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.backend_a.id
  port             = var.backend_port
}

resource "aws_lb_target_group_attachment" "backend_b" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.backend_b.id
  port             = var.backend_port
}

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = var.backend_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
