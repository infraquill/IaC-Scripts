# Azure DevOps Subscription Creation

This repo automates creation of a brand new Azure subscription, assigns it to a Management Group, and applies tags.

## Why this layout?
- **pipelines/** holds the Azure DevOps pipeline definition (`create-subscription.yml`).
- **scripts/** holds bash scripts that do the real work using Azure CLI.
  - Easier to review, version, and reuse.
  - Pipeline YAML stays short and readable.

## Flow
1. `create_subscription.sh`
   - Uses your SPN service connection.
   - Creates the subscription alias.
   - Polls until the sub is `Enabled`.
   - Exposes `newSubscriptionId` back to the pipeline.

2. `finalize_subscription.sh`
   - Adds the new subscription into your target Management Group.
   - Applies tags.
   - Prints a final summary table.

## Setup in Azure DevOps
1. Add a Service Connection that logs in with your Subscription Creator SPN and has MG rights.
2. Update `azureServiceConnection` in the YAML to that name.
3. Update parameter defaults for:
   - `billingScope`
   - `managementGroupId`
   - optional `tags`

## Run
- In DevOps, create a pipeline from `pipelines/create-subscription.yml`.
- Run it manually, override parameters if needed.
- The job log will show:
  - timestamps
  - alias request
  - poll state
  - final summary (subscriptionId, MG, tags)
