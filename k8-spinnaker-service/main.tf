#add ssl secret
resource "kubernetes_secret" "ssl-secret" {
  metadata {
    name = var.ssl-cert-name
    namespace = local.namespace
  }

  type = "Opaque"

  data = {
    "qcloud_cert_id" = var.ssl-cert-id
  }
}

#add tcr secret
resource "kubernetes_secret_v1" "tcr-spinnaker" {
  metadata {
    name = "tcr-spinnaker"
    namespace = "spinnaker"
  }

  type = "kubernetes.io/dockercfg"

  data = {
    ".dockercfg" = jsonencode({
      auths = {
        "${"https://usw1-dev-main.tencentcloudcr.com"}" = {
          "username" = data.terraform_remote_state.k8-tcr.outputs.username
          "password" = data.terraform_remote_state.k8-tcr.outputs.token
          "auth"     = base64encode("${data.terraform_remote_state.k8-tcr.outputs.username}:${data.terraform_remote_state.k8-tcr.outputs.token}")
        }
      }
    })
  }
}

resource "kubernetes_secret_v1" "tcr-spinnaker-secret" {
  metadata {
    name = "tc-tcr-api-access"
    namespace = "spinnaker"
  }

  data = {
    "SecretID" = data.terraform_remote_state.accounts.outputs.spin-tcr-user_secret_id
    "SecretKey" = data.terraform_remote_state.accounts.outputs.spin-tcr-user_secret_key
  }
}

resource "kubernetes_secret_v1" "dns-spinnaker-secret" {
  metadata {
    name = "tc-dns-api-access"
    namespace = "spinnaker"
  }

  data = {
    "SecretID" = data.terraform_remote_state.accounts.outputs.spin-dns-user_secret_id
    "SecretKey" = data.terraform_remote_state.accounts.outputs.spin-dns-user_secret_key
  }
}

#Deploy Spinnaker deck service 
resource "kubernetes_service" "spinnaker-deck" {
  metadata {
    name      = "spin-deck-private"
    namespace = local.namespace
    labels = (merge(
      local.common_tags,
      local.extra_tags,
      {cluster= "spin-deck"}
    ))
    annotations = {
      "service.kubernetes.io/qcloud-loadbalancer-internal-subnetid" = "${data.terraform_remote_state.vpc.outputs.priv_subnet_1}"
    }
  }
  spec {
    selector = {
      app             = "spin",
      cluster         = "spin-deck"
    }
    port {
      protocol        = "TCP"
      port            = 9000
      target_port     = 9000
    }
    type = "NodePort"
  }
}

#Deploy Spinnaker Gate Service
resource "kubernetes_service" "spinnaker-gate" {
  metadata {
    name      = "spin-gate-private"
    namespace = local.namespace
    labels = (merge(
      local.common_tags,
      local.extra_tags,
      {cluster= "spin-gate"}
    ))
    annotations = {
      "service.kubernetes.io/qcloud-loadbalancer-internal-subnetid" = "${data.terraform_remote_state.vpc.outputs.priv_subnet_1}"
    }
  }
  spec {
    selector = {
      app             = "spin",
      cluster         = "spin-gate"
    }
    port {
      protocol        = "TCP"
      port            = 8084
      target_port     = 8084
    }
    type = "NodePort"
  }
}

resource "kubernetes_service" "spinn-api" {
  metadata {
    name = "spin-api"
    namespace = local.namespace
    labels = (merge(
      local.common_tags,
      local.extra_tags
    ))
    annotations = {
      "service.kubernetes.io/qcloud-loadbalancer-internal-subnetid" = "${data.terraform_remote_state.vpc.outputs.priv_subnet_1}"
    }
  }
  spec {
    selector = {
      app             = "spin",
      cluster         = "spin-gate"
    }
    port {
      port        = 443
      target_port = 8085
      protocol    = "TCP"
    }
    type = "LoadBalancer"
  }
}

#Deploy Spinnaker Ingress 
resource "kubernetes_ingress_v1" "spinnaker-ingress" {
  metadata {
    name = "spin-ingress"
    namespace = local.namespace
    labels = (merge(
      local.common_tags,
      local.extra_tags
    ))
    annotations = {
      "kubernetes.io/ingress.subnetId" = "${data.terraform_remote_state.vpc.outputs.priv_subnet_1}"
      "kubernetes.io/ingress.rule-mix" = "true"
      "kubernetes.io/ingress.class" = "qcloud"
      "qcloud_cert_id" = var.ssl-cert-id
      "ingress.cloud.tencent.com/tke-service-config" = "spin-ingress-config"
    }
  }

  spec {
    rule {
      host = "spinnaker-${var.environment_tag}-${var.region_tag}.${data.domain}"
      http {
        path {
          backend {
            service {
              name = "spin-deck-private"
              port {
                number = 9000
              }
            }
          }
          path = "/"
        }
      }
    }
   rule {
      host = "spinnaker-api-${var.environment_tag}-${var.region_tag}.${data.domain}"
      http {
        path {
          backend {
            service {
              name = "spin-gate-private"
              port {
                number = 8084
              }
            }
          }
          path = "/"
        }
      }
    }
    tls {
      secret_name = var.ssl-cert-name
    }
  }
}

resource "kubernetes_manifest" "spinnaker_ingress_config" {
  manifest = yamldecode(templatefile("./ingress_config/spin_ingress_config.yaml",{}))
}

#slack notificaiton crd
resource "kubernetes_manifest" "spinnaker_slack_crd" {
  manifest = yamldecode(templatefile("./crd/slack-crd.yaml",{}))
}

resource "tencentcloud_dnspod_record" "spinnaker-dns" {
  domain      = ***
  record_type = "A"
  record_line = "Default"
  ttl         = "60"
  value       = resource.kubernetes_ingress_v1.spinnaker-ingress.status.0.load_balancer.0.ingress.0.ip
  sub_domain  = "spinnaker-${var.environment_tag}-${var.region_tag}"
}

resource "tencentcloud_dnspod_record" "gate-dns" {
  domain      = ***
  record_type = "A"
  record_line = "Default"
  ttl         = "60"
  value       = resource.kubernetes_ingress_v1.spinnaker-ingress.status.0.load_balancer.0.ingress.0.ip
  sub_domain  = "spinnaker-api-${var.environment_tag}-${var.region_tag}"
}

resource "tencentcloud_dnspod_record" "api-dns" {
  domain      = ***
  record_type = "A"
  record_line = "Default"
  ttl         = "60"
  value       = resource.kubernetes_service.spinn-api.status.0.load_balancer.0.ingress.0.ip
  sub_domain  = "spinnaker-api-client-${var.environment_tag}-${var.region_tag}"
}

