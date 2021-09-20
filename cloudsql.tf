# Create the database cluster. In this case, cluster size will be 1 node for the forseeable future.
# This step is similar to installing MySQL on a local machine (or on a machine on your network)
resource "google_sql_database_instance" "stock-ticker-db-cluster" {
  name                  = "stock-ticker-db-cluster"
  project               = var.project_id
  region                = var.default_region
  database_version      = "MYSQL_5_7"
  root_password         = var.sql_password
  deletion_protection   = false
  settings {
    tier              = "db-f1-micro"
    activation_policy = "ALWAYS"
    availability_type = "REGIONAL"
    disk_size         = 200
    ip_configuration {
      ipv4_enabled    = true
      authorized_networks {
        name  = "on-prem"
        value = "${var.public_ip}/32"
      }
    }
    backup_configuration {
      binary_log_enabled             = true
      enabled                        = true
      transaction_log_retention_days = 3
      backup_retention_settings {
        retained_backups = 3
        retention_unit = "COUNT"
      }
    }
  }
}

# Create the database on the database cluster
resource "google_sql_database" "stock-ticker-db" {
  name     = "stock-ticker-db"
  project  = var.project_id
  instance = google_sql_database_instance.stock-ticker-db-cluster.name
  charset  = "UTF8"
}

# Create a non-root user (non-IAM in this case) to act on the database
resource "google_sql_user" "stock-ticker-db-user" {
  instance        = google_sql_database_instance.stock-ticker-db-cluster.name
  type            = "BUILT_IN"
  deletion_policy = "ABANDON"
  name            = var.sql_username
  password        = var.sql_password
}
