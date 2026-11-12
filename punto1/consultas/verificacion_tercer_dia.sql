-- Verificación de la incorporación del 2026-10-03.
-- Athena ejecuta una sentencia por vez: scripts/ejecutar_athena.py las
-- ejecuta por separado con --consulta 1, 2 y 3.

-- Consulta 1: los seis registros del tercer día.
-- "$path" muestra el objeto de S3 del que salió cada fila.
-- Resultado: resultados/final/verificacion_tercer_dia.csv
SELECT
    fecha,
    id_envio,
    ciudad,
    transportadora,
    estado,
    duracion_minutos,
    "$path" AS archivo_s3
FROM examen_entregas.entregas
WHERE fecha = '2026-10-03'
ORDER BY id_envio ASC;

-- Consulta 2: conteos por estado del tercer día.
-- Resultado: resultados/final/verificacion_estados_tercer_dia.csv
SELECT
    fecha,
    estado,
    COUNT(*) AS total_intentos
FROM examen_entregas.entregas
WHERE fecha = '2026-10-03'
GROUP BY fecha, estado
ORDER BY estado ASC;

-- Consulta 3: total de la tabla, registros del tercer día y fechas con datos.
-- Resultado: resultados/final/verificacion_total_tabla.csv
SELECT
    COUNT(*)                         AS total_registros,
    COUNT_IF(fecha = '2026-10-03')   AS registros_2026_10_03,
    COUNT(DISTINCT fecha)            AS fechas_con_datos
FROM examen_entregas.entregas;