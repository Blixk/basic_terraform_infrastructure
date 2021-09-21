resource "google_storage_bucket" "stock-ticker-bucket" {
  name                        = "stock-ticker-bucket"
  project                     = var.project_id
  location                    = "US"
  storage_class               = "MULTI_REGIONAL"
  uniform_bucket_level_access = false
}

resource "google_storage_bucket_access_control" "access-control-stock-ticker-bucket" {
  bucket = google_storage_bucket.stock-ticker-bucket.name
  entity = "user-keith.blix@gmail.com"
  role   = "OWNER"
}

resource "google_storage_default_object_access_control" "private-rule" {
  bucket = google_storage_bucket.stock-ticker-bucket.name
  entity = "user-keith.blix@gmail.com" 
  role   = "OWNER"
}

resource "google_storage_bucket" "kblix-tf-state" {
  name                        = "kblix-tf-state"
  project                     = var.project_id
  location                    = "US"
  storage_class               = "MULTI_REGIONAL"
  uniform_bucket_level_access = false
}

resource "google_storage_bucket_access_control" "access-control-tf-state" {
  bucket = google_storage_bucket.kblix-tf-state.name
  entity = "user-keith.blix@gmail.com"
  role   = "OWNER"
}

resource "google_storage_default_object_access_control" "private-rule-tf-state" {
  bucket = google_storage_bucket.kblix-tf-state.name
  entity = "user-keith.blix@gmail.com" 
  role   = "OWNER"
}


