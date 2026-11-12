#!/usr/bin/env python3
"""Ejecuta una consulta de consultas/ en el workgroup del ejercicio y guarda la evidencia.

Para cada ejecución:
  1. Lee el workgroup, la base de datos y la región de evidencias/outputs.json.
  2. Envía el SQL a Athena y espera a que termine.
  3. Descarga el CSV que Athena dejó en resultados-athena/ y lo guarda sin comillas
     en la ruta indicada (Athena pone todos los valores entre comillas).
  4. Registra la ejecución en evidencias/ejecuciones_athena.csv
     (etapa, archivo_sql, id_ejecucion, archivo_resultado).
  5. Si se indica --esperado, compara el resultado con la referencia.

Uso (desde la raíz del repositorio):
  python3 scripts/ejecutar_athena.py --etapa inicial \
      --sql consultas/intentos_por_fecha_estado.sql \
      --resultado resultados/inicial/intentos_por_fecha_estado.csv \
      --esperado resultados_esperados/intentos_por_fecha_estado_inicial.csv

Si el archivo SQL tiene varias sentencias, --consulta N elige la N-ésima (desde 1).
"""

import argparse
import csv
import io
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

import boto3

RAIZ = Path(__file__).resolve().parent.parent
OUTPUTS = RAIZ / "evidencias" / "outputs.json"
REGISTRO = RAIZ / "evidencias" / "ejecuciones_athena.csv"
BITACORA = RAIZ / "evidencias" / "bitacora_athena.txt"
COLUMNAS_REGISTRO = ["etapa", "archivo_sql", "id_ejecucion", "archivo_resultado"]


def leer_outputs():
    if not OUTPUTS.exists():
        sys.exit(f"No existe {OUTPUTS.relative_to(RAIZ)}. Ejecuta primero: "
                 "terraform -chdir=infraestructura output -json > evidencias/outputs.json")
    datos = json.loads(OUTPUTS.read_text(encoding="utf-8"))
    return {k: v["value"] for k, v in datos.items()}


def sentencias(texto):
    """Divide el archivo en sentencias y quita las líneas que solo son comentarios."""
    resultado = []
    for bloque in texto.split(";"):
        lineas = [l for l in bloque.splitlines() if l.strip() and not l.strip().startswith("--")]
        if lineas:
            resultado.append("\n".join(lineas))
    return resultado


def esperar(athena, id_ejecucion):
    while True:
        ejecucion = athena.get_query_execution(QueryExecutionId=id_ejecucion)["QueryExecution"]
        estado = ejecucion["Status"]["State"]
        if estado in ("SUCCEEDED", "FAILED", "CANCELLED"):
            return ejecucion
        time.sleep(1)


def descargar_csv(s3, ubicacion):
    url = urlparse(ubicacion)
    cuerpo = s3.get_object(Bucket=url.netloc, Key=url.path.lstrip("/"))["Body"].read()
    return list(csv.reader(io.StringIO(cuerpo.decode("utf-8"))))


def guardar_csv(filas, ruta):
    ruta.parent.mkdir(parents=True, exist_ok=True)
    with ruta.open("w", encoding="utf-8", newline="") as f:
        csv.writer(f, lineterminator="\n").writerows(filas)


def registrar(fila):
    """Agrega la ejecución al registro; si ya había una para el mismo resultado, la reemplaza."""
    filas = []
    if REGISTRO.exists():
        with REGISTRO.open(encoding="utf-8", newline="") as f:
            filas = [r for r in csv.DictReader(f)
                     if not (r["etapa"] == fila["etapa"]
                             and r["archivo_resultado"] == fila["archivo_resultado"])]
    filas.append(fila)
    with REGISTRO.open("w", encoding="utf-8", newline="") as f:
        escritor = csv.DictWriter(f, fieldnames=COLUMNAS_REGISTRO, lineterminator="\n")
        escritor.writeheader()
        escritor.writerows(filas)


def comparar(filas, ruta_esperado):
    with ruta_esperado.open(encoding="utf-8", newline="") as f:
        esperado = list(csv.reader(f))
    if filas == esperado:
        print(f"COMPARACIÓN: OK, coincide con {ruta_esperado.relative_to(RAIZ)}")
        return True
    print(f"COMPARACIÓN: DIFERENTE de {ruta_esperado.relative_to(RAIZ)}")
    for i in range(max(len(filas), len(esperado))):
        obtenida = filas[i] if i < len(filas) else None
        referencia = esperado[i] if i < len(esperado) else None
        if obtenida != referencia:
            print(f"  fila {i}: obtenida={obtenida} esperada={referencia}")
    return False


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--etapa", required=True, choices=["inicial", "final"])
    p.add_argument("--sql", required=True, help="Archivo SQL, relativo a la raíz del repositorio")
    p.add_argument("--resultado", required=True, help="CSV de salida, relativo a la raíz")
    p.add_argument("--consulta", type=int, default=1, help="Número de sentencia dentro del archivo")
    p.add_argument("--esperado", help="CSV de referencia para comparar (opcional)")
    args = p.parse_args()

    outputs = leer_outputs()
    ruta_sql = RAIZ / args.sql
    lista = sentencias(ruta_sql.read_text(encoding="utf-8"))
    if not 1 <= args.consulta <= len(lista):
        sys.exit(f"{args.sql} tiene {len(lista)} sentencia(s); --consulta {args.consulta} no existe")
    sql = lista[args.consulta - 1]

    sesion = boto3.Session(region_name=outputs["region"])
    athena = sesion.client("athena")
    s3 = sesion.client("s3")

    print(f"Workgroup: {outputs['workgroup']} | Base: {outputs['base_datos']} | Región: {outputs['region']}")
    print(f"SQL ({args.sql}, consulta {args.consulta}):\n{sql}\n")

    id_ejecucion = athena.start_query_execution(
        QueryString=sql,
        QueryExecutionContext={"Database": outputs["base_datos"]},
        WorkGroup=outputs["workgroup"],
    )["QueryExecutionId"]
    print(f"Id de ejecución: {id_ejecucion}")

    ejecucion = esperar(athena, id_ejecucion)
    estado = ejecucion["Status"]["State"]
    stats = ejecucion.get("Statistics", {})
    if estado != "SUCCEEDED":
        sys.exit(f"La consulta terminó en {estado}: {ejecucion['Status'].get('StateChangeReason', '')}")

    ubicacion = ejecucion["ResultConfiguration"]["OutputLocation"]
    filas = descargar_csv(s3, ubicacion)
    ruta_resultado = RAIZ / args.resultado
    guardar_csv(filas, ruta_resultado)

    registrar({
        "etapa": args.etapa,
        "archivo_sql": Path(args.sql).as_posix(),
        "id_ejecucion": id_ejecucion,
        "archivo_resultado": Path(args.resultado).as_posix(),
    })

    with BITACORA.open("a", encoding="utf-8") as f:
        f.write(
            f"{datetime.now(timezone.utc).isoformat(timespec='seconds')} | etapa={args.etapa} | "
            f"sql={args.sql}#{args.consulta} | id={id_ejecucion} | estado={estado} | "
            f"bytes_escaneados={stats.get('DataScannedInBytes')} | "
            f"tiempo_ms={stats.get('TotalExecutionTimeInMillis')} | "
            f"filas={len(filas) - 1} | resultado={args.resultado} | athena={ubicacion}\n"
        )

    print(f"Estado: {estado} | bytes escaneados: {stats.get('DataScannedInBytes')} | "
          f"filas de datos: {len(filas) - 1}")
    print(f"Resultado guardado en {args.resultado}\n")
    for fila in filas:
        print("  " + ",".join(fila))
    print()

    if args.esperado and not comparar(filas, RAIZ / args.esperado):
        sys.exit(1)


if __name__ == "__main__":
    main()