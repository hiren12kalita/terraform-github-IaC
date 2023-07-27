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

variable "cluster_name" {
  description = "Name of new or existing cluster."
}

variable "create_config" {
  description = "Create prerequisite resources, fill if project, vpc, or cluster creation is needed."
  type = object({
    cluster = optional(object({
      labels = optional(map(string))
      master_authorized_ranges = optional(map(string), {
        rfc-1918-10-8 = "10.0.0.0/8"
      })
      master_ipv4_cidr_block = optional(string, "172.16.20.0/28")
      vpc = optional(object({
        id        = string
        subnet_id = string
        secondary_range_names = optional(object({
          pods     = optional(string, "pods")
          services = optional(string, "services")
        }), {})
      }))
    }))
    project = optional(object({
      billing_account = string
      parent          = optional(string)
      shared_vpc_host = optional(string)
    }))
    vpc = optional(object({
      primary_range_nodes      = optional(string, "10.0.0.0/24")
      secondary_range_pods     = optional(string, "10.16.0.0/20")
      secondary_range_services = optional(string, "10.32.0.0/24")
    }))
  })
  nullable = false
  default  = {}
  # TODO(ludo): validate that only one of cluster.vpc and vpc is not null
}

# https://cloud.google.com/anthos/fleet-management/docs/before-you-begin/gke#gke-cross-project

variable "fleet_config" {
  description = "GKE Fleet configuration."
  type = object({
    project_id = optional(string)
  })
  nullable = false
  default  = {}
}

variable "prefix" {
  description = "Prefix used for resource names."
  type        = string
  nullable    = false
  default     = "jump-0"
}

variable "project_id" {
  description = "Project id of existing or created project."
  type        = string
  default     = null
}

variable "region" {
  description = "Region used for cluster and network resources."
  type        = string
  default     = "europe-west8"
}
