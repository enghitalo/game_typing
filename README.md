# game_typing

Typing game

## Deploy to AWS with OpenTofu

Infrastructure-as-code is provided under `infra/` using OpenTofu/Terraform 1.14+ and AWS provider 6.24+ to host the static site via S3 and CloudFront.

### Features

- **S3 bucket** with versioning and server-side encryption (AES256)
- **CloudFront CDN** with HTTP/3, compression, and custom cache policies
- **Origin Access Control (OAC)** for secure S3 access
- **Security headers** including CSP, HSTS, and XSS protection
- **Automatic tagging** via provider default_tags
- **Change detection** using source_hash for efficient updates

### Prerequisites

- AWS account with access keys configured locally (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, optional `AWS_SESSION_TOKEN`).
- OpenTofu CLI installed (`tofu`).

### Using a .env file for AWS credentials

OpenTofu/Terraform do not read `.env` automatically. Load your env vars before running `tofu`:

- Quick load in zsh (temporary for the session):

```zsh
set -a
source .env
set +a
```

- Using `direnv` (recommended):
  - Create `.env`:
    ```
    AWS_ACCESS_KEY_ID=...
    AWS_SECRET_ACCESS_KEY=...
    AWS_SESSION_TOKEN=...   # optional
    AWS_REGION=us-east-1    # optional
    ```
  - Create `.envrc`:
    ```
    export $(grep -v '^#' .env | xargs)
    ```
  - Run `direnv allow`.

Alternatively, use an `AWS_PROFILE` configured in `~/.aws/credentials` and set it via provider:

```hcl
provider "aws" {
	region  = var.aws_region
	profile = var.aws_profile
}
```

Add in `infra/variables.tf`:

```hcl
variable "aws_profile" { type = string default = "default" }
```

Then deploy with:

```zsh
tofu apply -var "aws_profile=my-profile"
```

### One-time setup

```
cd infra
tofu init
```

### Deploy

```
tofu apply -auto-approve
```

Once complete, note the output `cloudfront_domain`. Visit `https://<cloudfront_domain>` to access the app.

### Variables

- `aws_region`: Region for the S3 bucket (default `us-east-1`).
- `bucket_name`: Optional custom bucket name (must be globally unique). Example:

```
tofu apply -var "bucket_name=my-typing-app-123"
```

### Update site content

Any changes to `index.html`, `styles.css`, or `script.js` are uploaded automatically on `tofu apply` (objects are hashed and updated when they change).

### Destroy (optional)

```
tofu destroy
```

Note: Using CloudFront incurs small ongoing costs. Destroy resources when not needed.
