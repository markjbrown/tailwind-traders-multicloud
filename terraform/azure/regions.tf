module "primary_region" {
  source = "./region"

  deploy_identity = module.global.deploy_identity
  kubelet_identity = module.global.kubelet_identity
  location = "East US 2"
  resource_prefix = local.primary_resource_prefix

  app_aks_subnet_address_prefixes = [
    "192.168.0.0/24"
  ]

  app_vnet_address_space = [
    "192.168.0.0/16"
  ]
}