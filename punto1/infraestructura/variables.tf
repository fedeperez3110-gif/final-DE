variable "region" {
  description = "Región de AWS donde se despliega todo"
  type        = string
  default     = "us-east-2"
}

variable "prefijo" {
  description = "Prefijo del bucket; se le agrega el ID de la cuenta para que sea único"
  type        = string
  default     = "fp-examen-p1-entregas"
}

variable "nombre_base_datos" {
  description = "Base de datos del Glue Data Catalog (minúsculas y guion bajo)"
  type        = string
  default     = "examen_entregas"
}

variable "nombre_tabla" {
  description = "Tabla externa de intentos de entrega"
  type        = string
  default     = "entregas"
}

variable "nombre_workgroup" {
  description = "Workgroup de Athena para las consultas del ejercicio"
  type        = string
  default     = "fp-examen-p1-wg"
}

variable "fecha_inicio" {
  description = "Primera fecha proyectada (incluida), formato yyyy-MM-dd"
  type        = string
  default     = "2026-10-01"
}

variable "fecha_fin" {
  description = "Última fecha proyectada (incluida), formato yyyy-MM-dd"
  type        = string
  default     = "2026-10-03"
}
