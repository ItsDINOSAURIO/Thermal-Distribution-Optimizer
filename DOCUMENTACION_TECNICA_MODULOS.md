# Documentacion Tecnica De Modulos Actuales

Fecha de revision: 2026-07-10  
Root analizado: `C:\Users\emili\Downloads\modulos_tesis_refactor_limpio`  
Alcance: se revisan los modulos actuales del launcher, incluido `Interfaz_Ablacion_AlphaShape`, que mantiene su logica y usa `DATASETS/Reconstrucciones` como base experimental.

## 1. Alcance Y Archivos Revisados

El catalogo activo se obtiene desde `Aux_Codes/tesis_auxiliares.m` mediante `tesis_auxiliares('modulos_catalogo')`. El orden actual es:

1. `modulo_interaccion_comsol` - Interaccion con COMSOL.
2. `modulo_procesamiento_datos` - Modulo Procesamiento de Datos.
3. `modulo_manejador_visual_datos` - Manejador visual de datos.
4. `optimizador_3d_final` - Optimizador 3D.
5. `Interfaz_Ablacion_AlphaShape` - Verificacion experimental AlphaShape.

Tambien se documentan piezas de infraestructura porque condicionan rutas, tema, librerias y flujo de ejecucion:

- `modulos/launcher_tesis_modulos.m`.
- `Aux_Codes/tesis_auxiliares.m`.
- `Aux_Codes/inpolyhedron.m`, dependencia geometrica usada por preprocesamiento y optimizador.

Conteo aproximado de archivos revisados:

| Archivo | Lineas | Rol |
| --- | ---: | --- |
| `modulos/launcher_tesis_modulos.m` | 313 | Lanzador y retorno entre modulos. |
| `modulos/modulo_interaccion_comsol.m` | 3596 | Generacion COMSOL, extraccion COMSOL y copias locales de exportador/preprocesador. |
| `modulos/modulo_procesamiento_datos.m` | 7803 | STL/TXT, voxelizacion, correlacion, extrapolacion 4D, exportador de correcciones. |
| `modulos/modulo_manejador_visual_datos.m` | 2254 | Visualizador de distribuciones, correccion, volumen 4D y copias locales historicas. |
| `modulos/optimizador_3d_final.m` | 1932 | Optimizacion 3D por PSO y evaluacion geometrica. |
| `modulos/Interfaz_Ablacion_AlphaShape.m` | 1823 | Verificacion experimental por segmentacion, AlphaShape y comparacion STL. |
| `Aux_Codes/tesis_auxiliares.m` | 785 | Rutas, tema, catalogo y dashboard auxiliar. |
| `Aux_Codes/inpolyhedron.m` | 461 | Clasificacion punto-poliedro para mascaras binarias. |

Nota de lectura: el analisis es casi linea por linea a nivel funcional. En MATLAB los modulos estan escritos como apps procedurales con muchas funciones anidadas o copias locales; por legibilidad se agrupan por bloques, callbacks y funciones matematicas.

## 2. Dependencias Matematicas Y De MATLAB

| Funcion/libreria | Modulos | Nombre tecnico | Papel en el proyecto |
| --- | --- | --- | --- |
| `uifigure`, `uigridlayout`, `uipanel`, `uibutton`, `uidropdown`, `uitable`, `uiaxes` | Todos | Programacion de interfaces graficas en MATLAB | Construyen dashboards, paneles con scroll, ribbon, tablas editables, plots y callbacks. |
| COMSOL LiveLink: `mphload`, `mphsave`, `mphsolinfo`, `mpheval`, `mphinterp`, `mphlaunch` | Interaccion COMSOL | API LiveLink for MATLAB | Abre modelos `.mph`, consulta soluciones, evalua campos FEM y guarda modelos. |
| `meshgrid`, `ndgrid`, `linspace` | Extractor, procesamiento, visualizador, optimizador | Discretizacion regular cartesiana | Construyen rejillas 3D o 4D para muestreo, interpolacion, voxelizacion y visualizacion. |
| `interp1(...,'pchip')` | Correlacion, extrapolacion, visualizador | Interpolacion cubica Hermite preservadora de forma | Sincroniza curvas experimentales/simuladas y evalua factores termicos. |
| `polyfit`, `polyval` | Correlacion | Ajuste polinomial por minimos cuadrados | Ajusta `Delta T(t)=T_sim(t)-T_exp(t)` como polinomio de grado limitado. |
| `scatteredInterpolant` | Extrapolacion 4D | Interpolacion espacial de datos dispersos 3D | Lleva puntos termicos irregulares del dataset a una malla regular 3D. |
| `griddedInterpolant` | Extrapolacion 4D, visualizador | Interpolacion N-D en grilla regular | Exporta/evalua `T(x,y,z,t)` como funcion consultable 4D. |
| `svd(...,'econ')` | Extrapolacion 4D, factor de correccion | Descomposicion en valores singulares; base de PCA | Reduce modos temporales y extrapola dinamicas principales con 99% de energia. |
| LOWESS/cuadratico local implementado manualmente | Extrapolacion 4D | Regresion local ponderada con kernel tricubico | Extrapola el campo termico por ajuste cuadratico local en ventana temporal final. |
| Gradiente local implementado manualmente | Extrapolacion 4D | Extrapolacion lineal por pendiente local | Extiende cada voxel con pendiente estimada al final del intervalo. |
| `alphaShape`, `criticalAlpha`, `boundaryFacets` | Exportador STL | Reconstruccion geometrica por alpha shape | Convierte nubes de puntos de ablacion en superficies cerradas no convexas. |
| Suavizado Laplaciano manual | Exportador STL | Laplacian mesh smoothing | Reemplaza cada nodo por promedio de vecinos para suavizar la malla STL. |
| `triangulation`, `stlwrite` | Exportador STL | Malla triangular y exportacion STL | Guarda la frontera `alphaShape` como STL. |
| `inpolyhedron` | Preprocesador, optimizador | Prueba punto-en-poliedro por ray casting/interseccion de facetas | Clasifica voxeles dentro/fuera de una superficie STL triangulada. |
| `bwdist` | Preprocesador | Transformada de distancia euclidiana | Calcula SDF y TSDF desde mascara binaria. |
| `interp3` | Optimizador | Interpolacion 3D en grilla | Evalua distribuciones voxelizadas transformadas sobre la grilla del tumor. |
| `particleswarm` | Optimizador | Particle Swarm Optimization | Minimiza el fitness normalizado de cobertura/fuga/profundidad. |
| `isosurface` | Visualizador | Isosuperficie de campo escalar 3D | Reconstruye visualmente superficies `T >= T_abl` en volumen 4D. |
| `readtable`, `load`, `save`, `regexp` | Procesamiento e infraestructura | I/O tabular, MAT y expresiones regulares | Importa experimentales, lee MAT, escribe resultados y parsea metadata. |

## 3. Infraestructura Comun

### 3.1 `launcher_tesis_modulos.m`

Funcion: entrada central del proyecto.

Bloque inicial:

- Calcula `carpeta_launcher` con `mfilename('fullpath')`.
- Agrega al path `modulos` y `Aux_Codes`.
- Llama `tesis_auxiliares('configurar_paths', carpeta_launcher)` para detectar el root real buscando `DATASETS`.
- Obtiene tema con `tesis_auxiliares('tema_ui')`.
- Obtiene catalogo con `tesis_auxiliares('modulos_catalogo')`.

UI:

- Crea `uifigure` con nombre `Launcher Tesis - Flujo Termico 3D`.
- Usa `uigridlayout` de tres filas: ribbon/header, tarjetas de modulos, consola.
- El header conserva botones para abrir carpeta del proyecto y verificar modulos.
- El panel de modulos crea tarjetas con orden, nombre, funcion, descripcion, estado y boton `Ejecutar modulo`.
- La consola usa `uitextarea`; `registrar_evento` antepone hora y llama `drawnow limitrate`, por lo que el feedback visual depende de que los callbacks no bloqueen completamente MATLAB.

Flujo de lanzamiento:

- `ejecutar_modulo(idx)` verifica `which(modulo.funcion)`.
- Cierra el launcher antes de abrir el modulo, por diseno actual.
- Ejecuta `feval(modulo.funcion)`.
- Detecta figuras nuevas con `findall(groot,'Type','figure')`.
- Instala un `CloseRequestFcn` en la figura del modulo para preguntar cierre y reabrir el launcher.

Matematicamente no hace calculos numericos; su relevancia es de control de estado y ciclo de vida de las apps.

Tecnologias dormidas o repetidas:

- `detectar_figuras_nuevas` depende de que el modulo abra una figura nueva detectable. Si un modulo reutiliza una figura existente o falla antes de abrir, el launcher intenta reabrirse y lanza error.
- El sistema de retorno se repite conceptualmente en cada app con `CloseRequestFcn`; actualmente funciona, pero el acoplamiento debe mantenerse simple.

### 3.2 `Aux_Codes/tesis_auxiliares.m`

Funcion: helper unico para rutas, tema, catalogo y dashboards antiguos.

Acciones principales:

- `configurar_paths`: encuentra root, agrega `modulos`, `Aux_Codes` y carpeta del verificador al path.
- `project_root`: sube directorios hasta encontrar `DATASETS`.
- `dataset_paths`: define el contrato de carpetas:
  - `DATASETS/datasets_masivos`.
  - `DATASETS/datasets_corregidos`.
  - `DATASETS/correlaciones`.
  - `DATASETS/distribuciones_stl`.
  - `DATASETS/distribuciones_mat`.
  - `DATASETS/distribuciones_stl_corregidas`.
  - `DATASETS/distribuciones_mat_corregidas`.
  - `DATASETS/volumen_4d`.
  - `DATASETS/experimentales`.
  - `DATASETS/hueso_escaneado`.
  - `DATASETS/logs`.
  - `historial_sesion.mat` y `historial_tejidos_voxel.mat`.
- `asegurar_dataset_paths`: crea carpetas si no existen.
- `modulos_catalogo`: declara los cinco modulos actuales.
- `tema_ui`: aplica paleta, botones, labels, paneles, axes y textareas.
- `crear_dashboard_modulo`: dashboard generico anterior para modulos standalone.

Tecnologias dormidas o repetidas:

- `crear_dashboard_modulo_impl` aun contiene boton `exportar_log` y log propio. Los modulos nuevos ya usan UI integrada, asi que este helper es legacy para copias locales/standalone.
- La funcion de tema aplica recursivamente colores; si se crean controles nuevos despues de `apply`, hay que temarlos individualmente.

## 4. Modulo 1: `modulo_interaccion_comsol.m`

### 4.1 Objetivo

Este modulo concentra dos vistas activas:

1. Generador COMSOL.
2. Extractor COMSOL masivo.

Aunque el modulo tambien contiene copias locales del exportador MAT->STL/TXT y del preprocesador STL->MAT, la intencion arquitectonica reciente es que el procesamiento quede en `modulo_procesamiento_datos`. En este modulo esas copias existen por compatibilidad y ejecucion integrada antigua.

### 4.2 UI Y Flujo General

Lineas iniciales:

- `bootstrap_modulo` agrega `Aux_Codes` al path y configura rutas.
- `theme = tesis_auxiliares('tema_ui')` carga paleta.
- `paths = tesis_auxiliares('asegurar_dataset_paths')` crea/accede a `DATASETS`.
- `defaults = detectar_rutas_comsol_default(paths)` busca automaticamente `Antenas3D` y `DatosTejidos.mat` en el proyecto.

Dashboard:

- Usa `uifigure` + `uigridlayout` de tres filas: ribbon, panel de trabajo y log.
- Ribbon: selector `Vista activa: Generador COMSOL` / `Vista activa: Extractor COMSOL`, `Abrir DATASETS`, `Abrir carpeta del proyecto` y estado.
- Panel de trabajo: se alterna `pnl_generador` y `pnl_extractor` usando `Visible='on'/'off'`.
- Log: `uitextarea` con separaciones de cinco saltos de linea mediante `insertar_separacion_log`.

### 4.3 Generador COMSOL

Funciones clave:

- `obtener_config_generador` arma configuracion desde UI.
- `ejecutar_generador` valida rutas y llama `ejecutar_generador_comsol_integrado('run', cfg)`.
- `generador_sin_metales_multi_solucion_sin_tumor` contiene la logica real.
- `construir_modelo_base` crea el modelo COMSOL.
- `crear_study` crea estudio y solucion transitoria.
- `detectar_carbonizacion` revisa temperatura critica para cortar/registrar.
- `verificar_modelo_mat`, `solucion_existe`, `registrar` evitan repetir simulaciones.

Matematica y fisica aplicada:

- Electromagnetismo en frecuencia: `model.component('comp1').physics.create('emw','ElectromagneticWaves','geom1')`. En COMSOL esto representa la resolucion FEM del campo electromagnetico, configurado alrededor de `f = 2.45[GHz]`.
- Biocalor: `model.component('comp1').physics.create('ht','BioHeat','geom1')`. Por nombre fisico, la matematica corresponde al modelo de biocalor de Pennes: conduccion termica, perfusion sanguinea, metabolismo y fuente electromagnetica. El codigo parametriza `rho_sangre`, `Cp_sangre`, `T_sangre`, `omega_*`, `k_*`, `m_*`, `eps_*`, `sigma_*`.
- Propiedades termodependientes: se crean funciones COMSOL `Interpolation` a partir de `DatosTejidos.mat`. Este bloque convierte nombres a etiquetas validas y registra tablas de propiedades. La interpolacion exacta la ejecuta COMSOL dentro del modelo.
- Geometria multiantena: `calcular_posiciones(num_antenas)` define arreglos espaciales:
  - 1 antena: centro `(0,0)`.
  - 2 antenas: par simetrico `[-d/2,0]`, `[d/2,0]`.
  - 3 antenas: triangulo equilatero de radio `d/sqrt(3)`.
  - 4 antenas: cuadrado en `(+/-d/2,+/-d/2)`.
- Barrido parametrico: casos termicos, potencia y numero de antenas se recorren desde rangos UI. El paso de potencia se normaliza desde configuracion.
- Carbonizacion: `detectar_carbonizacion` usa `mpheval(model,'T',...)` sobre el dataset y compara contra `T_CRITICA`. Es un criterio de parada/registro, no una ecuacion termica nueva.

Validacion y omision de trabajo:

- `verificar_modelo_mat` compara indice `.mat` de soluciones existentes contra potencias/casos requeridos.
- `solucion_existe` consulta tabla y `mphsolinfo`.
- Si un `.mph` y su indice indican que el modelo esta completo, el generador evita abrir/simular de nuevo.

Riesgos tecnicos:

- La configuracion por antena contiene muchos IDs de dominios y fronteras hardcodeados por tipo y numero de antenas. Es necesario porque COMSOL exporta entidades numericas, pero es fragil si cambian los `.mphbin`.
- `crear_herramientas_comsol` aun dice que extractor puede encadenar STL/MAT, pero la UI actual del modulo COMSOL solo expone generacion y extraccion de dataset. Es una descripcion heredada.

### 4.4 Extractor COMSOL Masivo

Funciones clave:

- `obtener_config_extractor` arma configuracion.
- `ejecutar_extractor` llama `ejecutar_extractor_comsol_integrado('run', cfg)`.
- `extractor_comsol_masivo` recorre `.mph` y produce `Dataset_Termico_Masivo.mat`.
- `aplicar_filtros_modelos_mph` filtra modelos por metadata en nombre/ruta.
- `debe_reextraer_modelo_existente` revisa si el modelo ya esta procesado o cambio.
- `extraer_tiempos`, `extraer_sondas`, `extraer_snapshots` hacen la extraccion numerica.

Datos extraidos:

1. `probes`: series puntuales `T(t)` en sondas.
2. `snapshots`: nubes filtradas por umbral de ablacion.
3. `full_field`: campo termico sobre rejilla compartida, recortada al dominio de extraccion.
4. `metadata`: caso, potencia, origen, dominio, firmas y datos de consistencia.

Matematica aplicada:

- Muestreo temporal: `extraer_tiempos` obtiene tiempos de solucion via `mphsolinfo`; si no puede, intenta inferirlos desde `mpheval`. La normalizacion a minutos usa reglas por magnitud.
- Seleccion de indices: `seleccionar_indices` aplica vecino temporal mas cercano: para cada tiempo deseado busca `argmin |t_sol - t_obj|`.
- Interpolacion puntual: `interpolar_sonda` usa `mphinterp(model,'T','coord',coord_mm,...)`. Esto es interpolacion FEM dentro de COMSOL sobre el campo solucionado.
- Fallback de sonda: si hay NaN, `nodo_mas_cercano` evalua coordenadas de malla (`x,y,z`) y busca el nodo con distancia euclidiana minima que tenga la mayor cantidad de tiempos finitos. Distancia: `sqrt((x-x0)^2+(y-y0)^2+(z-z0)^2)`.
- Conversion Kelvin/Celsius: `es_kelvin` detecta valores compatibles con Kelvin y resta 273.15. Esta logica esta en extractor, aunque actualmente se espera `degC` desde COMSOL.
- Rejilla del extractor: `extraer_snapshots` construye `linspace` en `x`, `y`, `z` con `numero_grilla` y `meshgrid`. Esta grilla si se usa durante la extraccion COMSOL para muestrear el campo termico que se guarda en `full_field` y para formar snapshots.
- Dominio de hueso: si `extraer_solo_hueso` esta activo, se limita a `z = 0..45 mm` y radio `50 mm` con mascara `hypot(X,Y) <= radio`. Esto reduce puntos al bloque de hueso definido por el generador.
- Mascara de ablacion: `mask_ablacion = T_v >= temperatura_ablacion`. Guarda solo puntos sobre el umbral en `snapshots`, pero conserva `full_field.T_C` completo para postproceso.
- Carbonizacion informativa: `mask_carbonizacion = T_v >= temperatura_carbonizacion`, se registra conteo, no necesariamente corta la extraccion en este modulo.

Caso especial de una antena:

- `aplicar_desfase_1antena` detecta `1ant` en la ruta `.mph` y modifica coordenadas de sondas con desfase X/Y configurado.
- En la UI actual los defaults son `desfase_x = 1`, `desfase_y = 1` y sondas `(0,0,18.6)`, `(0,0,25.2)`, `(0,0,31.8)`, `(0,0,38.4)`.
- La logica evita consultar exactamente sobre el eje donde el modelo de una antena puede no tener datos validos por la geometria de la antena.

Validacion y omision de trabajo:

- `crear_firma_archivo_mph` guarda identidad del `.mph` por nombre, bytes y fecha.
- `firma_origen_invalida` fuerza reextraccion si el archivo COMSOL cambio.
- `modelo_tiene_registros_incompletos`, `registro_dataset_incompleto`, `full_field_incompleto`, `probes_incompletas` buscan NaN, campos faltantes o dimensiones inconsistentes.
- `metadata_incompatible` revisa dominio, sondas, grilla y filtros contra la configuracion actual.
- `metadata_1ant_invalida` y `probes_1ant_invalidas` revisan que el desfase especial no se haya perdido.

Tecnologias dormidas o repetidas:

- `numero_iteraciones_suavizado` aparece en metadata del extractor, pero el suavizado no se aplica aqui; se usa al reconstruir STL. Esto puede confundir porque extractor y exportador conviven en el mismo archivo.
- `obtener_config_extractor` asigna `ignorar_filtros_modelo` dos veces en el struct.
- Hay UIs antiguas `lanzar_ui_extractor_comsol_masivo`, `lanzar_ui_generador_sin_metales`, `lanzar_ui_comsol_mat_exportador_masivo`, `lanzar_ui_preprocesar_stl_a_mat` embebidas. No son la UI principal del modulo nuevo.

### 4.5 Exportador MAT -> STL/TXT Embebido

Aunque conceptualmente pertenece al procesamiento, este modulo conserva una copia local.

Funciones clave:

- `comsol_mat_exportador_masivo`.
- `exportar_modelos`.
- `exportar_datasets_de_modelo`.
- `exportar_stl_de_snapshots`.
- `preparar_plan_temporal_stl`.
- `encontrar_primer_corte_sostenido`.
- `generar_stl_ablacion`.
- `suavizar_malla_laplaciano`.

Matematica aplicada:

- Filtrado termico util: se conservan puntos con `T_min <= T <= T_max`. Por configuracion actual, `T_min` suele ser 55 C; `T_max` es 500 C para caso 0 y 120 C para casos termodependientes.
- Tmax dual: `obtener_maximos_termicos_snapshot` calcula `max(T)` desde el vector termico y lee `snapshot.T_max_C` si existe. La decision usa el mayor valor disponible.
- Corte termico sostenido: `encontrar_primer_corte_sostenido` aplica un producto acumulado inverso sobre el vector booleano `Tmax > Tmax_limite`. Devuelve el primer instante desde el cual ese instante y todos los posteriores exceden el limite. Es un criterio de prefijo valido.
- Preservacion de continuidad ante oscilaciones: si un tiempo excede 120 C pero algun posterior baja de 120 C, no se corta la serie; se filtran los puntos fuera de ventana para ese instante.
- `alphaShape`: reconstruye una frontera no convexa desde puntos de ablacion.
- `criticalAlpha(...,'one-region')`: si la forma inicial no tiene regiones, aumenta/adapta el alpha para obtener una region conectada.
- `boundaryFacets`: extrae triangulos y nodos de la frontera.
- Suavizado Laplaciano: durante `N` iteraciones, cada nodo se reemplaza por el promedio de sus vecinos. Esto reduce ruido geometricamente, pero tambien puede contraer volumen si se aplica demasiado.
- `stlwrite(triangulation(...))`: exporta la malla triangular.

Checkpoint `.done`:

- `crear_firma_snapshot_stl` genera firma `stl_export_v5|criterio=prefijo_sostenido|...` con tiempo, numero de puntos, alpha, suavizado, limites termicos, min/max/suma de puntos.
- `checkpoint_stl_vigente` solo acepta omitir si el `.stl` y `.done` existen y la firma esperada aparece en el `.done`.
- Si cambia la nube, parametros o umbrales, se reexporta.

### 4.6 Preprocesador STL -> MAT Embebido

Funciones clave:

- `preprocesar_stl_a_mat`.
- `crear_rejilla`.
- `guardar_representacion_volumetrica`.
- `leer_stl_binario`.
- `checkpoint_preprocesamiento_vigente`.

Matematica aplicada:

- Lectura STL binario: lee normales y vertices por faceta, elimina vertices repetidos y reconstruye conectividad.
- Rejilla de voxelizacion: `crear_rejilla` genera una caja envolvente de la geometria con margen de una resolucion.
- Punto en poliedro: `inpolyhedron(forma,puntos_rejilla)` crea mascara binaria de voxeles internos.
- Mascara: guarda `mascara` como volumen booleano.
- SDF: `sdf = (bwdist(mascara) - bwdist(~mascara)) * resolucion`. Por esta convencion, el signo queda como parte del contrato con el optimizador.
- TSDF: recorta SDF a `+/- 2*resolucion`.

Tecnologias dormidas o repetidas:

- Esta copia esta duplicada en `modulo_procesamiento_datos.m`; la version de procesamiento es la que deberia considerarse fuente activa para el flujo posterior.
- La UI standalone de preprocesador sigue existiendo y llama `tesis_auxiliares('crear_dashboard_modulo')`, pero no es la UI principal nueva.

## 5. Modulo 2: `modulo_procesamiento_datos.m`

### 5.1 Objetivo

Es el modulo mas matematico del proyecto. Contiene cinco vistas internas:

1. `STL/TXT desde MAT`.
2. `Voxelizar STL`.
3. `Correlacion`.
4. `Extrapolacion 4D`.
5. `Correcciones masivas`.

Todas comparten una consola de eventos y rutas desde `DATASETS`.

### 5.2 Vista STL/TXT Desde MAT

Esta vista llama `ejecutar_exportador_mat_integrado('run', cfg)` y ejecuta la misma logica descrita en la seccion 4.5.

Parametros UI:

- `MAT masivo`.
- `Salida STL/TXT`.
- `T min C`.
- `T max caso0`.
- `T max casos>0`.
- `Alpha radius`.
- `Suavizado`.

Matematica central:

- Filtrado termico por intervalo.
- Corte sostenido de carbonizacion.
- Reconstruccion `alphaShape`.
- Suavizado Laplaciano.
- Exportacion `stlwrite`.
- Registro TXT de sondas.

### 5.3 Vista Voxelizar STL

Llama `ejecutar_preprocesador_stl_integrado('run', cfg)`.

Parametros UI:

- Carpeta STL.
- Salida MAT.
- Resolucion mm.
- Tipo: `sdf`, `mascara`, `tsdf`.

Matematica central:

- Voxelizacion por clasificacion punto-poliedro con `inpolyhedron`.
- Distancia euclidiana con `bwdist`.
- SDF/TSDF para optimizacion.

Contrato con el optimizador:

- Debe guardar `gridX`, `gridY`, `gridZ` ademas de `grid_x`, `grid_y`, `grid_z` por compatibilidad historica.
- El optimizador carga `mascara`, `sdf` o `tsdf` segun metodo seleccionado.

### 5.4 Vista Correlacion

Funciones clave:

- `leer_experimental`.
- `leer_txt_sondas`.
- `preparar_curvas_correlacion`.
- `sincronizar_curvas_ui`.
- `calcular_correlacion`.
- `crear_zonas_correccion`.
- `crear_modelo_correccion_ui`.
- `crear_extrapolacion_factor_ui`.

Flujo:

1. Se carga archivo experimental (`csv`, `xlsx`, `xls`) con `readtable`.
2. Se carga TXT de sondas exportado desde MAT/STL.
3. Los tiempos se normalizan a minutos.
4. El recorte experimental y simulado se hace por ventanas en minutos, no por segundos.
5. Se selecciona una sonda o columnas equivalentes.
6. Se interpolan ambas curvas a un `t_comun` de `N comun` puntos usando PCHIP.
7. Se calcula diferencia `Delta T = T_sim - T_exp`.
8. Se ajusta polinomio de grado limitado.
9. Se calcula factor de enfriamiento sobre incremento termico.
10. Se crean zonas por profundidad si hay al menos dos sondas.

Matematica 1: interpolacion temporal PCHIP.

- `interp1(t_exp, y_exp, t_comun, 'pchip')`.
- `interp1(t_sim, y_sim, t_comun, 'pchip')`.
- Nombre cientifico: interpolacion cubica Hermite preservadora de forma.
- Ventaja: evita oscilaciones fuertes de splines cubicos globales cuando hay curvas monotono-crecientes de temperatura.

Matematica 2: ajuste polinomial por minimos cuadrados.

- `p_arreglo = polyfit(t_comun, y_delta, grado)`.
- `polyfit` encuentra coeficientes del polinomio que minimiza error cuadratico.
- El codigo limita grado a `min(cfg.grado, 12, numel(t_comun)-1)` para evitar polinomios imposibles por falta de puntos y reducir divergencia.
- `polyval` evalua el polinomio para graficar o reconstruir una funcion aplicada.

Matematica 3: correccion por factor sobre incremento termico local.

Formula guardada en `correccion_termica.formula_aplicacion`:

```text
T_corr(p,t) = T_base(p) + offset_base_C + factor_enfriamiento(t) * (T(p,t) - T_base(p))
```

Donde:

- `T_base(p)` es la temperatura basal/local inicial de cada punto.
- `offset_base_C = base_exp - base_sim` corrige diferencias basales.
- `factor_enfriamiento(t)` se calcula como:

```text
factor(t) = incremento_exp(t) / incremento_sim(t)
```

- `incremento_exp = T_exp - T_exp(0)`.
- `incremento_sim = T_sim - T_sim(0)`.
- El factor se limita a `[0,1]` para evitar calentar artificialmente si la metodologia busca enfriamiento/correccion hacia experimento.
- Se evita dividir cuando el calentamiento simulado es demasiado pequeno usando `umbral = max(0.5, 0.01*max(abs(inc_sim)))`.

Matematica 4: zonas por profundidad.

Profundidades por defecto:

- Simulacion: `[18.6, 25.2, 31.8, 38.4]` mm.
- Experimento: `[26.4, 19.8, 13.2, 6.6]` mm.

Las fronteras de zona se calculan con puntos medios en Z:

```text
z_edges = [-Inf, (z1+z2)/2, (z2+z3)/2, ..., Inf]
```

Cada zona guarda su propio polinomio, factor, offset y origen temporal. Al aplicar en volumen o dataset completo, los puntos se asignan por su coordenada `z`.

Matematica 5: extrapolacion del factor por PCA/SSA.

Funcion: `crear_extrapolacion_factor_ui`.

Pasos:

1. Toma el ultimo 50% de la curva de factor.
2. Re-muestrea uniformemente con PCHIP.
3. Construye matriz de trayectoria tipo Hankel con ventanas de longitud `L`.
4. Centra la serie restando media.
5. Aplica `svd(X,'econ')`.
6. Retiene modos hasta 99% de energia, con maximo 8 modos y restricciones de ventana.
7. Calcula coeficientes de recurrencia lineal desde los modos retenidos.
8. Predice pasos futuros limitando cambio maximo por paso.
9. Acota el factor dentro de limites extrapolados y dentro de `[0,1]`.

Nombre cientifico: Singular Spectrum Analysis (SSA) con proyeccion PCA mediante descomposicion en valores singulares.

### 5.5 Vista Extrapolacion 4D

Funciones clave:

- `cargar_dataset_termico`.
- `construir_funcion_volumen`.
- `construir_malla`.
- `calcular_volumen_por_tiempo`.
- `construir_extrapolacion_campo`.
- `seleccionar_extrapolacion`.
- `aplicar_correccion_volumen`.
- `exportar_volumen_desde_resultado`.

Flujo:

1. Selecciona dataset termico masivo y correccion.
2. Selecciona modelo y dataset interno.
3. Usa `full_field` si existe; si no, concatena puntos de snapshots.
4. Construye malla regular `nx x ny x nz` sobre caja envolvente ampliada 5%.
5. Para cada tiempo, interpola puntos termicos a la malla con `scatteredInterpolant`.
6. Para cada voxel, interpola en el tiempo con PCHIP a `nt_fine` instantes.
7. Calcula volumen por conteo de voxeles `T >= T_abl`.
8. Si `T extra max min` es mayor que el maximo temporal disponible, extrapola con tres metodos.
9. Selecciona metodo final para exportacion, pero conserva los tres metodos en estructuras exportables.
10. Si hay correccion, aplica formula global o zonal sobre el campo completo.
11. Exporta `griddedInterpolant` 4D y metadatos.

Matematica espacial: interpolacion dispersa 3D.

```text
F = scatteredInterpolant(x, y, z, T, 'linear', 'linear')
T_grid = F(Xq, Yq, Zq)
```

Nombre tecnico: interpolacion lineal sobre triangulacion de datos dispersos. Se usa porque los puntos COMSOL pueden no coincidir con una grilla cartesiana regular.

Matematica temporal: PCHIP por voxel.

```text
T_4D_vec(voxel,:) = interp1(t_valid, serie, t_fine, 'pchip', NaN)
```

Nombre tecnico: interpolacion cubica Hermite preservadora de forma 1D, aplicada independientemente a cada voxel.

Volumen de ablacion:

```text
V(t) = count(T(:,t) >= T_abl) * voxel_vol
voxel_vol = dx * dy * dz
```

Este volumen es una aproximacion de suma de Riemann sobre malla regular.

Extrapolacion 4D metodo 1: gradiente local.

- Toma ventana final de hasta 12 instantes.
- Ajusta pendiente lineal por voxel alrededor del ultimo tiempo.
- Formula:

```text
T_ext(t) = T_final + b * (t - t_final)
```

- La incertidumbre `sigma_grad` aumenta con distancia temporal y RMSE local.

Extrapolacion 4D metodo 2: LOWESS cuadratico local.

- Usa pesos tricubicos:

```text
w = (1 - |u|^3)^3
```

- Ajusta modelo local por voxel:

```text
T(t) = a0 + a1*dt + a2*dt^2
```

- Fija `a0` al ultimo valor real para continuidad.
- Nombre tecnico: regresion local ponderada, LOWESS/LOESS de grado 2.

Extrapolacion 4D metodo 3: PCA temporal.

- Centra el campo: `T_center = T_4D_vec - mean(T_4D_vec,2)`.
- Aplica `svd(T_center,'econ')`, con:

```text
T_center = U * S * V'
```

- Retiene modos hasta 99% de energia.
- Extrapola la coordenada temporal de cada modo con derivada final.
- Reconstruye:

```text
T_ext_pca = U_r * S_r * V_ext' + T_mean
```

- Corrige continuidad para que el primer extrapolado parta del ultimo campo real.

Correccion 4D:

- Global: aplica el factor a todos los voxeles.
- Zonal: crea `Z_nd` y aplica factor por banda de profundidad.
- Usa intensidad:

```text
factor_aplicado = 1 + intensidad * (factor_modelo - 1)
```

Si intensidad es 1, se usa el factor completo; si es 0, no corrige.

Importante:

- Si `T extra max min = 0`, el codigo actual no extrapola automaticamente a 30 min; usa como horizonte final el maximo de los datos interpolados y pone `nt_ext=0`.

### 5.6 Vista Correcciones Masivas

Funciones clave:

- `ejecutar_exportador_masivo_correcciones`.
- `corregir_dataset_completo_exportador`.
- `corregir_dataset_individual_exportador`.
- `aplicar_correccion_exportador`.
- `exportar_stl_txt_corregido` mediante exportador integrado.
- `preprocesar_stl` mediante preprocesador integrado.

Flujo:

1. Carga dataset masivo base.
2. Detecta correlaciones `.mat`.
3. Filtra modelos/datasets compatibles con metadata de cada correlacion.
4. Aplica correccion al `full_field` completo cuando existe.
5. Recalcula snapshots corregidos filtrando por umbral de ablacion.
6. Corrige sondas.
7. Guarda dataset corregido.
8. Opcionalmente exporta STL/TXT corregidos.
9. Opcionalmente voxeliza esos STL a MAT para el optimizador.

Matematica:

- Es la misma formula de factor sobre incremento termico local, aplicada masivamente.
- Si hay zonas, cada punto usa su banda `z`.
- Los snapshots corregidos conservan solo puntos `T_corr >= umbral`.

Validacion y omision:

- `dataset_corregido_vigente_exportador` y `.done` evitan regenerar dataset corregido si la firma coincide.
- `limpiar_salidas_por_filtro_exportador` elimina salidas previas incompatibles si se fuerza sobrescritura.

Tecnologias dormidas o repetidas:

- `crear_pasos_procesamiento` declara un pipeline por pasos con nombres de funciones historicas, pero la UI activa usa directamente subpaneles y callbacks.
- `ejecutar_selftest` existe en la copia local del correlador, pero no se expone en UI.
- `lanzar_ui_comsol_mat_exportador_masivo`, `lanzar_ui_preprocesar_stl_a_mat`, `correlador_volumen_interpolado_ui`, `lanzar_ui_exportador_masivo_correcciones` son UIs standalone embebidas; la UI principal nueva no depende de ellas para mostrar vistas.
- `export_rbf` existe pero en la UI principal se configura como `false`; es tecnologia latente.
- Existe logica para `run_export('mat')`, pero los botones visibles principales son `1 Dataset corregido` y `Todo corregido`; no hay boton directo separado solo para `mat` en la parte compacta actual.

## 6. Modulo 3: `modulo_manejador_visual_datos.m`

### 6.1 Objetivo

Es una app de inspeccion visual. Tiene dos vistas activas:

1. `Distribuciones termicas`: dataset original/corregido, correccion visual y sondas.
2. `Correccion y volumen`: curvas de correccion, volumen 4D, metodos de extrapolacion y visualizacion 3D.

### 6.2 Vista Distribuciones Termicas

Funciones clave:

- `load_dataset_dist`.
- `load_corr_dist`.
- `modelos_dist`, `datasets_dist`, `tiempos_dist`.
- `points_temp`.
- `apply_corr`.
- `apply_corr_zonal`.
- `plot_cloud`.
- `plot_probes`.

Flujo:

1. Al seleccionar un dataset MAT, se carga inmediatamente con `load_dataset`.
2. El selector de modelo se llena desde campos del struct, omitiendo `session_meta`.
3. El selector de dataset se llena desde el modelo elegido.
4. El selector de tiempo muestra tiempos `t_min` de snapshots.
5. `points_temp` usa `full_field.points` y `full_field.T_C` si existen; si no, usa `snapshots(idx).points` y `snapshots(idx).T`.
6. Para rendimiento visual, `sample_points3` limita a 80,000 puntos.
7. Se grafica original y corregida como `scatter3` coloreado por temperatura.
8. Las sondas se grafican como curvas `T(t)`.

Matematica aplicada:

- Correccion global:

```text
Tcorr = Tbase + offset + f * (T - Tbase)
```

- Correccion zonal: se repite por zonas `z_min <= z < z_max`.
- Filtro visual: solo grafica puntos con `Tmin <= T <= Tmax`.
- No reconstruye volumen ni STL; solo visualiza puntos.

Observacion importante:

- En esta vista, `evaluar_factor_ct` usa directamente `interp1(...,'pchip','extrap')` sobre `factor_enfriamiento`. No usa explicitamente `correccion_termica.extrapolacion_factor` PCA/SSA. Por eso, para tiempos fuera del rango de correccion, la vista puede diferir del exportador/procesamiento que si usa el modelo de extrapolacion del factor.

### 6.3 Vista Correccion Y Volumen

Funciones clave:

- `load_corr_math`.
- `load_vol_math`.
- `plot_corr_math`.
- `plot_funcion_correccion_math`.
- `actualizar_controles_volumen_math`.
- `seleccionar_volumen_math`.
- `plot_vol_math`.
- `draw_planes_math`.
- `draw_volumen_3d_math`.

Curvas de correccion:

- Grafica experimental, simulada y simulada corregida si existen en el MAT de correlacion.
- Grafica `Delta T` y `factor_enfriamiento` con `yyaxis`.

Volumen 4D:

- Detecta metodos exportados en `metodos_extrapolacion`: `pca_temporal`, `lowess_cuadratico`, `gradiente_local`.
- Permite seleccionar campo `Exportado/corregido` o `Sin correccion`.
- Ajusta tiempos con lista y slider.
- Grafica volumen 2D contra tiempo.
- Grafica planos ortogonales XY, XZ, YZ evaluando `Fgrid`.
- Grafica isosuperficie 3D usando `isosurface` con `T_abl`.

Matematica de visualizacion:

- Los planos son cortes del campo `T(x,y,z,t)` en coordenadas centrales:

```text
Txy = F(X, Y, z_c, t)
Txz = F(X, y_c, Z, t)
Tyz = F(x_c, Y, Z, t)
```

- La isosuperficie muestra el conjunto:

```text
{(x,y,z) : T(x,y,z,t) = T_abl}
```

- El volumen mostrado proviene de los vectores exportados; no recalcula integral salvo cuando usa estructuras ya exportadas.

Tecnologias dormidas o repetidas:

- Desde la linea aproximada 1080 inicia una copia local completa de `visualizador_ablacion_corregida_masivo.m`.
- Desde la linea aproximada 3016 inicia una copia local de `correlador_volumen_interpolado_ui.m`.
- Ambas copias incluyen `selftest`; la UI principal nueva no los expone.
- Hay duplicacion de funciones de extrapolacion de factor (`crear_extrapolacion_factor`, `extrapolar_factor_pca`) tanto en la parte activa como en copias historicas.
- El visualizador activo de distribuciones no usa el modelo PCA/SSA de extrapolacion del factor, como se indico arriba.

## 7. Modulo 4: `optimizador_3d_final.m`

### 7.1 Objetivo

Carga una geometria STL de tumor/hueso de estudio, calibra plano de acceso, detecta distribuciones termicas voxelizadas y optimiza posicion/orientacion mediante PSO para maximizar cobertura tumoral y minimizar fuga externa.

### 7.2 UI Y Catalogo De Distribuciones

Bloques iniciales:

- Configura paths y obtiene rutas:
  - `distribuciones_mat`.
  - `distribuciones_mat_corregidas`.
  - `distribuciones_stl`.
  - `distribuciones_stl_corregidas`.
  - historial de sesion y cache voxel.
- Define dos raices de catalogo: `original` y `corregido`.
- `app.profundidad_base_antena_mm = 26.4`.

UI:

- Sidebar con metodo voxel: `mascara`, `sdf`, `tsdf`.
- Sistema de filtros por pila: categoria, disponibles y activos.
- Resoluciones: tumor fina y tumor gruesa.
- Botones: cargar STL, calibrar acceso, calcular optimo, exportar PDF.
- Vista 3D, convergencia PSO, resultados e historial.

Catalogo:

- `obtener_catalogo_distribuciones` busca archivos `*_<metodo>_res*.mat` en raices original y corregida.
- `metadatos_ruta` parsea carpetas tipo `Monopolo/1ant/Caso_0/Potencia_30W`.
- `extraer_resolucion_nombre_mat` obtiene resolucion desde nombre del MAT.
- Los filtros activos reducen origen, tipo, antenas, caso, potencia y resolucion.

### 7.3 Carga Y Calibracion STL

Funciones clave:

- `cargar_tumor`.
- `lector_stl`.
- `preparar_geometria_base_apoyo_z0`.
- `calibrar_acceso`.
- `capturar_punto_acceso`.
- `calcular_rotacion_calibracion`.

Matematica aplicada:

- Centrado XY y apoyo en z=0:

```text
origen = [mean(vertices(:,1:2)), min(vertices(:,3))]
vertices_base = vertices - origen
```

Esto coloca el STL reposando en `z=0` y elimina desplazamiento XY global.

- Calibracion de acceso:
  - El usuario selecciona una cara del STL.
  - Se calcula centroide de cada triangulo y se busca el mas cercano al click.
  - La normal de la cara se calcula con producto cruz:

```text
normal = cross(v2-v1, v3-v1) / norm(cross(v2-v1,v3-v1))
```

  - Si la normal apunta hacia adentro, se invierte usando el centroide global.
  - `calcular_rotacion_calibracion` alinea esa normal con el eje Z usando producto cruz y producto punto. Matematicamente es una rotacion entre vectores, equivalente a formula de Rodrigues en la implementacion completa.
  - Despues de rotar, vuelve a apoyar el objeto en `z=0`.
  - `z_acceso` queda como coordenada Z del plano de insercion.

- Ejes de rotacion dominantes:

```text
dimensiones = max(vertices) - min(vertices)
ejes_a_rotar = indices de las dos dimensiones mayores
```

Esto reduce la orientacion del problema a dos angulos.

### 7.4 Voxelizacion Del Tumor

Funciones clave:

- En `realizar_optimizacion`, se construyen dos rejillas:
  - fina: para evaluacion final.
  - gruesa: para PSO.
- `inpolyhedron(app.caras_tumor, app.vertices_tumor_reorientado, grid)` clasifica voxeles internos.
- Se guarda cache en `historial_tejidos_voxel.mat` usando hash aproximado de vertices y resoluciones.

Matematica:

- Rejilla cartesiana:

```text
x = minGrid(1):res:maxGrid(1)
y = minGrid(2):res:maxGrid(2)
z = minGrid(3):res:maxGrid(3)
```

- Mascara tumoral:

```text
mask = punto_en_poliedro(grid, superficie_tumor)
```

- Volumen tumoral:

```text
V_tumor = sum(mask) * res^3
```

Uso de resoluciones:

- PSO usa grilla gruesa del STL/tumor para evaluar muchas posiciones rapido.
- La distribucion termica MAT normalmente fue voxelizada a resolucion propia, por ejemplo `0.5 mm`, y se interpola sobre la grilla del tumor durante evaluacion.
- Al final, el mejor candidato se reevalua con grilla fina del STL/tumor para obtener metricas mas confiables.

### 7.5 Optimizacion PSO Bifasica

Funciones clave:

- `realizar_optimizacion`.
- `fitness_unico`.
- `calcular_metricas_fitness`.
- `calcular_interseccion_volumen`.
- `transformacion_rotacional`.
- `hacer_matriz_rotacion`.

Variables optimizadas:

```text
pos = [tx, ty, tz, r1, r2]
```

- `tx,ty,tz`: traslacion de la distribucion termica.
- `r1,r2`: dos rotaciones asignadas a los ejes dominantes del STL.

Fase 1:

- `particleswarm` con 80 particulas y 40 iteraciones.
- Inicializa posiciones en puntos accesibles del tumor.
- Explora globalmente dentro de bounds.

Fase 2:

- Centra una ventana local alrededor del mejor de fase 1.
- 60 particulas, 100 iteraciones.
- Refina la solucion.

Nombre cientifico: Particle Swarm Optimization, metaheuristica poblacional de optimizacion global inspirada en dinamica de enjambres. MATLAB minimiza la funcion objetivo, por eso menor fitness es mejor.

### 7.6 Transformaciones Geometricas

Rotacion:

```text
R = Rz * Ry * Rx
p_global = R * p_local + [tx,ty,tz]
```

- `mapear_ejes` asigna los dos angulos a `rx`, `ry`, `rz` segun los ejes dominantes.
- `hacer_matriz_rotacion` define matrices canonicas de rotacion 3D.

Interseccion de volumen:

1. Obtiene caja envolvente transformada de la distribucion.
2. Filtra solo voxeles del tumor dentro de esa caja para ahorrar computo.
3. Convierte coordenadas globales a locales:

```text
coords_locales = R' * (grid_global - posicion)
```

4. Interpola la distribucion sobre esas coordenadas:
   - `mascara`: `interp3(...,'nearest',0)` y `dentro_gota = d > 0.5`.
   - `sdf` o `tsdf`: `interp3(...,'linear',1e6)` y `dentro_gota = d < 0`.
5. Calcula:

```text
V_dist = sum(dentro_gota) * res^3
V_inter = sum(dentro_gota & mask_tumor) * res^3
V_ext = V_dist - V_inter
```

### 7.7 Fitness Unificado

Funcion: `calcular_metricas_fitness`.

Metricas:

```text
cobertura = V_inter / V_tumor
fuga = V_ext / V_dist
dist_centro_norm = norm(centro_gota - centro_tumor) / escala
profundidad_norm = max(0, z_acceso - centro_gota_z) / escala
```

Fitness:

```text
fitness = escala_fitness * ( -cobertura
                             + peso_fuga*fuga
                             + peso_centroide*dist_centro_norm^2
                             + peso_profundidad*profundidad_norm^2 )
```

Pesos actuales:

- `peso_fuga = 0.15`.
- `peso_centroide = 0.02`.
- `peso_profundidad = 0.05`.
- `escala_fitness = 1000`.

Interpretacion:

- Menor fitness es mejor.
- La cobertura resta porque se desea maximizarla.
- La fuga, distancia al centro y profundidad penalizan.
- `fitness_pso` se obtiene sobre grilla gruesa.
- `fitness_fino` se recalcula sobre grilla fina y es el criterio final para elegir el mejor global.

### 7.8 Antenas Y Profundidad

- `cargar_mapa_antenas_local` conserva coordenadas hardcodeadas para `1ant`, `2ant`, `3ant`, `4ant`.
- La antena 1 se transforma junto con la distribucion para estimar su posicion global.
- Profundidad total:

```text
profundidad_total = profundidad_base_antena_mm + profundidad_stl_mm
```

Donde `profundidad_base_antena_mm = 26.4` y `profundidad_stl_mm` se calcula desde `z_acceso` y la posicion global de la antena.

### 7.9 Tecnologias Dormidas O Repetidas

- Campos de musculo y hueso (`vertices_musculo`, `caras_musculo`, etc.) existen como soporte latente, pero la UI principal solo carga tumor STL. Se agregaron validaciones para no fallar si esos campos no existen.
- `rng(1234)` hace reproducible la optimizacion, pero puede reducir exploracion entre corridas si no se cambia la semilla.
- `clc; clear;` al inicio es propio de script standalone; en una app lanzada desde launcher puede limpiar workspace y consola de MATLAB, aunque no rompe variables internas porque despues crea `app`.
- El cache de voxelizacion usa `tumor_hash = sum(vertices)*1e12`; es rapido pero no criptograficamente robusto. Dos geometrias distintas podrian colisionar teoricamente si sumas coinciden.
- El lector STL es binario manual. Si se requiere ASCII STL, podria fallar salvo que el archivo este en formato binario.
- La lista de historiales ya carga corrida al seleccionar, pero la logica de import/export sigue siendo propia del optimizador, no centralizada.

## 8. Dependencia Auxiliar: `inpolyhedron.m`

Aunque no es modulo del launcher, es central.

Funcion matematica:

- Determina si puntos de consulta estan dentro de una superficie triangular 3D cerrada.
- Entrada puede ser `FV` con `faces` y `vertices`, o `faces, vertices, qPts`.
- Devuelve vector logico `IN`.

Metodo conceptual:

- Usa facetas triangulares y normales.
- Clasifica puntos por intersecciones tipo ray casting / comparacion respecto a facetas.
- Divide internamente facetas en una grilla para mejorar rendimiento.

Uso en el proyecto:

- En preprocesamiento: convierte STL de ablacion a mascara voxelizada.
- En optimizador: convierte tumor STL a mascara fina/gruesa.

Supuestos importantes:

- La superficie debe estar cerrada y triangulada correctamente.
- Las normales importan; el archivo trae opcion `FLIPNORMALS` para convenciones opuestas.
- Tiene TODOs propios del autor sobre memoria y seleccion de grilla interna, por lo que en geometrias enormes podria ser cuello de botella.

## 9. Resumen De Feats Dormidas, Repetidas O Riesgos De Sobrecodigo

| Area | Tipo | Observacion |
| --- | --- | --- |
| `modulo_interaccion_comsol` | Repetida | Incluye copias locales de exportador MAT->STL y preprocesador STL->MAT, aunque el flujo actual los concentra en Procesamiento. |
| `modulo_interaccion_comsol` | Dormida | UIs standalone `lanzar_ui_*` y botones de exportar log embebidos no son la UI principal nueva. |
| `modulo_interaccion_comsol` | Riesgo | IDs de dominios/fronteras COMSOL hardcodeados por antena. Necesarios, pero fragiles ante cambios de `.mphbin`. |
| `modulo_interaccion_comsol` | Ambigua | `numero_iteraciones_suavizado` aparece asociado al extractor, pero suavizado aplica a STL, no a extraccion COMSOL. |
| `modulo_procesamiento_datos` | Repetida | Copias locales de exportador, preprocesador, correlador y exportador masivo conviven con UI integrada. |
| `modulo_procesamiento_datos` | Dormida | `crear_pasos_procesamiento` no gobierna la UI activa. |
| `modulo_procesamiento_datos` | Dormida | `ejecutar_selftest` no expuesto. |
| `modulo_procesamiento_datos` | Latente | Exportacion RBF existe, pero `export_rbf=false` desde UI. |
| `modulo_manejador_visual_datos` | Repetida | Contiene copias locales completas del visualizador corregido y del correlador/volumen. |
| `modulo_manejador_visual_datos` | Inconsistencia | Vista de distribuciones extrapola factor con PCHIP directo y no con PCA/SSA guardado en `extrapolacion_factor`. |
| `optimizador_3d_final` | Latente | Soporte musculo/hueso parcialmente dormido; campos pueden no existir. |
| `optimizador_3d_final` | Riesgo | Cache por suma de vertices es aproximado; puede no detectar cambios geometricos raros. |
| `tesis_auxiliares` | Dormida | `crear_dashboard_modulo` conserva flujo antiguo con exportacion de log. |
| `inpolyhedron` | Riesgo externo | Tiene TODOs de rendimiento/memoria; geometrias muy densas pueden degradar tiempos. |

## 10. Lectura Global Del Flujo Matematico

El proyecto transforma la salida FEM de COMSOL en representaciones geometricas y volumetricas utiles:

1. COMSOL resuelve electromagnetismo y biocalor.
2. El extractor muestrea `T(x,y,z,t)` sobre dominio de hueso y sondas.
3. El exportador filtra puntos termicos utiles por umbral y reconstruye superficies STL por `alphaShape`.
4. El preprocesador convierte STL en mascara/SDF/TSDF mediante `inpolyhedron` y `bwdist`.
5. El correlador calcula correccion experimental como factor de incremento termico local, global o por zonas.
6. La extrapolacion 4D crea una funcion `T(x,y,z,t)` en grilla regular usando interpolacion espacial, temporal y tres extrapoladores.
7. El exportador masivo aplica la correccion a todos los datasets compatibles y regenera distribuciones corregidas.
8. El visualizador permite inspeccionar original/corregido, curvas, volumen y metodos.
9. El optimizador usa distribuciones voxelizadas para minimizar fitness de posicion/orientacion.

## 11. Referencias Oficiales Consultadas

- MathWorks, `uifigure`: https://www.mathworks.com/help/matlab/ref/uifigure.html
- MathWorks, `uigridlayout`: https://www.mathworks.com/help/matlab/ref/uigridlayout.html
- MathWorks, `uitable`: https://www.mathworks.com/help/matlab/ref/uitable.html
- MathWorks, `uiaxes`: https://www.mathworks.com/help/matlab/ref/uiaxes.html
- MathWorks, `interp1`: https://www.mathworks.com/help/matlab/ref/interp1.html
- MathWorks, `polyfit`: https://www.mathworks.com/help/matlab/ref/polyfit.html
- MathWorks, `scatteredInterpolant`: https://www.mathworks.com/help/matlab/ref/scatteredinterpolant.html
- MathWorks, `griddedInterpolant`: https://www.mathworks.com/help/matlab/ref/griddedinterpolant.html
- MathWorks, `svd`: https://www.mathworks.com/help/matlab/ref/svd.html
- MathWorks, `alphaShape`: https://www.mathworks.com/help/matlab/ref/alphaShape.html
- MathWorks, `isosurface`: https://www.mathworks.com/help/matlab/ref/isosurface.html
- MathWorks, `bwdist`: https://www.mathworks.com/help/images/ref/bwdist.html
- MathWorks, `interp3`: https://www.mathworks.com/help/matlab/ref/interp3.html
- MathWorks, `meshgrid`: https://www.mathworks.com/help/matlab/ref/meshgrid.html
- MathWorks, `triangulation`: https://www.mathworks.com/help/matlab/ref/triangulation.html
- MathWorks, `stlwrite`: https://www.mathworks.com/help/matlab/ref/stlwrite.html
- MathWorks, `particleswarm`: https://www.mathworks.com/help/gads/particleswarm.html
- MathWorks, `readtable`: https://www.mathworks.com/help/matlab/ref/readtable.html
- MathWorks, `load`: https://www.mathworks.com/help/matlab/ref/load.html
- MathWorks, `save`: https://www.mathworks.com/help/matlab/ref/save.html
- MathWorks, `regexp`: https://www.mathworks.com/help/matlab/ref/regexp.html

## 12. Nota Final De Mantenimiento

La logica numerica principal es coherente con el flujo actual, pero el proyecto aun conserva muchas copias locales por compatibilidad. Para el siguiente refactor, el mayor beneficio no seria cambiar matematica, sino decidir una sola fuente activa por tecnologia:

- COMSOL: generador/extractor.
- Procesamiento: exportador STL, voxelizador, correlador, extrapolador 4D, exportador corregido.
- Visualizador: solo lectura/inspeccion.
- Optimizador: solo catalogo, voxelizacion del STL de estudio, PSO y reporte.

Mientras esas copias convivan, conviene documentar toda correccion matematica en un lugar y replicarla conscientemente, especialmente la extrapolacion PCA/SSA del factor termico, porque ahi es facil que visualizador y exportador muestren comportamientos distintos.
