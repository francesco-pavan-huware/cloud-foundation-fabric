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

variable "apigee_config" {
  description = "Apigee Configuration"
  type = object({
    addons_config = optional(object({
      advanced_api_ops    = optional(bool, false)
      api_security        = optional(bool, false)
      connectors_platform = optional(bool, false)
      integration         = optional(bool, false)
      monetization        = optional(bool, false)
    }))
    organization = object({
      display_name            = optional(string)
      description             = optional(string, "Terraform-managed")
      billing_type            = optional(string)
      database_encryption_key = optional(string)
      analytics_region        = optional(string, "europe-west1")
      retention               = optional(string)
      disable_vpc_peering     = optional(bool, false)
    })
    envgroups = optional(map(list(string)), {})
    environments = optional(map(object({
      description  = optional(string)
      display_name = optional(string)
      envgroups    = optional(list(string), [])
      iam          = optional(map(list(string)), {})
      iam_bindings = optional(map(object({
        role    = string
        members = list(string)
        condition = optional(object({
          expression  = string
          title       = string
          description = optional(string)
        }))
      })), {})
      iam_bindings_additive = optional(map(object({
        role   = string
        member = string
        condition = optional(object({
          expression  = string
          title       = string
          description = optional(string)
        }))
      })), {})
      node_config = optional(object({
        min_node_count = optional(number)
        max_node_count = optional(number)
      }), {})
      type = optional(string)
    })), {})
    instances = optional(map(object({
      disk_encryption_key   = optional(string)
      environments          = optional(list(string), [])
      external              = optional(bool, true)
      runtime_ip_cidr_range = optional(string)
      subnet = object({
        ip_cidr_range = optional(string)
        id            = optional(string)
      })
      subnet_proxy_only_ip_cidr_range = optional(string)
      subnet_psc = object({
        ip_cidr_range = optional(string)
        id            = optional(string)
      })
      troubleshooting_ip_cidr_range = optional(string)
    })), {})
    endpoint_attachments = optional(map(object({
      region             = string
      service_attachment = string
      dns_names          = optional(list(string), [])
    })), {})
  })
  validation {
    condition = (!var.apigee_config.organization.disable_vpc_peering ||
    alltrue([for k, v in var.apigee_config.endpoint_attachments : length(v.dns_names) == 0]))
    error_message = "If disable_vpc_peering is true for the organization, DNS names cannot be used for endpoint attachments."
  }
  nullable = false
}

variable "glb_config" {
  description = "GLB configuration."
  type = object({
    log_sample_rate = optional(number)
    outlier_detection = optional(object({
      consecutive_errors                    = optional(number)
      consecutive_gateway_failure           = optional(number)
      enforcing_consecutive_errors          = optional(number)
      enforcing_consecutive_gateway_failure = optional(number)
      enforcing_success_rate                = optional(number)
      max_ejection_percent                  = optional(number)
      success_rate_minimum_hosts            = optional(number)
      success_rate_request_volume           = optional(number)
      success_rate_stdev_factor             = optional(number)
      base_ejection_time = optional(object({
        seconds = number
        nanos   = optional(number)
      }))
      interval = optional(object({
        seconds = number
        nanos   = optional(number)
      }))
    }))
    security_policy = optional(object({
      advanced_options_config = optional(object({
        json_parsing = optional(object({
          enable        = optional(bool, false)
          content_types = optional(list(string))
        }))
        log_level = optional(string)
      }))
      adaptive_protection_config = optional(object({
        layer_7_ddos_defense_config = optional(object({
          enable          = optional(bool, false)
          rule_visibility = optional(string)
        }))
        auto_deploy_config = optional(object({
          load_threshold              = optional(number)
          confidence_threshold        = optional(number)
          impacted_baseline_threshold = optional(number)
          expiration_sec              = optional(number)
        }))
      }))
      rate_limit_threshold = optional(object({
        count        = number
        interval_sec = number
      }))
      forbidden_src_ip_ranges = optional(list(string), [])
      forbidden_regions       = optional(list(string), [])
      preconfigured_waf_rules = optional(map(object({
        sensitivity      = optional(number)
        opt_in_rule_ids  = optional(list(string), [])
        opt_out_rule_ids = optional(list(string), [])
      })))
    }))
    ssl_certificates = object({
      certificate_ids = optional(list(string), [])
      create_configs = optional(map(object({
        certificate = string
        private_key = string
      })), {})
      managed_configs = optional(map(object({
        domains     = list(string)
        description = optional(string)
      })), {})
      self_signed_configs = optional(list(string), null)
    })
  })
  default = null
}

variable "ilb_l7_config" {
  description = "ILB L7 configuration."
  type = object({
    log_sample_rate = optional(number)
    outlier_detection = optional(object({
      consecutive_errors                    = optional(number)
      consecutive_gateway_failure           = optional(number)
      enforcing_consecutive_errors          = optional(number)
      enforcing_consecutive_gateway_failure = optional(number)
      enforcing_success_rate                = optional(number)
      max_ejection_percent                  = optional(number)
      success_rate_minimum_hosts            = optional(number)
      success_rate_request_volume           = optional(number)
      success_rate_stdev_factor             = optional(number)
      base_ejection_time = optional(object({
        seconds = number
        nanos   = optional(number)
      }))
      interval = optional(object({
        seconds = number
        nanos   = optional(number)
      }))
    }))
    ssl_certificates = object({
      certificate_ids = optional(list(string), [])
      create_configs = optional(map(object({
        certificate = string
        private_key = string
      })), {})
      self_signed_configs = optional(list(string), [])
    })
  })
  default = null
}

variable "enable_monitoring" {
  description = "Boolean flag indicating whether an custom metric to monitor instances should be created in Cloud monitoring."
  type        = bool
  default     = false
}

variable "prefix" {
  description = "Prefix to use for resources created"
  type        = string
  default     = null
}

variable "project_config" {
  description = "Project configuration."
  type = object({
    billing_account_id      = optional(string)
    compute_metadata        = optional(map(string), {})
    contacts                = optional(map(list(string)), {})
    custom_roles            = optional(map(list(string)), {})
    default_service_account = optional(string, "keep")
    descriptive_name        = optional(string)
    iam                     = optional(map(list(string)), {})
    group_iam               = optional(map(list(string)), {})
    iam_bindings = optional(map(object({
      role    = string
      members = list(string)
      condition = optional(object({
        expression  = string
        title       = string
        description = optional(string)
      }))
    })), {})
    iam_bindings_additive = optional(map(object({
      role   = string
      member = string
      condition = optional(object({
        expression  = string
        title       = string
        description = optional(string)
      }))
    })), {})
    labels              = optional(map(string), {})
    lien_reason         = optional(string)
    logging_data_access = optional(map(map(list(string))), {})
    log_exclusions      = optional(map(string), {})
    logging_sinks = optional(map(object({
      bq_partitioned_table = optional(bool)
      description          = optional(string)
      destination          = string
      disabled             = optional(bool, false)
      exclusions           = optional(map(string), {})
      filter               = string
      iam                  = optional(bool, true)
      type                 = string
      unique_writer        = optional(bool, true)
    })), {})
    metric_scopes = optional(list(string), [])
    name          = string
    org_policies = optional(map(object({
      inherit_from_parent = optional(bool) # for list policies only.
      reset               = optional(bool)
      rules = optional(list(object({
        allow = optional(object({
          all    = optional(bool)
          values = optional(list(string))
        }))
        deny = optional(object({
          all    = optional(bool)
          values = optional(list(string))
        }))
        enforce = optional(bool) # for boolean policies only.
        condition = optional(object({
          description = optional(string)
          expression  = optional(string)
          location    = optional(string)
          title       = optional(string)
        }), {})
      })), [])
    })), {})
    org_policies_data_path     = optional(string)
    parent                     = optional(string)
    project_create             = optional(bool, true)
    service_perimeter_bridges  = optional(list(string))
    service_perimeter_standard = optional(string)
    services                   = optional(list(string), [])
    shared_vpc_host_config = optional(object({
      enabled          = bool
      service_projects = optional(list(string), [])
    }))
    shared_vpc_service_config = optional(object({
      host_project         = string
      service_identity_iam = optional(map(list(string)), {})
      service_iam_grants   = optional(list(string), [])
    }))
    skip_delete  = optional(bool, false)
    tag_bindings = optional(map(string))
  })
}

variable "shared_vpc_config" {
  description = "Shared VPC config."
  type = object({
    id             = string
    use_for_apigee = optional(bool, false)
  })
  default = null
}
