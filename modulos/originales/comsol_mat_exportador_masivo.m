function comsol_mat_exportador_masivo(varargin)
% =========================================================================
%  COMSOL_MAT_EXPORTADOR_MASIVO
% =========================================================================
%
%  DESCRIPCIÓN GENERAL
%  -------------------
%  Exporta información térmica previamente extraída desde COMSOL y guardada
%  en un archivo .mat del flujo "Extractor Masivo". Este módulo NO requiere
%  COMSOL LiveLink ni abre archivos .mph; trabaja directamente sobre la
%  estructura MATLAB ya generada por el extractor.
%
%  POSICIÓN DENTRO DEL FLUJO DE TRABAJO
%  ------------------------------------
%  COMSOL_Extractor_Masivo / extractor_comsol_masivo
%      -> genera un .mat con modelos, datasets, snapshots 3D y sondas.
%
%  comsol_mat_exportador_masivo
%      -> toma ese .mat y produce salidas externas reutilizables:
%         1) STL por instante temporal de la zona de ablación.
%         2) TXT consolidado con la evolución térmica de las sondas.
%
%  Extractor_STL / preprocesar_stl_a_mat / optimizador_3d_final
%      -> pueden reutilizar los STL exportados para procesos geométricos,
%         voxelización u optimización espacial.
%
%  ESTRUCTURA DE ENTRADA ESPERADA
%  ------------------------------
%  dataset.(nombre_modelo).(tag_dataset)
%      .snapshots(k).t_min      -> tiempo del snapshot en minutos
%      .snapshots(k).points     -> nube de puntos [N x 3] de ablación
%      .snapshots(k).T          -> temperaturas asociadas [N x 1]
%      .t_min                   -> vector temporal del dataset
%      .probes                  -> struct de sondas puntuales
%
%  ESTRUCTURA DE SALIDA
%  --------------------
%  <carpeta_del_mat>/Exported_Datasets_STL_TXT/
%      <nombre_modelo>/
%          <tag_dataset>/
%              Registro_Sondas_Temperatura.txt
%              Geometria_Ablacion_t0.0000min.stl
%              Geometria_Ablacion_t1.0000min.stl
%              ...
%
%  NOTAS DE REFACTOR
%  -----------------
%  - Se conserva la lógica original de exportación.
%  - Se normalizan variables y funciones a snake_case en español.
%  - Se separa la lógica repetitiva en funciones auxiliares.
%  - Se mantienen nombres históricos de archivos/carpetas para compatibilidad.
%  - La función principal debe guardarse como:
%        comsol_mat_exportador_masivo.m
%
%  DEPENDENCIAS MATLAB
%  -------------------
%  - alphaShape
%  - boundaryFacets
%  - triangulation
%  - stlwrite
%
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
        lanzar_ui_comsol_mat_exportador_masivo();
        return;
    end

    config_ui = struct();
    if nargin >= 2 && strcmpi(varargin{1}, 'run')
        config_ui = varargin{2};
    end
    configurar_log_exportador(obtener_campo_config(config_ui, 'logfn', []));
    limpieza_logger = onCleanup(@() configurar_log_exportador([]));
    clc;
    if ~logical(obtener_campo_config(config_ui, 'mantener_figuras', false))
        close all;
    end

    %% CONFIGURACIÓN
    % Dejar vacío para seleccionar el archivo .mat mediante cuadro de diálogo.
    ruta_mat_entrada = obtener_campo_config(config_ui, 'ruta_mat_entrada', '');

    % Parámetros para reconstrucción geométrica 3D.
    iteraciones_suavizado = round(obtener_campo_config(config_ui, ...
        'iteraciones_suavizado', 4));
    radio_alpha = obtener_campo_config(config_ui, ...
        'radio_alpha', 0);  % 0 = calculo automatico adaptativo.
    temperatura_min_stl = obtener_campo_config(config_ui, 'temperatura_min_stl', 55);
    temperatura_max_stl_caso0 = obtener_campo_config( ...
        config_ui, 'temperatura_max_stl_caso0', 500);
    temperatura_max_stl_termo = obtener_campo_config( ...
        config_ui, 'temperatura_max_stl_termo', 120);

    %% CARGA DEL DATASET
    ruta_mat_entrada = seleccionar_archivo_mat(ruta_mat_entrada);
    if isempty(ruta_mat_entrada)
        log_exportador('Proceso cancelado por el usuario.\n');
        return;
    end

    log_exportador('Cargando conjunto de datos: %s ...\n', ruta_mat_entrada);
    [dataset, carga_correcta] = cargar_dataset_desde_mat(ruta_mat_entrada);
    if ~carga_correcta
        return;
    end

    carpeta_exportacion = crear_carpeta_exportacion(ruta_mat_entrada, config_ui);

    imprimir_separador();
    log_exportador('INICIANDO EXPORTACIÓN MASIVA DE STL Y TXT\n');
    imprimir_separador();

    exportar_modelos(dataset, carpeta_exportacion, radio_alpha, ...
        iteraciones_suavizado, temperatura_min_stl, ...
        temperatura_max_stl_caso0, temperatura_max_stl_termo);

    imprimir_separador();
    log_exportador('PROCESO FINALIZADO CON ÉXITO.\n');
    log_exportador('Todos los archivos válidos fueron guardados en:\n %s\n', carpeta_exportacion);
    imprimir_separador();
end

function lanzar_ui_comsol_mat_exportador_masivo()
    entradas = struct( ...
        'key', 'ruta_mat_entrada', ...
        'label', 'MAT del extractor', ...
        'kind', 'file', ...
        'filter', {{'*.mat', 'Dataset termico del extractor (*.mat)'}}, ...
        'title', 'Selecciona el .mat del Extractor Masivo', ...
        'default', '');

    tesis_auxiliares('crear_dashboard_modulo',  ...
        'COMSOL MAT Exportador', ...
        ['Exporta STL por instante y TXT de sondas desde el .mat ', ...
         'estructurado generado por el extractor masivo.'], ...
        entradas, ...
        @(valores, logfn) ejecutar_desde_ui_comsol_mat_exportador(valores, logfn));
end

function ejecutar_desde_ui_comsol_mat_exportador(valores, logfn)
    if isempty(valores.ruta_mat_entrada) || ~isfile(valores.ruta_mat_entrada)
        error('Selecciona un archivo .mat valido antes de ejecutar.');
    end
    valores.logfn = logfn;
    data_paths = tesis_auxiliares('asegurar_dataset_paths');
    valores.carpeta_exportacion = data_paths.distribuciones_stl;
    logfn('MAT de entrada: %s', valores.ruta_mat_entrada);
    logfn('Salida optimizador STL: %s', valores.carpeta_exportacion);
    comsol_mat_exportador_masivo('run', valores);
    logfn('Exportacion STL/TXT terminada.');
end

function valor = obtener_campo_config(config, campo, valor_default)
    valor = valor_default;
    if isstruct(config) && isfield(config, campo) && ~isempty(config.(campo))
        valor = config.(campo);
    end
end

%% =========================================================================
%% SELECCIÓN Y CARGA
%% =========================================================================
function ruta_mat_entrada = seleccionar_archivo_mat(ruta_mat_entrada)
% seleccionar_archivo_mat
% Devuelve la ruta del .mat a procesar. Si la ruta está vacía, abre UI.

    if ~isempty(ruta_mat_entrada)
        return;
    end

    data_paths = tesis_auxiliares('asegurar_dataset_paths');
    [archivo, carpeta] = uigetfile( ...
        '*.mat', ...
        'Selecciona el conjunto de datos (.mat) del Extractor Masivo', ...
        data_paths.datasets_masivos);

    if isequal(archivo, 0)
        ruta_mat_entrada = '';
        return;
    end

    ruta_mat_entrada = fullfile(carpeta, archivo);
end

function [dataset, carga_correcta] = cargar_dataset_desde_mat(ruta_mat_entrada)
% cargar_dataset_desde_mat
% Carga el primer struct encontrado dentro del .mat. Se conserva la lógica
% original, donde el archivo generado por el extractor contiene una variable
% principal con la estructura del dataset.

    dataset = struct();
    carga_correcta = false;

    try
        datos_crudos = load(ruta_mat_entrada);
        nombres_variables = fieldnames(datos_crudos);

        if isempty(nombres_variables)
            log_exportador('[ERROR] El archivo .mat no contiene variables.\n');
            return;
        end

        dataset = datos_crudos.(nombres_variables{1});
        carga_correcta = true;

    catch excepcion
        log_exportador('[ERROR] No se pudo leer el archivo .mat: %s\n', excepcion.message);
    end
end

function carpeta_exportacion = crear_carpeta_exportacion(~, config_ui)
% crear_carpeta_exportacion
% Crea la carpeta raíz de exportación junto al archivo .mat de entrada.

    carpeta_exportacion = obtener_campo_config(config_ui, 'carpeta_exportacion', '');
    if isempty(carpeta_exportacion)
        data_paths = tesis_auxiliares('asegurar_dataset_paths');
        carpeta_exportacion = data_paths.distribuciones_stl;
    end
    crear_carpeta_si_no_existe(carpeta_exportacion);
end

%% =========================================================================
%% EXPORTACIÓN PRINCIPAL
%% =========================================================================
function exportar_modelos(dataset, carpeta_exportacion, radio_alpha, ...
        iteraciones_suavizado, temperatura_min_stl, ...
        temperatura_max_stl_caso0, temperatura_max_stl_termo)
% exportar_modelos
% Recorre todos los modelos y datasets almacenados dentro de la estructura
% principal, ignorando metadatos globales y entradas no estructuradas.

    nombres_modelos = fieldnames(dataset);

    log_exportador('Modelos detectados en MAT: %d\n', numel(nombres_modelos));
    for indice_modelo = 1:numel(nombres_modelos)
        nombre_modelo = nombres_modelos{indice_modelo};

        if strcmp(nombre_modelo, 'session_meta')
            continue;
        end

        log_exportador('[Modelo %d/%d] %s\n', indice_modelo, numel(nombres_modelos), nombre_modelo);

        estructura_modelo = dataset.(nombre_modelo);
        if ~isstruct(estructura_modelo)
            continue;
        end

        exportar_datasets_de_modelo( ...
            estructura_modelo, ...
            nombre_modelo, ...
            carpeta_exportacion, ...
            radio_alpha, ...
            iteraciones_suavizado, ...
            temperatura_min_stl, ...
            temperatura_max_stl_caso0, ...
            temperatura_max_stl_termo);
    end
end

function exportar_datasets_de_modelo(estructura_modelo, nombre_modelo, ...
        carpeta_exportacion, radio_alpha, iteraciones_suavizado, ...
        temperatura_min_stl, temperatura_max_stl_caso0, ...
        temperatura_max_stl_termo)
% exportar_datasets_de_modelo
% Recorre los datasets de un modelo y delega la exportación de cada solución.

    tags_dataset = fieldnames(estructura_modelo);

    log_exportador('  Datasets detectados: %d\n', numel(tags_dataset));
    for indice_dataset = 1:numel(tags_dataset)
        tag_dataset = tags_dataset{indice_dataset};

        if ismember(tag_dataset, {'session_meta', 'datasets_omitidos', 'source_signature'})
            continue;
        end

        datos_solucion = estructura_modelo.(tag_dataset);
        if ~es_dataset_valido(datos_solucion)
            continue;
        end

        [metadata_util, motivo_metadata] = dataset_exportable_por_metadata(nombre_modelo, tag_dataset);
        if ~metadata_util
            log_exportador('Omitido: %s -> %s (%s)\n', nombre_modelo, tag_dataset, motivo_metadata);
            continue;
        end

        log_exportador('  [Dataset %d/%d] %s -> %s\n', ...
            indice_dataset, numel(tags_dataset), nombre_modelo, tag_dataset);

        subcarpeta_optimizador = subcarpeta_optimizador_desde_metadata(nombre_modelo, tag_dataset);
        carpeta_salida = fullfile(carpeta_exportacion, subcarpeta_optimizador);
        crear_carpeta_si_no_existe(carpeta_salida);
        idx_caso = extraer_caso_dataset_stl(tag_dataset, datos_solucion);
        temperatura_max_stl = seleccionar_maximo_termico_stl( ...
            idx_caso, temperatura_max_stl_caso0, ...
            temperatura_max_stl_termo);
        log_exportador(['    Ventana termica STL: %.1f a %.1f C ' ...
            '(caso %d, recorrido inicial -> final).\n'], ...
            temperatura_min_stl, temperatura_max_stl, idx_caso);

        exportar_stl_de_snapshots( ...
            datos_solucion.snapshots, ...
            carpeta_salida, ...
            radio_alpha, ...
            iteraciones_suavizado, ...
            temperatura_min_stl, ...
            temperatura_max_stl);

        exportar_registro_sondas( ...
            datos_solucion, ...
            nombre_modelo, ...
            tag_dataset, ...
            carpeta_salida);
    end
end

function es_valido = es_dataset_valido(datos_solucion)
% es_dataset_valido
% Valida que la entrada represente una solución con snapshots exportables.

    es_valido = isstruct(datos_solucion) && isfield(datos_solucion, 'snapshots');
end

%% =========================================================================
%% CANAL A: EXPORTACIÓN STL
%% =========================================================================
function exportar_stl_de_snapshots(snapshots, carpeta_salida, ...
        radio_alpha, iteraciones_suavizado, temperatura_min_stl, ...
        temperatura_max_stl)
% exportar_stl_de_snapshots
% Exporta un STL por cada instante temporal con una nube de puntos válida.

    numero_snapshots = numel(snapshots);
    [orden_temporal, tmax_datos, tmax_metadata, tmax_decision] = ...
        preparar_plan_temporal_stl(snapshots);
    reportar_consistencia_tmax(tmax_datos, tmax_metadata);
    excede_maximo = isfinite(tmax_decision) & ...
        tmax_decision > temperatura_max_stl;
    posicion_corte = encontrar_primer_corte_sostenido(excede_maximo(orden_temporal));

    log_exportador(['  Exportando %d archivos STL ' ...
        '(geometria util, %.1f <= T <= %.1f C)...\n'], ...
        numero_snapshots, temperatura_min_stl, temperatura_max_stl);
    log_exportador(['    Criterio temporal: recorrido creciente; ' ...
        'corte desde el primer instante cuyo Tmax y todos los posteriores ' ...
        'exceden %.1f C.\n'], temperatura_max_stl);
    n_exportados = 0;
    n_omitidos = 0;
    n_sin_puntos = 0;
    n_excluidos_corte = 0;
    n_error = 0;

    for posicion_temporal = 1:numel(orden_temporal)
        indice_snapshot = orden_temporal(posicion_temporal);
        snapshot = snapshots(indice_snapshot);

        if ~isfield(snapshot, 'points') || ~isfield(snapshot, 't_min')
            n_sin_puntos = n_sin_puntos + 1;
            continue;
        end
        nombre_stl = sprintf('Geometria_Ablacion_t%.4fmin.stl', snapshot.t_min);
        ruta_stl = fullfile(carpeta_salida, nombre_stl);
        ruta_done = [ruta_stl '.done'];

        if isfield(snapshot, 'points_ablacion_corregida')
            puntos = snapshot.points_ablacion_corregida;
            temperaturas_snapshot = obtener_temperaturas_snapshot(snapshot, 'T_ablacion_corregida');
        else
            puntos = snapshot.points;
            temperaturas_snapshot = obtener_temperaturas_snapshot(snapshot, 'T');
        end

        if ~isnumeric(puntos) || ~ismatrix(puntos) || ...
                size(puntos, 2) ~= 3
            n_sin_puntos = n_sin_puntos + 1;
            eliminar_salida_stl_obsoleta(ruta_stl, ruta_done);
            log_exportador(['    [%d/%d] t=%.4f min sin coordenadas ' ...
                'numericas N x 3. STL eliminado/omitido.\n'], ...
                posicion_temporal, numero_snapshots, snapshot.t_min);
            continue;
        end

        if isempty(temperaturas_snapshot) || ...
                numel(temperaturas_snapshot) ~= size(puntos, 1)
            n_sin_puntos = n_sin_puntos + 1;
            eliminar_salida_stl_obsoleta(ruta_stl, ruta_done);
            log_exportador(['    [%d/%d] t=%.4f min sin temperaturas ' ...
                'asociadas validas. STL eliminado/omitido.\n'], ...
                posicion_temporal, numero_snapshots, snapshot.t_min);
            continue;
        end

        if isfinite(posicion_corte) && posicion_temporal >= posicion_corte
            n_excluidos_corte = n_excluidos_corte + 1;
            temperatura_maxima_real = tmax_decision(indice_snapshot);
            eliminar_salida_stl_obsoleta(ruta_stl, ruta_done);
            log_exportador(['    [%d/%d] t=%.4f min EXCLUIDO: ' ...
                'corte termico sostenido. Tmax=%.4f C > %.1f C ' ...
                'en este instante y posteriores.\n'], ...
                posicion_temporal, numero_snapshots, snapshot.t_min, ...
                temperatura_maxima_real, temperatura_max_stl);
            continue;
        end

        temperatura_maxima_real = tmax_decision(indice_snapshot);
        if isfinite(temperatura_maxima_real) && ...
                temperatura_maxima_real > temperatura_max_stl
            log_exportador(['    [%d/%d] t=%.4f min con Tmax=%.4f C ' ...
                '> %.1f C, sin corte sostenido. Se conserva continuidad ' ...
                'filtrando puntos fuera de ventana.\n'], ...
                posicion_temporal, numero_snapshots, snapshot.t_min, ...
                temperatura_maxima_real, temperatura_max_stl);
        end

        mascara_temperatura = isfinite(temperaturas_snapshot(:)) & ...
            temperaturas_snapshot(:) >= temperatura_min_stl & ...
            temperaturas_snapshot(:) <= temperatura_max_stl & ...
            all(isfinite(double(puntos)), 2);
        if any(~mascara_temperatura)
            log_exportador(['    [%d/%d] t=%.4f min filtro STL ' ...
                '%.1f <= T <= %.1f C: %d/%d puntos.\n'], ...
                posicion_temporal, numero_snapshots, snapshot.t_min, ...
                temperatura_min_stl, temperatura_max_stl, ...
                sum(mascara_temperatura), numel(mascara_temperatura));
        end
        puntos = puntos(mascara_temperatura, :);
        if ~tiene_puntos_suficientes(puntos)
            n_sin_puntos = n_sin_puntos + 1;
            eliminar_salida_stl_obsoleta(ruta_stl, ruta_done);
            log_exportador('    [%d/%d] t=%.4f min sin puntos suficientes. Omitido.\n', ...
                posicion_temporal, numero_snapshots, snapshot.t_min);
            continue;
        end

        firma_snapshot = crear_firma_snapshot_stl( ...
            puntos, snapshot.t_min, radio_alpha, iteraciones_suavizado, ...
            temperatura_min_stl, temperatura_max_stl);

        if checkpoint_stl_vigente(ruta_stl, ruta_done, firma_snapshot)
            n_omitidos = n_omitidos + 1;
            log_exportador('    [%d/%d] %s vigente por .done. Omitido.\n', ...
                posicion_temporal, numero_snapshots, nombre_stl);
            continue;
        end

        log_exportador('    [%d/%d] Exportando %s ...\n', ...
            posicion_temporal, numero_snapshots, nombre_stl);
        generado = generar_stl_ablacion( ...
            puntos, ...
            snapshot.t_min, ...
            ruta_stl, ...
            radio_alpha, ...
            iteraciones_suavizado);
        if generado
            escribir_checkpoint_stl(ruta_done, firma_snapshot);
            n_exportados = n_exportados + 1;
        else
            n_error = n_error + 1;
        end
    end
    log_exportador(['  Resumen STL: exportados=%d | omitidos_done=%d | ' ...
        'excluidos_corte=%d | sin_puntos=%d | errores=%d\n'], ...
        n_exportados, n_omitidos, n_excluidos_corte, ...
        n_sin_puntos, n_error);
end

function [orden_temporal, tmax_datos, tmax_metadata, tmax_decision] = ...
        preparar_plan_temporal_stl(snapshots)
% preparar_plan_temporal_stl
% Ordena los snapshots por tiempo creciente y calcula Tmax desde dos fuentes:
% la distribucion termica exportada y la metadata T_max_C, si existe.

    numero_snapshots = numel(snapshots);
    tiempos = nan(numero_snapshots, 1);
    tmax_datos = nan(numero_snapshots, 1);
    tmax_metadata = nan(numero_snapshots, 1);
    tmax_decision = nan(numero_snapshots, 1);

    for i = 1:numero_snapshots
        snapshot = snapshots(i);
        if isfield(snapshot, 't_min') && isnumeric(snapshot.t_min) && ...
                isscalar(snapshot.t_min) && isfinite(snapshot.t_min)
            tiempos(i) = double(snapshot.t_min);
        end

        if isfield(snapshot, 'points_ablacion_corregida')
            temperaturas = obtener_temperaturas_snapshot( ...
                snapshot, 'T_ablacion_corregida');
        else
            temperaturas = obtener_temperaturas_snapshot(snapshot, 'T');
        end
        [tmax_datos(i), tmax_metadata(i), tmax_decision(i)] = ...
            obtener_maximos_termicos_snapshot(snapshot, temperaturas);
    end

    indices_validos = find(isfinite(tiempos));
    [~, orden_local] = sort(tiempos(indices_validos), 'ascend');
    orden_temporal = indices_validos(orden_local);
    indices_sin_tiempo = find(~isfinite(tiempos));
    orden_temporal = [orden_temporal; indices_sin_tiempo];
end

function reportar_consistencia_tmax(tmax_datos, tmax_metadata)
% reportar_consistencia_tmax
% Informa si la Tmax de metadata y la Tmax recalculada desde T difieren.

    mascara = isfinite(tmax_datos) & isfinite(tmax_metadata);
    if ~any(mascara)
        log_exportador(['    Tmax: no hay pares suficientes para comparar ' ...
            'metadata contra distribucion termica.\n']);
        return;
    end

    diferencias = abs(tmax_datos(mascara) - tmax_metadata(mascara));
    tolerancia = 1e-6;
    n_diferencias = nnz(diferencias > tolerancia);
    if n_diferencias == 0
        log_exportador(['    Tmax verificada: metadata T_max_C coincide ' ...
            'con max(T) en %d snapshots.\n'], nnz(mascara));
    else
        log_exportador(['    [WARN] Tmax metadata vs max(T): %d/%d ' ...
            'snapshots difieren. Diferencia maxima %.6g C. ' ...
            'Se usa el mayor valor para el corte.\n'], ...
            n_diferencias, nnz(mascara), max(diferencias));
    end
end

function posicion_corte = encontrar_primer_corte_sostenido(excede_maximo)
% encontrar_primer_corte_sostenido
% Devuelve la primera posicion cuyo valor y todos los posteriores exceden el
% limite termico. Si hay oscilaciones bajo el limite despues, no hay corte.

    posicion_corte = NaN;
    excede_maximo = logical(excede_maximo(:));
    if isempty(excede_maximo)
        return;
    end

    sufijo_sostenido = flipud(cumprod(double(flipud(excede_maximo))) > 0);
    indice = find(sufijo_sostenido, 1, 'first');
    if ~isempty(indice)
        posicion_corte = indice;
    end
end

function es_suficiente = tiene_puntos_suficientes(puntos)
% tiene_puntos_suficientes
% Un sólido triangulable requiere al menos cuatro puntos no coplanares. Esta
% verificación conserva el umbral mínimo original.

    es_suficiente = ~isempty(puntos) && size(puntos, 1) >= 4;
end

function temperaturas = obtener_temperaturas_snapshot(snapshot, campo_preferido)
% obtener_temperaturas_snapshot
% Devuelve el vector termico asociado a la nube de puntos exportable.

    temperaturas = [];
    if isfield(snapshot, campo_preferido)
        temperaturas = snapshot.(campo_preferido);
    elseif isfield(snapshot, 'T')
        temperaturas = snapshot.T;
    end
end

function [tmax_datos, tmax_metadata, tmax_decision] = ...
        obtener_maximos_termicos_snapshot(snapshot, temperaturas)
% obtener_maximos_termicos_snapshot
% Calcula Tmax desde el vector termico y lee T_max_C de metadata. La decision
% usa el mayor valor disponible para no ignorar informacion conservadora.

    valores = double(temperaturas(:));
    valores = valores(isfinite(valores));
    if isempty(valores)
        tmax_datos = NaN;
    else
        tmax_datos = max(valores);
    end

    tmax_metadata = NaN;
    if isfield(snapshot, 'T_max_C') && ...
            isnumeric(snapshot.T_max_C) && isscalar(snapshot.T_max_C) && ...
            isfinite(snapshot.T_max_C)
        tmax_metadata = double(snapshot.T_max_C);
    end

    tmax_decision = max([tmax_datos, tmax_metadata], [], 'omitnan');
    if isempty(tmax_decision) || ~isfinite(tmax_decision)
        tmax_decision = NaN;
    end
end

function generado = generar_stl_ablacion(puntos, tiempo_min, ruta_stl, radio_alpha, iteraciones_suavizado)
% generar_stl_ablacion
% Reconstruye una superficie cerrada aproximada mediante alphaShape, suaviza
% la malla triangular y la guarda en formato STL.

    generado = false;
    try
        radio_alpha_local = calcular_radio_alpha(puntos, radio_alpha);
        forma_alpha = alphaShape(puntos(:, 1), puntos(:, 2), puntos(:, 3), radio_alpha_local);

        if numRegions(forma_alpha) == 0
            radio_alpha_local = criticalAlpha(forma_alpha, 'one-region');
            forma_alpha = alphaShape(puntos(:, 1), puntos(:, 2), puntos(:, 3), radio_alpha_local);
        end

        if numRegions(forma_alpha) < 1
            return;
        end

        [triangulos, nodos] = boundaryFacets(forma_alpha);
        if size(triangulos, 1) < 4
            return;
        end

        [triangulos_suavizados, nodos_suavizados] = suavizar_malla_laplaciano( ...
            triangulos, ...
            nodos, ...
            iteraciones_suavizado);

        stlwrite(triangulation(triangulos_suavizados, nodos_suavizados), ruta_stl);
        generado = true;

    catch excepcion_stl
        log_exportador( ...
            '     [WARN] Error generando STL en instante t=%.4f: %s\n', ...
            tiempo_min, ...
            excepcion_stl.message);
    end
end

function radio_alpha_local = calcular_radio_alpha(puntos, radio_alpha)
% calcular_radio_alpha
% Usa el radio indicado por el usuario. Si es cero o negativo, calcula un
% radio adaptativo a partir de las dimensiones de la nube de puntos.

    radio_alpha_local = radio_alpha;

    if radio_alpha_local > 0
        return;
    end

    dimensiones = max(puntos) - min(puntos);
    densidad_volumetrica = (prod(dimensiones + eps) / size(puntos, 1))^(1 / 3);
    radio_alpha_local = max(2.0, densidad_volumetrica * 2.2);
end

function firma = crear_firma_snapshot_stl(puntos, tiempo_min, ...
        radio_alpha, iteraciones_suavizado, temperatura_min_stl, ...
        temperatura_max_stl)
% crear_firma_snapshot_stl
% Registra la identidad numerica minima del STL generado. Si cambian puntos,
% tiempo o parametros de reconstruccion, el checkpoint deja de ser valido.

    puntos = double(puntos);
    mins = min(puntos, [], 1);
    maxs = max(puntos, [], 1);
    suma = sum(puntos, 1);
    firma = sprintf(['stl_export_v5|criterio=prefijo_sostenido|' ...
        't=%.10g|n=%d|alpha=%.10g|smooth=%d|' ...
        'tmin=%.10g|tmax=%.10g|', ...
        'min=[%.10g %.10g %.10g]|max=[%.10g %.10g %.10g]|sum=[%.10g %.10g %.10g]'], ...
        tiempo_min, size(puntos, 1), radio_alpha, ...
        iteraciones_suavizado, temperatura_min_stl, ...
        temperatura_max_stl, ...
        mins(1), mins(2), mins(3), maxs(1), maxs(2), maxs(3), ...
        suma(1), suma(2), suma(3));
end

function eliminar_salida_stl_obsoleta(ruta_stl, ruta_done)
    if isfile(ruta_stl)
        delete(ruta_stl);
    end
    if isfile(ruta_done)
        delete(ruta_done);
    end
end

function idx_caso = extraer_caso_dataset_stl(tag_dataset, datos_solucion)
    idx_caso = NaN;
    token = regexp(tag_dataset, '(?:^|_)c(\d+)(?:_|$)', ...
        'tokens', 'once', 'ignorecase');
    if ~isempty(token)
        idx_caso = str2double(token{1});
    elseif isfield(datos_solucion, 'metadata') && ...
            isstruct(datos_solucion.metadata)
        campos = {'idx_caso', 'caso'};
        for i = 1:numel(campos)
            if isfield(datos_solucion.metadata, campos{i})
                idx_caso = double(datos_solucion.metadata.(campos{i}));
                break;
            end
        end
    end
    if ~isfinite(idx_caso)
        error('No se pudo determinar el caso termico para %s.', tag_dataset);
    end
end

function temperatura_max = seleccionar_maximo_termico_stl( ...
        idx_caso, temperatura_max_caso0, temperatura_max_termo)
    if idx_caso == 0
        temperatura_max = temperatura_max_caso0;
    else
        temperatura_max = temperatura_max_termo;
    end
end

function vigente = checkpoint_stl_vigente(ruta_stl, ruta_done, firma_esperada)
% checkpoint_stl_vigente
% Omite la regeneracion solo cuando existen el STL y su .done compatible.

    vigente = false;
    if ~isfile(ruta_stl) || ~isfile(ruta_done)
        return;
    end

    try
        contenido = fileread(ruta_done);
        vigente = contains(contenido, firma_esperada);
    catch
        vigente = false;
    end
end

function escribir_checkpoint_stl(ruta_done, firma_snapshot)
% escribir_checkpoint_stl
% Crea la marca de finalizacion junto al STL exportado.

    identificador = fopen(ruta_done, 'w');
    if identificador == -1
        log_exportador('     [WARN] No se pudo crear checkpoint: %s\n', ruta_done);
        return;
    end

    limpieza = onCleanup(@() fclose(identificador));
    fprintf(identificador, 'done=true\n');
    fprintf(identificador, 'created_at=%s\n', datestr(now));
    fprintf(identificador, 'signature=%s\n', firma_snapshot);
    clear limpieza;
end

%% =========================================================================
%% CANAL B: EXPORTACIÓN TXT DE SONDAS
%% =========================================================================
function exportar_registro_sondas(datos_solucion, nombre_modelo, tag_dataset, carpeta_salida)
% exportar_registro_sondas
% Exporta un archivo TXT consolidado con metadatos de sondas y evolución
% térmica temporal de cada sonda disponible.

    if ~tiene_sondas(datos_solucion)
        log_exportador('  [INFO] No se encontraron datos de sondas para este dataset.\n');
        return;
    end

    nombres_sondas = fieldnames(datos_solucion.probes);
    ruta_txt = fullfile(carpeta_salida, 'Registro_Sondas_Temperatura.txt');
    ruta_done = [ruta_txt '.done'];
    firma_sondas = crear_firma_sondas_txt(datos_solucion, nombre_modelo, tag_dataset, nombres_sondas);

    if checkpoint_stl_vigente(ruta_txt, ruta_done, firma_sondas)
        log_exportador('  Registro de sondas vigente por .done. Omitido.\n');
        return;
    end

    log_exportador('  Exportando registro de sondas a: %s\n', 'Registro_Sondas_Temperatura.txt');

    identificador_archivo = fopen(ruta_txt, 'w');
    if identificador_archivo == -1
        log_exportador('     [ERROR] No se pudo crear el archivo de texto.\n');
        return;
    end

    cerrar_archivo = onCleanup(@() fclose(identificador_archivo));

    escribir_encabezado_sondas( ...
        identificador_archivo, ...
        datos_solucion.probes, ...
        nombres_sondas, ...
        nombre_modelo, ...
        tag_dataset);

    escribir_tabla_sondas( ...
        identificador_archivo, ...
        datos_solucion, ...
        nombres_sondas);

    clear cerrar_archivo;
    escribir_checkpoint_stl(ruta_done, firma_sondas);
end

function firma = crear_firma_sondas_txt(datos_solucion, nombre_modelo, tag_dataset, nombres_sondas)
% crear_firma_sondas_txt
% Registra la identidad minima del TXT de sondas para omitir reexportaciones
% cuando el modelo/dataset/tiempos/series no han cambiado.

    t = double(datos_solucion.t_min(:));
    partes = {sprintf('sondas_txt_v1|modelo=%s|dataset=%s|nt=%d|nprobes=%d', ...
        nombre_modelo, tag_dataset, numel(t), numel(nombres_sondas))};
    if ~isempty(t)
        partes{end + 1} = sprintf('tmin=%.10g|tmax=%.10g|tsum=%.10g', ...
            min(t), max(t), sum(t));
    end
    for indice_sonda = 1:numel(nombres_sondas)
        nombre_sonda = nombres_sondas{indice_sonda};
        sonda = datos_solucion.probes.(nombre_sonda);
        T = double(sonda.T(:));
        finitos = isfinite(T);
        if any(finitos)
            Tmin = min(T(finitos));
            Tmax = max(T(finitos));
            Tsum = sum(T(finitos));
        else
            Tmin = NaN;
            Tmax = NaN;
            Tsum = NaN;
        end
        coord_mm = obtener_vector_sonda(sonda, 'coord_mm');
        coord_real = obtener_vector_sonda(sonda, 'coord_real');
        partes{end + 1} = sprintf(['probe=%s|coord=[%.10g %.10g %.10g]|', ...
            'real=[%.10g %.10g %.10g]|n=%d|finite=%d|min=%.10g|max=%.10g|sum=%.10g'], ...
            nombre_sonda, coord_mm(1), coord_mm(2), coord_mm(3), ...
            coord_real(1), coord_real(2), coord_real(3), ...
            numel(T), sum(finitos), Tmin, Tmax, Tsum); %#ok<AGROW>
    end
    firma = strjoin(partes, ';');
end

function vector = obtener_vector_sonda(sonda, campo)
    vector = [NaN, NaN, NaN];
    if isfield(sonda, campo) && numel(sonda.(campo)) >= 3
        vector = double(sonda.(campo)(1:3));
        vector = vector(:)';
    end
end

function existe_sondas = tiene_sondas(datos_solucion)
% tiene_sondas
% Determina si una solución posee struct de sondas con al menos un campo.

    existe_sondas = isfield(datos_solucion, 'probes') && ...
                    isstruct(datos_solucion.probes) && ...
                    ~isempty(fieldnames(datos_solucion.probes));
end

function escribir_encabezado_sondas(identificador_archivo, probes, nombres_sondas, nombre_modelo, tag_dataset)
% escribir_encabezado_sondas
% Escribe metadatos generales y coordenadas de sondas en el TXT.

    fprintf(identificador_archivo, '=========================================================================\n');
    fprintf(identificador_archivo, ' REGISTRO DE CAMBIOS DE TEMPERATURA EN SONDAS - CANAL B\n');
    fprintf(identificador_archivo, '=========================================================================\n');
    fprintf(identificador_archivo, 'Modelo Origen : %s\n', nombre_modelo);
    fprintf(identificador_archivo, 'Dataset Tag   : %s\n', tag_dataset);
    fprintf(identificador_archivo, 'Fecha Export. : %s\n', datestr(now));
    fprintf(identificador_archivo, '-------------------------------------------------------------------------\n');
    fprintf(identificador_archivo, 'UBICACIÓN DE LAS SONDAS (Coordenadas Reales / Nodos de Malla):\n');

    for indice_sonda = 1:numel(nombres_sondas)
        nombre_sonda = nombres_sondas{indice_sonda};
        sonda = probes.(nombre_sonda);

        fprintf( ...
            identificador_archivo, ...
            '  Sonda %-12s ➔ Pedida: [%6.2f, %6.2f, %6.2f] mm | Real: [%6.2f, %6.2f, %6.2f] mm (In_Domain=%d)\n', ...
            nombre_sonda, ...
            sonda.coord_mm, ...
            sonda.coord_real, ...
            sonda.in_domain);
    end

    fprintf(identificador_archivo, '=========================================================================\n');
end

function escribir_tabla_sondas(identificador_archivo, datos_solucion, nombres_sondas)
% escribir_tabla_sondas
% Escribe la tabla temporal de temperaturas para todas las sondas.

    fprintf(identificador_archivo, '%-12s', 'Tiempo(min)');
    for indice_sonda = 1:numel(nombres_sondas)
        fprintf(identificador_archivo, '\t%-18s', [nombres_sondas{indice_sonda} '(°C)']);
    end
    fprintf(identificador_archivo, '\n');

    vector_tiempo = datos_solucion.t_min;
    numero_instantes = numel(vector_tiempo);

    for indice_tiempo = 1:numero_instantes
        fprintf(identificador_archivo, '%-12.4f', vector_tiempo(indice_tiempo));

        for indice_sonda = 1:numel(nombres_sondas)
            nombre_sonda = nombres_sondas{indice_sonda};
            valor_temperatura = datos_solucion.probes.(nombre_sonda).T(indice_tiempo);

            if isnan(valor_temperatura)
                fprintf(identificador_archivo, '\t%-18s', 'NaN');
            else
                fprintf(identificador_archivo, '\t%-18.4f', valor_temperatura);
            end
        end

        fprintf(identificador_archivo, '\n');
    end
end

%% =========================================================================
%% UTILIDADES
%% =========================================================================
function [triangulos_salida, nodos_salida] = suavizar_malla_laplaciano(triangulos, nodos, numero_iteraciones)
% suavizar_malla_laplaciano
% Aplica suavizado Laplaciano simple sobre la malla triangular. Cada nodo se
% actualiza al promedio de sus vecinos inmediatos durante N iteraciones.

    nodos_salida = nodos;
    numero_nodos = size(nodos, 1);

    for iteracion = 1:numero_iteraciones
        nodos_nuevos = nodos_salida;

        for indice_nodo = 1:numero_nodos
            [filas_triangulos, ~] = find(triangulos == indice_nodo);
            if isempty(filas_triangulos)
                continue;
            end

            nodos_vecinos = unique(triangulos(filas_triangulos, :));
            nodos_vecinos(nodos_vecinos == indice_nodo) = [];

            if ~isempty(nodos_vecinos)
                nodos_nuevos(indice_nodo, :) = mean(nodos_salida(nodos_vecinos, :), 1);
            end
        end

        nodos_salida = nodos_nuevos;
    end

    triangulos_salida = triangulos;
end

function crear_carpeta_si_no_existe(ruta_carpeta)
% crear_carpeta_si_no_existe
% Crea una carpeta solo si aún no existe.

    if ~exist(ruta_carpeta, 'dir')
        mkdir(ruta_carpeta);
    end
end

function imprimir_separador()
% imprimir_separador
% Imprime un separador visual de consola.

    log_exportador('%s\n', repmat('-', 1, 75));
end

function subcarpeta = subcarpeta_optimizador_desde_metadata(nombre_modelo, tag_dataset)
    tipo = extraer_primer_match(nombre_modelo, {'Doble_slot', 'Monopolo', 'Un_slot'}, 'Tipo_desconocido');
    antena = regexp(nombre_modelo, '\d+ant', 'match', 'once');
    if isempty(antena)
        antena = 'antenas_desconocidas';
    end
    caso = regexp(tag_dataset, 'c(\d+)', 'tokens', 'once');
    if isempty(caso)
        caso_txt = 'Caso_desconocido';
    else
        caso_txt = sprintf('Caso_%s', caso{1});
    end
    potencia = regexp(tag_dataset, 'p(\d+)', 'tokens', 'once');
    if isempty(potencia)
        potencia_txt = 'Potencia_desconocida';
    else
        potencia_txt = sprintf('Potencia_%sW', potencia{1});
    end
    subcarpeta = fullfile(tipo, antena, caso_txt, potencia_txt);
end

function [es_util, motivo] = dataset_exportable_por_metadata(nombre_modelo, tag_dataset)
    es_util = false;
    motivo = '';

    tipo = extraer_primer_match(nombre_modelo, {'Doble_slot', 'Monopolo', 'Un_slot'}, '');
    if isempty(tipo)
        motivo = 'tipo de antena no detectable en nombre de modelo';
        return;
    end

    antena = regexp(nombre_modelo, '\d+ant', 'match', 'once');
    if isempty(antena)
        motivo = 'numero de antenas no detectable en nombre de modelo';
        return;
    end

    [tiene_metadata, ~, ~] = extraer_metadata_tag_dataset(tag_dataset);
    if ~tiene_metadata
        motivo = 'tag sin metadata de caso/potencia generada por COMSOL';
        return;
    end

    es_util = true;
end

function [tiene_metadata, caso, potencia] = extraer_metadata_tag_dataset(tag_dataset)
    tag = lower(char(tag_dataset));
    caso_token = regexp(tag, '(?:^|[_-])(?:c|caso)_?(\d+)(?=$|[_-])', 'tokens', 'once');
    potencia_token = regexp(tag, '(?:^|[_-])(?:p|potencia)_?(\d+)(?:w)?(?=$|[_-])', 'tokens', 'once');
    if isempty(potencia_token)
        potencia_token = regexp(tag, '(\d+)\s*w', 'tokens', 'once');
    end
    tiene_metadata = ~isempty(caso_token) && ~isempty(potencia_token);
    caso = NaN;
    potencia = NaN;
    if tiene_metadata
        caso = str2double(caso_token{1});
        potencia = str2double(potencia_token{1});
    end
end

function valor = extraer_primer_match(texto, candidatos, valor_default)
    valor = valor_default;
    for k = 1:numel(candidatos)
        if contains(texto, candidatos{k}, 'IgnoreCase', true)
            valor = candidatos{k};
            return;
        end
    end
end

function logger = configurar_log_exportador(nuevo_logger)
    persistent logger_actual
    if nargin > 0
        logger_actual = nuevo_logger;
    end
    logger = logger_actual;
end

function log_exportador(formato, varargin)
    logger = configurar_log_exportador();
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
