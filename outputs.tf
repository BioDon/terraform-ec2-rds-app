output "webserver_ips" {
  description = "The Public IP address(es) of the EC2 Instance(s)"
  value       = aws_instance.project-web[0].public_ip
  depends_on  = [aws_instance.project-web]
}

output "web_public_dns" {
  description = "The Public DNS name(s) of the EC2 Instance(s)"
  value       = aws_instance.project-web[0].public_dns
  depends_on  = [aws_instance.project-web]
}

output "db_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.projectdatabase.address
  depends_on  = [aws_db_instance.projectdatabase]
}

output "db_port" {
  description = "The port of the database"
  value       = aws_db_instance.projectdatabase.port
}