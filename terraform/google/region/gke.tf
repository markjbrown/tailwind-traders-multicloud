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
  name     = lower("${local.resource_prefix}-APP-node-pool")
  location = local.location
  cluster  = google_container_cluster.gke.name

  autoscaling {
    max_node_count = 2
    min_node_count = 1
  }

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
  version    = "v1.10.0"
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

resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.3.0"
  namespace  = "kube-system"

  set {
    name  = "controller.service.loadBalancerIP"
    value = google_compute_address.ip.address
  }

  depends_on = [
    google_container_cluster.gke
  ]
}

resource "kubernetes_service_account" "gke" {
  metadata {
    name      = "gke"
    namespace = "default"
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.gke.email
    }
  }
}

resource "google_service_account" "gke" {
  account_id   = lower(join("-", [local.resource_prefix, "gke", "sa"]))
  display_name = "GKE"
}

resource "google_project_iam_binding" "gke_sa" {
  project = data.google_client_config.current.project
  role    = "roles/firebase.admin"
  members = ["serviceAccount:${google_service_account.gke.email}"]
}

resource "google_service_account_iam_binding" "gke_wq" {
  service_account_id = google_service_account.gke.name
  role               = "roles/iam.workloadIdentityUser"
  members            = ["serviceAccount:${data.google_client_config.current.project}.svc.id.goog[${kubernetes_service_account.gke.metadata[0].namespace}/${kubernetes_service_account.gke.metadata[0].name}]"]
}

