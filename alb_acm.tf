
# #ACM CONFIGURATION
# #Creates ACM issues certificate and requests validation via DNS(Route53)
# resource "aws_acm_certificate" "jenkins_lb_https_cert" {
#   provider          = aws.region-master
#   domain_name       = join(".", ["jenkins", data.aws_route53_zone.dns.name])
#   validation_method = "DNS"
#   tags = {
#     Name = "Jenkins-ACM"
#   }
# }

# #Validates ACM issued certificate via Route53
# resource "aws_acm_certificate_validation" "cert" {
#   provider                = aws.region-master
#   certificate_arn         = aws_acm_certificate.jenkins_lb_https_cert.arn
#   for_each                = aws_route53_record.cert_validation
#   validation_record_fqdns = [aws_route53_record.cert_validation[each.key].fqdn]
# }

####ACM CONFIG END
resource "aws_lb" "jenkins_master_app_loadbalancer" {

  provider           = aws.region-master
  name               = "jenkins-master-app-loadbalancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.loadbalancer_sg.id]
  subnets            = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]
  tags = {
    Name = "Jenkins-LB"
  }
}

resource "aws_lb_target_group" "app-lb-tg" {

  provider    = aws.region-master
  name        = "app-lb-tg"
  vpc_id      = aws_vpc.vpc_master.id
  port        = 8080
  target_type = "instance"
  protocol    = "HTTP"

  health_check {
    enabled  = true
    interval = 10
    path     = "/login"
    port     = 8080
    protocol = "HTTP"
    matcher  = "200-299"
  }
  tags = {
    Name = "jenkins-target-group"
  }
}

# resource "aws_lb_listener" "jenkins_listener_ssl" {

#   provider          = aws.region-master
#   load_balancer_arn = aws_lb.jenkins_master_app_loadbalancer.arn
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   port              = "443"
#   protocol          = "HTTPS"
#   certificate_arn   = aws_acm_certificate.jenkins_lb_https_cert.arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app-lb-tg.arn
#   }
# }

resource "aws_lb_listener" "jenkins_listener_http" {

  provider          = aws.region-master
  load_balancer_arn = aws_lb.jenkins_master_app_loadbalancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app-lb-tg.arn
  }
}

resource "aws_lb_target_group_attachment" "jenkins_master_lb_tg_attach" {

  provider         = aws.region-master
  
  target_group_arn = aws_lb_target_group.app-lb-tg.arn
  target_id        = aws_instance.jenkins_master.id
  port             = 8080
}
