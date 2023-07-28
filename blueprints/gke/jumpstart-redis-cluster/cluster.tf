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

locals {
  cluster_vpc = (
    local.use_shared_vpc || !local.create_vpc
    ? {
      network = try(var.create_config.cluster.vpc.id, null)
      secondary_range_names = try(
        var.create_config.cluster.vpc.secondary_range_names, null
      )
      subnet = try(var.create_config.cluster.vpc.subnet_id, null)
    }
    : {
      network               = module.vpc.0.id
      secondary_range_names = { pods = "pods", services = "services" }
      subnet                = module.vpc.0.subnet_ids["${var.region}/${var.prefix}-default"]
    }
  )
}

module "cluster" {
  source     = "../../../modules/gke-cluster-autopilot"
  count      = var.create_config.cluster != null ? 1 : 0
  project_id = module.project.project_id
  name       = var.cluster_name
  location   = var.region
  vpc_config = {
    network                  = local.cluster_vpc.network
    subnetwork               = local.cluster_vpc.subnet
    secondary_range_names    = local.cluster_vpc.secondary_range_names
    master_authorized_ranges = var.create_config.cluster.master_authorized_ranges
    master_ipv4_cidr_block   = var.create_config.cluster.master_ipv4_cidr_block
  }
  private_cluster_config = {
    enable_private_endpoint = true
    master_global_access    = true
  }
  labels = var.create_config.cluster.labels
}