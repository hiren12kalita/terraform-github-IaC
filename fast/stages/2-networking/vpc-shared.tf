/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

################################################################################
#                                    Shared                                    #
################################################################################

module "shared-vpc" {
  source     = "../../../modules/net-vpc"
  project_id = module.net-project.project_id
  name       = "prod-core-shared-0"
  mtu        = 1500
  dns_policy = {
    inbound = true
  }
  delete_default_routes_on_create = true
  create_googleapis_routes = {
    restricted   = true
    restricted-6 = false
    private      = true
    private-6    = false
  }
  psa_config = {
    ranges = {
      gcve-shared-primary   = "100.101.5.0/24"
      gcve-shared-secondary = "100.102.5.0/24"
    }
    export_routes = false
    import_routes = true
  }
  subnets = [
    {
      ip_cidr_range = "100.101.4.0/28"
      name          = "prod-core-shared-0-nva-primary"
      region        = "europe-west8"
    },
    {
      ip_cidr_range = "100.102.4.128/28"
      name          = "prod-core-shared-0-nva-secondary"
      region        = "europe-west12"
    }
  ]
}

resource "google_compute_route" "shared-primary-tagged" {
  project      = module.net-project.project_id
  network      = module.shared-vpc.name
  name         = "shared-primary-tagged"
  description  = "Terraform-managed."
  dest_range   = "0.0.0.0/0"
  priority     = 1000
  tags         = [var.regions.primary]
  next_hop_ilb = module.shared-ilb-primary.forwarding_rule_self_link
}

resource "google_compute_route" "shared-secondary-tagged" {
  project      = module.net-project.project_id
  network      = module.shared-vpc.name
  name         = "shared-secondary-tagged"
  description  = "Terraform-managed."
  dest_range   = "0.0.0.0/0"
  priority     = 1000
  tags         = [var.regions.secondary]
  next_hop_ilb = module.shared-ilb-secondary.forwarding_rule_self_link
}

module "shared-firewall" {
  source     = "../../../modules/net-vpc-firewall"
  project_id = module.net-project.project_id
  network    = module.shared-vpc.name
  default_rules_config = {
    disabled = true
  }
  factories_config = {
    cidr_tpl_file = "${var.factories_config.data_dir}/cidrs.yaml"
    rules_folder  = "${var.factories_config.data_dir}/firewall-rules/shared"
  }
}

module "shared-addresses" {
  source     = "../../../modules/net-address"
  project_id = module.net-project.project_id
  internal_addresses = {
    shared-lb-primary = {
      region     = var.regions.primary
      subnetwork = module.shared-vpc.subnet_self_links["${var.regions.primary}/prod-core-shared-0-nva-primary"]
      address    = cidrhost(module.shared-vpc.subnet_ips["${var.regions.primary}/prod-core-shared-0-nva-primary"], -3)
    }
    shared-lb-secondary = {
      region     = var.regions.secondary
      subnetwork = module.shared-vpc.subnet_self_links["${var.regions.secondary}/prod-core-shared-0-nva-secondary"]
      address    = cidrhost(module.shared-vpc.subnet_ips["${var.regions.secondary}/prod-core-shared-0-nva-secondary"], -3)
    }
  }
}

module "shared-ilb-primary" {
  source     = "../../../modules/net-lb-int"
  project_id = module.net-project.project_id
  region     = var.regions.primary
  name       = "shared-lb-primary"
  vpc_config = {
    network    = module.shared-vpc.name
    subnetwork = module.shared-vpc.subnet_self_links["${var.regions.primary}/prod-core-shared-0-nva-primary"]
  }
  address       = module.shared-addresses.internal_addresses["shared-lb-primary"].address
  service_label = var.prefix
  global_access = true
  backends = [for z in local.zones :
    {
      failover       = false
      group          = google_compute_instance_group.nva-primary[z].id
      balancing_mode = "CONNECTION"
    }
  ]
  health_check_config = {
    tcp = {
      port = 22
    }
  }
}


module "shared-ilb-secondary" {
  source     = "../../../modules/net-lb-int"
  project_id = module.net-project.project_id
  region     = var.regions.secondary
  name       = "shared-lb-secondary"
  vpc_config = {
    network    = module.shared-vpc.name
    subnetwork = module.shared-vpc.subnet_self_links["${var.regions.secondary}/prod-core-shared-0-nva-secondary"]
  }
  address       = module.shared-addresses.internal_addresses["shared-lb-secondary"].address
  service_label = var.prefix
  global_access = true
  backends = [for z in ["a"] :
    {
      failover       = false
      group          = google_compute_instance_group.nva-secondary[z].id
      balancing_mode = "CONNECTION"
    }
  ]
  health_check_config = {
    tcp = {
      port = 22
    }
  }
}