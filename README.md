# aws-bb-containerization

### Security
* Kubernetes access is provided to stricted groups of users
  - Platform team(admin access)
  - Team eshop(access to a specific namespace)
  - Team game(access to a specific namespace)
* Control plane logging is enabled
* Authentication is required to access the cluster
* Encryption of etcd secrets is enabled using AWS KMS service
* Workers storages are encrypted with AWS KMS key
* Bottlrocket AMI is in use to provide better security and optimization for EKS
* #TODO Pod security
* #TODO Network security(policies)

### Reliability
* Kubernetes cluster is deployed across 3 availability zones.
* Each AZ has nat gateway
* Application pods are deployed with 3 replicas each, replicas are deployed across 3 AZ.
* Karpenter is in place to scale cluster up/down.

### Cost optimization
* Karpenter and node termination handler are in place to safely use spot instances, which allows to optimize cost of infrastructure
* #TODO Configure karpenter spot policy

### CI/CD 
* GitHub pipeline is in use to provide ci/cd for infrastructure