resource "kubernetes_ingress" "grafana" {
  metadata {
    name      = "grafana"
    namespace = "monitoring"
    annotations = {
      "kubernetes.io/ingress.class" : "nginx"
      "cert-manager.io/cluster-issuer" : "letsencrypt-prod"
    }
  }

  spec {
    rule {
      host = "grafana.nainika.store"

      http {
        path {
          path = "/"
          backend {
            service_name = "grafana"
            service_port = 80
          }
        }
      }
    }
  }
}