-- Cantidad de intentos por fecha y estado.
-- Sin filtro de fechas: Athena recorre todas las fechas proyectadas
-- (2026-10-01 a 2026-10-03) y solo devuelve las que tienen archivo en S3.
-- Por eso la misma consulta sirve para la etapa inicial y para la final.
SELECT
    fecha,
    estado,
    COUNT(*) AS total_intentos
FROM examen_entregas.entregas
GROUP BY fecha, estado
ORDER BY fecha ASC, estado ASC;