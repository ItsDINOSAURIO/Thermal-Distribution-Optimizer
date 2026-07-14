function preprocesar_stl_a_mat(varargin)
% =========================================================================
%  PREPROCESAMIENTO STL A REPRESENTACIÓN VOLUMÉTRICA .MAT
% =========================================================================
%
%  FUNCIONALIDAD
%  Convierte archivos STL de distribuciones térmicas en archivos .mat para
%  uso posterior en optimización espacial. El usuario selecciona una carpeta,
%  una resolución de voxelizado y un método de representación volumétrica.
%
%  MÉTODOS SOPORTADOS
%  - mascara : ocupación binaria del volumen.
%  - sdf     : campo de distancia con signo.
%  - tsdf    : campo de distancia con signo truncado.
%
%  CONVENCIONES
%  - Las geometrías se centran respecto a su centroide antes de voxelizar.
%  - Se conserva el filtrado original de distribuciones tempranas consideradas
%    no útiles para optimización.
%  - Requiere inpolyhedron para la prueba punto-en-poliedro.
% =========================================================================
    % Permite ejecutar el modulo desde el launcher o directamente.
    carpeta_modulo = fileparts(mfilename('fullpath'));
    candidatos_aux = {fullfile(carpeta_modulo, '..', 'Aux_Codes'), ...
        fullfile(carpeta_modulo, '..', '..', 'Aux_Codes')};
    for k_aux = 1:numel(candidatos_aux)
        if isfolder(candidatos_aux{k_aux}), addpath(candidatos_aux{k_aux}); end
    end
    if exist('tesis_auxiliares', 'file') == 2
        tesis_auxiliares('configurar_paths', carpeta_modulo);
    end

    if nargin == 0
        lanzar_ui_preprocesar_stl_a_mat();
        return;
    end

    clc;
    config = struct();
    if nargin >= 2 && strcmpi(varargin{1}, 'run')
        config = varargin{2};
    end
    configurar_log_preprocesador(obtener_campo_config_local(config, 'logfn', []));
    limpieza_logger = onCleanup(@() configurar_log_preprocesador([]));

    if isfield(config, 'carpeta_stl') && ~isempty(config.carpeta_stl)
        carpeta_stl = config.carpeta_stl;
    else
        data_paths = tesis_auxiliares('asegurar_dataset_paths');
        carpeta_stl = uigetdir(data_paths.distribuciones_stl, ...
            'Selecciona la carpeta raiz con archivos STL');
        if isequal(carpeta_stl, 0)
            log_preprocesador('Proceso cancelado por el usuario.\n');
            return;
        end
    end

    if isfield(config, 'resolucion') && ~isempty(config.resolucion)
        resolucion = config.resolucion;
    else
        resolucion = input('Introduce la resolución de voxelizado en mm, por ejemplo 0.5: ');
    end
    if isempty(resolucion) || ~isnumeric(resolucion) || resolucion <= 0
        error('La resolución debe ser un número positivo.');
    end

    if isfield(config, 'tipo_procesamiento') && ~isempty(config.tipo_procesamiento)
        tipo_procesamiento = config.tipo_procesamiento;
    else
        tipo_procesamiento = seleccionar_tipo_procesamiento();
    end
    archivos_stl = dir(fullfile(carpeta_stl, '**', '*.stl'));
    if isempty(archivos_stl)
        error('No se encontraron archivos .stl en la carpeta especificada.');
    end

    log_preprocesador('Procesando %d distribuciones térmicas...\n', numel(archivos_stl));

    carpeta_salida = obtener_carpeta_salida_mat(carpeta_stl, config);
    if ~exist(carpeta_salida, 'dir')
        mkdir(carpeta_salida);
    end

    n_procesados = 0;
    n_omitidos_metadata = 0;
    n_omitidos_filtro = 0;
    n_descartados_tiempo = 0;
    n_existentes = 0;
    filtro_metadata = obtener_campo_config_local(config, 'filtro_metadata', struct());

    for indice_archivo = 1:numel(archivos_stl)
        archivo_actual = archivos_stl(indice_archivo);
        ruta_stl = fullfile(archivo_actual.folder, archivo_actual.name);
        ruta_relativa = erase(ruta_stl, [carpeta_stl filesep]);
        [subcarpeta, nombre_base, ~] = fileparts(ruta_relativa);

        [ruta_util, motivo_metadata] = ruta_stl_tiene_metadata_util(ruta_relativa);
        if ~ruta_util
            n_omitidos_metadata = n_omitidos_metadata + 1;
            log_preprocesador('Distribucion %d/%d: %s ... Omitida: %s.\n', ...
                indice_archivo, numel(archivos_stl), ruta_relativa, motivo_metadata);
            continue;
        end

        if ~ruta_stl_pasa_filtro_metadata_preprocesador(ruta_relativa, filtro_metadata)
            n_omitidos_filtro = n_omitidos_filtro + 1;
            continue;
        end

        if debe_descartarse_por_tiempo_temprano(ruta_relativa, nombre_base)
            n_descartados_tiempo = n_descartados_tiempo + 1;
            log_preprocesador('Distribución %d/%d: %s ... Descartada.\n', ...
                indice_archivo, numel(archivos_stl), ruta_relativa);
            continue;
        end

        carpeta_destino = fullfile(carpeta_salida, subcarpeta);
        if ~exist(carpeta_destino, 'dir')
            mkdir(carpeta_destino);
        end

        ruta_salida = fullfile(carpeta_destino, ...
            sprintf('%s_%s_res%.2f.mat', nombre_base, tipo_procesamiento, resolucion));
        ruta_done = [ruta_salida '.done'];
        firma_preprocesamiento = crear_firma_preprocesamiento_stl( ...
            ruta_stl, tipo_procesamiento, resolucion);

        if checkpoint_preprocesamiento_vigente(ruta_salida, ruta_done, firma_preprocesamiento)
            n_existentes = n_existentes + 1;
            log_preprocesador('Distribucion %d/%d: %s ... Ya existe vigente, omitiendo.\n', ...
                indice_archivo, numel(archivos_stl), ruta_relativa);
            continue;
        end
        if isfile(ruta_salida)
            log_preprocesador('Distribucion %d/%d: %s ... Existe sin checkpoint vigente, se regenerara.\n', ...
                indice_archivo, numel(archivos_stl), ruta_relativa);
        end

        log_preprocesador('Distribución %d/%d: %s ...', ...
            indice_archivo, numel(archivos_stl), ruta_relativa);
        tic;

        [vertices, caras] = leer_stl_binario(ruta_stl);
        centro = mean(vertices, 1);
        vertices_centrados = vertices - centro;

        [grid_x, grid_y, grid_z] = crear_rejilla(vertices_centrados, resolucion);
        forma.vertices = vertices_centrados;
        forma.faces = caras;

        guardar_representacion_volumetrica( ...
            ruta_salida, tipo_procesamiento, forma, grid_x, grid_y, grid_z, centro, resolucion);
        escribir_checkpoint_preprocesamiento(ruta_done, firma_preprocesamiento);
        n_procesados = n_procesados + 1;
        log_preprocesador('  tiempo: %.2f s | salida: %s\n', toc, ruta_salida);
    end

    log_preprocesador(['Resumen preprocesamiento: procesados=%d | existentes=%d | ', ...
        'omitidos_metadata=%d | omitidos_filtro=%d | descartados_tiempo=%d\n'], ...
        n_procesados, n_existentes, n_omitidos_metadata, ...
        n_omitidos_filtro, n_descartados_tiempo);
    log_preprocesador('Procesamiento completado. Archivos guardados en: %s\n', carpeta_salida);
end

function lanzar_ui_preprocesar_stl_a_mat()
    entradas = struct( ...
        'key', {'carpeta_stl', 'tipo_procesamiento', 'resolucion'}, ...
        'label', {'carpeta raiz STL', 'Tipo de preprocesamiento', 'Resolucion voxel (mm)'}, ...
        'kind', {'folder', 'choice', 'numeric'}, ...
        'filter', {'*.*', '', ''}, ...
        'title', {'Selecciona la carpeta raiz con archivos STL', '', ''}, ...
        'default', {'', 'sdf', 0.5}, ...
        'items', {{}, {'sdf', 'mascara', 'tsdf'}, {}}, ...
        'limits', {[], [], [eps Inf]});

    tesis_auxiliares('crear_dashboard_modulo',  ...
        'Preprocesar STL a MAT', ...
        'Convierte STL de distribuciones termicas a volumenes MAT para optimizacion.', ...
        entradas, ...
        @ejecutar_desde_ui);

    function ejecutar_desde_ui(valores, logfn)
        if isempty(valores.carpeta_stl)
            error('Seleccione primero la carpeta raiz STL.');
        end
        if ~isfinite(valores.resolucion) || valores.resolucion <= 0
            error('La resolucion debe ser positiva.');
        end
        config = valores;
        config.logfn = logfn;
        logfn('Resolucion: %.2f mm.', config.resolucion);
        logfn('Metodo seleccionado: %s.', config.tipo_procesamiento);
        preprocesar_stl_a_mat('run', config);
    end
end

function tipo_procesamiento = seleccionar_tipo_procesamiento()
    log_preprocesador(['Seleccione el método deseado:\n', ...
             '1. sdf\n', ...
             '2. mascara\n', ...
             '3. tsdf\n']);
    opcion = input('Opción: ');

    switch opcion
        case 1
            tipo_procesamiento = 'sdf';
        case 2
            tipo_procesamiento = 'mascara';
        case 3
            tipo_procesamiento = 'tsdf';
        otherwise
            error('Seleccione una opción válida del 1 al 3.');
    end
end

function [es_util, motivo] = ruta_stl_tiene_metadata_util(ruta_relativa)
    ruta = lower(strrep(char(ruta_relativa), '\', '/'));
    es_util = false;

    tiene_tipo = contains(ruta, 'monopolo') || contains(ruta, 'doble_slot') || contains(ruta, 'un_slot');
    if ~tiene_tipo
        motivo = 'sin tipo de antena reconocible';
        return;
    end

    if isempty(regexp(ruta, '\d+ant', 'once'))
        motivo = 'sin numero de antenas reconocible';
        return;
    end

    if isempty(regexp(ruta, 'caso_?\d+', 'once'))
        motivo = 'sin carpeta Caso_X';
        return;
    end

    if isempty(regexp(ruta, 'potencia_?\d+w', 'once'))
        motivo = 'sin carpeta Potencia_YW';
        return;
    end

    if ~contains(ruta, 'geometria_ablacion')
        motivo = 'archivo STL no corresponde a geometria de ablacion';
        return;
    end

    es_util = true;
    motivo = 'metadata util';
end

function pasa = ruta_stl_pasa_filtro_metadata_preprocesador(ruta_relativa, filtro_metadata)
    pasa = true;
    if ~isstruct(filtro_metadata) || isempty(fieldnames(filtro_metadata))
        return;
    end

    ruta = lower(strrep(char(ruta_relativa), '\', '/'));
    if isfield(filtro_metadata, 'antena') && ~isempty(filtro_metadata.antena)
        antena = lower(char(filtro_metadata.antena));
        pasa = pasa && ~isempty(regexp(ruta, ['(^|/)' regexptranslate('escape', antena) '(/|$)'], 'once'));
    end
    if isfield(filtro_metadata, 'caso') && ~isempty(filtro_metadata.caso)
        caso_num = regexprep(lower(char(filtro_metadata.caso)), '^c', '');
        pasa = pasa && contains(ruta, ['caso_' caso_num]);
    end
    if isfield(filtro_metadata, 'potencia') && ~isempty(filtro_metadata.potencia)
        potencia_num = regexprep(lower(char(filtro_metadata.potencia)), '^p', '');
        pasa = pasa && contains(ruta, ['potencia_' potencia_num 'w']);
    end
end

function descartar = debe_descartarse_por_tiempo_temprano(ruta_relativa, nombre_base)
    descartar = false;

    es_potencia_10w = contains(ruta_relativa, 'Potencia_10W');
    es_potencia_5w  = contains(ruta_relativa, 'Potencia_5W');

    tiene_1_antena = contains(ruta_relativa, '1ant');
    tiene_2_antenas = contains(ruta_relativa, '2ant');
    tiene_3_antenas = contains(ruta_relativa, '3ant');
    tiene_4_antenas = contains(ruta_relativa, '4ant');

    es_t1 = contains(nombre_base, 't1min');
    es_t2 = contains(nombre_base, 't2min');
    es_t3 = contains(nombre_base, 't3min');

    if tiene_1_antena
        return;
    end

    if es_potencia_10w && es_t1
        descartar = true;
        return;
    end

    if es_potencia_5w
        if (tiene_2_antenas || tiene_3_antenas) && (es_t1 || es_t2)
            descartar = true;
        elseif tiene_4_antenas && (es_t1 || es_t2 || es_t3)
            descartar = true;
        end
    end
end

function [grid_x, grid_y, grid_z] = crear_rejilla(vertices, resolucion)
    limites_minimos = min(vertices, [], 1) - resolucion;
    limites_maximos = max(vertices, [], 1) + resolucion;

    [grid_x, grid_y, grid_z] = meshgrid( ...
        limites_minimos(1):resolucion:limites_maximos(1), ...
        limites_minimos(2):resolucion:limites_maximos(2), ...
        limites_minimos(3):resolucion:limites_maximos(3));
end

function guardar_representacion_volumetrica(ruta_salida, tipo_procesamiento, forma, grid_x, grid_y, grid_z, centro, resolucion)
    puntos_rejilla = [grid_x(:), grid_y(:), grid_z(:)];
    mascara = inpolyhedron(forma, puntos_rejilla);
    mascara = reshape(mascara, size(grid_x));

    % Alias de compatibilidad: el optimizador histórico espera gridX/gridY/gridZ.
    gridX = grid_x;
    gridY = grid_y;
    gridZ = grid_z;

    switch tipo_procesamiento
        case 'mascara'
            save(ruta_salida, 'mascara', 'grid_x', 'grid_y', 'grid_z', 'gridX', 'gridY', 'gridZ', 'centro', 'resolucion');
            log_preprocesador('  mascara guardada.\n');

        case 'sdf'
            sdf = (bwdist(mascara) - bwdist(~mascara)) * resolucion;
            save(ruta_salida, 'sdf', 'grid_x', 'grid_y', 'grid_z', 'gridX', 'gridY', 'gridZ', 'centro', 'resolucion');
            log_preprocesador('  SDF guardada.\n');

        case 'tsdf'
            sdf = (bwdist(mascara) - bwdist(~mascara)) * resolucion;
            distancia_truncamiento = 2 * resolucion;
            truncDist = distancia_truncamiento;
            tsdf = max(-distancia_truncamiento, min(distancia_truncamiento, sdf));
            save(ruta_salida, 'tsdf', 'grid_x', 'grid_y', 'grid_z', 'gridX', 'gridY', 'gridZ', ...
                'centro', 'resolucion', 'distancia_truncamiento', 'truncDist');
            log_preprocesador('  TSDF guardada.\n');
    end
end

function firma = crear_firma_preprocesamiento_stl(ruta_stl, tipo_procesamiento, resolucion)
    info = dir(ruta_stl);
    if isempty(info)
        [~, nombre_archivo, extension] = fileparts(ruta_stl);
        nombre = [nombre_archivo extension];
        bytes = NaN;
        fecha = NaN;
    else
        nombre = info(1).name;
        bytes = info(1).bytes;
        fecha = info(1).datenum;
    end
    firma = sprintf('stl_preprocess_v2|archivo=%s|bytes=%d|datenum=%.12g|tipo=%s|res=%.10g', ...
        nombre, bytes, fecha, char(tipo_procesamiento), resolucion);
end

function vigente = checkpoint_preprocesamiento_vigente(ruta_mat, ruta_done, firma_esperada)
    vigente = false;
    if ~isfile(ruta_mat) || ~isfile(ruta_done)
        return;
    end
    try
        contenido = fileread(ruta_done);
        vigente = contains(contenido, firma_esperada);
    catch
        vigente = false;
    end
end

function escribir_checkpoint_preprocesamiento(ruta_done, firma_preprocesamiento)
    identificador = fopen(ruta_done, 'w');
    if identificador == -1
        log_preprocesador('  [WARN] No se pudo crear checkpoint: %s\n', ruta_done);
        return;
    end
    limpieza = onCleanup(@() fclose(identificador));
    fprintf(identificador, 'done=true\n');
    fprintf(identificador, 'created_at=%s\n', datestr(now));
    fprintf(identificador, 'signature=%s\n', firma_preprocesamiento);
    clear limpieza;
end

function carpeta_salida = obtener_carpeta_salida_mat(carpeta_stl, config)
    carpeta_salida = obtener_campo_config_local(config, 'carpeta_salida', '');
    if ~isempty(carpeta_salida)
        return;
    end
    data_paths = tesis_auxiliares('asegurar_dataset_paths');
    [carpeta_padre, nombre_carpeta] = fileparts(carpeta_stl);
    if strcmpi(nombre_carpeta, 'distribuciones_stl')
        carpeta_salida = fullfile(carpeta_padre, 'distribuciones_mat');
    elseif ruta_es_raiz_o_subruta_preprocesador(carpeta_stl, data_paths.distribuciones_stl_corregidas)
        ruta_rel = extraer_ruta_relativa_preprocesador(carpeta_stl, data_paths.distribuciones_stl_corregidas);
        carpeta_salida = fullfile(data_paths.distribuciones_mat_corregidas, ruta_rel);
    elseif ruta_es_raiz_o_subruta_preprocesador(carpeta_stl, data_paths.distribuciones_stl)
        ruta_rel = extraer_ruta_relativa_preprocesador(carpeta_stl, data_paths.distribuciones_stl);
        carpeta_salida = fullfile(data_paths.distribuciones_mat, ruta_rel);
    else
        carpeta_salida = fullfile(carpeta_stl, 'distribuciones_mat');
    end
end

function tf = ruta_es_raiz_o_subruta_preprocesador(ruta, raiz)
    ruta_abs = char(java.io.File(ruta).getCanonicalPath());
    raiz_abs = char(java.io.File(raiz).getCanonicalPath());
    tf = strcmpi(ruta_abs, raiz_abs) || ...
        startsWith(ruta_abs, [raiz_abs filesep], 'IgnoreCase', true);
end

function ruta_rel = extraer_ruta_relativa_preprocesador(ruta, raiz)
    ruta_abs = char(java.io.File(ruta).getCanonicalPath());
    raiz_abs = char(java.io.File(raiz).getCanonicalPath());
    if strcmpi(ruta_abs, raiz_abs)
        ruta_rel = '';
    else
        ruta_rel = ruta_abs(numel(raiz_abs) + 2:end);
    end
end

function valor = obtener_campo_config_local(config, campo, valor_default)
    valor = valor_default;
    if isstruct(config) && isfield(config, campo) && ~isempty(config.(campo))
        valor = config.(campo);
    end
end

function logger = configurar_log_preprocesador(nuevo_logger)
    persistent logger_actual
    if nargin > 0
        logger_actual = nuevo_logger;
    end
    logger = logger_actual;
end

function log_preprocesador(formato, varargin)
    logger = configurar_log_preprocesador();
    if isempty(logger)
        fprintf(formato, varargin{:});
        return;
    end
    mensaje = sprintf(formato, varargin{:});
    mensaje = regexprep(mensaje, '[\r\n]+$', '');
    lineas = regexp(mensaje, '\r\n|\n|\r', 'split');
    for k = 1:numel(lineas)
        if ~isempty(lineas{k})
            logger('%s', lineas{k});
        end
    end
end

function [vertices, caras] = leer_stl_binario(nombre_archivo)
    identificador = fopen(nombre_archivo, 'rb');
    if identificador < 0
        error('No se pudo abrir el STL: %s', nombre_archivo);
    end

    limpieza = onCleanup(@() fclose(identificador));
    fseek(identificador, 80, 'bof');
    numero_caras = fread(identificador, 1, 'uint32');
    vertices_crudos = zeros(numero_caras * 3, 3);

    for indice_cara = 1:numero_caras
        fread(identificador, 3, 'float32');
        vertice_1 = fread(identificador, 3, 'float32');
        vertice_2 = fread(identificador, 3, 'float32');
        vertice_3 = fread(identificador, 3, 'float32');
        fread(identificador, 1, 'uint16');

        indice_base = (indice_cara - 1) * 3;
        vertices_crudos(indice_base + 1, :) = vertice_1';
        vertices_crudos(indice_base + 2, :) = vertice_2';
        vertices_crudos(indice_base + 3, :) = vertice_3';
    end

    [vertices, ~, indices_unicos] = unique(vertices_crudos, 'rows', 'stable');
    caras = reshape(indices_unicos, 3, numero_caras)';
end
