provider "azurerm" {
  version  = "~>2.0.0"
  features {}
}

resource "azurerm_resource_group" "dash" {
  name     = "${var.resource_group_prefix}-PUB-DASH-${var.environment}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "data" {
  name     = "${var.resource_group_prefix}-PUB-DATA-${var.environment}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "data" {
  name                     = "publicdashacc${lower(var.environment)}"
  resource_group_name      = azurerm_resource_group.data.name
  location                 = var.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "RAGRS"

  tags                     = var.tags
}

resource "azurerm_storage_container" "downloads" {
  name                     = "downloads"
  storage_account_name     = azurerm_storage_account.data.name
  container_access_type    = "container"
}

resource "azurerm_storage_container" "publicdata" {
  name                     = "publicdata"
  storage_account_name     = azurerm_storage_account.data.name
  container_access_type    = "container"
}

resource "azurerm_storage_container" "tiles" {
  name                     = "tiles"
  storage_account_name     = azurerm_storage_account.data.name
  container_access_type    = "container"
}

resource "azurerm_storage_container" "tiles-png" {
  name                     = "tiles-png"
  storage_account_name     = azurerm_storage_account.data.name
  container_access_type    = "container"
}

resource "azurerm_app_service_plan" "dash" {
  name                = "ASP-Covid19Static-a9c6-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.dash.name
  kind                = "app"

  sku {
    tier = "PremiumV2"
    size = "P2v2"
    capacity = "2"
  }

  tags = var.tags
}

resource "azurerm_app_service" "dash" {
  name                = "Covid19Static${var.environment}"
  location            = azurerm_resource_group.dash.location
  resource_group_name = azurerm_resource_group.dash.name
  app_service_plan_id = azurerm_app_service_plan.dash.id

  site_config {
    dotnet_framework_version = "v4.0"
    #scm_type                 = "LocalGit"
  }

  app_settings = {
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "True"
    "WEBSITE_HTTPLOGGING_RETENTION_DAYS" = "3"
    "WEBSITE_NODE_DEFAULT_VERSION" = "10.14"
  }

}

resource "azurerm_storage_account" "function" {
  name                     = "fndashstorageacc${lower(var.environment)}"
  resource_group_name      = azurerm_resource_group.dash.name
  location                 = var.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags                     = var.tags
}

resource "azurerm_storage_container" "azure-webjobs-hosts" {
  name                     = "azure-webjobs-hosts"
  storage_account_name     = azurerm_storage_account.function.name
  container_access_type    = "private"
}

resource "azurerm_storage_container" "azure-webjobs-secrets" {
  name                     = "azure-webjobs-secrets"
  storage_account_name     = azurerm_storage_account.function.name
  container_access_type    = "private"
}

resource "azurerm_application_insights" "dash" {
  name                = "Covid19PublicAppInsights${var.environment}"
  location            = azurerm_resource_group.dash.location
  resource_group_name = azurerm_resource_group.dash.name
  application_type    = "web"
}

output "instrumentation_key" {
  value = azurerm_application_insights.dash.instrumentation_key
}

output "app_id" {
  value = azurerm_application_insights.dash.app_id
}

resource "azurerm_function_app" "function" {
  name                      = "fn-coronavirus-dashboard-pipeline-etl-${lower(var.environment)}"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.dash.name
  app_service_plan_id       = azurerm_app_service_plan.dash.id
  storage_connection_string = azurerm_storage_account.function.primary_connection_string
  version                   = "~3"
 
  
  app_settings = {
    "AzureWebJobsStorage" = azurerm_storage_account.function.primary_connection_string,
    "FUNCTIONS_EXTENSION_VERSION" = "~3",
    "FUNCTIONS_WORKER_RUNTIME" = "python",
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.dash.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = "InstrumentationKey=${azurerm_application_insights.dash.instrumentation_key}"
    "BUILD_FLAGS" = "UseExpressBuild"
    "DeploymentBlobStorage" = azurerm_storage_account.function.primary_connection_string
    "ENABLE_ORYX_BUILD" = "true"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "1"
    "XDG_CACHE_HOME" = "/tmp/.cache"
  }
}

resource "azurerm_log_analytics_workspace" "dash" {
  name                = "law-covid19static-${lower(var.environment)}"
  location            = azurerm_resource_group.dash.location
  resource_group_name = azurerm_resource_group.dash.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_log_analytics_solution" "dash" {
  solution_name         = "AzureCdnCoreAnalytics"
  location              = azurerm_resource_group.dash.location
  resource_group_name   = azurerm_resource_group.dash.name
  workspace_resource_id = azurerm_log_analytics_workspace.dash.id
  workspace_name        = azurerm_log_analytics_workspace.dash.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/AzureCdnCoreAnalytics"
  }
}

