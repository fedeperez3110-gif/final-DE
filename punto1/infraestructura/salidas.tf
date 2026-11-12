output "region" {
  description = "Región del despliegue"
  value       = var.region
}

output "bucket" {
  description = "Nombre del bucket S3"
  value       = aws_s3_bucket.datos.bucket
}

output "bucket_arn" {
  description = "ARN del bucket S3"
  value       = aws_s3_bucket.datos.arn
}

output "ruta_entregas" {
  description = "Prefijo de los datos"
  value       = local.ruta_entregas
}

output "ruta_resultados_athena" {
  description = "Prefijo de los resultados de Athena"
  value       = local.ruta_resultados
}

output "base_datos" {
  description = "Base de datos del Glue Data Catalog"
  value       = aws_glue_catalog_database.entregas.name
}

output "tabla" {
  description = "Tabla externa con partition projection"
  value       = aws_glue_catalog_table.entregas.name
}

output "plantilla_ubicacion" {
  description = "Plantilla de ubicación de las particiones"
  value       = aws_glue_catalog_table.entregas.parameters["storage.location.template"]
}

output "workgroup" {
  description = "Workgroup de Athena"
  value       = aws_athena_workgroup.entregas.name
}
