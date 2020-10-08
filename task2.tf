provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIAXWIFKWW5O5BDS3O6"
  secret_key = "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"
}



resource "aws_security_group" "sg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-bdcdd1d5"

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sgs"
  }
}



resource "tls_private_key" "privatekey" {
  algorithm   = "RSA"
  rsa_bits  = "4096"
}

resource aws_key_pair "key_pair" {
  key_name   = "newkey"
  public_key = tls_private_key.privatekey.public_key_openssh
}





resource "aws_instance" "TERRAFORM" {
  ami           = "ami-0732b62d310b80e97"
  instance_type = "t2.micro"
  vpc_security_group_ids =  [ aws_security_group.sg.id ]
  key_name = "newkey"




connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.privatekey.private_key_pem
    host     = aws_instance.TERRAFORM.public_ip
}
provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd git php -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }


  tags = {
    Name = "TERRAFORM"
  }
}


resource "aws_efs_file_system" "efs" {
  creation_token = "ram1"


  tags = {
    Name = "ram1"
  }
}


resource "aws_efs_mount_target" "mount" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_instance.TERRAFORM.subnet_id


}



resource "null_resource" "rohan" {


depends_on = [  aws_efs_mount_target.mount ]  
  


connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.privatekey.private_key_pem
    host     = aws_instance.TERRAFORM.public_ip
}
provisioner "remote-exec" {
    inline = [
      "sudo yum -y install nfs-utils",
      "sudo echo ${aws_efs_file_system.efs.dns_name}:/var/www/html efs defaults,_netdev 0 0 >> sudo /etc/fstab",
      "sudo mount  ${aws_efs_file_system.efs.dns_name}:/var/www/html",
      "sudo git clone https://github.com/rsshekhawat0/task2hybrid.git  /var/www/html",
      
    ]
  
}
}



resource "aws_s3_bucket" "rohan151" {


   depends_on = [ 
     null_resource.rohan,
 ]
    bucket  = "rohan151"
    acl = "private"
    force_destroy = true
  
}




locals {
  s3_origin_id = "aws_s3_bucket.rohan151.id"
}


resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.rohan151.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
}
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "rohan.jpg"


  logging_config {
    include_cookies = false
    bucket          =  aws_s3_bucket.rohan151.bucket_domain_name


  }




  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id


    forwarded_values {
      query_string = false


      cookies {
        forward = "none"
      }
    }


    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }


  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id


    forwarded_values {
      query_string = false


      cookies {
        forward = "none"
      }
    }


    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }


  price_class = "PriceClass_200"


  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE","IN"]
    }
  }


  tags = {
    Environment = "production"
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  
}
}





resource "null_resource" "nullremote2"  {


depends_on = [


     aws_cloudfront_distribution.s3_distribution,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.privatekey.private_key_pem
    host     = aws_instance.TERRAFORM.public_ip
  }


provisioner "remote-exec" {
  inline = [
   "sudo su << EOF",
   "echo \"<img src='https://${aws_cloudfront_distribution.s3_distribution.domain_name}/rohan.jpg'  width='400' lenght='500' >\" >> /var/www/html/rohan.html",
   "EOF"
  ]
}
}






resource "null_resource" "nulllocal1"  {


  depends_on = [
    null_resource.nullremote2,
  ]


    provisioner "local-exec" {
        command = " start chrome  ${aws_instance.TERRAFORM.public_ip}/rohan.html"
    }
}










