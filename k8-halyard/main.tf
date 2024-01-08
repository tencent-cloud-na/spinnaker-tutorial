#Create PVC
resource "kubernetes_persistent_volume_claim" "halyard_pvc" {
  metadata {
    name = "halyard-pvc"
    namespace = local.namespace 
    annotations = {
      "volume.beta.kubernetes.io/storage-provisioner" = "com.tencent.cloud.csi.cbs"
    }
    labels = (merge(
      local.common_tags,
      local.extra_tags
    ))
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
    storage_class_name = "cbs"
  }
}

#Deploy Halyard
resource "kubernetes_deployment" "halyard" {
  metadata {
    name      = "${var.role_tag}-halyard"
    namespace = local.namespace
    labels = (merge(
      local.common_tags,
      local.extra_tags
    ))
  }

  spec {
    replicas          = 1
    revision_history_limit = 2
    min_ready_seconds = 5
    progress_deadline_seconds = 600
    selector {
      match_labels = {
        spinnaker = "spinnaker-halyard"
      }
    }
    template {
      metadata {
        labels = (merge(
          local.common_tags,
          local.extra_tags
        ))
      }

      spec {
        service_account_name = "halyard-user-dev"
        container {
          image = "***"
          name  = "${var.role_tag}-halyard"
          image_pull_policy = "Always"
          volume_mount {
            name = "halyard-config"
            mount_path = "/home/spinnaker"
          }
        }
        security_context {
            run_as_user = 1000
            fs_group = 1000
        }
        volume {
          name = "halyard-config"
          persistent_volume_claim {
            claim_name = "halyard-pvc"
          }
        }
      }
    }
  }
}
