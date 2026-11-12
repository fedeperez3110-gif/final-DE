from datetime import datetime, timezone

from airflow import DAG
from airflow.operators.python import PythonOperator
from runtime import run_dbt

with DAG(
    dag_id="examen_ventas",
    start_date=datetime(2026, 1, 1, tzinfo=timezone.utc),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    max_active_tasks=1,
    default_args={"retries": 0},
    tags=["examen"],
) as dag:
    # Comprueba la actualidad de raw.ventas antes de construir.
    # dbt termina con código 0 en pass y warn, y con código 1 en error;
    # run_dbt usa check=True, así que el error hace fallar la tarea.
    comprobar_freshness = PythonOperator(
        task_id="comprobar_freshness",
        python_callable=run_dbt,
        op_args=[["source", "freshness"]],
    )

    construir_resumen = PythonOperator(
        task_id="construir_resumen",
        python_callable=run_dbt,
        op_args=[["build"]],
    )

    # Regla predeterminada all_success: si freshness falla,
    # construir_resumen queda upstream_failed y no se ejecuta.
    comprobar_freshness >> construir_resumen
