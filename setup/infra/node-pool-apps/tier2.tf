/**
 * Copyright 2019 Google LLC
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

resource "google_container_node_pool" "tier2" {
  provider           = google-beta
  count              = var.tier2_pool_enabled ? 1 : 0
  name               = "tier2"
  location           = var.region
  cluster            = data.google_container_cluster.broker.name
  initial_node_count = var.tier2_pool_initial_node_count

  node_config {
    preemptible  = var.tier2_pool_preemptive_nodes
    machine_type = var.tier2_pool_machine_type

    service_account = data.google_service_account.broker_cluster.email

    disk_size_gb = var.tier2_pool_disk_size_gb
    disk_type    = var.tier2_pool_disk_type

    ephemeral_storage_config {
      local_ssd_count = var.tier2_pool_ephemeral_storage_ssd_count
    }

    image_type = "COS_CONTAINERD"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    metadata = {
      cluster_name             = data.google_container_cluster.broker.name
      node_pool                = "tier2"
      disable-legacy-endpoints = "true"
    }

    labels = {
      cluster_name = data.google_container_cluster.broker.name
      node_pool    = "tier2"

      # updated by node init daemonset when finished.
      "app.broker/initialized" = "false"

      # Used to set pod affinity
      "app.broker/tier" = "tier2"
    }

    taint = [
      {
        # Taint to be removed when node init daemonset completes.
        key    = "app.broker/node-init"
        value  = true
        effect = "NO_SCHEDULE"
      },
      {
        # Repel pods without the tier toleration.
        key    = "app.broker/tier"
        value  = "tier2"
        effect = "NO_SCHEDULE"
      },
    ]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  autoscaling {
    min_node_count = var.tier2_pool_min_node_count
    max_node_count = var.tier2_pool_max_node_count
  }

  // node labels and taints are modified dynamically by the node init containers
  // ignore changes so that Terraform doesn't try to undo their modifications.
  lifecycle {
    ignore_changes = [
      node_config[0].labels,
      node_config[0].taint
    ]
  }
}
