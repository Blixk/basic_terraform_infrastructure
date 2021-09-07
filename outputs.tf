output "vpc_name" {
  description = "The name of the VPC created"
  value       = google_compute_network.kblix-cka-vpc.name
}


#output "public_gateway_ip" {
#  description = "The IP that Google has assigned for our public gateway"
#  value       = google_compute_subnetwork.public-primary.gateway_address
#}

#output "public_ssh_key" {
#  description = "The SSH key used to log into gcp bastions"
#  value       = google_compute_instance_template.bastion-primary.metadata
#}
