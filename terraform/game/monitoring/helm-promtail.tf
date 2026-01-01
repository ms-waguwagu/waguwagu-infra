data "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "promtail" {
  name      = "promtail"
  namespace = data.kubernetes_namespace_v1.monitoring.metadata[0].name

  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = "6.15.5"

  values = [
    file("${path.module}/promtail-values.yaml")
  ]
}
