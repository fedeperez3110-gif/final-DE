###############################################################################
# Punto 1 — S3 + Glue Data Catalog (partition projection) + Athena
###############################################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Proyecto = "examen-final"
      Punto    = "1"
    }
  }
}

# ID de la cuenta, para que el nombre del bucket sea único en todo el mundo
data "aws_caller_identity" "actual" {}

locals {
  nombre_bucket   = "${var.prefijo}-${data.aws_caller_identity.actual.account_id}"
  ruta_entregas   = "s3://${local.nombre_bucket}/entregas/"
  ruta_resultados = "s3://${local.nombre_bucket}/resultados-athena/"
}

# -----------------------------------------------------------------------------
# 1. Bucket S3 privado
#    Los prefijos entregas/ y resultados-athena/ son parte de las claves de los
#    objetos: no hace falta crearlos antes.
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "datos" {
  bucket = local.nombre_bucket

  # Permite que terraform destroy elimine el bucket aunque tenga objetos
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "datos" {
  bucket = aws_s3_bucket.datos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# 2. Base de datos del Glue Data Catalog
# -----------------------------------------------------------------------------
resource "aws_glue_catalog_database" "entregas" {
  name        = var.nombre_base_datos
  description = "Examen final - punto 1: intentos de entrega"
}

# -----------------------------------------------------------------------------
# 3. Tabla externa con partition projection por fecha
# -----------------------------------------------------------------------------
resource "aws_glue_catalog_table" "entregas" {
  name          = var.nombre_tabla
  database_name = aws_glue_catalog_database.entregas.name
  table_type    = "EXTERNAL_TABLE"
  description   = "Intentos de entrega, particionados por fecha (partition projection)"

  parameters = {
    "EXTERNAL"               = "TRUE"
    "classification"         = "csv"
    "skip.header.line.count" = "1"

    # Partition projection: Athena calcula las particiones en cada consulta
    "projection.enabled"             = "true"
    "projection.fecha.type"          = "date"
    "projection.fecha.format"        = "yyyy-MM-dd"
    "projection.fecha.range"         = "${var.fecha_inicio},${var.fecha_fin}"
    "projection.fecha.interval"      = "1"
    "projection.fecha.interval.unit" = "DAYS"

    # $${fecha} lleva doble $ para que Terraform no lo interprete como variable;
    # en AWS queda como ${fecha}. La plantilla es el prefijo y termina en /.
    "storage.location.template" = "${local.ruta_entregas}fecha=$${fecha}/"
  }

  # fecha no está dentro del CSV: sale de la carpeta fecha=yyyy-MM-dd
  partition_keys {
    name    = "fecha"
    type    = "string"
    comment = "Fecha del archivo (yyyy-MM-dd)"
  }

  storage_descriptor {
    location      = local.ruta_entregas
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    # Los valores no tienen comillas ni comas internas: basta LazySimpleSerDe
    ser_de_info {
      name                  = "csv"
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"

      parameters = {
        "field.delim"          = ","
        "serialization.format" = ","
      }
    }

    # Las cinco columnas, en el orden del archivo
    columns {
      name = "id_envio"
      type = "string"
    }

    columns {
      name = "ciudad"
      type = "string"
    }

    columns {
      name = "transportadora"
      type = "string"
    }

    columns {
      name = "estado"
      type = "string"
    }

    columns {
      name = "duracion_minutos"
      type = "int"
    }
  }
}

# -----------------------------------------------------------------------------
# 4. Workgroup de Athena con resultados en resultados-athena/
# -----------------------------------------------------------------------------
resource "aws_athena_workgroup" "entregas" {
  name        = var.nombre_workgroup
  description = "Examen final - punto 1"

  # Permite borrar el workgroup aunque tenga historial de consultas
  force_destroy = true

  configuration {
    # Obliga a que todas las consultas usen esta ubicación de resultados
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = local.ruta_resultados

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}
