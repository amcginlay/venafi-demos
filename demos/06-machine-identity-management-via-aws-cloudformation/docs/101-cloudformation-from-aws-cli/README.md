# 101. Appendix CloudFormation From AWS CLI

## Introduction

The Stack Creation and Updates shown in this workshop can, of course, all be done via the [AWS CLI](https://aws.amazon.com/cli).
The simplest way to gain access to the the CLI for your AWS Account is via [AWS CloudShell](https://aws.amazon.com/cloudshell).

To access CloudShell, navigate to https://us-east-1.console.aws.amazon.com/cloudshell.
This provides a Linux-based terminal environment with the CLI pre-installed, pre-configured and ready to go.

Here's the CLI equivalent of some key steps you take in this workshop.

### Setup Variables

```
STACK_BASE_NAME=johnlennon                                            # <--- PERSONALIZE THIS TO SUIT
CERT_AUTH_PRODUCT=DIGICERT\\Digicert Test Account\\ssl_cloud_wildcard # <--- PERSONALIZE THIS TO SUIT

TLSPCAPIKey=<API_KEY_FROM_TLSPC>
PrivateKeyPassphrase=<PRIVATE_KEY_PASSPHRASE>

ID=${RANDOM}
ZONE=${STACK_BASE_NAME}-${ID}-app\\${STACK_BASE_NAME}-${ID}-cit # <--- BACKSLASHES ESCAPED ('\\')
```

NOTE: the ID variable is a "random" number used to introduce a degree of name uniqueness.
This helps avoid name collisions and is useful when testing

### TLSPC Policy - Create

```
aws cloudformation create-stack \
  --stack-name ${STACK_BASE_NAME}-${ID}-policy \
  --template-url https://venafi-ecosystem.s3.amazonaws.com/tlspc/templates/tlspc-policy.yaml \
  --parameters \
    ParameterKey=CertificateAuthorityProduct,ParameterValue="${CERT_AUTH_PRODUCT}" \
    ParameterKey=Zone,ParameterValue=${ZONE} \
    ParameterKey=MaxValidDays,ParameterValue=90 \
    ParameterKey=Domains,ParameterValue=\"${STACK_BASE_NAME}.com\" \
    ParameterKey=TLSPCAPIKey,ParameterValue=${TLSPCAPIKey}
```

### TLSPC Policy - Update (Domains)

```
aws cloudformation update-stack \
  --stack-name ${STACK_BASE_NAME}-${ID}-policy \
  --template-url https://venafi-ecosystem.s3.amazonaws.com/tlspc/templates/tlspc-policy.yaml \
  --parameters \
    ParameterKey=CertificateAuthorityProduct,UsePreviousValue=true \
    ParameterKey=Zone,UsePreviousValue=true \
    ParameterKey=MaxValidDays,UsePreviousValue=true \
    ParameterKey=Domains,ParameterValue=\"${STACK_BASE_NAME}.com,example.com\" \
    ParameterKey=TLSPCAPIKey,UsePreviousValue=true
```

### TLSPC Certificate - Create

```
aws cloudformation create-stack \
  --stack-name ${STACK_BASE_NAME}-${ID}-cert \
  --template-url https://venafi-ecosystem.s3.amazonaws.com/tlspc/templates/tlspc-certificate.yaml \
  --parameters \
    ParameterKey=Zone,ParameterValue=${ZONE} \
    ParameterKey=CommonName,ParameterValue=www${ID}.${STACK_BASE_NAME}.com \
    ParameterKey=ValidityHours,ParameterValue=0 \
    ParameterKey=RenewalHours,ParameterValue=1440 \
    ParameterKey=TLSPCAPIKey,ParameterValue=${TLSPCAPIKey} \
    ParameterKey=PrivateKeyPassphrase,ParameterValue=${PrivateKeyPassphrase} \
    ParameterKey=TargetS3Bucket,ParameterValue= \
    ParameterKey=UpdateTrigger,ParameterValue=
```

### TLSPC Certificate - Update (Renewals)

```
aws cloudformation update-stack \
  --stack-name ${STACK_BASE_NAME}-${ID}-cert \
  --use-previous-template \
  --parameters \
    ParameterKey=Zone,UsePreviousValue=true \
    ParameterKey=CommonName,UsePreviousValue=true \
    ParameterKey=ValidityHours,UsePreviousValue=true \
    ParameterKey=RenewalHours,UsePreviousValue=true \
    ParameterKey=TLSPCAPIKey,UsePreviousValue=true \
    ParameterKey=PrivateKeyPassphrase,UsePreviousValue=true \
    ParameterKey=TargetS3Bucket,UsePreviousValue=true \
    ParameterKey=UpdateTrigger,ParameterValue=${RANDOM}
```

### TLSPC Policy - Delete

```
aws cloudformation delete-stack \
  --stack-name ${STACK_BASE_NAME}-${ID}-policy
```

### TLSPC Certificate - Delete

```
aws cloudformation delete-stack \
  --stack-name ${STACK_BASE_NAME}-${ID}-cert
```

Next: [Main Menu](../README.md)
