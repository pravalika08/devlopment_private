output "vpc_id" {
  value = aws_vpc.dev_vpc.id
}
output "security_group_id" {
  value = aws_security_group.sg_0106.id
}
output "public_subnet" {
  value = aws_subnet.public_subnet.id
}
output "private_subnet" {
  value = aws_subnet.private_subnet.id
}
/*output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}*/
