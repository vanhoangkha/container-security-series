# Container Security Series - Part 2: Container Image Security & Supply Chain

> **Series:** Container Security Toàn Diện (2026 Edition)
> **Author:** Security Research Series
> **Date:** June 2026

---

## 1. Tại Sao Image Security Là Nền Tảng?

Container image là **primary delivery artifact** trong modern supply chains. Nó bundle application code với tất cả dependencies, OS packages, runtime, và configuration thành một immutable artifact.

**Vấn đề thực tế:**
- Standard public images thường ship với **50-60 known CVEs**
- Minimal, source-built images giảm xuống còn **single-digit CVE count**
- **454,000+ malicious packages** mới được publish lên open source repositories trong năm 2025 (Sonatype Report)
- Tổng cộng hơn **1.2 triệu malicious packages** kể từ 2019

> Khi Log4Shell xuất hiện, companies có SBOMs trả lời "chúng ta có bị ảnh hưởng?" trong vài phút. Companies không có SBOMs mất hàng tuần để audit thủ công.

---

## 2. Software Supply Chain Attack Surface

Supply chain security focuses on **everything your code depends on** và **everything that touches your code** trên đường đến production.

```
Source Code → Dependencies → Build System → Registry → Deploy → Runtime
     ↑              ↑             ↑            ↑          ↑         ↑
  Compromised   Dependency    Build       Image      Misconfig  Runtime
   commits      confusion    tampering   poisoning              exploits
```

### Attack Vectors Phổ Biến

| Vector | Technique | Impact |
|--------|-----------|--------|
| **Dependency-based** | Dependency confusion, typosquatting, maintainer account takeover | Malicious code injection qua legitimate channel |
| **Build system** | Compromised CI/CD, injected build steps | Invisible code injection (source stays clean) |
| **Image/Registry** | Tampered images, name squatting, registry misconfiguration | Compromised images reach production |
| **CI/CD Pipeline** | Secret exfiltration, modified build outputs | Access credentials, deploy malicious artifacts |

### Real-World Examples

- **SolarWinds** (2020): Build system compromise → 18,000 customers affected
- **xz-utils backdoor** (2024): Maintainer social engineering → near-miss SSH compromise
- **Log4Shell** (2021): Transitive dependency vulnerability → massive blast radius
- **Codecov** (2021): CI/CD pipeline exploitation → secret exfiltration

---

## 3. Container Image Scanning

### 3.1. Tại Sao Cần Scanning?

Image scanning phân tích container images để detect:
- Vulnerable OS packages (rpm, dpkg, apk)
- Vulnerable language packages (npm, pip, maven, go)
- Embedded secrets và credentials
- Malware
- Misconfigurations

### 3.2. Scanning Ở Đâu?

Scanning nên xảy ra ở **nhiều điểm** trong pipeline:

```
Developer → CI/CD Build → Registry Push → Admission Control → Runtime
    ↓            ↓              ↓                ↓                ↓
  Local       Pipeline        Registry         Cluster        Continuous
  scan         scan            scan             gate            rescan
```

### 3.3. Image Scanning với Trivy

```bash
# Scan container image
trivy image myregistry.com/myapp:latest

# Scan với severity filter
trivy image --severity HIGH,CRITICAL myregistry.com/myapp:latest

# Scan và fail nếu có critical vulnerabilities
trivy image --exit-code 1 --severity CRITICAL myregistry.com/myapp:latest

# Scan filesystem (source code)
trivy fs --security-checks vuln,secret,config .

# Scan Kubernetes cluster
trivy k8s --report summary cluster
```

### 3.4. Image Scanning với Grype

```bash
# Scan từ SBOM (nhanh hơn, chính xác hơn)
grype sbom:./sbom.cdx.json --output json --file vulnerability-report.json

# Fail pipeline nếu có high severity
grype sbom:./sbom.cdx.json --fail-on high
```

### 3.5. CI/CD Integration (GitHub Actions)

```yaml
name: Container Security Scan
on:
  push:
    branches: [main]
  pull_request:

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'
      
      - name: Upload scan results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'
```

---

## 4. SBOM (Software Bill of Materials)

### 4.1. SBOM Là Gì?

SBOM là **machine-readable inventory** của mọi software component trong artifact:
- Tên package, version
- License information
- Hash/checksum
- Relationships giữa components
- Transitive dependencies

### 4.2. SBOM Formats

| Format | Standard | Best For |
|--------|----------|----------|
| **SPDX** | ISO/IEC 5962:2021 (Linux Foundation) | License compliance, legal/procurement |
| **CycloneDX** | OWASP Standard | Security analysis, vulnerability scanning, VEX |

**Best practice:** Generate cả hai formats. Storage rẻ, auditors prefer format của họ.

### 4.3. Generate SBOM với Syft

```bash
# Generate CycloneDX JSON (cho security tooling)
syft myregistry.com/myapp:latest \
  --output cyclonedx-json=sbom.cdx.json \
  --source-name "myapp" \
  --source-version "$(git rev-parse HEAD)"

# Generate SPDX JSON (cho license compliance)
syft myregistry.com/myapp:latest \
  --output spdx-json=sbom.spdx.json

# Scan source directory (catch development dependencies)
syft dir:. --output cyclonedx-json=sbom-source.cdx.json \
  --exclude ./vendor \
  --exclude ./.git
```

### 4.4. SBOM Components Syft Tìm Thấy

| Category | Examples | Risk |
|----------|----------|------|
| **OS Packages** | Alpine apk, Debian dpkg, RPMs | CVEs trong base image (libssl, glibc) |
| **Language Packages** | pip requirements, npm modules, Go modules | Direct application dependencies |
| **Transitive Dependencies** | Packages that your packages depend on | Surprise vulnerabilities 4+ levels deep |

### 4.5. Sử Dụng SBOM Cho Incident Response

Khi CVE mới được announce:
```bash
# Query tất cả SBOMs stored từ pipelines
# Tìm affected images trong vài phút thay vì hàng tuần
grype sbom:./sbom.cdx.json --only-vuln-id CVE-2024-XXXXX
```

---

## 5. Container Image Signing & Verification

### 5.1. Tại Sao Cần Signing?

Image signing tạo **cryptographic chain of trust** giữa:
- Entity đã build image
- Environment sẽ deploy image

Nó đảm bảo:
- Image chưa bị tampered
- Image đến từ trusted source
- Tag corresponds đến specific digest đã được signed

### 5.2. Sigstore Ecosystem

```
┌─────────────────────────────────────────────────────┐
│                 SIGSTORE ECOSYSTEM                    │
├─────────────────────────────────────────────────────┤
│                                                       │
│  Cosign ─── Sign/Verify container images              │
│     │                                                 │
│     ├── Fulcio ─── Certificate Authority (short-lived)│
│     │              Issues signing certificates         │
│     │              via OIDC tokens                     │
│     │                                                 │
│     └── Rekor ─── Transparency Log                    │
│                   Public, append-only log              │
│                   Non-repudiation at scale             │
│                                                       │
│  Keyless Signing:                                     │
│  - No long-lived private keys to manage/rotate/leak   │
│  - Authenticate via short-lived OIDC token            │
│  - Private key exists for milliseconds                │
│  - Certificate chain recorded in Rekor                │
│                                                       │
└─────────────────────────────────────────────────────┘
```

### 5.3. Sign Images với Cosign (Keyless)

```bash
# Sign image using OIDC identity (keyless)
COSIGN_EXPERIMENTAL=1 cosign sign \
  --yes \
  myregistry.com/myapp@sha256:abc123...

# Verify signature
COSIGN_EXPERIMENTAL=1 cosign verify \
  --certificate-identity-regexp="https://gitlab.com/mycompany/myapp//.gitlab-ci.yml@refs/heads/main" \
  --certificate-oidc-issuer="https://gitlab.com" \
  myregistry.com/myapp@sha256:abc123...

# Attach SBOM as attestation
COSIGN_EXPERIMENTAL=1 cosign attest \
  --yes \
  --predicate sbom.cdx.json \
  --type cyclonedx \
  myregistry.com/myapp@sha256:abc123...
```

### 5.4. Docker Content Trust

```bash
# Enable Docker Content Trust
export DOCKER_CONTENT_TRUST=1

# Pull sẽ fail nếu image không có trust data
docker pull myregistry/myapp:latest
# Error: remote trust data does not exist

# Generate signing key
docker trust key generate mykey

# Sign image
docker trust sign myregistry/myapp:v1.0

# Inspect trust info
docker trust inspect --pretty myregistry/myapp:latest
```

### 5.5. Quan Trọng: Sign Digest, Không Phải Tag

```
Tag = Mutable (có thể bị move sang image khác)
Digest = Immutable (SHA256 of image manifest)

✅ Sign: myapp@sha256:abc123...
❌ Sign: myapp:latest
```

---

## 6. SLSA Framework (Supply-chain Levels for Software Artifacts)

### 6.1. SLSA Build Levels

| Level | Requirements | What It Proves |
|-------|-------------|----------------|
| **Level 1** | Build process documented | You have a pipeline |
| **Level 2** | Version-controlled, signed provenance | Build came from your CI/CD |
| **Level 3** | Isolated environment, non-falsifiable provenance, 2-person review | Build cannot be tampered |
| **Level 4** | Hermetic builds, reproducible outputs | Maximum integrity |

**Target cho hầu hết enterprise workloads:** Level 2-3

### 6.2. SLSA Provenance Attestation

Provenance answers: **What was built, by whom, from what source, with what tools?**

```bash
# Attach SLSA provenance attestation
cosign attest \
  --yes \
  --predicate provenance.json \
  --type slsaprovenance \
  myregistry.com/myapp@sha256:abc123...
```

---

## 7. Secure Container Images Best Practices

### 7.1. Use Minimal Base Images

```dockerfile
# ❌ Bad: Full OS image (hundreds of CVEs)
FROM ubuntu:22.04

# ✅ Better: Minimal distro
FROM alpine:3.19

# ✅ Best: Distroless (no shell, no package manager)
FROM gcr.io/distroless/static-debian12

# ✅ Best: Hardened images (near-zero CVEs)
FROM docker.io/library/node:20-alpine  # → Replace with hardened variant
```

### 7.2. Multi-stage Builds

```dockerfile
# Build stage: full toolchain
FROM golang:1.22 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/server .

# Production stage: minimal image
FROM gcr.io/distroless/static-debian12
COPY --from=builder /app/server /server
USER nonroot:nonroot
ENTRYPOINT ["/server"]
```

### 7.3. Pin Dependencies

```dockerfile
# ❌ Bad: Unpinned
FROM node:latest
RUN npm install express

# ✅ Good: Pinned versions + digest
FROM node:20.11.1-alpine3.19@sha256:abc123...
COPY package.json package-lock.json ./
RUN npm ci --only=production
```

### 7.4. Non-Root User

```dockerfile
# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Switch to non-root
USER appuser:appgroup
```

### 7.5. Read-Only Filesystem

```yaml
# Kubernetes deployment
securityContext:
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1001
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
```

---

## 8. Registry Security

### 8.1. Registry Access Controls

| Control | Purpose |
|---------|---------|
| **RBAC** | Granular permissions cho push/pull |
| **MFA** | Extra verification layer |
| **Registry Access Management** | Control which registries developers can pull from |
| **Image signing policies** | Only signed images can be pushed/pulled |
| **Audit trails** | Track every registry interaction |

### 8.2. Private Registry Best Practices

```bash
# Enable vulnerability scanning on push (AWS ECR)
aws ecr put-image-scanning-configuration \
  --repository-name myapp \
  --image-scanning-configuration scanOnPush=true

# Enable image tag immutability
aws ecr put-image-tag-mutability \
  --repository-name myapp \
  --image-tag-mutability IMMUTABLE

# Set lifecycle policy (clean up old images)
aws ecr put-lifecycle-policy \
  --repository-name myapp \
  --lifecycle-policy-text file://lifecycle-policy.json
```

### 8.3. Admission Controllers (Kubernetes)

```yaml
# Kyverno policy: Only allow signed images
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  rules:
    - name: verify-cosign-signature
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "myregistry.com/*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/myorg/*"
                    issuer: "https://token.actions.githubusercontent.com"
```

---

## 9. Complete CI/CD Supply Chain Pipeline

### GitLab CI Example

```yaml
stages:
  - build
  - sbom
  - scan
  - sign
  - deploy

variables:
  IMAGE_NAME: "${CI_REGISTRY_IMAGE}"
  IMAGE_TAG: "${CI_COMMIT_SHA}"

build:
  stage: build
  image: docker:26
  services:
    - docker:26-dind
  script:
    - docker build
        --label "org.opencontainers.image.revision=${CI_COMMIT_SHA}"
        --label "org.opencontainers.image.source=${CI_PROJECT_URL}"
        -t ${IMAGE_NAME}:${IMAGE_TAG} .
    - docker save ${IMAGE_NAME}:${IMAGE_TAG} -o image.tar
  artifacts:
    paths: [image.tar]
    expire_in: 1 hour

sbom:
  stage: sbom
  dependencies: [build]
  script:
    - syft ${IMAGE_NAME}:${IMAGE_TAG}
        --output cyclonedx-json=sbom.cdx.json
    - syft ${IMAGE_NAME}:${IMAGE_TAG}
        --output spdx-json=sbom.spdx.json
  artifacts:
    paths: [sbom.cdx.json, sbom.spdx.json]
    expire_in: 1 year

scan:
  stage: scan
  dependencies: [sbom]
  script:
    - grype sbom:./sbom.cdx.json
        --output json --file vuln-report.json
        --fail-on high
  artifacts:
    paths: [vuln-report.json]

sign:
  stage: sign
  id_tokens:
    SIGSTORE_ID_TOKEN:
      aud: sigstore
  dependencies: [build, sbom]
  script:
    - docker push ${IMAGE_NAME}:${IMAGE_TAG}
    - IMAGE_DIGEST=$(docker inspect --format='{{ index .RepoDigests 0 }}' ${IMAGE_NAME}:${IMAGE_TAG})
    # NOTE: If using Helm/Go templates, escape as: {{ `{{index .RepoDigests 0}}` }}
    - cosign sign --yes --identity-token=${SIGSTORE_ID_TOKEN} ${IMAGE_DIGEST}
    - cosign attest --yes --identity-token=${SIGSTORE_ID_TOKEN}
        --predicate sbom.cdx.json --type cyclonedx ${IMAGE_DIGEST}
  only: [main]
```

---

## 10. Hands-On: Dockerfile Security Scanning

### 10.1. Vulnerable Dockerfile (Before)

```dockerfile
# ❌ INSECURE Dockerfile - 8 security issues
FROM ubuntu:latest
MAINTAINER admin@company.com

# Running as root (default)
RUN apt-get update && apt-get install -y curl wget git python3 python3-pip
RUN pip3 install flask requests

# Secrets hardcoded in image
ENV DATABASE_URL=postgresql://admin:P@ssw0rd@db.internal:5432/prod
ENV API_KEY=sk-live-abc123secretkey456

COPY . /app
WORKDIR /app

# ADD with URL (can download malicious content)
ADD https://example.com/config.tar.gz /tmp/

# Exposing unnecessary ports
EXPOSE 22 80 443 8080 9090

CMD ["python3", "app.py"]
```

### 10.2. Scan It

```bash
# Trivy misconfig scan trên Dockerfile
$ trivy config ./Dockerfile
2026-06-14T10:00:00Z  INFO  Detected config files: 1

Dockerfile (dockerfile)
========================
Tests: 23 (SUCCESSES: 15, FAILURES: 8)
Failures: 8 (HIGH: 4, MEDIUM: 3, LOW: 1)

HIGH: Specify a tag in the 'FROM' statement for image 'ubuntu'
──────────────────────────────────────
Use a specific version tag. ':latest' may break without notice.

HIGH: Secrets exposed in ENV - DATABASE_URL contains password
──────────────────────────────────────
Do not store secrets in Dockerfile. Use runtime injection.

HIGH: Running as root (no USER instruction)
──────────────────────────────────────
Add 'USER <non-root>' before CMD/ENTRYPOINT.

HIGH: ADD used with URL (use COPY + curl instead)
──────────────────────────────────────
ADD from URL can introduce untrusted content.

MEDIUM: apt-get update and install in separate RUN (cache issues)
MEDIUM: pip install without --no-cache-dir
MEDIUM: MAINTAINER deprecated (use LABEL)
LOW: Multiple ports exposed unnecessarily

# Hadolint (Dockerfile linter)
$ hadolint Dockerfile
Dockerfile:1 DL3007 warning: Using latest is prone to errors
Dockerfile:5 DL3008 warning: Pin versions in apt get install
Dockerfile:6 DL3013 warning: Pin versions in pip install
Dockerfile:8 DL3059 info: Multiple consecutive RUN instructions
```

### 10.3. Secure Dockerfile (After)

```dockerfile
# ✅ SECURE Dockerfile - all issues fixed
FROM python:3.12.3-alpine3.19@sha256:a1b2c3d4...

# Metadata via LABEL (not MAINTAINER)
LABEL org.opencontainers.image.source="https://github.com/myorg/myapp"
LABEL org.opencontainers.image.authors="team@company.com"

# Install dependencies in single layer, remove cache
RUN apk add --no-cache \
      curl=8.5.0-r0 \
    && rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup -h /app

# Install Python deps (as root, then switch)
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --require-hashes -r requirements.txt

# Copy application code
COPY --chown=appuser:appgroup . .

# Switch to non-root user
USER appuser:appgroup

# Only expose what's needed
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["python3", "app.py"]
```

### 10.4. Key Differences

| Issue | Before | After |
|-------|--------|-------|
| Base image | `ubuntu:latest` (300MB, 60+ CVEs) | `python:3.12-alpine@sha256:...` (50MB, <5 CVEs) |
| User | root | `appuser:1001` |
| Secrets | Hardcoded in ENV | Removed (inject at runtime) |
| ADD from URL | Yes | Removed |
| Pinned versions | No | Yes (image + packages) |
| Cache cleanup | No | `--no-cache`, `rm -rf` |
| Exposed ports | 5 ports | 1 port |
| Health check | None | Configured |

---

## 11. Compliance & Regulatory Requirements

### Frameworks Áp Dụng

| Framework | Requirement | Status |
|-----------|-------------|--------|
| **EO 14028** (US) | SBOM cho federal software | In force |
| **EU Cyber Resilience Act** | SBOM cho digital products bán tại EU | In force |
| **NIST SSDF** (SP 800-218) | Secure development practices | Reference architecture |
| **SLSA** | Build integrity verification | Graduated framework |
| **OpenSSF Scorecard** | Open source project security posture | Evaluation tool |

### Auditors Hỏi 5 Câu

1. **What is in this artifact?** → SBOM (CycloneDX/SPDX)
2. **When was it built and by whom?** → Cosign attestation + Rekor log
3. **Is this the approved artifact?** → Image digest comparison
4. **Has it been scanned?** → Vulnerability report (Grype/Trivy)
5. **What is the provenance?** → SLSA provenance attestation

---

## 12. Key Takeaways

1. **Start with trusted base images** — highest-leverage single action
2. **Generate SBOMs automatically** mỗi build, store ≥ 1 year
3. **Sign images** với keyless signing (Cosign/Sigstore) — no key management overhead
4. **Scan at every stage** — developer, CI/CD, registry, admission, runtime
5. **Pin all dependencies** — exact versions, lock files, image digests
6. **Enforce at infrastructure level** — admission controllers, registry policies
7. **Verify at every transition** — source → build → registry → deploy
8. **Use multi-stage builds** + distroless/minimal base images
9. **Never run as root** — non-root user + read-only filesystem
10. **Tag immutability** — prevent tag mutation attacks

---

## References

- Docker. "What is Software Supply Chain Security?" (June 2026)
- Bitslovers. "SBOM + Container Signing on GitLab CI: Supply Chain Security in 2026"
- Minimus.io. "Software Supply Chain Security Tools Guide (2026)"
- Sonatype. "2026 State of the Software Supply Chain"
- Sailor.sh. "CKS Supply Chain Security: Image Scanning, SBOMs & Admission Control"
- TechBytes. "Automating SBOMs & Signed Attestations"

---

*← [Part 1: Introduction & Overview](./part1-introduction-overview.md)*
*→ Tiếp theo: [Part 3: Runtime Security & Monitoring](./part3-runtime-security-monitoring.md)*
