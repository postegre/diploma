output "bastion_public_ip" {
  value = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
}

output "kibana_url" {
  value = "http://${yandex_compute_instance.kibana.network_interface[0].nat_ip_address}:5601"
}

output "zabbix_url" {
  value = "http://${yandex_compute_instance.zabbix.network_interface[0].nat_ip_address}"
}

output "alb_public_ip" {
  value = yandex_alb_load_balancer.alb.listener[0].endpoint[0].address[0].external_ipv4_address[0].address
}

# Generate Ansible inventory with FQDNs in .ru-central1.internal
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/hosts.ini"
  content = templatefile("${path.module}/templates/hosts.ini.tftpl", {
    bastion_fqdn = "${yandex_compute_instance.bastion.name}.ru-central1.internal"
    web_a_fqdn   = "${yandex_compute_instance.web_a.name}.ru-central1.internal"
    web_b_fqdn   = "${yandex_compute_instance.web_b.name}.ru-central1.internal"
    zabbix_fqdn  = "${yandex_compute_instance.zabbix.name}.ru-central1.internal"
    es_fqdn      = "${yandex_compute_instance.elasticsearch.name}.ru-central1.internal"
    kibana_fqdn  = "${yandex_compute_instance.kibana.name}.ru-central1.internal"
    bastion_pub  = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
    vm_user      = var.vm_user
  })
}

output "ansible_inventory_path" {
  value = local_file.ansible_inventory.filename
}
