variable "location" {
  description = "The supported Azure location where the resource deployed"
  type        = string
}

variable "environment_name" {
  description = "The name of the azd environment to be deployed"
  type        = string
}

variable "principal_id" {
  description = "The Id of the azd service principal to add to deployed keyvault access policies"
  type        = string
  default     = ""
}

// App specific parameters - provide the values via the main.parameters.json referencing e.g. environment parameters
variable "sku_name" {
  description = "The name of the SKU used to create the key vault"
  type        = string
  default     = "F1"
}

variable "health_check_path" {
  description = "The path to the health check endpoint"
  type        = string
  default     = "/health"
}


variable "oDataUrl" {
  description = "SAP OData service URL"
  type        = string
  default     = "https://sandbox.api.sap.com/s4hanacloud"
}

variable "oDataUsername" {
  description = "SAP OData user name"
  type        = string
  default     = ""
}

variable "oDataUserpwd" {
  description = "SAP OData user password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "_APIKey" {
  description = "API Key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ApiKeyHeaderName" {
  description = "API Key Header Name"
  type        = string
  default     = "APIKey"
}
