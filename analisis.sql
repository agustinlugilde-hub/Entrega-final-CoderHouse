-- analisis.sql
-- Proyecto Capstone: EDA de ventas e-commerce en PostgreSQL


-- PARTE 1: LIMPIEZA DE DATOS
-- Objetivo: que ninguna métrica de negocio quede sesgada por NULLs.

-- 1.1 Verificar tipos de datos: dinero debe ser NUMERIC y fechas DATE.
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('clientes', 'productos', 'pedidos')
  AND column_name IN ('fecha_pedido', 'fecha_registro', 'precio_unitario', 'precio_lista', 'cantidad')
ORDER BY table_name, column_name;

-- 1.2 Diagnóstico: ¿cuántos NULLs hay en las columnas de pedidos?
SELECT
    COUNT(*)                                          AS total_pedidos,
    COUNT(*) FILTER (WHERE fecha_pedido    IS NULL)   AS fecha_nula,
    COUNT(*) FILTER (WHERE cantidad        IS NULL)   AS cantidad_nula,
    COUNT(*) FILTER (WHERE precio_unitario IS NULL)   AS precio_nulo
FROM pedidos;

-- 1.3 Vista con los datos limpios. Todo el análisis posterior consulta
-- Decisiones sobre los NULLs:
--   * precio_unitario NULL -> usamos el precio de lista del producto.
--   * cantidad NULL        -> asumimos 1 unidad: es el mínimo posible
--   * fecha_pedido NULL    -> NO se inventa. Una fecha falsa distorsionaría la serie mensual, así que se conserva NULL y esos pedidos se excluyen solo de los análisis temporales
--   * ciudad NULL          -> 'Sin informar', para que no desaparezca

CREATE OR REPLACE VIEW pedidos_limpios AS
SELECT
    p.id_pedido,
    p.id_cliente,
    p.id_producto,
    p.fecha_pedido,
    COALESCE(p.cantidad, 1)                                  AS cantidad,
    COALESCE(p.precio_unitario, pr.precio_lista)             AS precio_unitario,
    COALESCE(p.cantidad, 1)
        * COALESCE(p.precio_unitario, pr.precio_lista)       AS monto_total,
    pr.nombre                                                AS producto,
    pr.categoria,
    c.nombre                                                 AS cliente,
    COALESCE(c.ciudad, 'Sin informar')                       AS ciudad
FROM pedidos   p
JOIN productos pr ON pr.id_producto = p.id_producto
JOIN clientes  c  ON c.id_cliente   = p.id_cliente;

-- 1.4 Validación de consistencia: los registros deben ser exactamente iguales (200)
SELECT
    (SELECT COUNT(*) FROM pedidos)         AS filas_pedidos,
    (SELECT COUNT(*) FROM pedidos_limpios) AS filas_vista;

-- 1.5 Control final: tras la limpieza no deben quedar NULLs en montos.
SELECT COUNT(*) AS montos_nulos_restantes
FROM pedidos_limpios
WHERE monto_total IS NULL;


-- PARTE 2: ANÁLISIS


-- Consulta 1: Top 5 clientes por gasto total 
-- Pregunta: ¿Quiénes son los clientes que más facturan y cuánto dependemos de ellos?

SELECT
    cliente,
    COUNT(*)                                                          AS cantidad_pedidos,
    SUM(monto_total)                                                  AS gasto_total,
    ROUND(100.0 * SUM(monto_total) / SUM(SUM(monto_total)) OVER (), 1) AS pct_de_ventas
FROM pedidos_limpios
GROUP BY id_cliente, cliente      
ORDER BY gasto_total DESC
LIMIT 5;


-- Consulta 2: Ventas totales por mes y variación mensual
-- Pregunta: ¿Hay estacionalidad? 

WITH ventas_mensuales AS (
    SELECT
        DATE_TRUNC('month', fecha_pedido)::DATE AS mes,
        SUM(monto_total)                        AS ventas
    FROM pedidos_limpios
    WHERE fecha_pedido IS NOT NULL     
    GROUP BY DATE_TRUNC('month', fecha_pedido)
)
SELECT
    mes,
    ventas,
    LAG(ventas) OVER (ORDER BY mes)    AS ventas_mes_anterior,
    ROUND(100.0 * (ventas - LAG(ventas) OVER (ORDER BY mes))
          / NULLIF(LAG(ventas) OVER (ORDER BY mes), 0), 1) AS variacion_pct
FROM ventas_mensuales
ORDER BY mes;



-- Consulta 3: Los 3 productos menos vendidos
-- Pregunta: ¿Que productos no rotan y son candidatos a liquidar o descontinuar?

SELECT
    pr.nombre                              AS producto,
    pr.categoria,
    COALESCE(SUM(pl.cantidad), 0)          AS unidades_vendidas,
    COALESCE(SUM(pl.monto_total), 0)       AS ingresos
FROM productos pr
LEFT JOIN pedidos_limpios pl ON pl.id_producto = pr.id_producto
GROUP BY pr.id_producto, pr.nombre, pr.categoria
ORDER BY unidades_vendidas ASC, ingresos ASC   
LIMIT 3;



-- Consulta 4: Ranking de los 3 más pedidos por categoría 
-- Pregunta: ¿Que categorias sostienen el negocio y cuales aportan poco?

WITH ranking AS (
    SELECT
        categoria,
        id_pedido,
        cliente,
        producto,
        monto_total,
        RANK() OVER (PARTITION BY categoria ORDER BY monto_total DESC) AS posicion
    FROM pedidos_limpios
)
SELECT *
FROM ranking
WHERE posicion <= 3        
ORDER BY categoria, posicion;




