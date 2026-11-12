-- Porcentaje de entregas exitosas por fecha y ciudad.
-- 100 × entregas con estado 'entregado' / total de intentos del grupo.
-- El numerador se convierte a DOUBLE para evitar la división entera, y el
-- resultado se convierte a DECIMAL(5,2) para que siempre tenga dos decimales.
SELECT
    fecha,
    ciudad,
    CAST(
        ROUND(100 * CAST(COUNT_IF(estado = 'entregado') AS DOUBLE) / COUNT(*), 2)
        AS DECIMAL(5, 2)
    ) AS porcentaje_exito
FROM examen_entregas.entregas
GROUP BY fecha, ciudad
ORDER BY fecha ASC, ciudad ASC;