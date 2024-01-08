#Deploy Spinnaker artifact service 
resource "kubernetes_service" "spin-artifact-service" {
  metadata {
    name      = "spin-artifact"
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
      Role            = "${var.role_tag}"
    }
    port {
      protocol        = "TCP"
      port            = 80
      target_port     = 80
    }
    type = "LoadBalancer"
  }
}

#spin artifact deployment
resource "kubernetes_deployment" "spin-artifact-deployment" {
  metadata {
    name      = "spin-artifact"
    namespace = local.namespace
    labels = (merge(
      local.common_tags,
      local.extra_tags
    ))
  }

  spec {
    replicas          = 1
    selector {
      match_labels = {
        app             = "spin",
        Role            = "${var.role_tag}"
      }
    }
    template {
      metadata {
        labels = (merge(
          local.common_tags,
          local.extra_tags
        ))
        annotations = {
          redeploy-trigger = random_uuid.k8s-redepoly.keepers.time
        }
      }

      spec {
        container {
          image = "dev-tcr.uncappedtech.com/dev/spin-artifact-repo:latest"
          image_pull_policy = "Always"
          name  = "spin-artifact"
        }
      }
    }
  }

}

resource "random_uuid" "k8s-redepoly" {
  keepers = {
    # Generate a new id each time we switch to a new AMI id
    time = timestamp()
  }
}