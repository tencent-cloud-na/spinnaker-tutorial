terraform {
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = ">=1.77.9"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.13.1"
    }
  }
}

provider "kubernetes" {
  host                   = "https://${data.tencentcloud_kubernetes_clusters.k8s.list.0.pgw_endpoint}"
  cluster_ca_certificate = data.tencentcloud_kubernetes_clusters.k8s.list.0.certification_authority
  token                  = data.tencentcloud_kubernetes_clusters.k8s.list.0.password
}

provider "tencentcloud" {
  region = var.vpc_region
}