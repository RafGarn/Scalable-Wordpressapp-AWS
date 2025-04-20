# Scalable-Wordpressapp-AWS

## Steps

### 1. Create Ubuntu VM and Apache Site
- Launch an Ubuntu virtual machine (EC2).
- Install Apache and configure a virtual host-using the script i provided  in APACHE_SITE.
- Assign a custom domain (e.g., via `site.com`) to the server, php version you want to use.

### 2. Create an image from you ec2 machine
- After your server is fully configured (Apache, PHP, domain), create an Amazon Machine Image (AMI).
- This AMI will be used in the CloudFormation template to scale your WordPress site.

### 3. CloudFormation Template
Use your CloudFormation template to deploy the following infrastructure:
**Application Load Balancer (ALB)**
**Auto Scaling Group (ASG)**
**Launch Template**
**RDS (Relational Database Service)**
**Security Groups**
