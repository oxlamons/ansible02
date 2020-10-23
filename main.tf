provider "hcloud" {
  token = var.hcloud_token
  #base_url = "https://api.hetzner.cloud/v1/"
}
# Генерируется пароль
resource "random_password" "password" {
  count   = "${length(var.domains)}"
  length  = "10"
  special = false
  lower   = true
  number  = true
}
data "hcloud_ssh_key" "rebrain_ssh_key" {
  name = "REBRAIN.SSH.PUB.KEY"
}
# Add ssh key
resource "hcloud_ssh_key" "anton" {
  name       = "anton ssh_key"
  public_key = var.my_ssh_key
  labels = {
    "module" : "devops"
    "email" : "oxlamons_at_gmail_com"
  }
}
# Создаем VPC
resource "hcloud_server" "renode1" {
  count       = "${length(var.domains)}"
  name        = "${element(var.domains, count.index)}.oxlamons.devops.rebrain.srwx.net"
  image       = "ubuntu-18.04"
  server_type = "cx11"
  ssh_keys = [hcloud_ssh_key.anton.id,
  data.hcloud_ssh_key.rebrain_ssh_key.name]

  #Меняем пароль root на указаный в переменных и подключаюсь к VPC
  provisioner "remote-exec" {
    inline = [
      "echo root:${random_password.password[count.index].result} | chpasswd"
    ]
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
      host        = self.ipv4_address
    }
  }
  provisioner "local-exec" {
    command = "echo ${element(var.domains, count.index)}.oxlamons.devops.srwx.net root ${element(random_password.password.*.result, count.index)} >> login.txt"

  }
  labels = {
    "module" : "devops"
    "email" : "oxlamons_at_gmail_com"
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.ipv4_address},' -u root nginx1.yml"
  }
}
resource "null_resource" "ansible" {
  count = "${length(var.domains)}"

  provisioner "local-exec" {
    command = "ansible-playbook -i '${element(hcloud_server.renode1.*.ipv4_address, count.index)},' -u root nginx1.yml"
  }
}
# Create a new provider using the SSH key
provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.aws_region
}
# Создаем route53  и привязываем VPC
data "aws_route53_zone" "selected" {
  name = "devops.rebrain.srwx.net"
}
resource "aws_route53_record" "www" {
  count           = "${length(var.domains)}"
  zone_id         = data.aws_route53_zone.selected.zone_id
  name            = "oxlamons.${data.aws_route53_zone.selected.name}"
  type            = "A"
  ttl             = "300"
  records         = ["${element(hcloud_server.renode1.*.ipv4_address, count.index)}"]
  allow_overwrite = true
}
# Вывод данных в консоль
output "server_ip_renode1" {
  value = hcloud_server.renode1.*.ipv4_address
}
output "server_id_renode1" {
  value       = hcloud_server.renode1.*.id
  description = "ID"
}
output "sever_password_renode1" {
  value = random_password.password.*.result
}
