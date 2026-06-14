# Container Security Series - Part 5: Network Security & Zero Trust

> **Series:** Container Security Toàn Diện (2026 Edition)
> **Author:** Security Research Series
> **Date:** June 2026

---

## 1. Tại Sao Network Security Cực Kỳ Quan Trọng?

Containers spin up và down trong vài giây, microservices communicate across networks, và workloads chạy trên shared infrastructure. Trong môi trường này:

- **Lateral movement** là attack vector phổ biến nhất sau initial access
- Compromised pod có thể **scan và attack** mọi service khác trong cluster nếu không có network policies
- Traditional perimeter security **không hoạt động** trong dynamic container environments
- Container network là **flat by default** — mọi pod nói chuyện với mọi pod

> Zero Trust principle: **"Never trust, always verify"** — mọi API call phải được validated và logged, mọi privilege phải được explicitly granted.

---

## 2. Container Network Security Challenges

| Challenge | Description |
|-----------|-------------|
| **Ephemeral workloads** | IPs change constantly, IP-based rules fail |
| **East-West traffic** | 80%+ traffic là internal service-to-service |
| **Shared infrastructure** | Multi-tenant environments, noisy neighbors |
| **Dynamic scaling** | New instances spawn/terminate continuously |
| **Service discovery** | DNS-based, can be poisoned |
| **Encrypted traffic** | Hard to inspect TLS traffic at network level |

---

## 3. Zero Trust Architecture for Containers

### 3.1. Zero Trust Principles

```
Traditional (Castle & Moat):     Zero Trust:
┌────────────────────────┐       ┌────────────────────────┐
│  TRUSTED ZONE          │       │  UNTRUSTED EVERYWHERE  │
│  ┌──┐ ← → ┌──┐       │       │  ┌──┐ ←✓→ ┌──┐       │
│  │A │      │B │ Trust  │       │  │A │ mTLS │B │ Verify │
│  └──┘      └──┘ within │       │  └──┘      └──┘ every  │
│                        │       │                  call   │
│  Perimeter = Security  │       │  Identity = Security   │
└────────────────────────┘       └────────────────────────┘
```

### 3.2. Zero Trust Pillars for Container Networking

| Pillar | Implementation |
|--------|---------------|
| **Identity** | mTLS, SPIFFE/SPIRE, service accounts |
| **Authentication** | Mutual certificate verification every connection |
| **Authorization** | Fine-grained policy per service/endpoint |
| **Encryption** | All traffic encrypted (mTLS) — no exceptions |
| **Least Privilege** | Default-deny, explicit allow per service pair |
| **Continuous Verification** | Every request validated, no persistent trust |
| **Observability** | Log all connections, detect anomalies |

---

## 4. Mutual TLS (mTLS)

### 4.1. mTLS vs Standard TLS

```
Standard TLS:                    Mutual TLS (mTLS):
Client ──→ Server                Client ←→ Server

1. Client verifies server cert   1. Client verifies server cert
2. Encrypted tunnel established  2. Server verifies client cert
3. Server doesn't know who       3. Both identities confirmed
   the client really is          4. Encrypted + authenticated
```

### 4.2. Tại Sao mTLS Cho Containers?

- **Authentication**: Cả hai sides verify identity — không phải chỉ server
- **Encryption**: All traffic encrypted, even internal
- **Non-repudiation**: Actions tied to verified identity
- **Prevents MITM**: Even if attacker is inside the network
- **Compliance**: PCI-DSS, HIPAA require encryption of sensitive data in transit

### 4.3. Certificate Management Challenge

```
Without Service Mesh:              With Service Mesh:
- Manual cert generation           - Automatic cert issuance
- Manual cert rotation             - Automatic rotation (24h expiry)
- Manual cert distribution         - Sidecar handles TLS
- Application code changes         - Zero application changes
- Certificate expiry risks         - Never expires (auto-renewed)
```

---

## 5. Service Mesh Architecture

### 5.1. What Is a Service Mesh?

Service mesh là **infrastructure layer** facilitating secure communication between microservices through:
- Distributed sidecar proxies
- Automated mTLS encryption
- Fine-grained traffic policies
- Observability (metrics, traces, logs)

```
┌─────────────────────────────────────────────────────────┐
│                    CONTROL PLANE                          │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Certificate │  │    Policy    │  │  Service     │  │
│  │   Authority  │  │   Engine    │  │  Discovery   │  │
│  └──────┬──────┘  └──────┬───────┘  └──────┬───────┘  │
├─────────┼────────────────┼──────────────────┼──────────┤
│         │    DATA PLANE  │                  │           │
│  ┌──────▼───────────────┐│                  │           │
│  │ Pod A                ││                  │           │
│  │ ┌─────┐  ┌────────┐ ││                  │           │
│  │ │ App │←→│Sidecar │←┼┼── mTLS ──────────┼───┐      │
│  │ └─────┘  │(Envoy) │ ││                  │   │      │
│  │           └────────┘ ││                  │   │      │
│  └──────────────────────┘│                  │   │      │
│                          │                  │   │      │
│  ┌──────────────────────┐│                  │   │      │
│  │ Pod B                ││                  │   │      │
│  │ ┌─────┐  ┌────────┐ ││                  │   │      │
│  │ │ App │←→│Sidecar │←┼┼──────────────────┘   │      │
│  │ └─────┘  │(Envoy) │ │◄──────────────────────┘      │
│  │           └────────┘ ││                              │
│  └──────────────────────┘│                              │
└─────────────────────────────────────────────────────────┘
```

### 5.2. Service Mesh Comparison (2026)

| Feature | Istio | Linkerd | Cilium Service Mesh |
|---------|-------|---------|-------------------|
| **mTLS** | ✅ Automatic | ✅ Automatic | ✅ Automatic |
| **Proxy** | Envoy (sidecar) | linkerd2-proxy (sidecar) | eBPF (no sidecar) |
| **Performance** | Higher latency | Lower latency | Lowest (kernel-level) |
| **Complexity** | High | Medium | Medium |
| **L7 policies** | ✅ Full | ✅ Basic | ✅ Full |
| **Resource usage** | High | Low | Lowest |
| **CNCF Status** | Graduated | Graduated | Graduated |
| **Best for** | Feature-rich enterprise | Simple, lightweight | Performance-critical |

### 5.3. Sidecar vs Sidecar-less (eBPF)

```
Traditional Sidecar:              Cilium (eBPF, no sidecar):
┌──────────────────┐              ┌──────────────────┐
│ Pod              │              │ Pod              │
│ ┌────┐ ┌──────┐ │              │ ┌────┐           │
│ │App │→│Envoy │→│── network    │ │App │───────────│── network
│ └────┘ └──────┘ │              │ └────┘           │
│ +50MB RAM/pod   │              │ No extra memory  │
│ +1ms latency    │              │ Kernel-level     │
└──────────────────┘              └──────────────────┘
                                        ↓
                                  ┌──────────────────┐
                                  │ eBPF (kernel)    │
                                  │ mTLS + Policy    │
                                  │ Per-node, shared │
                                  └──────────────────┘
```

---

## 6. Istio Security Configuration

### 6.0. Install Istio (Security-Focused Profile)

```bash
# Download istioctl
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.22.0 sh -
export PATH=$PWD/istio-1.22.0/bin:$PATH

# Install with hardened security profile
istioctl install --set profile=default \
  --set meshConfig.defaultConfig.holdApplicationUntilProxyStarts=true \
  --set meshConfig.accessLogFile=/dev/stdout \
  --set values.global.pilotCertProvider=istiod

# Enable sidecar injection for production namespace
kubectl label namespace production istio-injection=enabled

# Verify installation
istioctl verify-install
istioctl analyze --namespace production
```

### 6.1. Enable Strict mTLS

```yaml
# PeerAuthentication: Require mTLS for all traffic in namespace
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT  # STRICT = mTLS required, PERMISSIVE = allow both
```

### 6.1.1. Verify mTLS Is Working

```bash
# Check mTLS status for all services
istioctl x describe pod <pod-name> -n production

# Verify mutual TLS between services
istioctl proxy-config secret <pod-name> -n production
# Should show: ROOTCA, default (cert chain), ROOTCA (trusted CA)

# Check if connection is using mTLS
kubectl exec -n production deploy/frontend -c istio-proxy -- \
  openssl s_client -connect backend.production:8080 \
  -cert /etc/certs/cert-chain.pem \
  -key /etc/certs/key.pem \
  -CAfile /etc/certs/root-cert.pem 2>/dev/null | \
  grep "Verify return code"
# Expected: Verify return code: 0 (ok)

# Use istioctl to check mTLS compliance across mesh
istioctl x authz check <pod-name> -n production

# Visualize mTLS status (via Kiali dashboard)
istioctl dashboard kiali
# Navigate to Graph → Display "Security" to see lock icons on edges

# Test: Try plaintext connection (should FAIL with STRICT mTLS)
kubectl exec -n production deploy/test-pod -- \
  curl -v http://backend.production:8080/health
# Expected: connection refused (non-mTLS rejected)

# Test: Connection FROM pod WITH sidecar (should SUCCEED)
kubectl exec -n production deploy/frontend -c frontend -- \
  curl -s http://backend.production:8080/health
# Expected: 200 OK (sidecar handles mTLS transparently)
```

### 6.2. Authorization Policy (L7)

```yaml
# Only allow frontend to call backend on specific paths
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: backend-policy
  namespace: production
spec:
  selector:
    matchLabels:
      app: backend
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/production/sa/frontend"]
      to:
        - operation:
            methods: ["GET", "POST"]
            paths: ["/api/v1/*"]
    - from:
        - source:
            principals: ["cluster.local/ns/production/sa/admin-service"]
      to:
        - operation:
            methods: ["GET", "POST", "PUT", "DELETE"]
            paths: ["/api/v1/*", "/admin/*"]
---
# Default deny all traffic in namespace
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  {}  # Empty spec = deny all
```

### 6.3. Request Authentication (JWT)

```yaml
# Require valid JWT for specific services
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: require-jwt
  namespace: production
spec:
  selector:
    matchLabels:
      app: api-gateway
  jwtRules:
    - issuer: "https://auth.mycompany.com"
      jwksUri: "https://auth.mycompany.com/.well-known/jwks.json"
      audiences: ["api.mycompany.com"]
      forwardOriginalToken: true
```

---

## 7. Cilium Network Security

### 7.0. Cilium vs Calico: Production Comparison (2026)

> "Your choice of CNI plugin is one of the most consequential decisions you will make when building a Kubernetes platform. It determines how pods communicate, how network policies are enforced, how you observe traffic, and increasingly, how you implement service mesh and runtime security."
> — TasrieIT

| Feature | Cilium | Calico |
|---------|--------|--------|
| **Dataplane** | eBPF (kernel-level) | iptables or eBPF (optional) |
| **Performance** | ⚡ Higher throughput, lower latency | Good, eBPF mode matches Cilium |
| **NetworkPolicy** | Full + CiliumNetworkPolicy (L7) | Full + GlobalNetworkPolicy |
| **L7 (HTTP/gRPC)** | ✅ Native (path, method, headers) | ❌ (need service mesh) |
| **DNS policies** | ✅ Native FQDN-based rules | ❌ (need NetworkSet workaround) |
| **Service mesh** | ✅ Built-in (sidecar-less, eBPF) | ❌ (pair with Istio/Linkerd) |
| **Encryption** | ✅ WireGuard / IPsec | ✅ WireGuard |
| **Observability** | ✅ Hubble (native, excellent) | Calico flow logs (basic) |
| **Multi-cluster** | ✅ Cluster Mesh | ✅ Calico Federation |
| **BGP** | ✅ | ✅ (stronger, more mature) |
| **Windows** | ❌ | ✅ |
| **Maturity** | CNCF Graduated (2024) | Established (10+ years) |
| **Resource usage** | Higher (eBPF maps in kernel) | Lower (lighter footprint) |
| **Learning curve** | Steeper (eBPF concepts) | Gentler (traditional networking) |
| **Best for** | L7 security, observability, no sidecar mesh | Hybrid/multi-cloud, BGP, Windows |

**When to choose Cilium:**
- Need L7 network policies (HTTP path/method filtering) without service mesh
- Want built-in observability (Hubble) without extra tools
- Performance is critical (eBPF bypasses iptables overhead)
- Want sidecar-less service mesh

**When to choose Calico:**
- Need Windows node support
- BGP peering with existing network infrastructure
- Lighter resource footprint preferred
- Already have Istio/Linkerd for L7 concerns

### 7.1. Cilium Network Policies (L3-L7)

```yaml
# CiliumNetworkPolicy: L7-aware with identity-based matching
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: frontend-to-backend
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: frontend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/api/v1/.*"
              - method: "POST"
                path: "/api/v1/orders"
                headers:
                  - 'Content-Type: application/json'
```

### 7.2. Cilium DNS-Based Policies

```yaml
# Allow egress only to specific external domains
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-external-apis
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: payment-service
  egress:
    - toFQDNs:
        - matchName: "api.stripe.com"
        - matchName: "api.paypal.com"
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
    # Allow DNS resolution
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
```

### 7.3. Cilium Cluster-Wide Default Deny

```yaml
# Cluster-wide default deny (all namespaces)
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: default-deny-all
spec:
  endpointSelector: {}
  ingress:
    - fromEndpoints:
        - matchLabels:
            reserved:host: ""  # Allow kubelet health checks
  egress:
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
```

---

## 8. SPIFFE/SPIRE: Identity Framework

### 8.1. SPIFFE Overview

**SPIFFE** (Secure Production Identity Framework for Everyone) cung cấp:
- Cryptographic identity cho mỗi workload
- Platform-agnostic (works across K8s, VMs, bare metal)
- Short-lived certificates (không phải long-lived secrets)
- Identity format: `spiffe://trust-domain/path`

```
SPIFFE ID: spiffe://mycompany.com/ns/production/sa/payment-service

Components:
- Trust domain: mycompany.com
- Namespace: production
- Service account: payment-service
```

### 8.2. SPIRE Architecture

```
┌─────────────────────────────────┐
│         SPIRE Server             │
│  • Issues SVIDs (certificates)   │
│  • Maintains registration entries│
│  • Root CA                       │
└──────────────┬──────────────────┘
               │
     ┌─────────┼─────────┐
     │         │         │
┌────▼───┐ ┌──▼────┐ ┌──▼────┐
│ SPIRE  │ │ SPIRE │ │ SPIRE │
│ Agent  │ │ Agent │ │ Agent │  (per-node)
│ Node 1 │ │ Node 2│ │ Node 3│
└────┬───┘ └───┬───┘ └───┬───┘
     │         │         │
┌────▼───┐ ┌──▼────┐ ┌──▼────┐
│Workload│ │Workload│ │Workload│ (gets short-lived cert)
└────────┘ └───────┘ └───────┘
```

### 8.3. SPIFFE in Kubernetes

```yaml
# Register workload identity with SPIRE
apiVersion: spire.spiffe.io/v1alpha1
kind: ClusterSPIFFEID
metadata:
  name: payment-service
spec:
  spiffeIDTemplate: "spiffe://mycompany.com/ns/{{ .PodMeta.Namespace }}/sa/{{ .PodSpec.ServiceAccountName }}"
  podSelector:
    matchLabels:
      app: payment-service
  namespaceSelector:
    matchLabels:
      environment: production
```

---

## 9. Network Micro-Segmentation

### 9.1. Segmentation Strategy

```
┌─────────────────────────────────────────────────────┐
│                 CLUSTER                               │
│                                                       │
│  ┌─────────────────────┐   ┌────────────────────┐   │
│  │  ZONE: Frontend     │   │  ZONE: Backend     │   │
│  │  ┌───┐  ┌───┐      │   │  ┌───┐  ┌───┐     │   │
│  │  │Web│  │Web│      │──→│  │API│  │API│     │   │
│  │  └───┘  └───┘      │   │  └───┘  └───┘     │   │
│  │  (port 443 only in) │   │  (from frontend    │   │
│  └─────────────────────┘   │   port 8080 only)  │   │
│                             └─────────┬──────────┘   │
│                                       │              │
│                             ┌─────────▼──────────┐   │
│                             │  ZONE: Data        │   │
│                             │  ┌──┐  ┌───────┐   │   │
│                             │  │DB│  │ Cache │   │   │
│                             │  └──┘  └───────┘   │   │
│                             │  (from backend     │   │
│                             │   port 5432/6379)  │   │
│                             └────────────────────┘   │
│                                                       │
│  ┌─────────────────────┐                             │
│  │  ZONE: System       │                             │
│  │  (kube-system,      │                             │
│  │   monitoring, istio)│                             │
│  └─────────────────────┘                             │
└─────────────────────────────────────────────────────┘
```

### 9.2. Implementation with Labels

```yaml
# Namespace-level segmentation
apiVersion: v1
kind: Namespace
metadata:
  name: data-tier
  labels:
    zone: data
    sensitivity: high
---
# Cross-namespace policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-data
  namespace: data-tier
spec:
  podSelector:
    matchLabels:
      app: postgres
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              zone: backend
          podSelector:
            matchLabels:
              role: api
      ports:
        - protocol: TCP
          port: 5432
```

---

## 10. Egress Security & Data Exfiltration Prevention

### 10.1. Control Outbound Traffic

```yaml
# Only allow specific external endpoints
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Egress
  egress:
    # Internal cluster communication
    - to:
        - namespaceSelector:
            matchLabels:
              zone: data
      ports:
        - protocol: TCP
          port: 5432
    # DNS
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
    # Specific external IPs only
    - to:
        - ipBlock:
            cidr: 52.94.0.0/16  # AWS services
      ports:
        - protocol: TCP
          port: 443
```

### 10.2. DNS Exfiltration Prevention

```yaml
# Cilium: DNS visibility + blocking suspicious queries
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: dns-policy
spec:
  endpointSelector:
    matchLabels:
      app: backend
  egress:
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
      toPorts:
        - ports:
            - port: "53"
              protocol: ANY
          rules:
            dns:
              # Only allow resolution of known domains
              - matchPattern: "*.mycompany.com"
              - matchPattern: "*.amazonaws.com"
              - matchName: "api.stripe.com"
```

---

## 11. Service-to-Service Security Patterns

### 11.1. API Gateway Pattern

```
External Traffic
       │
       ▼
┌──────────────────┐
│   API Gateway    │  ← Rate limiting, WAF, JWT validation
│  (Kong/NGINX)    │  ← TLS termination
└────────┬─────────┘
         │ mTLS
         ▼
┌──────────────────┐
│  Service Mesh    │  ← Identity verification
│  (Istio/Cilium)  │  ← L7 authorization
└────────┬─────────┘
         │
    ┌────┼────┐
    ▼    ▼    ▼
  ┌──┐ ┌──┐ ┌──┐
  │A │ │B │ │C │   Internal services
  └──┘ └──┘ └──┘   (all mTLS)
```

### 11.2. Network Policy + Service Mesh Together

```yaml
# Layer 1: Kubernetes NetworkPolicy (L3/L4)
# Coarse-grained: which pods can talk to which pods, on what ports
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-to-payment
spec:
  podSelector:
    matchLabels:
      app: payment
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: order-service
      ports:
        - port: 8443
---
# Layer 2: Istio AuthorizationPolicy (L7)
# Fine-grained: which paths, methods, headers are allowed
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: payment-authz
spec:
  selector:
    matchLabels:
      app: payment
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/production/sa/order-service"]
      to:
        - operation:
            methods: ["POST"]
            paths: ["/api/v1/charge"]
      when:
        - key: request.headers[x-request-id]
          notValues: [""]
```

---

## 12. Monitoring & Observability

### 12.1. Network Flow Visibility

```bash
# Cilium Hubble: network flow observability
hubble observe --namespace production --protocol TCP --verdict DROPPED

# See all denied traffic
hubble observe --verdict DROPPED --output json

# Monitor specific service communication
hubble observe --to-label app=payment-service --from-label app=order-service
```

### 12.2. Detecting Network Anomalies

| Anomaly | Detection Method | Action |
|---------|-----------------|--------|
| Unusual egress destination | Cilium flow logs + alerting | Block + investigate |
| Port scanning within cluster | Falco + network flow analysis | Quarantine pod |
| DNS tunneling | High DNS query volume, unusual query patterns | Block DNS to external |
| Lateral movement | New connections to previously uncontacted services | Alert + isolate |
| Data exfiltration | Large outbound data transfer, unusual protocols | Rate limit + alert |

### 12.3. Network Security Monitoring Stack

```yaml
# Prometheus rules for network anomalies
groups:
  - name: network-security
    rules:
      - alert: UnusualEgressTraffic
        expr: |
          sum(rate(hubble_drop_total{reason="POLICY_DENIED"}[5m])) by (source_pod) > 10
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Pod {{ $labels.source_pod }} generating many denied connections"
      
      - alert: PossiblePortScan
        expr: |
          count(count by (destination_port)(
            hubble_flows_processed_total{source_pod=~".+", verdict="FORWARDED"}
          )) by (source_pod) > 20
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Possible port scan from {{ $labels.source_pod }}"
```

---

## 13. Multi-Cloud & Hybrid Network Security

### 13.1. Cross-Cluster mTLS

```yaml
# Istio multi-cluster: trust domain federation
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    trustDomain: cluster1.mycompany.com
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster1
      network: network1
```

### 13.2. Zero Trust Multi-Cloud Pattern

```
┌──────────────────┐     ┌──────────────────┐
│  AWS EKS Cluster │     │  GCP GKE Cluster │
│                  │     │                  │
│  SPIFFE IDs:     │     │  SPIFFE IDs:     │
│  spiffe://corp/  │ mTLS│  spiffe://corp/  │
│  aws/production/ │←───→│  gcp/production/ │
│  service-a       │     │  service-b       │
│                  │     │                  │
│  Trust bundle    │     │  Trust bundle    │
│  (shared root)   │     │  (shared root)   │
└──────────────────┘     └──────────────────┘
         │                        │
         └────────┬───────────────┘
                  │
         ┌────────▼───────────┐
         │  SPIRE Federation  │
         │  (Trust Broker)    │
         └────────────────────┘
```

---

## 14. Network Security Checklist

### Baseline
- [ ] Default-deny NetworkPolicy applied to all production namespaces
- [ ] CNI plugin with policy enforcement deployed (Calico/Cilium)
- [ ] Verify policies are actually enforced (test with denied traffic)
- [ ] Block metadata service (169.254.169.254) from application pods
- [ ] Egress restricted to known endpoints only

### Encryption
- [ ] mTLS enabled for all service-to-service communication
- [ ] Service mesh deployed (Istio/Linkerd/Cilium)
- [ ] Certificate rotation automated (< 24h lifetime)
- [ ] No plaintext internal communication

### Zero Trust
- [ ] Identity-based policies (not IP-based)
- [ ] L7 authorization policies (path/method level)
- [ ] JWT validation at API gateway
- [ ] SPIFFE/SPIRE for cross-platform identity

### Monitoring
- [ ] Network flow logging enabled (Hubble/Calico logs)
- [ ] Alerting on denied traffic anomalies
- [ ] DNS query logging and monitoring
- [ ] Egress traffic volume monitoring
- [ ] Regular policy audit and cleanup

### Segmentation
- [ ] Zones defined (frontend/backend/data/system)
- [ ] Cross-zone traffic explicitly allowed only where needed
- [ ] Database tier accessible only from backend tier
- [ ] Namespace-level isolation enforced

---

## 15. Key Takeaways

1. **Container networks are flat by default** — segmentation must be explicitly implemented
2. **Zero Trust = identity-based, not perimeter-based** security
3. **mTLS everywhere** — service mesh makes this manageable
4. **Network Policies alone are L3/L4** — combine with service mesh for L7
5. **Cilium eBPF** offers lowest overhead, no sidecar service mesh
6. **SPIFFE/SPIRE** provides cross-platform cryptographic identity
7. **Default-deny + explicit allow** — the only safe starting point
8. **DNS policies** prevent data exfiltration via DNS tunneling
9. **Monitor denied traffic** — anomalies indicate attacks or misconfigs
10. **Layer: NetworkPolicy (L3/L4) + Service Mesh (L7) + Runtime (eBPF)** = defense in depth

---

## References

- Wiz. "What is a Service Mesh? Architecture, Benefits, Risks"
- SystemsArchitect.io. "Zero Trust Network Access vs Traditional VPC Security"
- KindaTechnical. "Network Security: TLS, mTLS, Service Mesh, and Zero Trust Architecture"
- Hokstad Consulting. "Zero Trust in Multi-Cloud Service Mesh Guide"
- Hokstad Consulting. "How Service Meshes Handle Zero Trust Security"
- GoCodeo. "How to Implement mTLS in Microservices and Zero Trust Architectures"

---

*← [Part 4: Kubernetes Security Hardening](./part4-kubernetes-security-hardening.md)*
*→ Tiếp theo: [Part 6: Security Tools & Platforms](./part6-security-tools-platforms.md)*
