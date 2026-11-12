# Respuestas — Punto 2

## 1. ¿Por qué usar `_loaded_at` y no `fecha_venta` para este control?

Porque el control debe responder si los datos llegaron recientemente, y esa información está en `_loaded_at`, no en `fecha_venta`. `_loaded_at` registra cuándo entró cada fila a `raw.ventas`. `fecha_venta` registra cuándo ocurrió la venta en el negocio, y eso no depende del momento en que se cargó.

En este ejercicio la diferencia se ve con claridad. Los tres escenarios tienen las mismas seis ventas, del 10 al 12 de enero de 2026, y solo cambia la marca de carga: hace 2 h, 18 h o 30 h. Si el control usara `fecha_venta`, la fecha más reciente sería siempre el 2026-01-12 y daría el mismo resultado en los tres escenarios. Además, ese resultado sería un error, porque esa fecha ya tiene meses de antigüedad. Con `_loaded_at`, en cambio, cada escenario cae en su estado: pass, warn y error. En la ejecución bloqueada, `sources.json` registra `max_loaded_at = 2026-11-11T06:36:31Z` y una antigüedad de 108 023 s, unas 30,0 h, frente a un `error_after` de 24 h (`evidencias/artifacts_desactualizada.txt`).

Tampoco son equivalentes en la práctica. Una venta antigua puede cargarse hoy, por ejemplo en una corrección o un reproceso. Y un día sin ventas, como un festivo, no significa que la carga se haya retrasado. Usar `fecha_venta` mezclaría el comportamiento del negocio con la salud del proceso de carga.

## 2. ¿Por qué las pruebas de integridad no garantizan actualidad?

Porque revisan otra propiedad de los datos. `unique`, `not_null`, la prueba de valores válidos y la comparación con los resultados esperados verifican que los datos que hay estén bien formados y den el resumen correcto. Ninguna verifica cuándo llegaron. Una tabla de hace un mes puede cumplir todas esas pruebas.

El escenario desactualizado lo muestra. Los datos de negocio son idénticos a los del escenario actualizado, así que `dbt build` pasaría todas las pruebas y reconstruiría el resumen sin ningún error técnico, aunque la última carga tenga 30 horas. Ese es justo el riesgo que plantea el enunciado: un proceso que termina bien con información vieja. En el último `dbt build` registrado (`run_results.json`, del run actualizado) pasaron las 17 pruebas, y los datos de negocio del escenario desactualizado son exactamente los mismos. Lo que bloqueó el resumen fue la tarea de freshness, no las pruebas.

Por eso la actualidad se comprueba aparte, con `dbt source freshness`, que compara el máximo de `_loaded_at` con la hora actual en UTC. `dbt build` no ejecuta esa comprobación por su cuenta: hay que ponerla antes del build en el DAG. Aun así, freshness solo garantiza que hubo una carga reciente, no que hayan llegado todas las ventas esperadas. Para eso se necesitarían controles de completitud, por ejemplo conteos por día comparados con el sistema de origen.
