## Project Structure

This repo is organized to support a microservices platform on **AWS** using **Terraform**, **Docker**, and **Kubernetes (EKS)**.

- `services/`
  - `java/`
    - `order-service/`
    - `user-service/`
  - `python/`
    - `data-service/`
- `docker/`
  - (Optional) shared Dockerfiles or build scripts.
- `infra/`
  - `terraform/`
    - `envs/`
      - `dev/`
      - `prod/`
    - `modules/`
      - `network/`   (VPC, subnets, security groups)
      - `eks/`       (EKS cluster + node groups)
      - `rds/`       (Postgres on RDS)
      - `redis/`     (ElastiCache or Redis)
      - `mq/`        (SQS/MSK or RabbitMQ/Kafka)
      - `gateway/`   (API Gateway + ALB)
      - `cdn/`       (S3 + CloudFront)
- `k8s/`
  - `base/`
    - `services/`   (Deployments/Services/Ingress templates, e.g. `file-downloader`)
    - `infra/`      (in-cluster infra like MinIO, Redis, MQ, ingress controllers)
  - `overlays/`
    - `dev/`
    - `prod/`
- `scripts/`
  - Helper scripts for builds, deployments, and tooling.

## Local development with Minikube

### Prerequisites

- Minikube running with a Kubernetes cluster.
- Docker CLI configured to use Minikube's Docker daemon when building images.

### One-click local cluster setup (`scripts/minikube-helm.sh`)

For a full local setup (namespace, RBAC, MinIO, and the FileDownloader service), you can use the helper script:

```bash
cd /home/seanfos/workdir/YTR
bash scripts/minikube-helm.sh
```

The script will:

- Start Minikube (or reuse an existing cluster).
- Enable the ingress addon.
- Point Docker to Minikube's Docker daemon and build the `file-downloader:latest` image from `services/python/FileDownloader`.
- Apply:
  - `infra/k8s/base/namespaces/ytr-namespace.yaml`
  - `infra/k8s/base/rbac/file-downloader-*.yaml`
  - `infra/k8s/base/infra/minio.yaml`
  - `infra/k8s/base/services/file-downloader.yaml`

After it completes, you can inspect resources with:

```bash
kubectl get pods,svc -n ytr
```

### MinIO (in-cluster object storage)

MinIO is deployed via Kubernetes manifests under `k8s/base/infra/minio.yaml`. It includes:

- A `Secret` named `minio-creds` that stores `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD`.
- A `Deployment` and `Service` named `minio` exposing:
  - API on port `9000`.
  - Console on port `9090`.

To deploy MinIO into Minikube:

```bash
cd /home/seanfos/workdir/YTR
kubectl apply -f infra/k8s/base/infra/minio.yaml
```

You can access the MinIO console locally with:

```bash
kubectl port-forward svc/minio 9090:9090
# then open http://localhost:9090 (user: minioadmin / pass: minioadmin)
```

### FileDownloader service (YouTube → MinIO Raw Videos bucket)

The Python `FileDownloader` microservice lives under `services/python/FileDownloader` and exposes a REST API:

- `GET /health` – basic health check.
- `POST /download` – accepts JSON body `{ "url": "<YouTube URL>" }`, downloads the video using `yt-dlp`, and uploads it to the MinIO **Raw Videos** bucket.

The service runs on port **8000** and uses FastAPI.

Kubernetes manifests for this service are in `infra/k8s/base/services/file-downloader.yaml`. The `Deployment`:

- Uses image `file-downloader:latest`.
- Reads MinIO connection details from:
  - `MINIO_ENDPOINT` (`minio:9000`)
  - `RAW_VIDEOS_BUCKET` (`raw-videos`)
  - `MINIO_SECURE` (`false`)
  - `minio-creds` secret (for credentials).

The Python code relies on these env vars and does **not** create MinIO or buckets; that is handled by infra.

### Running FileDownloader in Minikube (manual steps)

If you prefer to run the steps manually instead of using `scripts/minikube.sh`:

1. Start Minikube and point Docker to its daemon:

   ```bash
   minikube start
   eval "$(minikube docker-env)"
   ```

2. Build the FileDownloader image:

   ```bash
   cd /home/seanfos/workdir/YTR/services/python/FileDownloader
   docker build -t file-downloader:latest .
   ```

3. Apply namespace, RBAC, MinIO, and FileDownloader manifests:

   ```bash
   cd /home/seanfos/workdir/YTR
   kubectl apply -f infra/k8s/base/namespaces/ytr-namespace.yaml
   kubectl config set-context --current --namespace=ytr

   kubectl apply -f infra/k8s/base/rbac/file-downloader-sa.yaml
   kubectl apply -f infra/k8s/base/rbac/file-downloader-role.yaml
   kubectl apply -f infra/k8s/base/rbac/file-downloader-rolebinding.yaml

   kubectl apply -f infra/k8s/base/infra/minio.yaml
   kubectl apply -f infra/k8s/base/services/file-downloader.yaml
   ```

4. Verify pods are running:

   ```bash
   kubectl get pods
   ```

5. Port-forward the FileDownloader service and test the REST API:

   ```bash
   kubectl port-forward svc/file-downloader 8000:8000
   ```

   In a separate terminal:

   ```bash
   # Health check
   curl -i http://localhost:8000/health

   # Download a video
   curl -i -X POST http://localhost:8000/download \
     -H "Content-Type: application/json" \
     -d '{"url": "https://www.youtube.com/watch?v=VIDEO_ID"}'
   ```

   Or use the test script:
   ```bash
   bash scripts/test-download.sh "https://www.youtube.com/watch?v=VIDEO_ID"
   ```

---

## Local development with Docker Compose

The simplest way to run the full stack locally — no Kubernetes required.

### Prerequisites

- Docker Desktop (or Docker Engine + Compose plugin v2.1+)

### Start everything

```bash
cd /home/seanfos/workdir/YTR
docker compose up --build
```

This will:
- Start MinIO (API on `:9000`, console on `:9090`)
- Create the `raw-videos` bucket automatically
- Build and start the FileDownloader service on `:8000`
- Build and start the RssFeedService on `:8001`

### Usage

```bash
# Health checks
curl http://localhost:8000/health
curl http://localhost:8001/health

# Download a video
curl -X POST http://localhost:8000/download \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.youtube.com/watch?v=VIDEO_ID"}'

# Get the RSS feed (add this URL to your podcast app)
curl http://localhost:8001/rss
```

- **MinIO console:** http://localhost:9090 (user: `minioadmin` / pass: `minioadmin`)
- **RSS feed URL:** `http://localhost:8001/rss`

Video data persists in a Docker named volume (`minio-data`). To reset: `docker compose down -v`

---

## Cloud deployment with Terraform (AWS EKS)

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- AWS CLI configured (`aws configure`)
- IAM permissions to create VPC, EKS, ECR, S3, and DynamoDB resources

### Step 1: Bootstrap remote state (once)

```bash
AWS_REGION=us-east-1 bash scripts/bootstrap-tf-state.sh
```

This creates two S3 buckets (`ytr-terraform-state-dev`, `ytr-terraform-state-prod`) and a DynamoDB lock table (`ytr-terraform-locks`).

### Step 2: Provision infrastructure

```bash
cd infra/terraform/envs/dev
terraform init
terraform plan
terraform apply
```

This creates:
- VPC with public/private subnets across 2 AZs
- EKS cluster (`ytr-dev-cluster`) with `t3.medium` nodes
- ECR repositories for `file-downloader` and `rss-feed`

### Step 3: Push your images to ECR

```bash
# Get the ECR registry URL from Terraform output
ECR_URL=$(terraform output -json ecr_repository_urls | jq -r '.["file-downloader"]' | cut -d'/' -f1)

# Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin "${ECR_URL}"

# Build and push
docker build -t "${ECR_URL}/ytr-dev/file-downloader:v1" services/python/FileDownloader
docker push "${ECR_URL}/ytr-dev/file-downloader:v1"

docker build -t "${ECR_URL}/ytr-dev/rss-feed:v1" services/python/RssFeedService
docker push "${ECR_URL}/ytr-dev/rss-feed:v1"
```

### Step 4: Deploy via Helm

```bash
# Update kubeconfig
$(terraform output -raw kubeconfig_command)

# Deploy (update values-dev.yaml image.repository fields to ECR URLs first)
bash scripts/deploy-dev.sh
```

> **Note on Prometheus storage:** When deploying to EKS, add `storageClassName: gp2` to the Prometheus `storageSpec` in `infra/helm/platform/values-dev.yaml`. The `aws-ebs-csi-driver` EKS add-on (provisioned by Terraform) provides this storage class.

### Infrastructure layout

```
infra/terraform/
├── modules/
│   ├── network/   VPC, subnets, NAT gateway
│   ├── eks/       EKS cluster + managed node group + add-ons
│   └── ecr/       ECR repositories with lifecycle policies
└── envs/
    ├── dev/       1 node, single NAT GW (cost-optimised)
    └── prod/      2 nodes, NAT GW per AZ (high availability)
```

To tear down: `terraform destroy` from the env directory.
