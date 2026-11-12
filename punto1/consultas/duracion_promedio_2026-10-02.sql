-- Duración promedio de las entregas exitosas del 2 de octubre de 2026.
-- Se filtra por estado 'entregado' antes de promediar, para no incluir
-- los ceros de los intentos fallidos. El filtro por fecha hace que Athena
-- lea solo la partición de ese día.
SELECT
    fecha,
    CAST(
        ROUND(AVG(CAST(duracion_minutos AS DOUBLE)), 2)
        AS DECIMAL(10, 2)
    ) AS duracion_promedio_minutos
FROM examen_entregas.entregas
WHERE fecha = '2026-10-02'
  AND estado = 'entregado'
GROUP BY fecha;