
provider "google" {
  credentials = file("~/.terraform_credentials.json")
  project     = var.project_id
  region      = var.default_region
}

#
#resource "google_compute_project_metadata" "projectwide-metadata" {
#  project = var.project_id
#  metadata = {
#    enable-oslogin = "TRUE"
#  }
#}
#
#data "google_client_openid_userinfo" "keith" {
#}
#
#resource "google_os_login_ssh_public_key" "key" {
#  user = data.google_client_openid_userinfo.keith.email
#  key  = file("${var.ssh_publickey_path}/kblix-test-1.pub")
#}
