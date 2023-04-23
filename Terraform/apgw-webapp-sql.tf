provider "azurerm" {
    features{}
}

data "azurerm_resource_group" "apprg" {
  name     = "ApplicationResourceGroup"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "sharathapp-vnet"
  location            = data.azurerm_resource_group.apprg.location
  resource_group_name = data.azurerm_resource_group.apprg.name
  address_space       = ["10.4.0.0/16"]
}

# Subnets for App Service instances and app gateway
resource "azurerm_subnet" "appserv" {
  name                 = "frontend-app"
  resource_group_name  = data.azurerm_resource_group.apprg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.4.1.0/24"]
  enforce_private_link_endpoint_network_policies = true
  }

resource "azurerm_subnet" "appgw" {
  name                 = "appgw-subnet"
  resource_group_name  = data.azurerm_resource_group.apprg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.4.2.0/24"]
  enforce_private_link_endpoint_network_policies = true
  }


# App Service Plan
resource "azurerm_app_service_plan" "frontend" {
  name                = "sharath-frontend-asp"
  location            = data.azurerm_resource_group.apprg.location
  resource_group_name = data.azurerm_resource_group.apprg.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Premium"
    size = "P1V2"
  }
}


# Main App Service



resource "azurerm_app_service" "app-service1" {
  name                = var.app-service-name1
  location            = azurerm_resource_group.apprg.location
  resource_group_name = azurerm_resource_group.apprg.name
  app_service_plan_id = azurerm_app_service_plan.plan.id
  storage_connection_string = "${azurerm_storage_account.sharedrg.primary_connection_string}"
  app_settings {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = "${azurerm_application_insights.sharedrg.instrumentation_key}"
  }

  site_config {
    dotnet_framework_version = "v4.0"
    scm_type                 = "LocalGit"
  }

  connection_string {
    name  = "Database"
    type  = "SQLServer"
    value = "Server=tcp:${azurerm_sql_server.sqldb.fully_qualified_domain_name} Database=${azurerm_sql_database.db.name};User ID=${azurerm_sql_server.sqldb.administrator_login};Password=${azurerm_sql_server.sqldb.administrator_login_password};Trusted_Connection=False;Encrypt=True;"
  }
}

resource "azurerm_app_service" "app-service2" {
  name                = var.app-service-name2
  location            = azurerm_resource_group.apprg.location
  resource_group_name = azurerm_resource_group.apprg.name
  app_service_plan_id = azurerm_app_service_plan.plan.id
  storage_connection_string = "${azurerm_storage_account.test.primary_connection_string}"

  app_settings {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = "${azurerm_application_insights.test.instrumentation_key}"
  }

  site_config {
    dotnet_framework_version = "v4.0"
    scm_type                 = "LocalGit"
  }

  connection_string {
    name  = "Database"
    type  = "SQLServer"
    value = "Server=tcp:${azurerm_sql_server.sqldb.fully_qualified_domain_name} Database=${azurerm_sql_database.db.name};User ID=${azurerm_sql_server.sqldb.administrator_login};Password=${azurerm_sql_server.sqldb.administrator_login_password};Trusted_Connection=False;Encrypt=True;"
  }
}



#private endpoint

resource "azurerm_private_endpoint" "example1" {
  name                = "${azurerm_app_service.app-service1.name}-endpoint"
  location            = data.azurerm_resource_group.apprg.location
  resource_group_name = data.azurerm_resource_group.apprg.name
  subnet_id           = azurerm_subnet.appserv.id


  private_service_connection {
    name                           = "${azurerm_app_service.app-service1.name}-privateconnection"
    private_connection_resource_id = azurerm_app_service.app-service1.id
    subresource_names = ["sites"]
    is_manual_connection = false
  }
}

resource "azurerm_private_endpoint" "example2" {
  name                = "${azurerm_app_service.app-service2.name}-endpoint"
  location            = data.azurerm_resource_group.apprg.location
  resource_group_name = data.azurerm_resource_group.apprg.name
  subnet_id           = azurerm_subnet.appserv.id


  private_service_connection {
    name                           = "${azurerm_app_service.app-service2.name}-privateconnection"
    private_connection_resource_id = azurerm_app_service.app-service2.id
    subresource_names = ["sites"]
    is_manual_connection = false
  }
}

# private DNS
resource "azurerm_private_dns_zone" "example" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = data.azurerm_resource_group.apprg.name
}

#private DNS Link
resource "azurerm_private_dns_zone_virtual_network_link" "example1" {
  name                  = "${azurerm_app_service.app-service1.name}-dnslink"
  resource_group_name   = data.azurerm_resource_group.apprg.name
  private_dns_zone_name = azurerm_private_dns_zone.example1.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "example2" {
  name                  = "${azurerm_app_service.app-service2.name}-dnslink"
  resource_group_name   = data.azurerm_resource_group.apprg.name
  private_dns_zone_name = azurerm_private_dns_zone.example2.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled = false
}

resource "azurerm_public_ip" "agw" {
  name                = "sharath-agw-pip"
  location              = data.azurerm_resource_group.apprg.location
  resource_group_name   = data.azurerm_resource_group.apprg.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

# Application Gateway
resource "azurerm_application_gateway" "agw" {
  name                = "sharath-agw"
  location              = data.azurerm_resource_group.apprg.location
  resource_group_name   = data.azurerm_resource_group.apprg.name

  sku {
    name     = "WAF_Medium"
    tier     = "WAF"
    capacity = 2
  }

  waf_configuration {
    enabled          = "true"
    firewall_mode    = "Detection"
    rule_set_type    = "OWASP"
    rule_set_version = "3.0"
  }

  gateway_ip_configuration {
    name      = "subnet"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = "${azurerm_public_ip.agw.id}"
  }

  backend_address_pool {
    name        = "AppService"
    fqdns = ["${azurerm_app_service.app-service1.name}.azurewebsites.net","${azurerm_app_service.app-service2.name}.azurewebsites.net"]
  }

  http_listener {
    name                           = "http"
    frontend_ip_configuration_name = "frontend"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  probe {
    name                = "probe1"
    protocol            = "http"
    path                = "/"
    host                = "${azurerm_app_service.app-service1.name}.azurewebsites.net"
    interval            = "30"
    timeout             = "30"
    unhealthy_threshold = "3"
  }
  probe {
    name                = "probe2"
    protocol            = "http"
    path                = "/"
    host                = "${azurerm_app_service.app-service2.name}.azurewebsites.net"
    interval            = "30"
    timeout             = "30"
    unhealthy_threshold = "3"
  }

  backend_http_settings {
    name                  = "http1"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
    probe_name            = "probe1"
    pick_host_name_from_backend_address = true
  }

  backend_http_settings {
    name                  = "http2"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
    probe_name            = "probe2"
    pick_host_name_from_backend_address = true
  }
  request_routing_rule {
    name                       = "http1"
    rule_type                  = "Basic"
    http_listener_name         = "http1"
    backend_address_pool_name  = "AppService"
    backend_http_settings_name = "http1"


  }
  request_routing_rule {
    name                       = "http2"
    rule_type                  = "Basic"
    http_listener_name         = "http2"
    backend_address_pool_name  = "AppService"
    backend_http_settings_name = "http2"

  }
}
resource "azurerm_resource_group" "sharedrg" {
  name     = var.resource-group-name
  location = var.location
}

resource "random_id" "server" {
  keepers = {
    # Generate a new id each time we switch to a new Azure Resource Group
    rg_id = "${azurerm_resource_group.sharedrg.name}"
  }

  byte_length = 8
}

resource "azurerm_storage_account" "test" {
  name                     = "${random_id.server.hex}"
  resource_group_name      = "${azurerm_resource_group.sharedrg.name}"
  location                 = "${azurerm_resource_group.sharedrg.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_application_insights" "test" {
  name                = "test-terraform-insights"
  location            = "${azurerm_resource_group.sharedrg.location}"
  resource_group_name = "${azurerm_resource_group.sharedrg.name}"
  application_type    = "Web"
}
resource "azurerm_sql_server" "sqldb" {
  name                         = "terraform-sqlserver"
  resource_group_name          = azurerm_resource_group.sharedrg.name
  location                     = azurerm_resource_group.sharedrg.location
  version                      = "12.0"
  administrator_login          = "sharath"
  administrator_login_password = "4-v3ry-53cr37-p455w0rd"
}

resource "azurerm_sql_database" "db" {
  name                = "terraform-sqldatabase"
  resource_group_name = azurerm_resource_group.sharedrg.name
  location            = azurerm_resource_group.sharedrg.location
  server_name         = azurerm_sql_server.sqldb.name

  tags = {
    environment = "production"
  }
}
