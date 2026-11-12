-- Resumen diario de ventas: una fila por fecha del negocio.
-- ingreso_total multiplica cantidad (INTEGER) por precio_unitario (DECIMAL(12,2)),
-- así que el resultado sigue siendo DECIMAL y conserva los centavos exactos.
select
    fecha_venta,
    count(*)                             as numero_ventas,
    cast(sum(cantidad) as bigint)        as unidades_vendidas,
    sum(cantidad * precio_unitario)      as ingreso_total
from {{ ref('stg_ventas') }}
group by fecha_venta
