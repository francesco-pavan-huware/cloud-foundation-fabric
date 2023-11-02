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
  internal_instances = { for k, v in var.apigee_config.instances : k => v if v.subnet != null && v.subnet_psc != null }
  external_instances = { for k, v in var.apigee_config.instances : k => v if v.external && v.subnet_psc != null }
  instances          = merge(local.internal_instances, local.external_instances)
  preconfigured_waf_rules = { for k, v in try(var.glb_config.security_policy.preconfigured_waf_rules, {}) : k =>
    merge(v.sensitivity == null ? {} : {
      sensitivity = v.sensitivity
      },
      length(v.opt_in_rule_ids) > 0 ? {
        opt_in_rule_ids = v.opt_in_rule_ids
      } : {},
      length(v.opt_out_rule_ids) > 0 ? {
        opt_out_rule_ids = v.opt_out_rule_ids
    } : {})
  }
}

resource "google_compute_region_network_endpoint_group" "psc_negs" {
  for_each              = (var.glb_config == null && var.ilb_l7_config == null) ? {} : local.instances
  project               = module.project.project_id
  region                = each.key
  name                  = "apigee-${each.key}"
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  psc_target_service    = module.apigee.instances[each.key].service_attachment
  network               = try(module.vpc[0].id, var.shared_vpc_config.id)
  subnetwork            = try(module.vpc[0].subnets_psc["${each.key}/subnet-psc-${each.key}"].name, each.value.subnet_psc.id)
}

module "glb" {
  count               = length(local.external_instances) > 0 && var.glb_config != null ? 1 : 0
  source              = "../../../modules/net-lb-app-ext"
  name                = "nb-glb"
  project_id          = module.project.project_id
  protocol            = "HTTPS"
  use_classic_version = false
  backend_service_configs = {
    default = {
      backends          = [for k, v in local.external_instances : { backend = google_compute_region_network_endpoint_group.psc_negs[k].id }]
      protocol          = "HTTPS"
      health_checks     = []
      outlier_detection = var.glb_config.outlier_detection
      security_policy   = try(google_compute_security_policy.policy[0].name, null)
      log_sample_rate   = var.glb_config.log_sample_rate
    }
  }
  health_check_configs = {
    default = {
      https = { port_specification = "USE_SERVING_PORT" }
    }
  }
  ssl_certificates = var.glb_config.ssl_certificates
}

module "nb_ilb_l7" {
  for_each   = var.ilb_l7_config == null ? {} : local.internal_instances
  source     = "../../../modules/net-lb-app-int"
  name       = "nb-ilb-l7-${each.key}"
  project_id = module.project.project_id
  region     = each.key
  protocol   = "HTTPS"
  backend_service_configs = {
    default = {
      backends = [{
        group = google_compute_region_network_endpoint_group.psc_negs[each.key].id
      }]
      health_checks   = []
      log_sample_rate = var.ilb_l7_config.log_sample_rate
    }
  }
  ssl_certificates = var.ilb_l7_config.ssl_certificates
  vpc_config = {
    network    = try(module.vpc[0].id, var.shared_vpc_config.id)
    subnetwork = try(module.vpc[0].subnets_psc["${each.key}/subnet-psc-${each.key}"].id, each.value.subnet.id)
  }
}

resource "google_compute_security_policy" "policy" {
  provider    = google-beta
  count       = try(var.glb_config.security_policy, null) == null ? 0 : 1
  name        = "cloud-armor-security-policy"
  description = "Cloud Armor Security Policy"
  project     = module.project.project_id
  dynamic "advanced_options_config" {
    for_each = try(var.glb_config.security_policy.advanced_options_config, null) == null ? [] : [""]
    content {
      json_parsing = try(var.glb_config.security_policy.adaptive_protection_config.json_parsing.enable, false) ? "DISABLED" : "STANDARD"
      dynamic "json_custom_config" {
        for_each = try(var.glb_config.security_policy.adaptive_protection_config.json_parsing.content_types, null) == null ? [] : [""]
        content {
          content_types = var.glb_config.security_policy.adaptive_protection_config.json_parsing.content_types
        }
      }
      log_level = var.glb_config.security_policy.advanced_options_config.log_level
    }
  }
  dynamic "adaptive_protection_config" {
    for_each = try(var.glb_config.security_policy.adaptive_protection_config, null) == null ? [] : [""]
    content {
      dynamic "layer_7_ddos_defense_config" {
        for_each = try(var.glb_config.security_policy.adaptive_protection_config.layer_7_ddos_defense_config, null) == null ? [] : [""]
        content {
          enable          = var.glb_config.security_policy.adaptive_protection_config.layer_7_ddos_defense_config.enable
          rule_visibility = var.glb_config.security_policy.adaptive_protection_config.layer_7_ddos_defense_config.rule_visibility
        }
      }
      dynamic "auto_deploy_config" {
        for_each = try(var.glb_config.security_policy.adaptive_protection_config.auto_deploy_config, null) == null ? [] : [""]
        content {
          load_threshold              = var.glb_config.security_policy.adaptive_protection_config.auto_deploy_config.load_threshold
          confidence_threshold        = var.glb_config.security_policy.adaptive_protection_config.auto_deploy_config.confidence_threshold
          impacted_baseline_threshold = var.glb_config.security_policy.adaptive_protection_config.auto_deploy_config.impacted_baseline_threshold
          expiration_sec              = var.glb_config.security_policy.adaptive_protection_config.auto_deploy_config.expiration_sec
        }
      }
    }
  }
  type = "CLOUD_ARMOR"
  dynamic "rule" {
    for_each = try(var.glb_config.security_policy.rate_limit_threshold, null) == null ? [] : [""]
    content {
      action   = "throttle"
      priority = 3000
      rate_limit_options {
        enforce_on_key = "ALL"
        conform_action = "allow"
        exceed_action  = "deny(429)"
        rate_limit_threshold {
          count        = var.glb_config.security_policy.rate_limit_threshold.count
          interval_sec = var.glb_config.security_policy.rate_limit_threshold.interval_sec
        }
      }
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = ["*"]
        }
      }
      description = "Rate limit all user IPs"
    }
  }
  dynamic "rule" {
    for_each = try(length(var.glb_config.security_policy.forbidden_src_ip_ranges), 0) > 0 ? [""] : []
    content {
      action   = "deny(403)"
      priority = 5000
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = var.glb_config.security_policy.forbidden_src_ip_ranges
        }
      }
      description = "Deny access to IPs in specific ranges"
    }
  }
  dynamic "rule" {
    for_each = try(length(var.glb_config.security_policy.forbidden_regions), 0) > 0 ? [""] : []
    content {
      action   = "deny(403)"
      priority = 7000
      match {
        expr {
          expression = "origin.region_code.matches(\"^${join("|", var.glb_config.security_policy.forbidden_regions)}$\")"
        }
      }
      description = "Block users from forbidden regions"
    }
  }
  dynamic "rule" {
    for_each = local.preconfigured_waf_rules
    content {
      action   = "deny(403)"
      priority = 10000 + index(keys(var.glb_config.security_policy.preconfigured_waf_rules), rule.key) * 1000
      match {
        expr {
          expression = "evaluatePreconfiguredWaf(\"${rule.key}\"${length(rule.value) > 0 ? join("", [",", jsonencode(rule.value)]) : ""})"
        }
      }
      description = "Preconfigured WAF rule (${rule.key})"
    }
  }
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default rule"
  }
}
