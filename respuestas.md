# Respuestas

## 1. ¿Por qué se pudo consultar el tercer día sin registrar una partición nueva?

Porque la tabla no depende de particiones guardadas en el catálogo. Con partition projection, Glue guarda las **reglas** para calcularlas y Athena las aplica en cada consulta: `fecha` es una fecha con formato `yyyy-MM-dd`, va de `2026-10-01` a `2026-10-03` y avanza de a un día. Con eso Athena genera los tres valores posibles y arma la ruta de cada uno con la plantilla `s3://<bucket>/entregas/fecha=${fecha}/`. Después lee los archivos que encuentra en esos prefijos.

El 2026-10-03 estaba dentro del rango desde el despliegue inicial (`evidencias/aplicacion_terraform.txt` y `evidencias/tabla_glue.json`). En la etapa inicial ese prefijo estaba vacío, así que la fecha no aportaba filas y la consulta no fallaba: `resultados/inicial/` solo tiene el 1 y el 2 de octubre. Cuando se subió el archivo a `entregas/fecha=2026-10-03/` (`evidencias/carga_tercer_dia.txt`), la siguiente consulta ya lo encontró. Lo muestran los 6 registros de `resultados/final/verificacion_tercer_dia.csv`, cada uno con su ruta en S3, y el total de 18 registros de `resultados/final/verificacion_total_tabla.csv`. Los bytes escaneados que registra `evidencias/bitacora_athena.txt` lo confirman: antes de subir el día 3, las consultas sobre toda la tabla leyeron 626 bytes (dos archivos de 313 bytes); después, la consulta del total leyó 949 (313 + 313 + 323).

En el catálogo no hubo particiones registradas: `evidencias/particiones_glue_final.json` muestra una lista vacía aun con los tres días cargados y consultados. Además, no se ejecutaron crawlers, `MSCK REPAIR TABLE`, `ALTER TABLE ADD PARTITION` ni un nuevo `terraform apply`: el único cambio fue un objeto nuevo en S3.

## 2. Si se subiera un archivo para el 4 de octubre manteniendo la configuración actual, ¿qué resultado se esperaría y qué se debería modificar para incluirlo?

El archivo quedaría en S3, pero **Athena no lo leería**. El rango proyectado termina el `2026-10-03`, así que Athena nunca genera el valor `2026-10-04` ni busca su prefijo. Las consultas sin filtro seguirían devolviendo los mismos 18 registros y las tres fechas actuales, y una consulta con `WHERE fecha = '2026-10-04'` devolvería cero filas. No habría ningún error: los datos simplemente no se verían, lo que puede pasar desapercibido.

Para incluirlo hay que ampliar el rango de la proyección **en Terraform**, no desde la consola. Basta con cambiar la variable `fecha_fin` a `2026-10-04`, o a una fecha posterior, y ejecutar `terraform apply`. Esto actualiza la propiedad `projection.fecha.range` de la tabla. No hace falta tocar el archivo, crear la partición ni ejecutar un crawler: después del cambio, la siguiente consulta ya incluiría ese día.

Si van a llegar archivos todos los días, conviene usar un rango con fin relativo, por ejemplo `2026-10-01,NOW`. Así cada día nuevo queda dentro de la proyección sin cambiar la tabla. Lo que no cambia es la condición sobre el archivo: debe subirse a `entregas/fecha=2026-10-04/` con el mismo formato y las mismas cinco columnas, porque la proyección no valida ni crea datos, solo indica dónde buscarlos.
