resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }
}

resource "kubernetes_config_map" "observability_config" {
  metadata {
    name      = "observability-config"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    PROMETHEUS_ENDPOINT = "http://prometheus-server.monitoring.svc.cluster.local"
    LOKI_ENDPOINT       = "http://loki:3100"
  }
}
