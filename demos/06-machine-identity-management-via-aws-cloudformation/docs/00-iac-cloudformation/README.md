# 00. Infrastructure As Code and AWS CloudFormation

## What is Infrastructure As Code?

[Infrastructure as Code](https://en.wikipedia.org/wiki/Infrastructure_as_code) (IaC) is an approach to **automating** the management and provisioning of infrastructure resources using machine-readable definition files rather than manually configuring infrastructure components.
It involves writing code in a high-level language, such as [YAML](https://en.wikipedia.org/wiki/YAML), to define the desired infrastructure.
Infrastructure declared this way can then be version-controlled, tested, and deployed in a reliable and consistent way.
By defining IaC, developers and operations teams can collaborate more effectively and ensure that infrastructure is consistent across all environments.

## What is AWS CloudFormation?

<p align="center">
  <img src="../images/cfn.png" height="256" width="256" />
</p>

[AWS CloudFormation](https://aws.amazon.com/cloudformation/) is a service provided by Amazon Web Services (AWS) that allows users to define and deploy parameterized IaC templates into your AWS Account.
Each template is capable of managing large collections of interdependent AWS resources, including compute resources such as [EC2](https://aws.amazon.com/ec2) instances, [S3](https://aws.amazon.com/s3) buckets, [SQS](https://aws.amazon.com/sqs) queues, [RDS](https://aws.amazon.com/rds) databases and so on.

[Terraform](https://www.terraform.io/) by Hashicorp is a platform-independent alternative to AWS CloudFormation.

## What are Custom Resources?

<p align="center">
  <img src="../images/iac.png" height="256" width="256" />
</p>

[Custom Resources](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-custom-resources.html) are a feature of AWS CloudFormation that allow users to extend CloudFormation functionality by adding custom code to their templates.
This feature enables users to define new resource types, backed by [Serverless](https://aws.amazon.com/serverless) AWS [Lambda](https://aws.amazon.com/lambda) functions, that are not natively supported by AWS CloudFormation.
Developers can define the code that will be executed when the Custom Resource is created, updated or deleted.

## Why is this important?

<p align="center">
  <img src="../images/tlspc.png" height="256" width="256" />
</p>

The [Venafi Ecosystem](https://marketplace.venafi.com/) team is tasked with making the consumption of Venafi services as frictionless as possible.
Perhaps you run hundreds of EC2 instances and choose [TLS Protect Cloud](https://venafi.com/tls-protect/) (TLSPC) over native AWS services such as [AWS Certificate Manager](https://aws.amazon.com/certificate-manager/) (ACM) in order to benefit from its flexibility and policy enforcement.
You will likely need to mint certificates via TLSPC **before** activating your AWS compute resources.
As such, TLSPC has become a deep-rooted dependency of your infrastructure.
The use of Custom Resources to represent TLSPC capabilities allows you to treat TLSPC as an extension of AWS, ensuring that policy-enforced X.509 certificates are delivered at the point of need, using familiar tools and best practice.

Next: [Main Menu](../README.md) | [01. Requirements, Terminology and Disclaimers](../01-requirements-terminology-and-disclaimers/README.md)
