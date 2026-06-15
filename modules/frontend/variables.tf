variable "project" {
  description = "Nombre del proyecto, usado como prefijo de nombres"
  type        = string
}

variable "bucket_suffix" {
  description = "Sufijo para que el nombre del bucket sea único globalmente"
  type        = string
}
