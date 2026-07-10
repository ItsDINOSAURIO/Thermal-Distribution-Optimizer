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
- `DATASETS/`: datos masivos, correlaciones, distribuciones STL/MAT, reportes, experimentales y reconstrucciones AlphaShape.
- `extras/`: archivos historicos o referencias que no participan directamente en el flujo actual.
- `iniciar_tesis.m`: bootstrap minimo para abrir el framework.

## Modulos principales del launcher

- `modulo_interaccion_comsol.m`: agrupa generador COMSOL y extractor COMSOL masivo.
- `modulo_procesamiento_datos.m`: agrupa exportacion STL/TXT, voxelizacion MAT, correlacion/volumen 4D y exportacion de correcciones.
- `modulo_manejador_visual_datos.m`: agrupa visualizacion de distribuciones, simulaciones corregidas, correlaciones y volumen 4D.
- `optimizador_3d_final.m`: optimizador 3D sobre datos procesados.
- `Interfaz_Ablacion_AlphaShape.m`: modulo final de verificacion experimental; lee y escribe su base en `DATASETS/Reconstrucciones`.

## Herramientas internas conservadas

Estas herramientas siguen disponibles para los contenedores, pero ya no aparecen como entradas principales del launcher:

- `generador_sin_metales_multi_solucion_sin_tumor.m`
- `extractor_comsol_masivo.m`
- `comsol_mat_exportador_masivo.m`
- `preprocesar_stl_a_mat.m`
- `visualizador_ablacion_corregida_masivo.m`
- `correlador_volumen_interpolado_ui.m`
- `exportador_masivo_correcciones.m`

Las rutas canonicas, el catalogo del launcher y el tema visual se resuelven mediante `tesis_auxiliares`, de modo que los modulos pueden vivir en subcarpetas sin perder acceso a `DATASETS`. El launcher se mantiene ligero y solo lanza los cinco modulos principales.
