terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "=0.119.0"
    }
  }
  required_version = ">= 1.8.3"
}

provider "yandex" {
  service_account_key_file = file("./.key.json")
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = "ru_central1-a"
}

resource "yandex_vpc_network" "network" {
  name = "network"
}

resource "yandex_vpc_subnet" "subnet1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_vpc_subnet" "subnet2" {
  name           = "subnet2"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["192.168.11.0/24"]
}


module "ya_instance_1" {
  source                = "./modules/instance"
  instance_family_image = "lamp"
  vpc_subnet_id         = yandex_vpc_subnet.subnet1.id
}

module "ya_instance_2" {
  source                = "./modules/instance"
  instance_family_image = "lamp"
  vpc_subnet_id         = yandex_vpc_subnet.subnet2.id
}

resource "yandex_lb_target_group" "web_servers_group" {
  name = "web-servers-group"
  target {
    subnet_id = yandex_vpc_subnet.subnet1.id
    address   = module.ya_instance_1.internal_ip_address_vm_1
  }
  target {
    subnet_id = yandex_vpc_subnet.subnet2.id
    address   = module.ya_instance_2.internal_ip_address_vm_2
  }
}
resource "yandex_lb_network_load_balancer" "web_load_balancer" {
  name = "web-load-balancer"
  listener {
    name = "ext-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }

  }
  attached_target_group {
    target_group_id = yandex_lb_target_group.web_servers_group.id
    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }

}