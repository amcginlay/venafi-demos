# 03. TLSPC Application Automation

## What you will learn

In this section you will use CloudFormation (sometimes abbreviated to CFN, or just CF) to deploy a Custom Resource representing a single Application in TLSPC.

## TLSPCApplication Templates and Functions

This exercise will make use of two objects stored in a publicly accessible (read-only) S3 bucket.
They are as follows:

| Type | Description | S3 | Source |
| - | - | - | - |
| Template | Orchestrates the lifecycle of a TLSPCApplication Custom Resource which references the Function | https://venafi-ecosystem.s3.amazonaws.com/tlspc/templates/tlspc-application.yaml | [View](../../tlspc/templates/tlspc-application.yaml)  |
| Function | Implements the Create/Update/Delete operations required by the TLSPCApplication Custom Resource | https://venafi-ecosystem.s3.amazonaws.com/tlspc/functions/tlspc-application.zip | [View](../../tlspc/functions/tlspc-application/app/app.py) |

## A note on Defaults and warning messages

Unless otherwise stated, all console settings should be left in their **DEFAULT** state.

Any warning banners which appear in the AWS Console during these steps are typically caused by policy restrictions in the target AWS Account and can be safely **IGNORED**.

## Creating your Application Stack

The following steps will model your Application requirements in a Cloudformation Stack and realize these inside TLSPC.
This Application will be used later to create certificates.

1. Navigate to https://us-east-1.console.aws.amazon.com/cloudformation/home
1. Click on "Create stack", then click "With new resources (standard)"
1. On the "Create stack" page, under "Specify template", set **"Amazon S3 URL"** to
   ```
   https://venafi-ecosystem.s3.amazonaws.com/tlspc/templates/tlspc-application.yaml
   ```
   then click "Next"
1. On the "Specify stack details" page:
   - Set **"Stack name"** to something uniquely identifiable for **yourself**, plus the letters "-app".
     Stack name can include letters (A-Z and a-z), numbers (0-9), and dashes (-).
     For example, John Lennon could use
     ```
     johnlennon-app
     ```
   - Set **"AppName"** to the **same value** you just used for the "Stack name"
   - Set **"AppDescription"** to
     ```
     I created this TLSPC application!
     ```
   - Set **"IssuingTemplateName"** to
     ```
     Default
     ```
     (see the NOTE below if this is missing from your TLSPC Account)
   - Set **"CertificateAuthority"** to
     ```
     BUILTIN
     ```
   - Set **"TLSPCAPIKey"** to whatever API Key value is provided to you at https://ui.venafi.cloud/platform-settings/user-preferences?key=api-keys
   - Click "Next"
1. On the "Configure stack options" page, under "Stack failure options", select **"Preserve successfully provisioned resources"**
1. Scroll to the foot of the "Review" page and finally click "Submit"

**NOTE**: A pristine TLSPC environment ships with the `Default` Issuing Template for the `Built-In CA`.
If your TLSPC environment has this Issuing Template renamed or is somehow missing, choose an alternate `Built-In CA` Issuing Template from the list shown at https://ui.venafi.cloud/certificate-issuance/issuing-templates.

<p align="center">
  <img src="../images/cfn-create-complete.png" />
</p>

After ~30 secs, the Stack will reach a "Status" of "CREATE_COMPLETE".

## Reviewing your results

At this point your newly created TLSPC Application will become visible at https://ui.venafi.cloud/certificate-issuance/applications

## Updating your Application Stack

The following steps will update your Application in TLSPC.
In doing so, you will familiarize yourself with the process for updating Stacks in CloudFormation.

1. Navigate to https://us-east-1.console.aws.amazon.com/cloudformation/home
1. Find or search for your Stack using the name you provided earlier.
1. The Stack name is displayed as a blue hyperlink.
   Click this link now.
1. Take a moment to browse over tabs which are on display.
   Here are some observations regarding these tabs.
   - **Stack info** - This tab includes the system generated Stack ID. This is an example of an Amazon Resource Name (ARN) which is a system-generated identifier assigned to all AWS resources.
   These identifiers are universally unique within the AWS cloud.
   - **Events** - Details the steps CloudFormation has taken to (one hopes) successfully translate your parameterized Template into a Stack.
   The Events tab is usually your first port of call when investigating CloudFormation failures.
   - **Resources** - A list of the resources (Native AWS and Custom) which CloudFormation created for you. You will observe that your Stack has one Lambda Function and one TLSPCApplication.
   In the column  named Physical ID you will find a handy blue hyperlink to the Lambda function.
   The TLSPCApplication also has a collection of letters and numbers known as the Physical ID.
   **Ask yourself, what do you think this represents?**
   - **Outputs** - Outputs are selected informative results of successful runs. For example, if your stack creates a database entry CloudFormation could deposit a unique identifier here.
   - **Parameters** - A copy of the Parameters used when the Stack was Created or Updated.
   - **Template** - A copy of the Template used when the Stack was Created or Updated.
   - **Change sets** - This feature is beyond scope for today.
1. In the upper-right portion of the screen you will see 4 buttons.
   Locate the "Update" button and click it.
1. On the "Update stack" page, click "Next".
1. On the "Specify stack details" page:
   - Change **"AppDescription"** to
     ```
     I updated this TLSPC application!
     ```
   - Click "Next"
1. Scroll to the foot of the "Configure stack options" page, then click "Next"
1. Scroll to the foot of the "Review" page and finally click "Submit"

<p align="center">
  <img src="../images/cfn-update-complete.png" />
</p>

After ~30 secs, the stack will reach a "Status" of "UPDATE_COMPLETE".

At this point your newly updated TLSPC Application will become visible at https://ui.venafi.cloud/certificate-issuance/applications

Next: [Main Menu](../README.md)
