function salida = graficador_estadistico_optimizador(entrada)
%GRAFICADOR_ESTADISTICO_OPTIMIZADOR Analiza historiales MAT del optimizador 3D.
%   Sin argumentos abre un selector de archivos. También acepta una ruta,
%   un arreglo string o una celda de rutas a MAT que contengan la variable hs.
%   Use 'selftest' para ejecutar las pruebas internas sin crear archivos.

%% CATÁLOGO DE CONFIGURACIÓN GRÁFICA (editar solamente esta sección)
cfg.mostrar_figuras = false;
cfg.cerrar_figuras = true;
cfg.resolucion_dpi = 300;
cfg.guardar_png = true;
cfg.guardar_tiff = false;
cfg.guardar_fig = true;
cfg.guardar_eps = false;

base.fuente = 'Times New Roman';
base.tamano_ejes = 12;
base.tamano_etiquetas = 14;
base.tamano_titulo = 16;
base.tamano_leyenda = 12;
base.ancho_linea = 2.0;
base.ancho_secundario = 1.2;
base.ancho_ejes = 1.0;
base.tamano_marcador = 38;
base.fondo = [1 1 1];
base.color_texto = [.15 .15 .15];
base.color_rejilla = [.72 .72 .72];
base.alpha_rejilla = .35;
base.ubicacion_leyenda = 'best';
base.columnas_leyenda = 1;
base.posicion = [100 100 1000 650];
base.mapa_color = 'turbo';
base.azimut = -40;
base.elevacion = 28;
base.proyeccion = 'perspective';
base.alpha_superficie = .22;
base.alpha_banda = .16;
base.color_corridas = [.72 .72 .72];
base.color_media = [.64 .08 .18];
base.ancho_corridas = .50;
base.etiquetas_panel = {'A)','B)','C)','D)','E)','F)'};

% Color de las series por número de antenas. Los ejes conservan color neutro.
cfg.colores_antenas = [0.0000 0.4470 0.7410; .8500 .3250 .0980; ...
                       .4660 .6740 .1880; .6400 .0800 .1800; ...
                       .4940 .1840 .5560; .3010 .7450 .9330];

% Cada entrada permite editar: activa, archivo, título, etiquetas y estilo.
cfg.graficas(1) = entrada_grafica(base,'convergencia_individual',true,'01_convergencia_corridas','Convergencia individual y media','Iteración','Función objetivo');
cfg.graficas(2) = entrada_grafica(base,'convergencia_apilada',true,'02_convergencia_corridas_apilada','Corridas y convergencia media del PSO','Iteración','Función objetivo');
cfg.graficas(3) = entrada_grafica(base,'media_de_individual',true,'03_convergencia_media_de','Convergencia media ± 1 desviación estándar','Iteración','Función objetivo');
cfg.graficas(4) = entrada_grafica(base,'media_de_apilada',true,'04_convergencia_media_de_apilada','Convergencia media ± 1 desviación estándar','Iteración','Función objetivo');
cfg.graficas(5) = entrada_grafica(base,'comparacion_medias',true,'05_comparacion_convergencia','Comparación de convergencia media','Iteración','Función objetivo');
cfg.graficas(6) = entrada_grafica(base,'varianza_iteracion',true,'06_varianza_iteracion','Varianza muestral por iteración','Iteración','Varianza del fitness');
cfg.graficas(7) = entrada_grafica(base,'mejor_peor_convergencia',true,'07_mejor_peor_convergencia','Mejor y peor convergencia observada','Iteración','Función objetivo');
cfg.graficas(8) = entrada_grafica(base,'comparacion_fases',true,'08_comparacion_fases','Convergencia por fases F1 y F2','Iteración de fase','Función objetivo');
cfg.graficas(9) = entrada_grafica(base,'fitness_fino',true,'09_distribucion_fitness_fino','Distribución del fitness fino final','Número de antenas','Fitness fino');
cfg.graficas(10) = entrada_grafica(base,'fitness_pso',true,'10_distribucion_fitness_pso','Distribución del fitness PSO final','Número de antenas','Fitness PSO');
cfg.graficas(11) = entrada_grafica(base,'tiempo_total',true,'11_distribucion_tiempo_total','Distribución del tiempo de optimización','Número de antenas','Tiempo total (s)');
cfg.graficas(12) = entrada_grafica(base,'tiempo_promedio',true,'12_tiempo_promedio','Tiempo promedio de optimización','Número de antenas','Tiempo total (s)');
cfg.graficas(13) = entrada_grafica(base,'tiempo_iteracion',true,'13_tiempo_iteracion','Tiempo promedio por iteración','Iteración','Tiempo (s)');
cfg.graficas(14) = entrada_grafica(base,'objetivo_1',true,'14_objetivo_1','Convergencia al objetivo del 1 %','Iteración','Corridas exitosas (%)');
cfg.graficas(15) = entrada_grafica(base,'objetivo_5',true,'15_objetivo_5','Convergencia al objetivo del 5 %','Iteración','Corridas exitosas (%)');
cfg.graficas(16) = entrada_grafica(base,'auc',true,'16_distribucion_auc','Distribución del área normalizada de convergencia','Número de antenas','AUC normalizada');
cfg.graficas(17) = entrada_grafica(base,'cobertura_exterior',true,'17_cobertura_exterior','Cobertura del tejido y distribución exterior','Número de antenas','Porcentaje (%)');
cfg.graficas(18) = entrada_grafica(base,'cobertura',true,'18_distribucion_cobertura','Distribución de cobertura del tejido','Número de antenas','Cobertura (%)');
cfg.graficas(19) = entrada_grafica(base,'exterior',true,'19_distribucion_exterior','Distribución exterior','Número de antenas','Exterior (%)');
cfg.graficas(20) = entrada_grafica(base,'volumenes',true,'20_volumenes','Volúmenes finales por corrida','Número de antenas','Volumen (mm³)');
cfg.graficas(21) = entrada_grafica(base,'iteraciones_fases',true,'21_iteraciones_fases','Iteraciones ejecutadas por fase','Número de antenas','Iteraciones');
cfg.graficas(22) = entrada_grafica(base,'parametros_evolucion',true,'22_parametros_evolucion','Evolución de parámetros de la mejor corrida','Iteración','Posición (mm) / rotación (°)');
cfg.graficas(23) = entrada_grafica(base,'parametros_distribucion',true,'23_parametros_distribucion','Distribución de parámetros optimizados','Parámetro','Valor');
cfg.graficas(24) = entrada_grafica(base,'fitness_mejor_medio',true,'24_fitness_mejor_medio','Mejor fitness y fitness medio del enjambre','Iteración','Función objetivo');
cfg.graficas(25) = entrada_grafica(base,'evaluaciones',true,'25_evaluaciones','Evaluaciones acumuladas del PSO','Iteración','Evaluaciones');
cfg.graficas(26) = entrada_grafica(base,'estancamiento',true,'26_estancamiento','Iteraciones de estancamiento del PSO','Iteración','Estancamiento');
cfg.graficas(27) = entrada_grafica(base,'posiciones_3d',true,'27_posiciones_3d','Posiciones optimizadas en el espacio 3D','X (mm)','Y (mm)');
cfg.graficas(27).z_etiqueta='Z (mm)'; cfg.graficas(27).posicion=[100 80 1050 720];
cfg.graficas(28) = entrada_grafica(base,'rotaciones',true,'28_rotaciones','Rotaciones optimizadas','Rotación 1 (°)','Rotación 2 (°)');
cfg.graficas(29) = entrada_grafica(base,'fitness_tiempo',true,'29_fitness_tiempo','Fitness frente al tiempo computacional','Tiempo total (s)','Fitness fino');
cfg.graficas(30) = entrada_grafica(base,'cobertura_exterior_dispersion',true,'30_cobertura_exterior_dispersion','Cobertura frente a distribución exterior','Cobertura (%)','Exterior (%)');
cfg.graficas(31) = entrada_grafica(base,'fitness_cobertura',true,'31_fitness_cobertura','Fitness frente a cobertura del tejido','Cobertura (%)','Fitness fino');
cfg.graficas(32) = entrada_grafica(base,'correlaciones',true,'32_matriz_correlaciones','Correlaciones entre métricas 3D','','');
cfg.graficas(33) = entrada_grafica(base,'mejor_espacial',true,'33_mejor_caso_espacial','Mejor configuración espacial 3D','X (mm)','Y (mm)');
cfg.graficas(33).z_etiqueta='Z (mm)'; cfg.graficas(33).posicion=[100 40 1100 780];
cfg.graficas(34) = entrada_grafica(base,'peor_espacial',true,'34_peor_caso_espacial','Peor configuración espacial 3D','X (mm)','Y (mm)');
cfg.graficas(34).z_etiqueta='Z (mm)'; cfg.graficas(34).posicion=[100 40 1100 780];
cfg.graficas(35) = entrada_grafica(base,'potencia',true,'35_distribucion_potencia','Distribución de potencia','Número de antenas','Potencia (W)');
cfg.graficas(36) = entrada_grafica(base,'tiempo_tratamiento',true,'36_distribucion_tiempo_tratamiento','Distribución del tiempo de tratamiento','Número de antenas','Tiempo de tratamiento (min)');
cfg.graficas(37) = entrada_grafica(base,'respuesta_potencia_tiempo',true,'37_respuesta_potencia_tiempo','Respuesta potencia-tiempo-fitness','Potencia (W)','Tiempo de tratamiento (min)');
cfg.graficas(37).z_etiqueta='Fitness fino'; cfg.graficas(37).posicion=[100 80 1050 720];
cfg.graficas(2).posicion=[100 40 1050 900];
cfg.graficas(4).posicion=[100 40 1050 900];
cfg.graficas(7).posicion=[100 40 1050 900];
cfg.graficas(8).posicion=[100 40 1050 900];
cfg.graficas(22).posicion=[100 25 1150 1000];
cfg.graficas(24).posicion=[100 40 1050 900];

if nargin == 1 && (ischar(entrada) || (isstring(entrada) && isscalar(entrada))) && ...
        strcmpi(char(entrada), 'selftest')
    ejecutar_selftest(cfg);
    salida = struct('selftest', true);
    return;
end

carpeta_modulo = fileparts(mfilename('fullpath'));
raiz_proyecto = fileparts(carpeta_modulo);
if nargin < 1 || isempty(entrada)
    [nombres, carpeta] = uigetfile(fullfile(raiz_proyecto, 'datasets', '*.mat'), ...
        'Seleccionar historiales del optimizador', 'MultiSelect', 'on');
    if isequal(nombres, 0), salida = struct('cancelado', true); return; end
    if ischar(nombres), nombres = {nombres}; end
    rutas = cellfun(@(n) fullfile(carpeta, n), nombres, 'UniformOutput', false);
else
    rutas = normalizar_rutas(entrada);
end

[corridas, avisos] = cargar_corridas(rutas);
if isempty(corridas)
    error('graficador_estadistico:sinCorridas', ...
        'Los MAT seleccionados no contienen corridas incluidas para análisis.');
end

marca_tiempo = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
carpeta_salida = fullfile(raiz_proyecto, 'datasets', ...
    'resultados_estadisticos_optimizador', marca_tiempo);
carpeta_csv = fullfile(carpeta_salida, 'csv');
carpeta_png = fullfile(carpeta_salida, 'png');
carpeta_fig = fullfile(carpeta_salida, 'fig');
carpeta_tiff = fullfile(carpeta_salida, 'tiff');
carpeta_eps = fullfile(carpeta_salida, 'eps');
carpetas = struct('png',carpeta_png,'fig',carpeta_fig,'tiff',carpeta_tiff,'eps',carpeta_eps);
crear_carpeta(carpeta_csv);
if cfg.guardar_png, crear_carpeta(carpeta_png); end
if cfg.guardar_fig, crear_carpeta(carpeta_fig); end
if cfg.guardar_tiff, crear_carpeta(carpeta_tiff); end
if cfg.guardar_eps, crear_carpeta(carpeta_eps); end

firmas = unique(string({corridas.cohorte}), 'stable');
resultados_cohortes = repmat(struct('firma', '', 'corridas', table(), ...
    'grupos', table(), 'iteraciones', table(), 'kruskal_wallis', table(), ...
    'comparaciones', table(), 'carpeta', ''), numel(firmas), 1);

for idx_cohorte = 1:numel(firmas)
    seleccion = strcmp({corridas.cohorte}, char(firmas(idx_cohorte)));
    [corridas_cohorte, tabla_corridas, tabla_grupos, tabla_iteraciones, ...
        tabla_kw, tabla_pares] = analizar_cohorte(corridas(seleccion));
    corridas(seleccion) = corridas_cohorte;
    nombre_cohorte = sprintf('cohorte_%02d', idx_cohorte);
    carpeta_cohorte = fullfile(carpeta_salida, nombre_cohorte);
    crear_carpeta(carpeta_cohorte);
    writetable(tabla_corridas, fullfile(carpeta_cohorte, 'resumen_corridas.csv'));
    writetable(tabla_grupos, fullfile(carpeta_cohorte, 'estadisticas_grupos.csv'));
    writetable(tabla_iteraciones, fullfile(carpeta_cohorte, 'estadisticas_iteracion.csv'));
    writetable(tabla_historial_crudo(corridas_cohorte), fullfile(carpeta_cohorte, 'historial_iteraciones_crudo.csv'));
    if ~isempty(tabla_kw), writetable(tabla_kw, fullfile(carpeta_cohorte, 'kruskal_wallis.csv')); end
    if ~isempty(tabla_pares), writetable(tabla_pares, fullfile(carpeta_cohorte, 'comparaciones_exploratorias.csv')); end
    generar_graficas(corridas_cohorte, tabla_iteraciones, tabla_grupos, ...
        carpetas, nombre_cohorte, cfg);
    resultados_cohortes(idx_cohorte).firma = char(firmas(idx_cohorte));
    resultados_cohortes(idx_cohorte).corridas = tabla_corridas;
    resultados_cohortes(idx_cohorte).grupos = tabla_grupos;
    resultados_cohortes(idx_cohorte).iteraciones = tabla_iteraciones;
    resultados_cohortes(idx_cohorte).kruskal_wallis = tabla_kw;
    resultados_cohortes(idx_cohorte).comparaciones = tabla_pares;
    resultados_cohortes(idx_cohorte).carpeta = carpeta_cohorte;
end

tabla_maestra = tabla_corridas_normalizadas(corridas);
writetable(tabla_maestra, fullfile(carpeta_csv, 'corridas_normalizadas.csv'));
save(fullfile(carpeta_salida, 'datos_normalizados.mat'), ...
    'corridas', 'resultados_cohortes', 'rutas', 'avisos', 'cfg', '-v7.3');
if ~isempty(avisos)
    fid = fopen(fullfile(carpeta_salida, 'avisos.txt'), 'w');
    if fid >= 0
        limpieza = onCleanup(@() fclose(fid));
        fprintf(fid, '%s\n', avisos{:});
    end
end
fprintf('GRAFICADOR_OPTIMIZADOR_OK corridas=%d cohortes=%d salida=%s\n', ...
    numel(corridas), numel(firmas), carpeta_salida);
salida = struct('cancelado', false, 'carpeta', carpeta_salida, ...
    'corridas', numel(corridas), 'cohortes', resultados_cohortes, ...
    'avisos', {avisos}, 'configuracion', cfg);
end

function rutas = normalizar_rutas(entrada)
if ischar(entrada)
    rutas = {entrada};
elseif isstring(entrada)
    rutas = cellstr(entrada(:));
elseif iscell(entrada)
    rutas = cellfun(@char, entrada(:), 'UniformOutput', false);
else
    error('graficador_estadistico:rutasInvalidas', ...
        'Las rutas deben ser texto, string o celda de textos.');
end
for k = 1:numel(rutas)
    if ~isfile(rutas{k})
        error('graficador_estadistico:archivoInexistente', ...
            'No existe el archivo: %s', rutas{k});
    end
end
end

function [corridas, avisos] = cargar_corridas(rutas)
corridas = repmat(plantilla_corrida(), 0, 1);
avisos = {};
for idx_archivo = 1:numel(rutas)
    variables = whos('-file', rutas{idx_archivo});
    if ~any(strcmp({variables.name}, 'hs'))
        avisos{end+1} = sprintf('Omitido sin variable hs: %s', rutas{idx_archivo}); 
        continue;
    end
    contenido = load(rutas{idx_archivo}, 'hs');
    historial = contenido.hs;
    if isstruct(historial), historial = num2cell(historial); end
    if ~iscell(historial)
        avisos{end+1} = sprintf('Omitido porque hs no es celda/struct: %s', rutas{idx_archivo}); 
        continue;
    end
    for idx_corrida = 1:numel(historial)
        corrida = historial{idx_corrida};
        if ~isstruct(corrida), continue; end
        [incluir, es_legacy] = debe_incluir_corrida(corrida);
        if ~incluir, continue; end
        normalizada = normalizar_corrida(corrida, rutas{idx_archivo}, es_legacy);
        if ~isfinite(normalizada.antenas)
            avisos{end+1} = sprintf('Corrida sin número de antenas en %s.', rutas{idx_archivo}); 
        end
        corridas(end+1,1) = normalizada; 
    end
end
[corridas, duplicadas] = deduplicar_corridas(corridas);
if duplicadas > 0, avisos{end+1} = sprintf('Se eliminaron %d corridas duplicadas.', duplicadas); end
if ~isempty(corridas) && any([corridas.legacy])
    avisos{end+1} = ['Se incluyeron historiales antiguos sin marca estadística; ' ...
        'sus métricas por iteración son limitadas.'];
end
end

function [incluir, legacy] = debe_incluir_corrida(corrida)
legacy = ~isfield(corrida, 'incluir_estadisticas');
if legacy
    incluir = true;
else
    valor = corrida.incluir_estadisticas;
    incluir = (islogical(valor) || isnumeric(valor)) && isscalar(valor) && logical(valor);
end
end

function r = normalizar_corrida(c, fuente, legacy)
r = plantilla_corrida(); r.fuente_mat = fuente; r.legacy = legacy;
if isfield(c, 'id'), r.id_corrida = campo_texto(c, 'id'); end
r.timestamp = campo_texto(c, 'timestamp');
if isfield(c, 'parametros') && isstruct(c.parametros), p = c.parametros; else, p = struct(); end
r.tipo_antena = campo_texto(p, 'tipo_antena'); r.caso = campo_texto(p, 'caso');
r.potencia = campo_texto(p, 'potencia'); r.distribucion = campo_texto(p, 'distribucion_termica');
r.potencia_w = numero_flexible(p, 'potencia');
r.tiempo_tratamiento_min = numero_flexible(p, 'tiempo_ejecucion');
r.antenas = numero_antenas(p); r.fitness_fino = campo_numerico(p, 'fitness_fino');
r.fitness_pso = campo_numerico(p, 'fitness_pso'); r.tiempo_total_s = campo_numerico(c, 'tiempo_total');
r.cobertura_pct = campo_numerico(p, 'porcentaje_interior'); r.exterior_pct = campo_numerico(p, 'porcentaje_exterior');
r.volumen_tumor_mm3 = campo_numerico(p, 'volumen_tumor');
r.volumen_distribucion_mm3 = campo_numerico(p, 'volumen_distribucion_termica');
r.volumen_exterior_mm3 = campo_numerico(p, 'volumen_exterior');
if isfield(p, 'posicion') && isnumeric(p.posicion)
    posicion = double(p.posicion(:).'); r.posicion(1:min(5,numel(posicion))) = posicion(1:min(5,numel(posicion)));
end
if isfield(p,'coordenadas_antenas') && isnumeric(p.coordenadas_antenas), r.coordenadas_antenas=double(p.coordenadas_antenas); end
if isfield(c,'vertices_tumor') && isnumeric(c.vertices_tumor), r.vertices_tumor=double(c.vertices_tumor); end
if isfield(c,'caras_tumor') && isnumeric(c.caras_tumor), r.caras_tumor=double(c.caras_tumor); end
if isfield(c,'ejes_a_rotar') && isnumeric(c.ejes_a_rotar), r.ejes_a_rotar=double(c.ejes_a_rotar(:).');
elseif isfield(p,'ejes_a_rotar') && isnumeric(p.ejes_a_rotar), r.ejes_a_rotar=double(p.ejes_a_rotar(:).'); end
r.historia_f1 = vector_numerico(c, 'historia_f1'); r.historia_f2 = vector_numerico(c, 'historia_f2');
if ~isempty(r.historia_f1) || ~isempty(r.historia_f2)
    r.historia = [r.historia_f1; r.historia_f2];
else
    r.historia = vector_numerico(c, 'historia_pso');
end
estadisticas = struct();
if isfield(c, 'estadisticas_pso') && isstruct(c.estadisticas_pso)
    estadisticas = c.estadisticas_pso;
    r.id_estadistico = campo_texto(estadisticas, 'id_estadistico');
    r.traza_f1 = normalizar_traza(campo_struct(estadisticas, 'traza_fase_1'));
    r.traza_f2 = normalizar_traza(campo_struct(estadisticas, 'traza_fase_2'));
end
r.cohorte = clave_cohorte(c, p, estadisticas);
r.clave_deduplicacion = clave_deduplicacion(r);
end

function r = plantilla_corrida()
r = struct('fuente_mat', '', 'legacy', false, 'id_corrida', '', ...
    'id_estadistico', '', 'timestamp', '', 'antenas', NaN, 'tipo_antena', '', ...
    'caso', '', 'potencia', '', 'potencia_w', NaN, 'tiempo_tratamiento_min', NaN, ...
    'distribucion', '', 'fitness_fino', NaN, ...
    'fitness_pso', NaN, 'tiempo_total_s', NaN, 'cobertura_pct', NaN, ...
    'exterior_pct', NaN, 'volumen_tumor_mm3', NaN, ...
    'volumen_distribucion_mm3', NaN, 'volumen_exterior_mm3', NaN, ...
    'posicion', nan(1,5), 'coordenadas_antenas', zeros(0,3), ...
    'vertices_tumor', zeros(0,3), 'caras_tumor', zeros(0,3), 'ejes_a_rotar', [1 2], ...
    'historia_f1', zeros(0,1), ...
    'historia_f2', zeros(0,1), 'historia', zeros(0,1), ...
    'traza_f1', traza_vacia(), 'traza_f2', traza_vacia(), ...
    'cohorte', '', 'clave_deduplicacion', '', ...
    'fitness_convergencia_final', NaN, 'auc_normalizada', NaN, 'tiempo_iteracion_medio_s', NaN, ...
    'primer_objetivo_1', NaN, 'primer_objetivo_5', NaN);
end

function traza = traza_vacia()
traza = struct('iteracion',zeros(0,1), 'mejor_fitness',zeros(0,1), ...
    'fitness_medio',zeros(0,1), 'evaluaciones',zeros(0,1), ...
    'estancamiento',zeros(0,1), 'tiempo_iteracion_s',zeros(0,1), ...
    'mejor_posicion',zeros(0,5));
end

function traza = normalizar_traza(origen)
traza = traza_vacia(); if isempty(fieldnames(origen)), return; end
campos = {'iteracion','mejor_fitness','fitness_medio','evaluaciones','estancamiento','tiempo_iteracion_s'};
for k = 1:numel(campos)
    if isfield(origen, campos{k}) && isnumeric(origen.(campos{k}))
        traza.(campos{k}) = double(origen.(campos{k})(:));
    end
end
if isfield(origen, 'mejor_posicion') && isnumeric(origen.mejor_posicion)
    posiciones = double(origen.mejor_posicion); if isvector(posiciones), posiciones = posiciones(:).'; end
    if size(posiciones,2) < 5, posiciones(:,end+1:5) = NaN; end
    traza.mejor_posicion = posiciones(:,1:5);
end
end

function [corridas, duplicadas] = deduplicar_corridas(corridas)
if isempty(corridas), duplicadas = 0; return; end
claves = string({corridas.clave_deduplicacion}); [~, indices] = unique(claves, 'stable');
duplicadas = numel(corridas) - numel(indices); corridas = corridas(sort(indices));
end

function clave = clave_deduplicacion(r)
if ~isempty(r.id_estadistico), clave = ['id|' r.id_estadistico]; return; end
inicial = NaN; final = NaN;
if ~isempty(r.historia), inicial = r.historia(1); final = r.historia(end); end
clave = sprintf('legacy|%s|%s|%s|%.15g|%.15g|%.15g|%d|%.15g|%.15g', ...
    r.timestamp, r.id_corrida, r.distribucion, r.fitness_fino, ...
    r.tiempo_total_s, r.fitness_pso, numel(r.historia), inicial, final);
end

function clave = clave_cohorte(c, p, e)
metodo = campo_texto(p, 'metodo_voxel'); tipo = campo_texto(p, 'tipo_antena'); caso = campo_texto(p, 'caso');
firma = ''; res_fina = NaN; res_gruesa = NaN; filtros = struct(); criterio = struct();
if ~isempty(fieldnames(e))
    firma = campo_texto(e, 'firma_geometria'); metodo = campo_texto_preferido(e, 'metodo_voxel', metodo);
    res_fina = campo_numerico(e, 'resolucion_fina_mm'); res_gruesa = campo_numerico(e, 'resolucion_gruesa_mm');
    filtros = campo_struct(e, 'filtros_activos'); criterio = campo_struct(e, 'criterio_fitness');
elseif isfield(p, 'criterio_fitness') && isstruct(p.criterio_fitness)
    criterio = p.criterio_fitness;
end
if isempty(firma) && isfield(c, 'vertices_tumor') && isnumeric(c.vertices_tumor)
    v = double(c.vertices_tumor); firma = sprintf('legacy_n%d_s%.9g_q%.9g', size(v,1), sum(v(:)), sum(v(:).^2));
end
clave = sprintf('geom=%s|tipo=%s|caso=%s|metodo=%s|rf=%.9g|rg=%.9g|%s|%s', ...
    firma, tipo, caso, metodo, res_fina, res_gruesa, ...
    serializar_filtros(filtros), serializar_estructura_numerica(criterio));
end

function texto = serializar_filtros(filtros)
if isempty(fieldnames(filtros)), texto = 'filtros=legacy'; return; end
campos = sort(fieldnames(filtros)); partes = {};
for k = 1:numel(campos)
    if strcmp(campos{k}, 'antenas'), continue; end
    valor = filtros.(campos{k});
    if iscell(valor) || isstring(valor) || ischar(valor)
        valores = sort(string(valor(:))); partes{end+1} = sprintf('%s=%s', campos{k}, strjoin(valores, ',')); 
    end
end
texto = strjoin(partes, ';');
end

function texto = serializar_estructura_numerica(s)
if isempty(fieldnames(s)), texto = 'criterio=legacy'; return; end
campos = sort(fieldnames(s)); partes = {};
for k = 1:numel(campos)
    valor = s.(campos{k});
    if isnumeric(valor) && isscalar(valor), partes{end+1} = sprintf('%s=%.12g', campos{k}, double(valor)); end 
end
texto = strjoin(partes, ';');
end

function [corridas, tabla_corridas, tabla_grupos, tabla_iteraciones, tabla_kw, tabla_pares] = analizar_cohorte(corridas)
grupos = unique([corridas.antenas]); grupos = grupos(isfinite(grupos));
for k = 1:numel(corridas)
    h = corridas(k).historia; validos = h(isfinite(h));
    if ~isempty(validos), corridas(k).fitness_convergencia_final = validos(end); end
    corridas(k).auc_normalizada = auc_normalizada(h);
    tiempos = traza_combinada(corridas(k), 'tiempo_iteracion_s');
    corridas(k).tiempo_iteracion_medio_s = media_finita(tiempos);
end
for idx_grupo = 1:numel(grupos)
    indices = find([corridas.antenas] == grupos(idx_grupo));
    finales = [corridas(indices).fitness_convergencia_final]; finales = finales(isfinite(finales));
    if isempty(finales), continue; end
    mejor = min(finales); objetivo_1 = mejor + 0.01 * abs(mejor); objetivo_5 = mejor + 0.05 * abs(mejor);
    for idx = indices
        corridas(idx).primer_objetivo_1 = primer_impacto(corridas(idx).historia, objetivo_1);
        corridas(idx).primer_objetivo_5 = primer_impacto(corridas(idx).historia, objetivo_5);
    end
end
tabla_corridas = tabla_corridas_normalizadas(corridas);
[tabla_grupos, tabla_iteraciones] = resumir_grupos(corridas, grupos);
[tabla_kw, tabla_pares] = comparaciones_exploratorias(corridas, grupos);
end

function tabla = tabla_corridas_normalizadas(corridas)
n = numel(corridas);
fuente=strings(n,1); legacy=false(n,1); id=strings(n,1); fecha=strings(n,1); antenas=nan(n,1);
tipo=strings(n,1); caso=strings(n,1); potencia=strings(n,1); distribucion=strings(n,1);
fino=nan(n,1); pso=nan(n,1); conv=nan(n,1); tiempo=nan(n,1); it1=zeros(n,1); it2=zeros(n,1);
cobertura=nan(n,1); exterior=nan(n,1); auc=nan(n,1); hit1=nan(n,1); hit5=nan(n,1);
potencia_w=nan(n,1); tratamiento=nan(n,1); tiempo_iter=nan(n,1); volumenes=nan(n,3);
posicion=nan(n,5); cohorte=strings(n,1);
for k=1:n
    fuente(k)=corridas(k).fuente_mat; legacy(k)=corridas(k).legacy;
    if isempty(corridas(k).id_estadistico), id(k)=corridas(k).id_corrida; else, id(k)=corridas(k).id_estadistico; end
    fecha(k)=corridas(k).timestamp; antenas(k)=corridas(k).antenas; tipo(k)=corridas(k).tipo_antena;
    caso(k)=corridas(k).caso; potencia(k)=corridas(k).potencia; distribucion(k)=corridas(k).distribucion;
    potencia_w(k)=corridas(k).potencia_w; tratamiento(k)=corridas(k).tiempo_tratamiento_min;
    fino(k)=corridas(k).fitness_fino; pso(k)=corridas(k).fitness_pso; conv(k)=corridas(k).fitness_convergencia_final;
    tiempo(k)=corridas(k).tiempo_total_s; it1(k)=numel(corridas(k).historia_f1); it2(k)=numel(corridas(k).historia_f2);
    cobertura(k)=corridas(k).cobertura_pct; exterior(k)=corridas(k).exterior_pct;
    tiempo_iter(k)=corridas(k).tiempo_iteracion_medio_s;
    volumenes(k,:)=[corridas(k).volumen_tumor_mm3 corridas(k).volumen_distribucion_mm3 corridas(k).volumen_exterior_mm3];
    auc(k)=corridas(k).auc_normalizada; hit1(k)=corridas(k).primer_objetivo_1; hit5(k)=corridas(k).primer_objetivo_5;
    posicion(k,:)=corridas(k).posicion; cohorte(k)=corridas(k).cohorte;
end
tabla = table(fuente,legacy,id,fecha,antenas,tipo,caso,potencia,distribucion, ...
    potencia_w,tratamiento,fino,pso,conv,tiempo,tiempo_iter,it1,it2,cobertura,exterior, ...
    volumenes(:,1),volumenes(:,2),volumenes(:,3),auc,hit1,hit5, ...
    posicion(:,1),posicion(:,2),posicion(:,3),rad2deg(posicion(:,4)),rad2deg(posicion(:,5)),cohorte, ...
    'VariableNames', {'FuenteMAT','EsquemaAntiguo','IdEstadistico','Fecha','Antenas', ...
    'TipoAntena','Caso','Potencia','Distribucion','Potencia_W','TiempoTratamiento_min', ...
    'FitnessFino','FitnessPSO','FitnessConvergenciaFinal','TiempoTotal_s','TiempoIteracionMedio_s', ...
    'IteracionesF1','IteracionesF2','Cobertura_pct','Exterior_pct','VolumenTejido_mm3', ...
    'VolumenDistribucion_mm3','VolumenExterior_mm3','AUCNormalizada','PrimerObjetivo1_iter', ...
    'PrimerObjetivo5_iter','X_mm','Y_mm','Z_mm','Rotacion1_deg','Rotacion2_deg','FirmaConfiguracion'});
end

function [tabla_grupos, tabla_iteraciones] = resumir_grupos(corridas, grupos)
filas = repmat(struct(), 0, 1); tabla_iteraciones = table();
for g = grupos
    c = corridas([corridas.antenas] == g); n = numel(c);
    fino=[c.fitness_fino]; pso=[c.fitness_pso]; tiempo=[c.tiempo_total_s]; cobertura=[c.cobertura_pct];
    exterior=[c.exterior_pct]; auc=[c.auc_normalizada]; conv=[c.fitness_convergencia_final]; conv=conv(isfinite(conv));
    tiempo_iter=[c.tiempo_iteracion_medio_s]; potencia=[c.potencia_w]; tratamiento=[c.tiempo_tratamiento_min];
    if isempty(conv), objetivo1=NaN;objetivo5=NaN; else, objetivo1=min(conv)+0.01*abs(min(conv));objetivo5=min(conv)+0.05*abs(min(conv)); end
    hits1=[c.primer_objetivo_1];hits5=[c.primer_objetivo_5];
    [mlo,mhi,medlo,medhi]=intervalos_bootstrap(fino); q=cuantiles(fino,[.25 .75]);
    fila=struct('Antenas',g,'Corridas',n,'FitnessFinoMedia',media_finita(fino), ...
        'FitnessFinoIC95Bajo',mlo,'FitnessFinoIC95Alto',mhi,'FitnessFinoMediana',mediana_finita(fino), ...
        'FitnessMedianaIC95Bajo',medlo,'FitnessMedianaIC95Alto',medhi, ...
        'FitnessFinoVarianza',varianza_finita(fino),'FitnessFinoDE',desviacion_finita(fino), ...
        'FitnessFinoQ1',q(1),'FitnessFinoQ3',q(2),'FitnessFinoMin',min_finito(fino), ...
        'FitnessFinoMax',max_finito(fino),'FitnessFinoCV_pct',cv_finito(fino), ...
        'FitnessFinoAsimetria',asimetria_finita(fino),'FitnessFinoCurtosisExceso',curtosis_finita(fino), ...
        'FitnessPSOMedia',media_finita(pso),'FitnessPSODE',desviacion_finita(pso), ...
        'TiempoMedia_s',media_finita(tiempo),'TiempoDE_s',desviacion_finita(tiempo), ...
        'TiempoIteracionMedia_s',media_finita(tiempo_iter),'TiempoIteracionDE_s',desviacion_finita(tiempo_iter), ...
        'PotenciaMedia_W',media_finita(potencia),'TiempoTratamientoMedia_min',media_finita(tratamiento), ...
        'CoberturaMedia_pct',media_finita(cobertura),'CoberturaDE_pct',desviacion_finita(cobertura), ...
        'ExteriorMedia_pct',media_finita(exterior),'ExteriorDE_pct',desviacion_finita(exterior), ...
        'AUCMedia',media_finita(auc),'AUCDE',desviacion_finita(auc),'Objetivo1',objetivo1, ...
        'Exito1_pct',100*mean(isfinite(hits1)),'MedianaPrimerObjetivo1_iter',mediana_finita(hits1), ...
        'Objetivo5',objetivo5,'Exito5_pct',100*mean(isfinite(hits5)), ...
        'MedianaPrimerObjetivo5_iter',mediana_finita(hits5));
    if isempty(filas), filas=fila; else, filas(end+1,1)=fila; end 
    matriz=matriz_historias(c);
    if ~isempty(matriz)
        iter=(1:size(matriz,2)).'; cuenta=sum(isfinite(matriz),1).'; media=mean(matriz,1,'omitnan').';
        variancia=var(matriz,0,1,'omitnan').';de=std(matriz,0,1,'omitnan').';mediana=median(matriz,1,'omitnan').';
        q1=cuantil_columnas(matriz,.25).';q3=cuantil_columnas(matriz,.75).';
        minimo=min(matriz,[],1,'omitnan').';maximo=max(matriz,[],1,'omitnan').';
        sem=de./sqrt(max(cuenta,1));
        tg=table(repmat(g,numel(iter),1),iter,cuenta,media,variancia,de,mediana,q1,q3,minimo,maximo,media-1.96*sem,media+1.96*sem, ...
            'VariableNames',{'Antenas','Iteracion','N','Media','Varianza','DesviacionEstandar','Mediana', ...
            'Q1','Q3','Minimo','Maximo','IC95MediaBajoAprox','IC95MediaAltoAprox'});
        tabla_iteraciones=[tabla_iteraciones;tg]; 
    end
end
if isempty(filas), tabla_grupos=table(); else, tabla_grupos=struct2table(filas); end
end

function [tabla_kw, tabla_pares] = comparaciones_exploratorias(corridas, grupos)
datos=cell(0,1); etiquetas=[];
for g=grupos
    x=[corridas([corridas.antenas]==g).fitness_fino]; x=x(isfinite(x));
    if numel(x)>=2, datos{end+1,1}=x(:); etiquetas(end+1)=g; end 
end
if numel(datos)<2, tabla_kw=table(); tabla_pares=table(); return; end
[H,p]=kruskal_wallis_manual(datos); tabla_kw=table(H,numel(datos)-1,p,'VariableNames',{'H','GradosLibertad','ValorP'});
filas=repmat(struct(),0,1); m=numel(datos)*(numel(datos)-1)/2;
for i=1:numel(datos)-1
    for j=i+1:numel(datos)
        [U,pU,z]=mann_whitney_manual(datos{i},datos{j}); delta=cliff_delta(datos{i},datos{j});
        fila=struct('AntenasA',etiquetas(i),'AntenasB',etiquetas(j),'U',U,'Z',z, ...
            'ValorP',pU,'ValorPAjustadoBonferroni',min(1,pU*m),'DeltaCliff_A_menos_B',delta, ...
            'MagnitudEfecto',magnitud_efecto(abs(delta)));
        if isempty(filas), filas=fila; else, filas(end+1,1)=fila; end 
    end
end
tabla_pares=struct2table(filas);
end

function generar_graficas(corridas,tabla_iter,tabla_grupos,carpetas,prefijo,cfg)
grupos=unique([corridas.antenas]);grupos=grupos(isfinite(grupos));if isempty(grupos),return;end
graficar_convergencias(corridas,tabla_iter,grupos,carpetas,prefijo,cfg);
graficar_distribucion(corridas,grupos,'fitness_fino','fitness_fino',carpetas,prefijo,cfg);
graficar_distribucion(corridas,grupos,'fitness_pso','fitness_pso',carpetas,prefijo,cfg);
graficar_distribucion(corridas,grupos,'tiempo_total_s','tiempo_total',carpetas,prefijo,cfg);
graficar_tiempo_promedio(corridas,grupos,carpetas,prefijo,cfg);
graficar_traza_media(corridas,grupos,'tiempo_iteracion_s','tiempo_iteracion',carpetas,prefijo,cfg);
graficar_exito(corridas,grupos,.01,'objetivo_1',carpetas,prefijo,cfg);
graficar_exito(corridas,grupos,.05,'objetivo_5',carpetas,prefijo,cfg);
graficar_distribucion(corridas,grupos,'auc_normalizada','auc',carpetas,prefijo,cfg);
graficar_cobertura_exterior(tabla_grupos,carpetas,prefijo,cfg);
graficar_distribucion(corridas,grupos,'cobertura_pct','cobertura',carpetas,prefijo,cfg);
graficar_distribucion(corridas,grupos,'exterior_pct','exterior',carpetas,prefijo,cfg);
graficar_volumenes(corridas,grupos,carpetas,prefijo,cfg);
graficar_iteraciones_fases(corridas,grupos,carpetas,prefijo,cfg);
graficar_parametros(corridas,grupos,carpetas,prefijo,cfg);
graficar_parametros_distribucion(corridas,grupos,carpetas,prefijo,cfg);
graficar_mejor_medio(corridas,grupos,carpetas,prefijo,cfg);
graficar_traza_media(corridas,grupos,'evaluaciones','evaluaciones',carpetas,prefijo,cfg);
graficar_traza_media(corridas,grupos,'estancamiento','estancamiento',carpetas,prefijo,cfg);
graficar_posiciones(corridas,grupos,carpetas,prefijo,cfg);
graficar_dispersion(corridas,grupos,'posicion_4','posicion_5','rotaciones',carpetas,prefijo,cfg);
graficar_dispersion(corridas,grupos,'tiempo_total_s','fitness_fino','fitness_tiempo',carpetas,prefijo,cfg);
graficar_dispersion(corridas,grupos,'cobertura_pct','exterior_pct','cobertura_exterior_dispersion',carpetas,prefijo,cfg);
graficar_dispersion(corridas,grupos,'cobertura_pct','fitness_fino','fitness_cobertura',carpetas,prefijo,cfg);
graficar_correlaciones(corridas,carpetas,prefijo,cfg);
graficar_espacial(corridas,grupos,true,carpetas,prefijo,cfg);
graficar_espacial(corridas,grupos,false,carpetas,prefijo,cfg);
graficar_distribucion(corridas,grupos,'potencia_w','potencia',carpetas,prefijo,cfg);
graficar_distribucion(corridas,grupos,'tiempo_tratamiento_min','tiempo_tratamiento',carpetas,prefijo,cfg);
graficar_respuesta(corridas,grupos,carpetas,prefijo,cfg);
end

function graficar_convergencias(corridas,tabla_iter,grupos,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,'convergencia_individual');
if g.activa
    for i=1:numel(grupos)
        c=corridas([corridas.antenas]==grupos(i));M=matriz_historias(c);if isempty(M),continue;end
        f=figura_nueva(cfg,g);ax=axes('Parent',f);hold(ax,'on');
        for r=1:size(M,1),plot(ax,M(r,:),'-','Color',g.color_corridas,'LineWidth',g.ancho_corridas,'HandleVisibility','off');end
        h1=plot(ax,NaN,NaN,'-','Color',g.color_corridas,'LineWidth',max(1,g.ancho_corridas));
        h2=plot(ax,mean(M,1,'omitnan'),'-','Color',color_antena(cfg,grupos(i)),'LineWidth',g.ancho_linea);
        rotular(ax,g,sprintf('%s - %s',g.titulo,etiqueta_antenas(grupos(i))));legend(ax,[h1 h2],{'Corridas','Media'},'Location',g.ubicacion_leyenda);
        guardar_figura(f,carpetas,nombre_salida(prefijo,g,sprintf('_%d_antenas',round(grupos(i)))),cfg,g);
    end
end
g=obtener_grafica(cfg,'convergencia_apilada');
if g.activa
    f=figura_nueva(cfg,g);t=tiledlayout(f,numel(grupos),1,'TileSpacing','compact','Padding','compact');
    for i=1:numel(grupos)
        ax=nexttile(t);hold(ax,'on');M=matriz_historias(corridas([corridas.antenas]==grupos(i)));
        for r=1:size(M,1),plot(ax,M(r,:),'-','Color',g.color_corridas,'LineWidth',g.ancho_corridas,'HandleVisibility','off');end
        plot(ax,mean(M,1,'omitnan'),'-','Color',g.color_media,'LineWidth',g.ancho_linea,'DisplayName','Media');
        title(ax,sprintf('%s %s',panel_cfg(g,i),etiqueta_antenas(grupos(i))));legend(ax,'Location',g.ubicacion_leyenda);grid(ax,'on');if i<numel(grupos),ax.XTickLabel=[];end
    end
    rotular_layout(t,g);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end
g=obtener_grafica(cfg,'media_de_individual');
if g.activa
    for i=1:numel(grupos)
        filas=tabla_iter.Antenas==grupos(i);if ~any(filas),continue;end
        x=tabla_iter.Iteracion(filas);mu=tabla_iter.Media(filas);sd=tabla_iter.DesviacionEstandar(filas);color=color_antena(cfg,grupos(i));
        f=figura_nueva(cfg,g);ax=axes('Parent',f);hold(ax,'on');
        fill(ax,[x;flipud(x)],[mu-sd;flipud(mu+sd)],aclarar(color,.70),'FaceAlpha',g.alpha_banda,'EdgeColor','none','HandleVisibility','off');
        plot(ax,x,mu,'Color',color,'LineWidth',g.ancho_linea,'DisplayName','Media');
        plot(ax,x,mu+sd,'--','Color',aclarar(color,.50),'LineWidth',g.ancho_secundario,'DisplayName','± 1 DE');
        plot(ax,x,mu-sd,'--','Color',aclarar(color,.50),'LineWidth',g.ancho_secundario,'HandleVisibility','off');
        rotular(ax,g,sprintf('%s - %s',g.titulo,etiqueta_antenas(grupos(i))));legend(ax,'Location',g.ubicacion_leyenda);
        guardar_figura(f,carpetas,nombre_salida(prefijo,g,sprintf('_%d_antenas',round(grupos(i)))),cfg,g);
    end
end
g=obtener_grafica(cfg,'media_de_apilada');
if g.activa
    f=figura_nueva(cfg,g);t=tiledlayout(f,numel(grupos),1,'TileSpacing','compact','Padding','compact');
    for i=1:numel(grupos)
        ax=nexttile(t);hold(ax,'on');filas=tabla_iter.Antenas==grupos(i);x=tabla_iter.Iteracion(filas);mu=tabla_iter.Media(filas);sd=tabla_iter.DesviacionEstandar(filas);color=color_antena(cfg,grupos(i));
        plot(ax,x,mu,'Color',color,'LineWidth',g.ancho_linea,'DisplayName','Media');plot(ax,x,mu+sd,'--','Color',aclarar(color,.55),'LineWidth',g.ancho_secundario,'DisplayName','± 1 DE');
        plot(ax,x,mu-sd,'--','Color',aclarar(color,.55),'LineWidth',g.ancho_secundario,'HandleVisibility','off');title(ax,sprintf('%s %s',panel_cfg(g,i),etiqueta_antenas(grupos(i))));legend(ax,'Location',g.ubicacion_leyenda);grid(ax,'on');if i<numel(grupos),ax.XTickLabel=[];end
    end
    rotular_layout(t,g);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end
graficar_comparacion_medias(tabla_iter,grupos,carpetas,prefijo,cfg);
graficar_varianza(tabla_iter,grupos,carpetas,prefijo,cfg);
graficar_mejor_peor(corridas,grupos,carpetas,prefijo,cfg);
graficar_fases(corridas,grupos,carpetas,prefijo,cfg);
end

function graficar_comparacion_medias(tabla_iter,grupos,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,'comparacion_medias');if ~g.activa,return;end
f=figura_nueva(cfg,g);ax=axes(f);hold(ax,'on');
for i=1:numel(grupos),filas=tabla_iter.Antenas==grupos(i);plot(ax,tabla_iter.Iteracion(filas),tabla_iter.Media(filas),'Color',color_antena(cfg,grupos(i)),'LineWidth',g.ancho_linea,'DisplayName',etiqueta_antenas(grupos(i)));end
rotular(ax,g,g.titulo);legend(ax,'Location',g.ubicacion_leyenda);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_varianza(tabla_iter,grupos,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,'varianza_iteracion');if ~g.activa||~ismember('Varianza',tabla_iter.Properties.VariableNames),return;end
f=figura_nueva(cfg,g);ax=axes(f);hold(ax,'on');
for i=1:numel(grupos),filas=tabla_iter.Antenas==grupos(i);plot(ax,tabla_iter.Iteracion(filas),tabla_iter.Varianza(filas),'Color',color_antena(cfg,grupos(i)),'LineWidth',g.ancho_linea,'DisplayName',etiqueta_antenas(grupos(i)));end
rotular(ax,g,g.titulo);legend(ax,'Location',g.ubicacion_leyenda);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_mejor_peor(corridas,grupos,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,'mejor_peor_convergencia');if ~g.activa,return;end
f=figura_nueva(cfg,g);t=tiledlayout(f,numel(grupos),1,'TileSpacing','compact','Padding','compact');hay=false;
for i=1:numel(grupos)
    ax=nexttile(t);hold(ax,'on');c=corridas([corridas.antenas]==grupos(i));v=arrayfun(@fitness_primario,c);validos=find(isfinite(v));
    if isempty(validos),continue;end
    [~,ib]=min(v(validos));[~,iw]=max(v(validos));mejor=c(validos(ib));peor=c(validos(iw));
    plot(ax,mejor.historia,'Color',[.20 .60 .30],'LineWidth',g.ancho_linea,'DisplayName','Mejor');plot(ax,peor.historia,'Color',[.75 .25 .20],'LineWidth',g.ancho_linea,'DisplayName','Peor');
    title(ax,sprintf('%s %s',panel_cfg(g,i),etiqueta_antenas(grupos(i))));legend(ax,'Location',g.ubicacion_leyenda);grid(ax,'on');if i<numel(grupos),ax.XTickLabel=[];end;hay=true;
end
if ~hay,close(f);return;end;rotular_layout(t,g);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_fases(corridas,grupos,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,'comparacion_fases');if ~g.activa,return;end
f=figura_nueva(cfg,g);t=tiledlayout(f,numel(grupos),1,'TileSpacing','compact','Padding','compact');hay=false;
for i=1:numel(grupos)
    ax=nexttile(t);hold(ax,'on');c=corridas([corridas.antenas]==grupos(i));M1=matriz_campo_vectores(c,'historia_f1');M2=matriz_campo_vectores(c,'historia_f2');
    if ~isempty(M1),plot(ax,mean(M1,1,'omitnan'),'Color',color_antena(cfg,grupos(i)),'LineWidth',g.ancho_linea,'DisplayName','Fase 1');hay=true;end
    if ~isempty(M2),plot(ax,mean(M2,1,'omitnan'),'--','Color',aclarar(color_antena(cfg,grupos(i)),.28),'LineWidth',g.ancho_linea,'DisplayName','Fase 2');hay=true;end
    title(ax,sprintf('%s %s',panel_cfg(g,i),etiqueta_antenas(grupos(i))));legend(ax,'Location',g.ubicacion_leyenda);grid(ax,'on');if i<numel(grupos),ax.XTickLabel=[];end
end
if ~hay,close(f);return;end;rotular_layout(t,g);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_distribucion(corridas,grupos,campo,id,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,id);if ~g.activa,return;end
f=figura_nueva(cfg,g);ax=axes(f);hold(ax,'on');hay=false;
for i=1:numel(grupos)
    x=arrayfun(@(c)valor_corrida(c,campo),corridas([corridas.antenas]==grupos(i)));x=x(isfinite(x));if isempty(x),continue;end
    b=boxchart(ax,i*ones(numel(x),1),x(:),'BoxFaceColor',color_antena(cfg,grupos(i)));b.MarkerColor=color_antena(cfg,grupos(i));hay=true;
end
if ~hay,close(f);return;end;xticks(ax,1:numel(grupos));xticklabels(ax,arrayfun(@etiqueta_antenas,grupos,'UniformOutput',false));rotular(ax,g,g.titulo);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_tiempo_promedio(corridas,grupos,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,'tiempo_promedio');if ~g.activa,return;end
medias=nan(size(grupos));de=nan(size(grupos));for i=1:numel(grupos),x=[corridas([corridas.antenas]==grupos(i)).tiempo_total_s];medias(i)=media_finita(x);de(i)=desviacion_finita(x);end
if ~any(isfinite(medias)),return;end;f=figura_nueva(cfg,g);ax=axes(f);b=bar(ax,1:numel(grupos),medias,'FaceColor','flat');for i=1:numel(grupos),b.CData(i,:)=color_antena(cfg,grupos(i));end
hold(ax,'on');errorbar(ax,1:numel(grupos),medias,de,'.','Color',g.color_texto,'LineWidth',g.ancho_secundario);xticks(ax,1:numel(grupos));xticklabels(ax,arrayfun(@etiqueta_antenas,grupos,'UniformOutput',false));rotular(ax,g,g.titulo);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_traza_media(corridas,grupos,campo,id,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,id);if ~g.activa,return;end;f=figura_nueva(cfg,g);ax=axes(f);hold(ax,'on');hay=false;
for i=1:numel(grupos),M=matriz_trazas(corridas([corridas.antenas]==grupos(i)),campo);if isempty(M),continue;end;plot(ax,mean(M,1,'omitnan'),'Color',color_antena(cfg,grupos(i)),'LineWidth',g.ancho_linea,'DisplayName',etiqueta_antenas(grupos(i)));hay=true;end
if ~hay,close(f);return;end;rotular(ax,g,g.titulo);legend(ax,'Location',g.ubicacion_leyenda);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_exito(corridas,grupos,fraccion,id,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,id);if ~g.activa,return;end;f=figura_nueva(cfg,g);ax=axes(f);hold(ax,'on');hay=false;
for i=1:numel(grupos)
    c=corridas([corridas.antenas]==grupos(i));finales=[c.fitness_convergencia_final];finales=finales(isfinite(finales));if isempty(finales),continue;end
    objetivo=min(finales)+fraccion*abs(min(finales));M=matriz_historias(c);acum=zeros(1,size(M,2));for k=1:size(M,2),acum(k)=100*mean(any(M(:,1:k)<=objetivo,2));end
    stairs(ax,1:numel(acum),acum,'Color',color_antena(cfg,grupos(i)),'LineWidth',g.ancho_linea,'DisplayName',etiqueta_antenas(grupos(i)));hay=true;
end
if ~hay,close(f);return;end;ylim(ax,[0 100]);rotular(ax,g,g.titulo);legend(ax,'Location',g.ubicacion_leyenda);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_cobertura_exterior(tabla_grupos,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,'cobertura_exterior');if ~g.activa||isempty(tabla_grupos),return;end
f=figura_nueva(cfg,g);ax=axes(f);medias=[tabla_grupos.CoberturaMedia_pct tabla_grupos.ExteriorMedia_pct];b=bar(ax,(1:height(tabla_grupos)).',medias,'grouped');
b(1).FaceColor=[.20 .60 .30];b(2).FaceColor=[.75 .25 .20];xticks(ax,1:height(tabla_grupos));xticklabels(ax,arrayfun(@etiqueta_antenas,tabla_grupos.Antenas,'UniformOutput',false));legend(ax,{'Cobertura del tejido','Exterior'},'Location',g.ubicacion_leyenda);rotular(ax,g,g.titulo);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_volumenes(corridas,grupos,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,'volumenes');if ~g.activa,return;end;campos={'volumen_tumor_mm3','volumen_distribucion_mm3','volumen_exterior_mm3'};titulos={'Tejido','Distribución térmica','Exterior'};
f=figura_nueva(cfg,g);t=tiledlayout(f,1,3,'TileSpacing','compact','Padding','compact');hay=false;
for p=1:3,ax=nexttile(t);hold(ax,'on');for i=1:numel(grupos),x=arrayfun(@(c)valor_corrida(c,campos{p}),corridas([corridas.antenas]==grupos(i)));x=x(isfinite(x));if isempty(x),continue;end;boxchart(ax,i*ones(numel(x),1),x(:),'BoxFaceColor',color_antena(cfg,grupos(i)));hay=true;end;title(ax,titulos{p});xticks(ax,1:numel(grupos));xticklabels(ax,arrayfun(@etiqueta_antenas,grupos,'UniformOutput',false));grid(ax,'on');end
if ~hay,close(f);return;end;rotular_layout(t,g);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_iteraciones_fases(corridas,grupos,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,'iteraciones_fases');if ~g.activa,return;end;m=nan(numel(grupos),2);de=m;
for i=1:numel(grupos),c=corridas([corridas.antenas]==grupos(i));a=arrayfun(@(x)numel(x.historia_f1),c);b=arrayfun(@(x)numel(x.historia_f2),c);m(i,:)=[mean(a) mean(b)];de(i,:)=[std(a,0) std(b,0)];end
if ~any(m(:)>0),return;end;f=figura_nueva(cfg,g);ax=axes(f);b=bar(ax,(1:numel(grupos)).',m,'grouped');b(1).FaceColor=[.20 .45 .75];b(2).FaceColor=[.75 .35 .20];hold(ax,'on');
for j=1:2,errorbar(ax,b(j).XEndPoints,m(:,j),de(:,j),'.','Color',g.color_texto,'LineWidth',g.ancho_secundario);end
xticks(ax,1:numel(grupos));xticklabels(ax,arrayfun(@etiqueta_antenas,grupos,'UniformOutput',false));legend(ax,{'Fase 1','Fase 2'},'Location',g.ubicacion_leyenda);rotular(ax,g,g.titulo);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_parametros(corridas,grupos,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,'parametros_evolucion');if ~g.activa,return;end;seleccionados=repmat(plantilla_corrida(),0,1);
for n=grupos,c=corridas([corridas.antenas]==n);c=c(arrayfun(@(x)~isempty(x.traza_f1.mejor_posicion)||~isempty(x.traza_f2.mejor_posicion),c));if isempty(c),continue;end;v=arrayfun(@fitness_primario,c);[~,i]=min(v);seleccionados(end+1)=c(i);end 
if isempty(seleccionados),return;end;f=figura_nueva(cfg,g);t=tiledlayout(f,numel(seleccionados),1,'TileSpacing','compact','Padding','compact');colores=lines(5);etiquetas={'X','Y','Z','Rotación 1','Rotación 2'};
for i=1:numel(seleccionados),ax=nexttile(t);hold(ax,'on');P=[seleccionados(i).traza_f1.mejor_posicion;seleccionados(i).traza_f2.mejor_posicion];P(:,4:5)=rad2deg(P(:,4:5));for k=1:5,plot(ax,P(:,k),'Color',colores(k,:),'LineWidth',g.ancho_secundario,'DisplayName',etiquetas{k});end;title(ax,sprintf('%s %s',panel_cfg(g,i),etiqueta_antenas(seleccionados(i).antenas)));legend(ax,'Location',g.ubicacion_leyenda,'NumColumns',5);grid(ax,'on');if i<numel(seleccionados),ax.XTickLabel=[];end;end
rotular_layout(t,g);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_parametros_distribucion(corridas,grupos,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,'parametros_distribucion');if ~g.activa,return;end;etiquetas={'X (mm)','Y (mm)','Z (mm)','Rotación 1 (°)','Rotación 2 (°)'};f=figura_nueva(cfg,g);t=tiledlayout(f,2,3,'TileSpacing','compact','Padding','compact');hay=false;
for p=1:5,ax=nexttile(t);hold(ax,'on');for i=1:numel(grupos),c=corridas([corridas.antenas]==grupos(i));x=arrayfun(@(r)r.posicion(p),c);if p>3,x=rad2deg(x);end;x=x(isfinite(x));if isempty(x),continue;end;boxchart(ax,i*ones(numel(x),1),x(:),'BoxFaceColor',color_antena(cfg,grupos(i)));hay=true;end;title(ax,etiquetas{p});xticks(ax,1:numel(grupos));xticklabels(ax,arrayfun(@etiqueta_antenas,grupos,'UniformOutput',false));grid(ax,'on');end
if ~hay,close(f);return;end;title(t,g.titulo);estilo_layout(t,g);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_mejor_medio(corridas,grupos,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,'fitness_mejor_medio');if ~g.activa,return;end;f=figura_nueva(cfg,g);t=tiledlayout(f,numel(grupos),1,'TileSpacing','compact','Padding','compact');hay=false;
for i=1:numel(grupos),ax=nexttile(t);hold(ax,'on');c=corridas([corridas.antenas]==grupos(i));c=c(arrayfun(@(x)~isempty(traza_combinada(x,'fitness_medio')),c));if isempty(c),continue;end;v=arrayfun(@fitness_primario,c);[~,j]=min(v);mejor=traza_combinada(c(j),'mejor_fitness');medio=traza_combinada(c(j),'fitness_medio');plot(ax,mejor,'Color',color_antena(cfg,grupos(i)),'LineWidth',g.ancho_linea,'DisplayName','Mejor');plot(ax,medio,'--','Color',aclarar(color_antena(cfg,grupos(i)),.35),'LineWidth',g.ancho_secundario,'DisplayName','Media del enjambre');title(ax,sprintf('%s %s',panel_cfg(g,i),etiqueta_antenas(grupos(i))));legend(ax,'Location',g.ubicacion_leyenda);grid(ax,'on');hay=true;end
if ~hay,close(f);return;end;rotular_layout(t,g);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_posiciones(corridas,grupos,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,'posiciones_3d');if ~g.activa,return;end;f=figura_nueva(cfg,g);ax=axes(f);hold(ax,'on');hay=false;
for i=1:numel(grupos),P=vertcat(corridas([corridas.antenas]==grupos(i)).posicion);v=all(isfinite(P(:,1:3)),2);if ~any(v),continue;end;scatter3(ax,P(v,1),P(v,2),P(v,3),g.tamano_marcador,color_antena(cfg,grupos(i)),'filled','DisplayName',etiqueta_antenas(grupos(i)));hay=true;end
if ~hay,close(f);return;end;zlabel(ax,g.z_etiqueta);view(ax,g.azimut,g.elevacion);axis(ax,'equal');set(ax,'Projection',g.proyeccion);rotular(ax,g,g.titulo);legend(ax,'Location',g.ubicacion_leyenda);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_dispersion(corridas,grupos,campo_x,campo_y,id,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,id);if ~g.activa,return;end;f=figura_nueva(cfg,g);ax=axes(f);hold(ax,'on');hay=false;
for i=1:numel(grupos),c=corridas([corridas.antenas]==grupos(i));x=arrayfun(@(r)valor_corrida(r,campo_x),c);y=arrayfun(@(r)valor_corrida(r,campo_y),c);v=isfinite(x)&isfinite(y);if ~any(v),continue;end;scatter(ax,x(v),y(v),g.tamano_marcador,color_antena(cfg,grupos(i)),'filled','DisplayName',etiqueta_antenas(grupos(i)));hay=true;end
if ~hay,close(f);return;end;rotular(ax,g,g.titulo);legend(ax,'Location',g.ubicacion_leyenda);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_correlaciones(corridas,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,'correlaciones');if ~g.activa,return;end
X=[[corridas.fitness_fino]' [corridas.fitness_pso]' [corridas.tiempo_total_s]' [corridas.cobertura_pct]' [corridas.exterior_pct]' [corridas.auc_normalizada]' vertcat(corridas.posicion) [corridas.potencia_w]' [corridas.tiempo_tratamiento_min]'];
etiquetas={'Fitness fino','Fitness PSO','Tiempo','Cobertura','Exterior','AUC','X','Y','Z','Rot. 1','Rot. 2','Potencia','T. tratamiento'};validas=sum(isfinite(X),1)>=2;
for j=find(validas),validas(j)=std(X(isfinite(X(:,j)),j),0)>0;end;X=X(:,validas);etiquetas=etiquetas(validas);if size(X,2)<2,return;end
C=corrcoef(X,'Rows','pairwise');f=figura_nueva(cfg,g);ax=axes(f);imagesc(ax,C);axis(ax,'equal','tight');clim(ax,[-1 1]);colormap(ax,g.mapa_color);cb=colorbar(ax);cb.Label.String='Correlación de Pearson';xticks(ax,1:numel(etiquetas));yticks(ax,1:numel(etiquetas));xticklabels(ax,etiquetas);yticklabels(ax,etiquetas);xtickangle(ax,45);title(ax,g.titulo);
if numel(etiquetas)<=10,for i=1:size(C,1),for j=1:size(C,2),text(ax,j,i,sprintf('%.2f',C(i,j)),'HorizontalAlignment','center','Color',g.color_texto);end,end,end
guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_espacial(corridas,grupos,mejor,carpetas,prefijo,cfg)
if mejor,id='mejor_espacial';else,id='peor_espacial';end;g=obtener_grafica(cfg,id);if ~g.activa,return;end;seleccionados=repmat(plantilla_corrida(),0,1);
for n=grupos,c=corridas([corridas.antenas]==n);c=c(arrayfun(@(r)size(r.vertices_tumor,2)==3&&size(r.caras_tumor,2)==3&&all(isfinite(r.posicion)),c));if isempty(c),continue;end;v=arrayfun(@fitness_primario,c);if mejor,[~,i]=min(v);else,[~,i]=max(v);end;seleccionados(end+1)=c(i);end 
if isempty(seleccionados),return;end;f=figura_nueva(cfg,g);t=tiledlayout(f,1,numel(seleccionados),'TileSpacing','compact','Padding','compact');
for i=1:numel(seleccionados),r=seleccionados(i);ax=nexttile(t);hold(ax,'on');patch(ax,'Faces',r.caras_tumor,'Vertices',r.vertices_tumor,'FaceColor',[.72 .72 .72],'EdgeColor','none','FaceAlpha',g.alpha_superficie,'DisplayName','Tejido');[puntas,R]=transformar_puntos(r.coordenadas_antenas,r.posicion,r.ejes_a_rotar);if isempty(puntas),[puntas,R]=transformar_puntos([0 0 0],r.posicion,r.ejes_a_rotar);end;direccion=R*[0;0;1];extension=max(range(r.vertices_tumor,1),[],'all')*.35;if ~isfinite(extension)||extension<=0,extension=20;end;for a=1:size(puntas,1),fin=puntas(a,:)+extension*direccion.';plot3(ax,[puntas(a,1) fin(1)],[puntas(a,2) fin(2)],[puntas(a,3) fin(3)],'-','Color',color_antena(cfg,r.antenas),'LineWidth',g.ancho_linea,'DisplayName',condicional(a==1,'Antena',''));scatter3(ax,puntas(a,1),puntas(a,2),puntas(a,3),g.tamano_marcador,color_antena(cfg,r.antenas),'filled','HandleVisibility','off');end;axis(ax,'equal');view(ax,g.azimut,g.elevacion);set(ax,'Projection',g.proyeccion);xlabel(ax,g.x_etiqueta);ylabel(ax,g.y_etiqueta);zlabel(ax,g.z_etiqueta);title(ax,sprintf('%s\nfitness = %.5g',etiqueta_antenas(r.antenas),fitness_primario(r)));grid(ax,'on');end
title(t,g.titulo);estilo_layout(t,g);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function graficar_respuesta(corridas,grupos,carpetas,prefijo,cfg)
g=obtener_grafica(cfg,'respuesta_potencia_tiempo');if ~g.activa,return;end;f=figura_nueva(cfg,g);ax=axes(f);hold(ax,'on');hay=false;
for i=1:numel(grupos),c=corridas([corridas.antenas]==grupos(i));x=[c.potencia_w];y=[c.tiempo_tratamiento_min];z=[c.fitness_fino];v=isfinite(x)&isfinite(y)&isfinite(z);if ~any(v),continue;end;scatter3(ax,x(v),y(v),z(v),g.tamano_marcador,color_antena(cfg,grupos(i)),'filled','DisplayName',etiqueta_antenas(grupos(i)));hay=true;end
if ~hay,close(f);return;end;zlabel(ax,g.z_etiqueta);view(ax,g.azimut,g.elevacion);set(ax,'Projection',g.proyeccion);rotular(ax,g,g.titulo);legend(ax,'Location',g.ubicacion_leyenda);guardar_figura(f,carpetas,nombre_salida(prefijo,g,''),cfg,g);
end

function g=entrada_grafica(base,id,activa,archivo,titulo,x_etiqueta,y_etiqueta)
g=base;g.id=id;g.activa=activa;g.archivo=archivo;g.titulo=titulo;g.x_etiqueta=x_etiqueta;g.y_etiqueta=y_etiqueta;g.z_etiqueta='';
end

function g=obtener_grafica(cfg,id)
i=find(strcmp({cfg.graficas.id},id),1);assert(~isempty(i),'Gráfica desconocida: %s',id);g=cfg.graficas(i);
end

function f=figura_nueva(cfg,g)
visible='off';if cfg.mostrar_figuras,visible='on';end;f=figure('Visible',visible,'Name',g.titulo,'Color',g.fondo,'Position',g.posicion);
end

function rotular(ax,g,titulo_grafica)
xlabel(ax,g.x_etiqueta);ylabel(ax,g.y_etiqueta);title(ax,titulo_grafica);grid(ax,'on');
end

function rotular_layout(t,g)
xlabel(t,g.x_etiqueta);ylabel(t,g.y_etiqueta);title(t,g.titulo);estilo_layout(t,g);
end

function nombre=nombre_salida(prefijo,g,sufijo),nombre=sprintf('%s_%s%s',prefijo,g.archivo,sufijo);end

function guardar_figura(f,carpetas,nombre,cfg,g)
aplicar_estilo(f,g);
if cfg.guardar_png,exportgraphics(f,fullfile(carpetas.png,[nombre '.png']),'Resolution',cfg.resolucion_dpi,'BackgroundColor',g.fondo);end
if cfg.guardar_tiff,exportgraphics(f,fullfile(carpetas.tiff,[nombre '.tiff']),'Resolution',cfg.resolucion_dpi,'BackgroundColor',g.fondo);end
if cfg.guardar_eps,exportgraphics(f,fullfile(carpetas.eps,[nombre '.eps']),'ContentType','vector','BackgroundColor',g.fondo);end
if cfg.guardar_fig,savefig(f,fullfile(carpetas.fig,[nombre '.fig']));end
if cfg.cerrar_figuras,close(f);end
end

function aplicar_estilo(f,g)
f.Color=g.fondo;ejes=findall(f,'Type','axes');for k=1:numel(ejes),estilo_ejes(ejes(k),g);end
textos=findall(f,'Type','text');for k=1:numel(textos),textos(k).Color=g.color_texto;textos(k).FontName=g.fuente;end
leyendas=findall(f,'Type','legend');for k=1:numel(leyendas),leyendas(k).Color=g.fondo;leyendas(k).TextColor=g.color_texto;leyendas(k).EdgeColor=g.color_rejilla;leyendas(k).FontName=g.fuente;leyendas(k).FontSize=g.tamano_leyenda;end
colorbars=findall(f,'Type','colorbar');for k=1:numel(colorbars),colorbars(k).Color=g.color_texto;colorbars(k).FontName=g.fuente;end
end

function estilo_ejes(ax,g)
ax.Color=g.fondo;ax.XColor=g.color_texto;ax.YColor=g.color_texto;if isprop(ax,'ZColor'),ax.ZColor=g.color_texto;end
ax.GridColor=g.color_rejilla;ax.GridAlpha=g.alpha_rejilla;ax.FontName=g.fuente;ax.FontSize=g.tamano_ejes;ax.LineWidth=g.ancho_ejes;box(ax,'on');
ax.Title.FontSize=g.tamano_titulo;ax.XLabel.FontSize=g.tamano_etiquetas;ax.YLabel.FontSize=g.tamano_etiquetas;if isprop(ax,'ZLabel'),ax.ZLabel.FontSize=g.tamano_etiquetas;end
end

function estilo_layout(t,g)
t.Title.Color=g.color_texto;t.XLabel.Color=g.color_texto;t.YLabel.Color=g.color_texto;t.Title.FontName=g.fuente;t.XLabel.FontName=g.fuente;t.YLabel.FontName=g.fuente;t.Title.FontSize=g.tamano_titulo;t.XLabel.FontSize=g.tamano_etiquetas;t.YLabel.FontSize=g.tamano_etiquetas;
end

function tabla=tabla_historial_crudo(corridas)
tabla=table();
for k=1:numel(corridas)
    mejor=traza_combinada(corridas(k),'mejor_fitness');if isempty(mejor),mejor=corridas(k).historia;end
    medio=traza_combinada(corridas(k),'fitness_medio');evaluaciones=traza_combinada(corridas(k),'evaluaciones');
    estancamiento=traza_combinada(corridas(k),'estancamiento');tiempo=traza_combinada(corridas(k),'tiempo_iteracion_s');
    n=max([numel(mejor) numel(medio) numel(evaluaciones) numel(estancamiento) numel(tiempo)]);if n==0,continue;end
    n1=max(numel(corridas(k).historia_f1),numel(corridas(k).traza_f1.mejor_fitness));n1=min(n1,n);
    fase=[repmat("F1",n1,1);repmat("F2",n-n1,1)];iteracion_fase=[(1:n1)';(1:n-n1)'];
    id=string(corridas(k).id_estadistico);if strlength(id)==0,id=string(corridas(k).id_corrida);end
    bloque=table(repmat(id,n,1),repmat(k,n,1),repmat(corridas(k).antenas,n,1),fase,(1:n)',iteracion_fase, ...
        ajustar_vector(mejor,n),ajustar_vector(medio,n),ajustar_vector(evaluaciones,n), ...
        ajustar_vector(estancamiento,n),ajustar_vector(tiempo,n), ...
        'VariableNames',{'IdCorrida','IndiceCorrida','Antenas','Fase','IteracionGlobal','IteracionFase', ...
        'MejorFitness','FitnessMedio','Evaluaciones','Estancamiento','TiempoIteracion_s'});
    tabla=[tabla;bloque]; 
end
end

function v=ajustar_vector(v,n)
v=double(v(:));v(end+1:n,1)=NaN;v=v(1:n);
end

function M=matriz_campo_vectores(corridas,campo)
longitudes=arrayfun(@(c)numel(c.(campo)),corridas);maximo=max([longitudes(:);0]);if maximo==0,M=zeros(0,0);return;end
M=nan(numel(corridas),maximo);for k=1:numel(corridas),v=corridas(k).(campo)(:).';M(k,1:numel(v))=v;end
end

function M=matriz_trazas(corridas,campo)
vectores=cell(numel(corridas),1);for k=1:numel(corridas),vectores{k}=traza_combinada(corridas(k),campo);end
maximo=max([cellfun(@numel,vectores);0]);if maximo==0,M=zeros(0,0);return;end
M=nan(numel(corridas),maximo);for k=1:numel(vectores),M(k,1:numel(vectores{k}))=vectores{k};end
end

function v=traza_combinada(c,campo)
v1=c.traza_f1.(campo);v2=c.traza_f2.(campo);
if strcmp(campo,'evaluaciones')&&~isempty(v1)&&~isempty(v2),v2=v2+v1(end);end
v=[v1(:);v2(:)];
end

function valor=valor_corrida(c,campo)
switch campo
    case 'posicion_4',valor=rad2deg(c.posicion(4));
    case 'posicion_5',valor=rad2deg(c.posicion(5));
    otherwise
        if isfield(c,campo)&&isnumeric(c.(campo))&&isscalar(c.(campo)),valor=double(c.(campo));else,valor=NaN;end
end
end

function color=color_antena(cfg,n)
i=round(n);if ~isfinite(i)||i<1,i=1;end;i=mod(i-1,size(cfg.colores_antenas,1))+1;color=cfg.colores_antenas(i,:);
end

function texto=panel_cfg(g,i)
if i<=numel(g.etiquetas_panel),texto=g.etiquetas_panel{i};else,texto=panel(i);end
end

function [salida,R]=transformar_puntos(puntos,posicion,ejes)
if isempty(puntos),puntos=zeros(0,3);end;if size(puntos,2)<3,puntos(:,end+1:3)=0;end
rx=0;ry=0;rz=0;angulos=posicion(4:5);ejes=double(ejes(:).');if numel(ejes)<2,ejes=[1 2];end
for k=1:2,if ejes(k)==1,rx=angulos(k);elseif ejes(k)==2,ry=angulos(k);else,rz=angulos(k);end,end
Rx=[1 0 0;0 cos(rx) -sin(rx);0 sin(rx) cos(rx)];Ry=[cos(ry) 0 sin(ry);0 1 0;-sin(ry) 0 cos(ry)];Rz=[cos(rz) -sin(rz) 0;sin(rz) cos(rz) 0;0 0 1];R=Rz*Ry*Rx;
salida=(R*puntos(:,1:3).').' + posicion(1:3);
end

function valor=condicional(condicion,si,no),if condicion,valor=si;else,valor=no;end,end

function M=matriz_historias(corridas)
longitudes=arrayfun(@(c)numel(c.historia),corridas);maximo=max([longitudes(:);0]);
if maximo==0,M=zeros(0,0);return;end
M=nan(numel(corridas),maximo);for k=1:numel(corridas),h=corridas(k).historia(:).';M(k,1:numel(h))=h;end
end

function a=auc_normalizada(h)
h=h(:);h=h(isfinite(h));if isempty(h),a=NaN;return;end
if isscalar(h),a=1;return;end
den=h(1)-h(end);if abs(den)<=eps(max(1,abs(h(1)))),a=1;else,a=trapz((h(1)-h)./den)/(numel(h)-1);end
end

function hit=primer_impacto(h,objetivo)
hit=NaN;idx=find(isfinite(h)&h<=objetivo,1,'first');if ~isempty(idx),hit=idx;end
end

function valor=fitness_primario(c)
valor=c.fitness_fino;if ~isfinite(valor),valor=c.fitness_pso;end
if ~isfinite(valor),valor=c.fitness_convergencia_final;end
end

function [mlo,mhi,medlo,medhi]=intervalos_bootstrap(x)
x=x(isfinite(x));if numel(x)<2,mlo=NaN;mhi=NaN;medlo=NaN;medhi=NaN;return;end
estado=rng;limpieza=onCleanup(@()rng(estado));
rng(20260711);B=10000;muestras=x(randi(numel(x),numel(x),B));
qm=cuantiles(mean(muestras,1),[.025 .975]);qmed=cuantiles(median(muestras,1),[.025 .975]);
mlo=qm(1);mhi=qm(2);medlo=qmed(1);medhi=qmed(2);
end

function q=cuantiles(x,p)
x=sort(x(isfinite(x)));q=nan(size(p));if isempty(x),return;end
for k=1:numel(p),pos=1+(numel(x)-1)*p(k);lo=floor(pos);hi=ceil(pos);q(k)=x(lo)+(pos-lo)*(x(hi)-x(lo));end
end

function q=cuantil_columnas(X,p)
q=nan(1,size(X,2));for k=1:size(X,2),q(k)=cuantiles(X(:,k),p);end
end

function [H,p]=kruskal_wallis_manual(grupos)
x=vertcat(grupos{:});etiquetas=[];
for k=1:numel(grupos),etiquetas=[etiquetas;repmat(k,numel(grupos{k}),1)];end 
r=rangos_empates(x);N=numel(x);H=0;
for k=1:numel(grupos),rk=r(etiquetas==k);H=H+numel(rk)*mean(rk)^2;end
H=12*H/(N*(N+1))-3*(N+1);[~,~,ic]=unique(x);cuentas=accumarray(ic,1);
C=1-sum(cuentas.^3-cuentas)/(N^3-N);if C>0,H=H/C;end
p=gammainc(H/2,(numel(grupos)-1)/2,'upper');
end

function [U,p,z]=mann_whitney_manual(x,y)
x=x(:);y=y(:);n1=numel(x);n2=numel(y);todo=[x;y];r=rangos_empates(todo);
U1=sum(r(1:n1))-n1*(n1+1)/2;U=min(U1,n1*n2-U1);mu=n1*n2/2;[~,~,ic]=unique(todo);t=accumarray(ic,1);
varU=n1*n2/12*((n1+n2+1)-sum(t.^3-t)/((n1+n2)*(n1+n2-1)));
if varU<=0,z=0;p=1;else,z=(U1-mu)/sqrt(varU);p=erfc(abs(z)/sqrt(2));end
end

function r=rangos_empates(x)
[sx,orden]=sort(x);r=zeros(size(x));i=1;
while i<=numel(sx),j=i;while j<numel(sx)&&sx(j+1)==sx(i),j=j+1;end;r(orden(i:j))=(i+j)/2;i=j+1;end
end

function d=cliff_delta(x,y)
d=mean(sign(x(:)-y(:).'),'all');
end

function texto=magnitud_efecto(valor)
if valor<.147,texto="despreciable";elseif valor<.33,texto="pequeño";elseif valor<.474,texto="mediano";else,texto="grande";end
end

function valor=media_finita(x),x=x(isfinite(x));if isempty(x),valor=NaN;else,valor=mean(x);end,end
function valor=mediana_finita(x),x=x(isfinite(x));if isempty(x),valor=NaN;else,valor=median(x);end,end
function valor=varianza_finita(x),x=x(isfinite(x));if numel(x)<2,valor=NaN;else,valor=var(x,0);end,end
function valor=desviacion_finita(x),x=x(isfinite(x));if numel(x)<2,valor=NaN;else,valor=std(x,0);end,end
function valor=min_finito(x),x=x(isfinite(x));if isempty(x),valor=NaN;else,valor=min(x);end,end
function valor=max_finito(x),x=x(isfinite(x));if isempty(x),valor=NaN;else,valor=max(x);end,end
function valor=cv_finito(x),m=media_finita(x);s=desviacion_finita(x);if ~isfinite(m)||abs(m)<eps,valor=NaN;else,valor=100*s/abs(m);end,end
function valor=asimetria_finita(x),x=x(isfinite(x));if numel(x)<3||std(x,1)==0,valor=NaN;else,z=(x-mean(x))/std(x,1);valor=mean(z.^3);end,end
function valor=curtosis_finita(x),x=x(isfinite(x));if numel(x)<4||std(x,1)==0,valor=NaN;else,z=(x-mean(x))/std(x,1);valor=mean(z.^4)-3;end,end

function n=numero_antenas(p)
n=campo_numerico(p,'numero_antenas');if isfinite(n),return;end
texto=campo_texto(p,'numero_antenas');token=regexp(texto,'\d+','match','once');if isempty(token),n=NaN;else,n=str2double(token);end
end

function v=numero_flexible(s,campo)
v=campo_numerico(s,campo);if isfinite(v),return;end
texto=campo_texto(s,campo);token=regexp(texto,'[-+]?\d+(?:[.,]\d+)?','match','once');
if isempty(token),v=NaN;else,v=str2double(strrep(token,',','.'));end
end

function v=campo_numerico(s,campo)
v=NaN;if isstruct(s)&&isfield(s,campo)&&isnumeric(s.(campo))&&isscalar(s.(campo))&&isfinite(double(s.(campo))),v=double(s.(campo));end
end

function texto=campo_texto(s,campo)
texto='';if isstruct(s)&&isfield(s,campo)&&~isempty(s.(campo)),texto=char(string(s.(campo)));end
end

function texto=campo_texto_preferido(s,campo,respaldo)
texto=campo_texto(s,campo);if isempty(texto),texto=respaldo;end
end

function s=campo_struct(origen,campo)
s=struct();if isstruct(origen)&&isfield(origen,campo)&&isstruct(origen.(campo)),s=origen.(campo);end
end

function v=vector_numerico(s,campo)
v=zeros(0,1);if isstruct(s)&&isfield(s,campo)&&isnumeric(s.(campo)),v=double(s.(campo)(:));end
end

function texto=etiqueta_antenas(n)
if n==1,texto='1 antena';else,texto=sprintf('%d antenas',round(n));end
end

function texto=panel(i)
letras='ABCDEFGHIJKLMNOPQRSTUVWXYZ';if i<=numel(letras),texto=sprintf('%c)',letras(i));else,texto=sprintf('%d)',i);end
end

function c=aclarar(color,factor),c=color+(1-color)*factor;end
function crear_carpeta(carpeta),if ~isfolder(carpeta),mkdir(carpeta);end,end

function ejecutar_selftest(cfg)
p=struct('numero_antenas','2ant','tipo_antena','Monopolo','caso','Caso_1', ...
    'potencia','Potencia_30W','tiempo_ejecucion','t15','distribucion_termica','demo','fitness_fino',-12, ...
    'fitness_pso',-11,'porcentaje_interior',90,'porcentaje_exterior',8, ...
    'volumen_tumor',100,'volumen_distribucion_termica',90,'volumen_exterior',8, ...
    'posicion',[1 2 3 .1 .2],'coordenadas_antenas',[0 0 0;2 0 0],'metodo_voxel','sdf');
c=struct('id',1,'timestamp','2026-08-07 12:00:00','parametros',p, ...
    'historia_pso',[10;9],'historia_f1',[10;8],'historia_f2',[7;6], ...
    'tiempo_total',4,'vertices_tumor',[0 0 0;4 0 0;0 4 0;0 0 4], ...
    'caras_tumor',[1 2 3;1 2 4;1 3 4;2 3 4],'ejes_a_rotar',[1 2],'incluir_estadisticas',true);
t=traza_vacia();t.mejor_posicion=[1 2 3 .1 .2;2 3 4 .2 .3];t.mejor_fitness=[10;8];
t.fitness_medio=[12;9];t.evaluaciones=[20;40];t.estancamiento=[0;1];t.tiempo_iteracion_s=[.1;.2];
c.estadisticas_pso=struct('id_estadistico','demo-1','firma_geometria','geom-demo', ...
    'metodo_voxel','sdf','resolucion_fina_mm',.5,'resolucion_gruesa_mm',1.5, ...
    'traza_fase_1',t,'traza_fase_2',t,'filtros_activos',struct(),'criterio_fitness',struct());
r1=normalizar_corrida(c,'demo.mat',false);assert(isequal(r1.historia,[10;8;7;6]));
assert(r1.antenas==2&&size(r1.traza_f1.mejor_posicion,2)==5);
c2=c;c2.id=2;c2.timestamp='2026-08-07 12:01:00';c2.estadisticas_pso.id_estadistico='demo-2';
c2.parametros.fitness_fino=-14;c2.historia_f1=[11;9];c2.historia_f2=[8;5];
r2=normalizar_corrida(c2,'demo2.mat',false);
[unicas,duplicadas]=deduplicar_corridas([r1;r1;r2]);assert(numel(unicas)==2&&duplicadas==1);
c3=c;c3.id=3;c3.timestamp='2026-08-07 12:02:00';c3.parametros.numero_antenas='3ant';c3.parametros.potencia='35W';
c3.parametros.tiempo_ejecucion='20min';c3.parametros.fitness_fino=-10;c3.parametros.posicion=[3 4 5 .2 .3];
c3.parametros.coordenadas_antenas=[0 0 0;2 0 0;0 2 0];c3.estadisticas_pso.id_estadistico='demo-3';
r3=normalizar_corrida(c3,'demo3.mat',false);c4=c3;c4.id=4;c4.timestamp='2026-08-07 12:03:00';
c4.parametros.fitness_fino=-16;c4.parametros.potencia='40W';c4.parametros.tiempo_ejecucion='25min';c4.estadisticas_pso.id_estadistico='demo-4';
r4=normalizar_corrida(c4,'demo4.mat',false);
[analizadas,tc,tg,ti,~,~]=analizar_cohorte([r1;r2;r3;r4]);assert(height(tc)==4&&height(tg)==2&&height(ti)==8);
assert(height(tabla_historial_crudo(analizadas))==16);
cfg.guardar_png=false;cfg.guardar_tiff=false;cfg.guardar_fig=false;cfg.guardar_eps=false;cfg.mostrar_figuras=false;cfg.cerrar_figuras=true;
carpetas=struct('png','','fig','','tiff','','eps','');generar_graficas(analizadas,ti,tg,carpetas,'selftest',cfg);
c.incluir_estadisticas=false;[incluir,legacy]=debe_incluir_corrida(c);assert(~incluir&&~legacy);
c=rmfield(c,'incluir_estadisticas');[incluir,legacy]=debe_incluir_corrida(c);assert(incluir&&legacy);
fprintf('SELFTEST_GRAFICADOR_ESTADISTICO_OK\n');
end
