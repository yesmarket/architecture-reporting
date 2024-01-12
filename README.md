# Architecture Reporting

## Overview

There are 2 main parts to this solution -

Firstly, there're some AWS Lambda functions that retrieve page property data from Confluence. This data is then sent to Elastic Cloud, so that we can build some reporting dashboards in Kibana.

There's also an EC2 reverse proxy that injects Kibana auth, so that we can display the reports in Confluence without having to authenticate to Kibana.

Everything in AWS and Elastic Cloud is deployed via IaC.

## Technologies

- git, gitcrypt
- Python
- AWS (IAM, networking/routing, security, Lambda, EC2)
- ElasticSearch (Elastic Cloud)
- Confluence
- Terraform
- Ansible

## Diagram

![alt text](https://github.com/yesmarket/architecture-reporting/assets/10783372/50c32538-4f79-4719-9bff-1e693ccaa01e)
