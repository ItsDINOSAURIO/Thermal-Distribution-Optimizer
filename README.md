# Framework personal de modulos de tesis

Este root queda organizado para separar codigo, auxiliares y datos.

## Arranque

Desde MATLAB, con el root del proyecto como carpeta actual:

```matlab
iniciar_tesis
```

Ese punto de entrada agrega `modulos` y `Aux_Codes` al path y abre el launcher.

## Estructura

- `modulos/`: modulos ejecutables actuales. Los contenedores principales son autosuficientes y contienen su logica integrada local.
- `Aux_Codes/`: `tesis_auxiliares.m` centraliza helpers de rutas, tema UI, dashboard compacto y catalogo; `inpolyhedron.m` queda como dependencia geometrica compartida.
- `datasets/`: datos masivos, correlaciones, distribuciones STL/MAT, reportes, experimentales y reconstrucciones AlphaShape. Es una carpeta local excluida de Git y los modulos crean su estructura cuando hace falta.
- `extras/`: archivos historicos o referencias que no participan directamente en el flujo actual.
- `iniciar_tesis.m`: bootstrap minimo para abrir el framework.

## Modulos principales del launcher

- `modulo_interaccion_comsol.m`: agrupa generador COMSOL y extractor COMSOL masivo.
- `modulo_procesamiento_datos.m`: agrupa exportacion STL/TXT, voxelizacion MAT, correlacion/volumen 4D y exportacion de correcciones.
- `modulo_manejador_visual_datos.m`: agrupa visualizacion de distribuciones, simulaciones corregidas, correlaciones y volumen 4D.
- `optimizador_3d_final.m`: optimizador 3D sobre datos procesados.
- `Interfaz_Ablacion_AlphaShape.m`: modulo final de verificacion experimental; lee y escribe su base en `datasets/Reconstrucciones`.

## Herramientas internas conservadas

Estas herramientas siguen disponibles para los contenedores, pero ya no aparecen como entradas principales del launcher:

- `generador_sin_metales_multi_solucion_sin_tumor.m`
- `extractor_comsol_masivo.m`
- `comsol_mat_exportador_masivo.m`
- `preprocesar_stl_a_mat.m`
- `visualizador_ablacion_corregida_masivo.m`
- `correlador_volumen_interpolado_ui.m`
- `exportador_masivo_correcciones.m`

Las rutas canonicas, el catalogo del launcher y el tema visual se resuelven mediante `tesis_auxiliares`, de modo que los modulos pueden vivir en subcarpetas sin perder acceso a `datasets`. El launcher se mantiene ligero y solo lanza los cinco modulos principales.

## Catalogo limpio y repetidos

`dividir_datasets_masivos_por_metadata` organiza cada ejecucion por `tipo de
antena / numero de antenas / caso / potencia` y, al terminar, ejecuta
`organizar_datasets_repetidos`. El organizador compara el registro termico
completo sin hashes y conserva un solo MAT canonico por identidad.

- Copias con contenido identico: `datasets_masivos_por_metadata/repetidos/equivalentes/`.
- Misma metadata con contenido diferente: `datasets_masivos_por_metadata/repetidos/conflictos/`.
- Trazabilidad: `repetidos/Indice_Repetidos.mat` y `Indice_Repetidos.csv`.

Ninguna variante se elimina. El indice activo, el exportador STL/TXT, el
voxelizador y los visualizadores excluyen siempre cualquier ruta dentro de
`repetidos`.

Las correlaciones nuevas guardan `tipo_antena`, `num_antenas`, `caso`,
`potencia_W`, `fecha_adquisicion`, `tiempo_ejecucion_min`, `numero_prueba` y
`num_zonas` dentro de `metadata_correlacion`. Su carpeta replica toda esa
jerarquia. Las correlaciones historicas siguen siendo compatibles: la metadata
faltante se recupera de las rutas de simulacion y experimento antes de filtrar.

El nombre final no repite metadata que ya pertenece a la ruta. En la hoja de la
jerarquia solo distingue el tipo de artefacto: `Correccion_termica_zonal.mat`,
`Correccion_termica_global.mat` o `Dataset_corregido.mat`. La identidad
experimental se conserva en las carpetas, dentro del MAT y en los tags internos
usados por el procesamiento.

Si ya existe una correccion en la misma ruta, el archivo canonico no se
sobrescribe. La nueva ejecucion se compara campo por campo y se conserva como
`repetidos/equivalentes/Revision_N` o `repetidos/conflictos/Revision_N`; el
catalogo de filtros omite ambas ramas.

Los productos derivados de un dataset corregido conservan la misma identidad
experimental. Tanto STL/TXT como MAT voxelizados se separan mediante
`Tipo/Antenas/Caso/Potencia/Fecha/Tiempo/Prueba/Zonas`. Los MAT de voxelizacion
tambien guardan `fecha_adquisicion`, `tiempo_ejecucion_min`, `numero_prueba`,
`num_zonas` y `zona_experimental` dentro de `metadata`. La limpieza de una
regeneracion queda limitada a esa adquisicion exacta.

El manejador visual incorpora `Fecha` como filtro del apartado Dataset. La
fecha se recupera desde `partition_meta`, `tag_correccion` o la ruta del MAT.
La clave interna del catalogo incluye la identidad de correccion, por lo que
dos adquisiciones del mismo modelo/dataset ya no se deduplican entre si.

En extrapolacion no existe un cargador manual de MAT de correccion. La
correlacion se resuelve solo cuando coinciden exactamente los filtros de tipo,
antenas, caso, potencia, fecha, tiempo, prueba y configuracion zonal. Una
coincidencia ambigua se bloquea; nunca se elige automaticamente la mas reciente.
