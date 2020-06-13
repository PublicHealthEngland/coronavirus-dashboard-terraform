provider "azurerm" {
  version  = "~>2.7.0"
  features {}
}

resource "azurerm_resource_group" "dash" {
  name     = "${var.resource_group_prefix}-PUB-DASH-${var.environment}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "asp" {
  name     = "${var.resource_group_prefix}-PUB-DASH-ASP-${var.environment}"
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
  kind                = "Windows"
  reserved            = "false"

  sku {
    tier = "PremiumV2"
    size = "P2v2"
    capacity = "2"
  }

  tags = var.tags
}

resource "azurerm_app_service_plan" "function" {
  name                = "aspcovid19dashboardetl${lower(var.environment)}"
  location            = var.location
  resource_group_name = azurerm_resource_group.asp.name
  kind                = "linux"
  reserved            = "true"

  sku {
    tier = "PremiumV2"
    size = "P2v2"
    capacity = "1"
  }

  tags = var.tags
}

resource "azurerm_app_service" "dash" {
  name                = "Covid19Static${var.environment}"
  location            = azurerm_resource_group.dash.location
  resource_group_name = azurerm_resource_group.dash.name
  app_service_plan_id = azurerm_app_service_plan.dash.id
  https_only          = true

  site_config {
    dotnet_framework_version = "v4.0"
    scm_type                  = "GitHub"
    default_documents         = ["index.html"]    
  }

  app_settings = {
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "True"
    #"WEBSITE_HTTPLOGGING_RETENTION_DAYS" = "3"
    "WEBSITE_NODE_DEFAULT_VERSION" = "10.14"
  }

  tags               = var.tags

  lifecycle {
    ignore_changes = [ site_config.0.scm_type,  ]
    }

}

resource "azurerm_storage_account" "function" {
  name                     = "fndashstorageacc${lower(var.environment)}"
  resource_group_name      = azurerm_resource_group.asp.name
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
  retention_in_days   = "90"
  tags                = var.tags
}

output "instrumentation_key" {
  value = azurerm_application_insights.dash.instrumentation_key
}

output "app_id" {
  value = azurerm_application_insights.dash.app_id
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

resource "azurerm_cosmosdb_account" "dash" {
  name                = "covid19pubdash"
  location            = azurerm_resource_group.dash.location
  resource_group_name = azurerm_resource_group.dash.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  enable_multiple_write_locations = false
  enable_automatic_failover = false

  consistency_policy {
        consistency_level       = "Session"
        max_interval_in_seconds = 5
        max_staleness_prefix    = 100
    }

   geo_location {
        failover_priority = 0
        location          = "uksouth"
    }

    tags = { 
              Application = "Dashboards", 
              Contact = "PHE/MSFT", 
              CosmosAccountType = "Non-Production",
              Criticality       = "Tier 1",
              Environment       = "DEV",
              Owner             = "COVID19",
              defaultExperience = "Core (SQL)",
              hidden-cosmos-mmspecial = ""
        }
}

resource "azurerm_cosmosdb_sql_database" "dash" {
  name                = "COVID19"
  resource_group_name = azurerm_resource_group.dash.name
  account_name        = azurerm_cosmosdb_account.dash.name
}

resource "azurerm_cosmosdb_sql_container" "dash" {
  name                = "publicdata"
  resource_group_name = azurerm_resource_group.dash.name
  account_name        = azurerm_cosmosdb_account.dash.name
  database_name       = azurerm_cosmosdb_sql_database.dash.name 
  partition_key_path  = "/hash"
  unique_key {
          paths = ["/hash",]
        }
}

resource "azurerm_data_factory" "dash" {
  name                = "covid19-data-transformer-${lower(var.environment)}"
  location            = var.location
  resource_group_name = azurerm_resource_group.dash.name
  tags                = var.tags

  github_configuration {
        account_name    = "publichealthengland"
        branch_name     = "master"
        repository_name = "coronavirus-dashboard-pipeline"
        root_folder     = "/"
        git_url         = "https://github.com/publichealthengland/coronavirus-dashboard-pipeline"
    }

    identity {
        type         = "SystemAssigned"
    }

  lifecycle {
    ignore_changes = [
      github_configuration.0.git_url,
    ]
  }
}

resource "azurerm_resource_group" "apim" {
  name     = "${var.resource_group_prefix}-PUB-DASH-${var.environment}-APIM"
  location = var.location
  tags     = var.tags

  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
}

resource "azurerm_redis_cache" "apim" {
  name                = "uks-covid19-pub-dash-redis-${lower(var.environment)}"
  location            = azurerm_resource_group.apim.location
  resource_group_name = azurerm_resource_group.apim.name
  capacity            = 1
  family              = "C"
  sku_name            = "Standard"
  enable_non_ssl_port = false
  #minimum_tls_version = "1.2"

  redis_configuration {
        aof_backup_enabled              = false
        enable_authentication           = true
        maxfragmentationmemory_reserved = 50
        maxmemory_delta                 = 50
        maxmemory_reserved              = 50
        rdb_backup_enabled              = false
    }

    lifecycle {
    ignore_changes = [
      redis_configuration.0.maxmemory_policy,tags,minimum_tls_version
    ]
  }

    tags = var.tags
}

resource "azurerm_api_management" "apim" {
  name                = "uks-covid19-pubdash-${lower(var.environment)}"
  location            = azurerm_resource_group.apim.location
  resource_group_name = azurerm_resource_group.apim.name
  publisher_email           = "russell.smith@microsoft.com"
  publisher_name            = "PHE"
  notification_sender_email = "apimgmt-noreply@mail.windowsazure.com"

  sku_name = "Developer_1"

  policy {
    xml_content = <<XML
        <!--
            IMPORTANT:
            - Policy elements can appear only within the <inbound>, <outbound>, <backend> section elements.
            - Only the <forward-request> policy element can appear within the <backend> section element.
            - To apply a policy to the incoming request (before it is forwarded to the backend service), place a corresponding policy element within the <inbound> section element.
            - To apply a policy to the outgoing response (before it is sent back to the caller), place a corresponding policy element within the <outbound> section element.
            - To add a policy position the cursor at the desired insertion point and click on the round button associated with the policy.
            - To remove a policy, delete the corresponding policy statement from the policy document.
            - Policies are applied in the order of their appearance, from the top down.
        -->
        <policies>
                <inbound />
                <backend>
                        <forward-request />
                </backend>
                <outbound />
        </policies>
    XML
    }

    lifecycle {
    ignore_changes = [
      tags,policy.0.xml_content
    ]
  }

    tags = var.tags
}

resource "azurerm_api_management_api" "apim" {
  display_name                = "covid19-api"
  name                        = "fn-coronavirus-dashboard-pipeline-etl-dev"
  api_management_name         = azurerm_api_management.apim.name
  resource_group_name         = azurerm_resource_group.apim.name
  revision                    = "1"
  path                        = "fn-coronavirus-dashboard-pipeline-etl-dev"
  description                 = "Import from \"fn-coronavirus-dashboard-pipeline-etl-dev\" Function App"
  
  protocols                  = [
        "https",
    ]

  subscription_key_parameter_names {
        header                = "Ocp-Apim-Subscription-Key"
        query                 = "subscription-key"
    }
}

resource "azurerm_api_management_api_operation" "apim-get" {
  operation_id        = "api-v1"
  api_name            = azurerm_api_management_api.apim.name
  api_management_name = azurerm_api_management_api.apim.api_management_name
  resource_group_name = azurerm_api_management_api.apim.resource_group_name
  display_name        = "api_v1"
  method              = "GET"
  url_template        = "/v1/data"

}

resource "azurerm_api_management_api_operation" "apim-post" {
  operation_id        = "post-api-v1"
  api_name            = azurerm_api_management_api.apim.name
  api_management_name = azurerm_api_management_api.apim.api_management_name
  resource_group_name = azurerm_api_management_api.apim.resource_group_name
  display_name        = "api_v1"
  method              = "POST"
  url_template        = "/v1/data"
}