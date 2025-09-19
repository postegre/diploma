# Daily snapshot schedule with 7-day retention
resource "yandex_compute_snapshot_schedule" "daily" {
  name = "${local.project}-daily-schedule"

  schedule_policy {
    expression = "0 0 * * *" # daily at 00:00 UTC
  }

  retention_period = "168h" # 7 days

  snapshot_spec {
    description = "Daily snapshot"
    labels      = local.labels
  }

  disk_ids = [
    yandex_compute_instance.bastion.boot_disk[0].disk_id,
    yandex_compute_instance.web_a.boot_disk[0].disk_id,
    yandex_compute_instance.web_b.boot_disk[0].disk_id,
    yandex_compute_instance.zabbix.boot_disk[0].disk_id,
    yandex_compute_instance.elasticsearch.boot_disk[0].disk_id,
    yandex_compute_instance.kibana.boot_disk[0].disk_id,
  ]
}
