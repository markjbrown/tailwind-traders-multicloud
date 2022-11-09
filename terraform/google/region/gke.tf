resource "google_container_cluster" "gke" {
  name     = lower("${local.resource_prefix}-APP-gke")
  location = local.location

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name


  workload_identity_config {
    workload_pool = "${data.google_client_config.current.project}.svc.id.goog"
  }
}

resource "google_container_node_pool" "node_pool" {
  name       = lower("${local.resource_prefix}-APP-node-pool")
  location   = local.location
  cluster    = google_container_cluster.gke.name
  node_count = 1

  node_config {
    machine_type = "n1-standard-1"
    disk_size_gb = 10
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }

  depends_on = [
    google_container_cluster.gke
  ]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.10.0"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name


  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [
    google_container_cluster.gke
  ]
}

resource "kubectl_manifest" "clusterissuer_le_prod" {
  yaml_body = yamlencode({
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = "letsencrypt-prod"
    }
    "spec" = {
      "acme" = {
        "email" = "myemail@email.com"
        "privateKeySecretRef" = {
          "name" = "letsencrypt-prod"
        }
        "server" = "https://acme-v02.api.letsencrypt.org/directory"
        "solvers" = [
          {
            "http01" = {
              "ingress" = {
                "class" = "ingress-gce"
              }
            }
          }
        ]
      }
    }
  })

  depends_on = [helm_release.cert_manager]
}

resource "google_compute_address" "ip" {
  name         = "tailwindtraders-ip"
  address_type = "EXTERNAL"
}

resource "kubernetes_secret" "tls" {
  metadata {
    name      = "tt-letsencrypt-prod"
    namespace = "default"
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = ""
    "tls.key" = ""
  }

  depends_on = [helm_release.cert_manager]
}

resource "kubernetes_ingress_v1" "fanout_ingress" {
  metadata {
    name      = "tt-ingress"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress-global-static-ip-name" = google_compute_address.ip.name
      "cert-manager.io/cluster-issuer"              = "letsencrypt-prod"
      "acme.cert-manager.io/http01-edit-in-place"   = "true"
    }
  }

  spec {
    tls {
      hosts = ["gke.tailwindtraders.click"]
      secret_name = kubernetes_secret.tls.metadata[0].name
    }

    rule {
      host = "gke.tailwindtraders.click"
      http {
        path {
          path = "/cart-api"
          backend {
            service {
              name = "cart-api"
              port {
                number = 80
              }
            }
          }
        }
        path {
          path = "/product-api"
          backend {
            service {
              name = "product-api"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.cert_manager,
    kubectl_manifest.clusterissuer_le_prod,
    kubernetes_secret.tls
  ]
}