# Infrastructure Architecture

## Complete AWS EKS DevOps Architecture

```mermaid
graph TB
    subgraph "External Access"
        User[End Users]
        DevOps[DevOps Engineers]
        Cloudflare[Cloudflare DNS/CDN]
    end
    
    subgraph "GitHub"
        Repo[Repository]
        Actions[GitHub Actions]
        DockerHub[Docker Hub Registry]
    end
    
    subgraph "AWS Cloud - ap-south-1"
        subgraph "VPC - 10.0.0.0/16"
            subgraph "Public Subnets"
                NLB[Network Load Balancer]
                NAT[NAT Gateway]
            end
            
            subgraph "Private Subnets - AZ1 & AZ2"
                subgraph "EKS Control Plane"
                    API[API Server]
                    ETCD[(etcd)]
                end
                
                subgraph "Worker Nodes - t3.small"
                    Node1[Node 1]
                    Node2[Node 2]
                end
            end
            
            subgraph "Persistent Storage"
                EBS1[(EBS Volume - Prometheus)]
                EBS2[(EBS Volume - Grafana)]
            end
        end
        
        subgraph "IAM & Security"
            IRSA[IAM Roles for Service Accounts]
            SG[Security Groups]
        end
    end
    
    subgraph "Kubernetes Cluster - nasa-eks"
        subgraph "Namespace: ingress-nginx"
            IngressController[NGINX Ingress Controller]
        end
        
        subgraph "Namespace: monitoring"
            Prometheus[Prometheus]
            Grafana[Grafana]
            AlertManager[Alert Manager]
            NodeExporter[Node Exporter]
            KubeStateMetrics[Kube State Metrics]
        end
        
        subgraph "Namespace: prod"
            ProdApp[Frontend App - Prod]
            ProdHPA[HPA - 3-10 pods]
            ProdIngress[Ingress - prod.nainika.store]
        end
        
        subgraph "Namespace: stage"
            StageApp[Frontend App - Stage]
            StageIngress[Ingress - stage.nainika.store]
        end
        
        GrafanaIngress[Ingress - grafana.nainika.store]
    end
    
    %% Connections
    User --> Cloudflare
    Cloudflare --> NLB
    NLB --> IngressController
    
    IngressController --> ProdIngress
    IngressController --> StageIngress
    IngressController --> GrafanaIngress
    
    ProdIngress --> ProdApp
    StageIngress --> StageApp
    GrafanaIngress --> Grafana
    
    ProdApp --> ProdHPA
    
    Prometheus --> EBS1
    Grafana --> EBS2
    
    Prometheus -.collects metrics.-> ProdApp
    Prometheus -.collects metrics.-> StageApp
    Prometheus -.collects metrics.-> IngressController
    Prometheus -.collects metrics.-> NodeExporter
    Prometheus -.collects metrics.-> KubeStateMetrics
    
    Grafana -.queries.-> Prometheus
    
    Node1 --> NAT
    Node2 --> NAT
    NAT --> Internet((Internet))
    
    DevOps --> Repo
    Repo --> Actions
    
    Actions -->|terraform apply| API
    Actions -->|docker build/push| DockerHub
    Actions -->|helm deploy| API
    
    DockerHub -.pull image.-> Node1
    DockerHub -.pull image.-> Node2
    
    IRSA -.authenticates.-> Prometheus
    IRSA -.authenticates.-> IngressController
    
    SG -.protects.-> Node1
    SG -.protects.-> Node2
    
    API --> Node1
    API --> Node2
    API --> ETCD
    
    classDef aws fill:#FF9900,stroke:#232F3E,stroke-width:2px,color:#fff
    classDef k8s fill:#326CE5,stroke:#fff,stroke-width:2px,color:#fff
    classDef external fill:#00D1B2,stroke:#fff,stroke-width:2px,color:#fff
    classDef storage fill:#7952B3,stroke:#fff,stroke-width:2px,color:#fff
    
    class NLB,NAT,EBS1,EBS2,IRSA,SG,API,ETCD aws
    class IngressController,Prometheus,Grafana,ProdApp,StageApp,ProdIngress,StageIngress,GrafanaIngress k8s
    class User,DevOps,Cloudflare,Repo,Actions,DockerHub external
```

## CI/CD Pipeline Flow

```mermaid
flowchart LR
    subgraph "Developer Workflow"
        Dev[Developer] -->|commits code| Git[GitHub Repository]
    end
    
    subgraph "GitHub Actions"
        Git -->|trigger| Check{Branch?}
        
        Check -->|main| ProdPipeline[Production Pipeline]
        Check -->|develop| StagePipeline[Staging Pipeline]
        Check -->|terraform/*| InfraPipeline[Infrastructure Pipeline]
        
        ProdPipeline --> Build1[Build Docker Image]
        Build1 --> Test1[Run Tests]
        Test1 --> Push1[Push to Registry]
        Push1 --> Deploy1[Deploy to Prod]
        
        StagePipeline --> Build2[Build Docker Image]
        Build2 --> Test2[Run Tests]
        Test2 --> Push2[Push to Registry]
        Push2 --> Deploy2[Deploy to Stage]
        
        InfraPipeline --> TFInit[Terraform Init]
        TFInit --> TFPlan[Terraform Plan]
        TFPlan --> TFApply[Terraform Apply]
        TFApply --> K8sSetup[Setup K8s Components]
    end
    
    subgraph "Container Registry"
        Push1 --> DockerHub[Docker Hub]
        Push2 --> DockerHub
    end
    
    subgraph "AWS EKS"
        Deploy1 --> ProdNS[Production Namespace]
        Deploy2 --> StageNS[Staging Namespace]
        K8sSetup --> Monitoring[Monitoring Stack]
        K8sSetup --> Ingress[Ingress Controller]
    end
    
    subgraph "Monitoring & Feedback"
        ProdNS --> Monitor[Prometheus/Grafana]
        StageNS --> Monitor
        Monitor --> Alert[Alerts]
        Alert -->|notify| Dev
    end
    
    classDef pipeline fill:#24292e,stroke:#f39c12,stroke-width:2px,color:#fff
    classDef deploy fill:#27ae60,stroke:#fff,stroke-width:2px,color:#fff
    classDef monitor fill:#e74c3c,stroke:#fff,stroke-width:2px,color:#fff
    
    class ProdPipeline,StagePipeline,InfraPipeline pipeline
    class Deploy1,Deploy2,K8sSetup deploy
    class Monitor,Alert monitor
```

## Network Architecture

```mermaid
graph TB
    subgraph "Internet"
        Client[Clients]
        DNS[Cloudflare DNS]
    end
    
    subgraph "AWS VPC - 10.0.0.0/16"
        subgraph "Public Subnet - 10.0.101.0/24 & 10.0.102.0/24"
            IGW[Internet Gateway]
            NLB[Network Load Balancer]
            NAT[NAT Gateway]
        end
        
        subgraph "Private Subnet - 10.0.1.0/24 & 10.0.2.0/24"
            subgraph "EKS Worker Nodes"
                Node1[Worker Node 1<br/>AZ: ap-south-1a]
                Node2[Worker Node 2<br/>AZ: ap-south-1b]
            end
            
            subgraph "Pods"
                NGINX[NGINX Ingress<br/>Port 80/443]
                App1[Frontend Pods<br/>Port 8080]
                Prom[Prometheus<br/>Port 9090]
                Graf[Grafana<br/>Port 3000]
            end
        end
        
        subgraph "Security Groups"
            SGALB[SG: ALB<br/>Allow: 80, 443]
            SGNode[SG: Nodes<br/>Allow: All from ALB]
            SGControl[SG: Control Plane<br/>Allow: 443 from Nodes]
        end
    end
    
    Client --> DNS
    DNS --> NLB
    NLB --> NGINX
    
    NGINX --> App1
    NGINX --> Graf
    
    App1 -.metrics.-> Prom
    Graf -.queries.-> Prom
    
    Node1 --> NAT
    Node2 --> NAT
    NAT --> IGW
    IGW --> Internet((Internet))
    
    SGALB -.protects.-> NLB
    SGNode -.protects.-> Node1
    SGNode -.protects.-> Node2
    
    classDef public fill:#3498db,stroke:#2c3e50,stroke-width:2px,color:#fff
    classDef private fill:#2ecc71,stroke:#27ae60,stroke-width:2px,color:#fff
    classDef security fill:#e74c3c,stroke:#c0392b,stroke-width:2px,color:#fff
    
    class IGW,NLB,NAT public
    class Node1,Node2,NGINX,App1,Prom,Graf private
    class SGALB,SGNode,SGControl security
```

## Monitoring Architecture

```mermaid
graph TB
    subgraph "Data Sources"
        Apps[Application Pods]
        Nodes[Kubernetes Nodes]
        Ingress[NGINX Ingress]
        K8s[Kubernetes API]
    end
    
    subgraph "Collection Layer"
        Apps -.metrics.-> ServiceMonitor[Service Monitors]
        Nodes -.metrics.-> NodeExporter[Node Exporter]
        Ingress -.metrics.-> IngressMetrics[Ingress Metrics]
        K8s -.state.-> KSM[Kube State Metrics]
    end
    
    subgraph "Storage & Processing"
        ServiceMonitor --> Prometheus[(Prometheus)]
        NodeExporter --> Prometheus
        IngressMetrics --> Prometheus
        KSM --> Prometheus
        
        Prometheus --> TSDB[(Time Series DB<br/>EBS Volume)]
    end
    
    subgraph "Visualization"
        Prometheus --> Grafana[Grafana]
        Grafana --> Dashboard1[NGINX Dashboard]
        Grafana --> Dashboard2[Cluster Dashboard]
        Grafana --> Dashboard3[Pods Dashboard]
        Grafana --> Dashboard4[Node Dashboard]
        Grafana --> Dashboard5[Prometheus Dashboard]
    end
    
    subgraph "Alerting"
        Prometheus --> AlertManager[Alert Manager]
        AlertManager --> Email[Email Notifications]
        AlertManager --> Slack[Slack Notifications]
    end
    
    subgraph "Users"
        DevOps[DevOps Team]
        Developers[Developers]
    end
    
    Dashboard1 --> DevOps
    Dashboard2 --> DevOps
    Dashboard3 --> Developers
    Dashboard4 --> DevOps
    Dashboard5 --> DevOps
    
    Email --> DevOps
    Slack --> DevOps
    
    classDef source fill:#3498db,stroke:#2980b9,stroke-width:2px,color:#fff
    classDef collect fill:#2ecc71,stroke:#27ae60,stroke-width:2px,color:#fff
    classDef store fill:#9b59b6,stroke:#8e44ad,stroke-width:2px,color:#fff
    classDef visual fill:#e74c3c,stroke:#c0392b,stroke-width:2px,color:#fff
    
    class Apps,Nodes,Ingress,K8s source
    class ServiceMonitor,NodeExporter,IngressMetrics,KSM collect
    class Prometheus,TSDB store
    class Grafana,Dashboard1,Dashboard2,Dashboard3,Dashboard4,Dashboard5 visual
```

## Security Architecture

```mermaid
graph TB
    subgraph "External Security"
        CF[Cloudflare<br/>DDoS Protection]
        TLS[TLS/SSL<br/>Certificates]
    end
    
    subgraph "Network Security"
        VPC[VPC Isolation<br/>10.0.0.0/16]
        SG[Security Groups]
        NACL[Network ACLs]
        PrivateSubnet[Private Subnets]
    end
    
    subgraph "Kubernetes Security"
        RBAC[RBAC<br/>Role-Based Access]
        SA[Service Accounts]
        PSP[Pod Security Policies]
        SecContext[Security Contexts<br/>Non-root, Read-only FS]
    end
    
    subgraph "AWS Security"
        IAM[IAM Roles]
        IRSA[IRSA<br/>IAM Roles for SA]
        KMS[KMS Encryption]
        Secrets[AWS Secrets Manager]
    end
    
    subgraph "Application Security"
        Container[Container Security<br/>Multi-stage builds]
        ImageScan[Image Scanning]
        HealthCheck[Health Checks]
    end
    
    subgraph "Data Security"
        EncryptTransit[Encryption in Transit]
        EncryptRest[Encryption at Rest<br/>EBS volumes]
        BackupEnc[Encrypted Backups]
    end
    
    CF --> TLS
    TLS --> VPC
    VPC --> SG
    SG --> PrivateSubnet
    
    PrivateSubnet --> RBAC
    RBAC --> SA
    SA --> IRSA
    
    IRSA --> IAM
    IAM --> KMS
    
    SA --> PSP
    PSP --> SecContext
    SecContext --> Container
    
    KMS --> EncryptRest
    TLS --> EncryptTransit
    
    Container --> ImageScan
    Container --> HealthCheck
    
    EncryptRest --> BackupEnc
    
    classDef external fill:#3498db,stroke:#2980b9,stroke-width:2px,color:#fff
    classDef network fill:#2ecc71,stroke:#27ae60,stroke-width:2px,color:#fff
    classDef k8s fill:#326CE5,stroke:#fff,stroke-width:2px,color:#fff
    classDef aws fill:#FF9900,stroke:#232F3E,stroke-width:2px,color:#fff
    classDef app fill:#e74c3c,stroke:#c0392b,stroke-width:2px,color:#fff
    
    class CF,TLS external
    class VPC,SG,NACL,PrivateSubnet network
    class RBAC,SA,PSP,SecContext k8s
    class IAM,IRSA,KMS,Secrets aws
    class Container,ImageScan,HealthCheck app
```

## Deployment Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Git as GitHub
    participant GHA as GitHub Actions
    participant TF as Terraform
    participant AWS as AWS
    participant K8s as Kubernetes
    participant Mon as Monitoring
    
    Note over Dev,Mon: Infrastructure Setup
    Dev->>Git: Push Terraform code
    Git->>GHA: Trigger workflow
    GHA->>TF: terraform init
    GHA->>TF: terraform plan
    GHA->>TF: terraform apply
    TF->>AWS: Create VPC, EKS
    TF->>K8s: Deploy NGINX Ingress
    TF->>K8s: Deploy Prometheus/Grafana
    K8s->>Mon: Setup monitoring
    
    Note over Dev,Mon: Application Deployment
    Dev->>Git: Push app code
    Git->>GHA: Trigger build
    GHA->>GHA: Build Docker image
    GHA->>GHA: Run tests
    GHA->>DockerHub: Push image
    GHA->>K8s: Deploy with Helm
    K8s->>K8s: Rolling update
    K8s->>Mon: Report metrics
    Mon->>Dev: Alert if issues
```
