resource "aws_lb" "this" {
  name               = "${var.env_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = [var.alb_sg_id]
  tags               = var.tags
}



resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
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

# HTTPS Listener (port 443)
resource "aws_lb_listener" "https" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn
  
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = "{\"error\":\"Unauthorized\",\"message\":\"Access denied\"}"
      status_code  = "401"
    }
  }
}

output "alb_arn" {
  value = aws_lb.this.arn
}
output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "security_group_id" {
  value = var.alb_sg_id
}
output "listener_arn" {
  value = aws_lb_listener.http.arn
}
output "https_listener_arn" {
  value = var.enable_https ? aws_lb_listener.https[0].arn : ""
} 