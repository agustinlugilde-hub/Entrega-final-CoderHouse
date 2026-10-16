[README.txt](https://github.com/user-attachments/files/33572652/README.txt)
==============================================================
CAPSTONE POSTGRESQL: ANALISIS EXPLORATORIO DE VENTAS DE UN E-COMMERCE
==============================================================

1. PROBLEMA DE NEGOCIO
--------------------------------------------------------------
Una tienda online vendio durante 2024 productos de cuatro categorias
(Electronica, Indumentaria, Accesorios y Hogar) a 20 clientes. La
direccion quiere responder cuatro preguntas para decidir donde poner
esfuerzo comercial:

  1. ¿Quienes son los clientes que mas facturan y cuanto dependemos de ellos?
  2. ¿Hay estacionalidad en las ventas?
  3. ¿Que productos no rotan y son candidatos a liquidar o descontinuar?
  4. ¿Que categorias sostienen el negocio y cuales aportan poco?

Este conjunto de datos es sintético (20 clientes, 12 productos y 200 pedidos) 
y lo generé con fallas a propósito para poder practicar la parte de limpieza de datos. 
Por eso, lo que obtuve acá aplica a este ejercicio; para un caso real tendría que usar un dataset de verdad y con más datos.

2. ESTRUCTURA DEL REPOSITORIO
--------------------------------------------------------------
  estructura.sql  Creacion de las tablas clientes, productos y pedidos
                  (con PK, FK, CHECK e indices) e insercion de los datos.
  analisis.sql    Limpieza de datos y 6 consultas de analisis comentadas.
  README.txt      Este documento.

Modelo de datos: la tabla pedidos se conecta con clientes (id_cliente) y
con productos (id_producto). Cada fila de pedidos es una linea de pedido.


3. COMO EJECUTAR EL CODIGO
--------------------------------------------------------------

  1) Crear la base de datos:
     psql -U postgres -c "CREATE DATABASE capstone_project;"

  2) Crear tablas e insertar datos:
     psql -U postgres -d capstone_project -f estructura.sql

  3) Ejecutar limpieza y analisis:
     psql -U postgres -d capstone_project -f analisis.sql



4. LIMPIEZA DE DATOS
--------------------------------------------------------------
Antes de analizar se midieron los NULLs en las columnas criticas de
pedidos (200 filas):

  Columna            NULLs     Tratamiento
  -----------------       --------   -----------------------------------------
  precio_unitario    10   COALESCE con el precio de lista del producto
  cantidad               4     COALESCE a 1 unidad (el minimo posible, para
                                       no sobrestimar ventas)
  fecha_pedido       6     NO se imputa: inventar fechas distorsionaria
                                       la serie mensual. Se excluyen solo del
                                       analisis por mes (equivalen al 2,5% del monto)
  ciudad (clientes)   2   COALESCE a 'Sin informar'

La regla de limpieza vive en una unica vista, pedidos_limpios, que usan
todas las consultas. Tambien se verifico que los tipos sean correctos
(DATE, NUMERIC) y que la vista tenga las mismas 200 filas que pedidos, para
descartar duplicacion por JOINs.


5. HALLAZGOS Y CONCLUSIONES
--------------------------------------------------------------
Las ventas totales del periodo suman $20,5 millones.

5.1 CLIENTES: LA FRECUENCIA NO ES LO MISMO QUE EL VALOR

  - Los 2 mejores clientes concentran el 28% de la facturacion (Lucia
    Rodriguez 16,4% y Nicolas Lopez 11,7%). Perder a uno solo tendria un
    impacto real.
  - Martin Lopez es el cliente que más compra (22 pedidos) pero recien es
    el tercero en gasto (6,8%): compra seguido articulos baratos. En
    cambio, Lucia y Nicolas compraron notebooks. Medir lealtad solo por
    cantidad de pedidos engaña.
  - Segmentando por cantidad de pedidos, los 6 clientes "leales" (30% de la
    base) generan el 44% de las ventas, pero los 9 "regulares" generan el
    47%: son el mayor volumen total y la oportunidad más concreta
    (convertirlos en leales con ofertas de recompra). Los 5 ocasionales
    aportan apenas el 10%.

  RECOMENDACION: armar un programa de atención prioritaria para los 5
  principales clientes y una campaña de fidelización dirigida a los
  regulares.

5.2 ESTACIONALIDAD: UN MES EXPLICA CASI UNA QUINTA PARTE DEL AÑO

  - Noviembre es el pico: $3,9 M, un +144% respecto de octubre y cerca del
    20% de las ventas con fecha. Es consistente con campañas de fin de
    año.
  - Septiembre es el piso ($0,7 M) y Junio tambien cae fuerte (-57% vs.
    mayo).
  - La serie es muy volatil, con subas y bajas de mas del 100% entre meses
    consecutivos. Con pocos pedidos y productos de ticket muy distinto, una
    sola venta de notebook mueve el mes.

  RECOMENDACION: reforzar stock y publicidad antes de Noviembre y diseñar
  acciones para el bache de Septiembre.

5.3 PRODUCTOS: MIRAR UNIDADES E INGRESOS JUNTOS

Los 3 productos menos vendidos en unidades son:

  Producto                 Unidades  Ingresos    Lectura
  ---------------------   --------    ----------  ------------------------------
  Set de Sabanas           2         $90.000     Casi no rota y aporta menos del
                                                 0,5% de las ventas: candidato
                                                 a liquidar o descontinuar.
  Notebook 14"             5         $4,25 M     Error de interpretacion comun:
                                                 vende poco pero es el producto
                                                 que mas factura (21% del
                                                 total). No se debe descontinuar.
  Campera Impermeable      12        $1,44 M     Rotacion baja pero ingreso
                                                 razonable; probablemente 
                                                 estacional, conviene revisarlo
                                                 por temporada.

5.4 CATEGORIAS Y RANKING DE PEDIDOS

  - Electronica concentra el 44% de las ventas con una participación
    similar en unidades al resto: el negocio depende de su ticket alto.
    Hogar aporta solo el 7,7%, y su producto estrella (Cafetera Italiana)
    es el que lidera los rankings de la categoria.
  - En el ranking con RANK() por categoria, los dos pedidos más grandes de
    Electronica son notebooks ($2,55 M y $1,7 M). En las demas categorias
    aparecen muchos empates en el primer puesto, porque el monto es
    cantidad por precio fijo: no hay un pedido que destaque, el negocio no
    depende de operaciones excepcionales fuera de Electronica.

  RECOMENDACION: evaluar si conviene ampliar el catalogo de Hogar o
  reducirlo, y proteger la oferta de Electronica (sobre todo notebooks),
  que sostiene casi la mitad del negocio.


