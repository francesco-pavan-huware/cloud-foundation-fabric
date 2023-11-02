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

output "project_id" {
  description = "Project."
  value       = module.project.project_id
}

output "network" {
  description = "Local network, if created."
  value       = try(var.shared_vpc_config.use_for_apigee, false) ? null : module.vpc[0]
}

output "instance_service_attachments" {
  description = "Instance service attachments."
  value       = { for k, v in module.apigee.instances : k => v.service_attachment }
}

output "endpoint_attachment_hosts" {
  description = "Endpoint attachment hosts."
  value       = module.apigee.endpoint_attachment_hosts
}
