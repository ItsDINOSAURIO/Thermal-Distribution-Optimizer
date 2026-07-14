function varargout = exportador_masivo_correcciones(varargin)
%EXPORTADOR_MASIVO_CORRECCIONES Aplica correlaciones a datasets completos.
%
% Flujo:
%   1. Carga un Dataset_Termico_Masivo.mat.
%   2. Recorre uno o varios .mat de correccion termica.
%   3. Exporta datasets corregidos completos.
%   4. Opcionalmente exporta STL/TXT corregidos y MAT voxelizados.
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

    if nargin >= 1 && ischar(varargin{1}) && strcmpi(varargin{1}, 'run')
        if nargin >= 2
            config = varargin{2};
        else
            config = struct();
        end
        resumen = ejecutar_exportador_masivo_correcciones(config);
        if nargout > 0
            varargout{1} = resumen;
        end
        return;
    end

    lanzar_ui_exportador_masivo_correcciones();
    if nargout > 0
        varargout{1} = [];
    end
end

function lanzar_ui_exportador_masivo_correcciones()
    theme = tesis_auxiliares('tema_ui');
    paths = tesis_auxiliares('asegurar_dataset_paths');

    fig = uifigure('Name', 'Exportador Masivo de Correcciones', ...
        'Position', [80 80 980 620], ...
        'Color', theme.colors.bg);

    pnl = uipanel(fig, 'Title', 'Configuracion', ...
        'Position', [12 12 370 596]);
    gl = uigridlayout(pnl, [19, 2]);
    gl.RowHeight = {24, 30, 24, 30, 24, 30, 24, 30, 24, 30, ...
        24, 30, 30, 30, 30, 30, 30, 30, '1x'};
    gl.ColumnWidth = {130, '1x'};

    uilabel(gl, 'Text', 'Dataset masivo:', 'FontWeight', 'bold');
    lbl_dataset = uilabel(gl, 'Text', paths.dataset_termico_masivo, ...
        'Interpreter', 'none');
    lbl_dataset.Layout.Column = 2;
    btn_dataset = uibutton(gl, 'Text', 'Seleccionar dataset');
    btn_dataset.Layout.Column = [1 2];

    uilabel(gl, 'Text', 'Correlaciones:', 'FontWeight', 'bold');
    lbl_corr = uilabel(gl, 'Text', paths.correlaciones, 'Interpreter', 'none');
    lbl_corr.Layout.Column = 2;
    btn_corr = uibutton(gl, 'Text', 'Seleccionar carpeta correlaciones');
    btn_corr.Layout.Column = [1 2];

    uilabel(gl, 'Text', 'Temperatura STL min:');
    ed_tmin = uieditfield(gl, 'numeric', 'Value', 55);
    uilabel(gl, 'Text', 'Alpha radius:');
    ed_alpha = uieditfield(gl, 'numeric', 'Value', 0);
    uilabel(gl, 'Text', 'Suavizado:');
    ed_smooth = uieditfield(gl, 'numeric', 'Value', 1, 'Limits', [0 20]);
    uilabel(gl, 'Text', 'Resolucion MAT:');
    ed_res = uieditfield(gl, 'numeric', 'Value', 0.5, 'Limits', [eps Inf]);
    uilabel(gl, 'Text', 'Tipo MAT:');
    dd_tipo = uidropdown(gl, 'Items', {'sdf', 'mascara', 'tsdf'}, 'Value', 'sdf');

    chk_overwrite = uicheckbox(gl, 'Text', 'Sobrescribir datasets corregidos', ...
        'Value', false);
    chk_overwrite.Layout.Column = [1 2];

    btn_step_dataset = uibutton(gl, 'Text', '1. Generar datasets corregidos');
    btn_step_dataset.Layout.Column = [1 2];
    tesis_auxiliares('tema_ui', 'button', btn_step_dataset, 'secondary');
    btn_step_stl = uibutton(gl, 'Text', '2. Exportar STL/TXT corregidos');
    btn_step_stl.Layout.Column = [1 2];
    tesis_auxiliares('tema_ui', 'button', btn_step_stl, 'secondary');
    btn_step_mat = uibutton(gl, 'Text', '3. Preprocesar MAT corregidos');
    btn_step_mat.Layout.Column = [1 2];
    tesis_auxiliares('tema_ui', 'button', btn_step_mat, 'secondary');

    btn_run = uibutton(gl, 'Text', 'Ejecutar todo');
    btn_run.Layout.Column = [1 2];
    tesis_auxiliares('tema_ui', 'button', btn_run, 'success');
    btn_open = uibutton(gl, 'Text', 'Abrir carpeta DATASETS');
    btn_open.Layout.Column = [1 2];

    pnl_log = uipanel(fig, 'Title', 'Registro de eventos', ...
        'Position', [398 12 570 596]);
    txt_log = uitextarea(pnl_log, ...
        'Position', [8 8 554 560], ...
        'Editable', 'off', ...
        'Value', {'Listo.'});

    ruta_dataset = paths.dataset_termico_masivo;
    carpeta_corr = paths.correlaciones;

    btn_dataset.ButtonPushedFcn = @(~,~) seleccionar_dataset();
    btn_corr.ButtonPushedFcn = @(~,~) seleccionar_correlaciones();
    btn_step_dataset.ButtonPushedFcn = @(~,~) ejecutar_desde_ui('dataset');
    btn_step_stl.ButtonPushedFcn = @(~,~) ejecutar_desde_ui('stl');
    btn_step_mat.ButtonPushedFcn = @(~,~) ejecutar_desde_ui('mat');
    btn_run.ButtonPushedFcn = @(~,~) ejecutar_desde_ui('todo');
    btn_open.ButtonPushedFcn = @(~,~) abrir_carpeta_exportador(paths.root);

    function seleccionar_dataset()
        [file, folder] = uigetfile('*.mat', 'Selecciona Dataset_Termico_Masivo.mat', ...
            paths.datasets_masivos);
        if isequal(file, 0), return; end
        ruta_dataset = fullfile(folder, file);
        lbl_dataset.Text = ruta_dataset;
    end

    function seleccionar_correlaciones()
        folder = uigetdir(paths.correlaciones, 'Selecciona carpeta de correlaciones');
        if isequal(folder, 0), return; end
        carpeta_corr = folder;
        lbl_corr.Text = carpeta_corr;
    end

    function log_ui(formato, varargin)
        msg = sprintf(formato, varargin{:});
        marca = char(datetime('now', 'Format', 'HH:mm:ss'));
        txt_log.Value = [{sprintf('[%s] %s', marca, msg)}; txt_log.Value(:)];
        drawnow limitrate;
    end

    function ejecutar_desde_ui(modo)
        if nargin < 1 || isempty(modo)
            modo = 'todo';
        end
        try
            txt_log.Value = [repmat({''}, 5, 1); txt_log.Value(:)];
            cfg = construir_config_ui(modo);
            log_ui('Modo seleccionado: %s', modo);
            ejecutar_exportador_masivo_correcciones(cfg);
            log_ui('Proceso completado: %s.', modo);
        catch ME
            log_ui('ERROR: %s', ME.message);
            uialert(fig, ME.message, 'Error exportador');
        end
    end

    function cfg = construir_config_ui(modo)
        switch lower(modo)
            case 'dataset'
                exportar_stl = false;
                exportar_mat = false;
            case 'stl'
                exportar_stl = true;
                exportar_mat = false;
            case 'mat'
                exportar_stl = false;
                exportar_mat = true;
            otherwise
                exportar_stl = true;
                exportar_mat = true;
        end
        cfg = struct( ...
            'ruta_dataset', ruta_dataset, ...
            'carpeta_correlaciones', carpeta_corr, ...
            'temperatura_min_stl', ed_tmin.Value, ...
            'radio_alpha', ed_alpha.Value, ...
            'iteraciones_suavizado', round(ed_smooth.Value), ...
            'resolucion_preprocesamiento', ed_res.Value, ...
            'tipo_preprocesamiento', dd_tipo.Value, ...
            'exportar_stl', exportar_stl, ...
            'exportar_mat', exportar_mat, ...
            'sobrescribir', chk_overwrite.Value, ...
            'logfn', @log_ui);
    end
end

function resumen = ejecutar_exportador_masivo_correcciones(config)
    paths = tesis_auxiliares('asegurar_dataset_paths');
    logfn = obtener_campo_config_exportador(config, 'logfn', []);
    if isempty(logfn)
        logfn = @(varargin) fprintf([varargin{1} '\n'], varargin{2:end});
    end

    ruta_dataset = obtener_campo_config_exportador(config, ...
        'ruta_dataset', paths.dataset_termico_masivo);
    carpeta_correlaciones = obtener_campo_config_exportador(config, ...
        'carpeta_correlaciones', paths.correlaciones);
    rutas_correcciones = obtener_campo_config_exportador(config, ...
        'rutas_correcciones', {});
    if isempty(rutas_correcciones)
        archivos = dir(fullfile(carpeta_correlaciones, '*.mat'));
        rutas_correcciones = arrayfun(@(a) fullfile(a.folder, a.name), ...
            archivos, 'UniformOutput', false);
    end

    if ~isfile(ruta_dataset)
        error('No existe el dataset masivo: %s', ruta_dataset);
    end
    if isempty(rutas_correcciones)
        error('No se encontraron correlaciones .mat en: %s', carpeta_correlaciones);
    end

    exportar_stl = obtener_campo_config_exportador(config, 'exportar_stl', true);
    exportar_mat = obtener_campo_config_exportador(config, 'exportar_mat', true);
    carpeta_salida_datasets = obtener_campo_config_exportador(config, ...
        'carpeta_salida_datasets', paths.datasets_corregidos);
    carpeta_salida_stl = obtener_campo_config_exportador(config, ...
        'carpeta_salida_stl', paths.distribuciones_stl_corregidas);
    carpeta_salida_mat = obtener_campo_config_exportador(config, ...
        'carpeta_salida_mat', paths.distribuciones_mat_corregidas);
    temperatura_min_stl = obtener_campo_config_exportador(config, ...
        'temperatura_min_stl', 55);
    radio_alpha = obtener_campo_config_exportador(config, 'radio_alpha', 0);
    iteraciones_suavizado = obtener_campo_config_exportador(config, ...
        'iteraciones_suavizado', 1);
    resolucion_pre = obtener_campo_config_exportador(config, ...
        'resolucion_preprocesamiento', 0.5);
    tipo_pre = obtener_campo_config_exportador(config, ...
        'tipo_preprocesamiento', 'sdf');
    sobrescribir = obtener_campo_config_exportador(config, 'sobrescribir', false);

    resumen = struct('correlaciones', {{}}, 'datasets', {{}}, ...
        'stl', {{}}, 'mat', {{}});
    dataset_base = [];
    logfn('Dataset base: %s', ruta_dataset);
    logfn('Correlaciones detectadas: %d', numel(rutas_correcciones));

    for ci = 1:numel(rutas_correcciones)
        ruta_corr = rutas_correcciones{ci};
        if ~isfile(ruta_corr)
            logfn('[WARN] Correlacion inexistente omitida: %s', ruta_corr);
            continue;
        end
        [~, nombre_corr] = fileparts(ruta_corr);
        tag_corr = sanitizar_tag_exportador(nombre_corr);
        filtro_corr = crear_filtro_correlacion_exportador(nombre_corr, tag_corr);
        logfn('---');
        logfn('[%d/%d] Correccion: %s', ci, numel(rutas_correcciones), nombre_corr);
        logfn('Filtro de correlacion: antenas=%s | potencia=%s | caso=%s', ...
            valor_filtro_log_exportador(filtro_corr.antena), ...
            valor_filtro_log_exportador(filtro_corr.potencia), ...
            valor_filtro_log_exportador(filtro_corr.caso));

        carpeta_dataset_corr = fullfile(carpeta_salida_datasets, tag_corr);
        asegurar_carpeta_exportador(carpeta_dataset_corr);
        ruta_out_dataset = fullfile(carpeta_dataset_corr, ...
            sprintf('Dataset_corregido_%s.mat', tag_corr));
        ruta_done_dataset = [ruta_out_dataset '.done'];
        dataset_vigente = dataset_corregido_vigente_exportador( ...
            ruta_out_dataset, ruta_done_dataset, filtro_corr);
        dataset_regenerado = false;
        if dataset_vigente && ~sobrescribir
            logfn('Fase 1/3 dataset corregido vigente. Omitido: %s', ruta_out_dataset);
        else
            if isempty(dataset_base)
                logfn('Cargando dataset base para correccion...');
                dataset_base = cargar_dataset_base_exportador(ruta_dataset);
            end
            corr_raw = load(ruta_corr);
            if ~isfield(corr_raw, 'correccion_termica')
                logfn('[WARN] Omitida: no contiene correccion_termica.');
                continue;
            end
            corr = corr_raw.correccion_termica;
            logfn('Fase 1/3 corrigiendo dataset completo...');
            dataset_corr = corregir_dataset_completo_exportador( ...
                dataset_base, corr, config, logfn, filtro_corr);
            dataset = dataset_corr;
            save(ruta_out_dataset, 'dataset', '-v7.3');
            escribir_done_exportador(ruta_done_dataset, ruta_dataset, ruta_corr, filtro_corr);
            dataset_regenerado = true;
            logfn('Dataset corregido guardado: %s', ruta_out_dataset);
        end

        resumen.correlaciones{end+1} = ruta_corr;
        resumen.datasets{end+1} = ruta_out_dataset;

        carpeta_stl = carpeta_salida_stl;
        if exportar_stl
            logfn('Fase 2/3 exportando STL/TXT corregidos...');
            if dataset_regenerado
                limpiar_salidas_por_filtro_exportador(carpeta_stl, filtro_corr, logfn);
            end
            cfg_stl = struct( ...
                'ruta_mat_entrada', ruta_out_dataset, ...
                'carpeta_exportacion', carpeta_stl, ...
                'mantener_figuras', true, ...
                'temperatura_min_stl', max(temperatura_min_stl, 0), ...
                'radio_alpha', radio_alpha, ...
                'iteraciones_suavizado', iteraciones_suavizado, ...
                'logfn', logfn);
            comsol_mat_exportador_masivo('run', cfg_stl);
            resumen.stl{end+1} = carpeta_stl;
        end

        if exportar_mat
            logfn('Fase 3/3 preprocesando STL corregidos a MAT...');
            if ~exportar_stl && ~isfolder(carpeta_stl)
                error(['Para preprocesar MAT se requiere la carpeta STL corregida: %s. ', ...
                    'Activa exportar_stl o genera esa carpeta previamente.'], carpeta_stl);
            end
            carpeta_mat = carpeta_salida_mat;
            if dataset_regenerado || exportar_stl
                limpiar_salidas_por_filtro_exportador(carpeta_mat, filtro_corr, logfn);
            end
            cfg_pre = struct( ...
                'carpeta_stl', carpeta_stl, ...
                'carpeta_salida', carpeta_mat, ...
                'resolucion', resolucion_pre, ...
                'tipo_procesamiento', tipo_pre, ...
                'filtro_metadata', filtro_corr, ...
                'logfn', logfn);
            preprocesar_stl_a_mat('run', cfg_pre);
            resumen.mat{end+1} = carpeta_mat;
        end
    end
end

function dataset_corr = corregir_dataset_completo_exportador(dataset_base, corr, config, logfn, filtro_corr)
    dataset_corr = struct();
    if isfield(dataset_base, 'session_meta')
        dataset_corr.session_meta = dataset_base.session_meta;
    end
    modelos = fieldnames(dataset_base);
    modelos = modelos(~strcmp(modelos, 'session_meta'));
    n_modelos_corregidos = 0;
    n_datasets_corregidos = 0;
    for mi = 1:numel(modelos)
        modelo = modelos{mi};
        if ~modelo_pasa_filtro_correlacion(modelo, filtro_corr)
            logfn('Modelo omitido por correlacion: %s', modelo);
            continue;
        end
        dsNames = fieldnames(dataset_base.(modelo));
        dsNames = dsNames(~strcmp(dsNames, 'session_meta'));
        ds_validos = {};
        for di = 1:numel(dsNames)
            dsName = dsNames{di};
            ds = dataset_base.(modelo).(dsName);
            if isstruct(ds) && isfield(ds, 'snapshots') && ~isempty(ds.snapshots) && ...
                    dataset_pasa_filtro_correlacion(dsName, filtro_corr)
                ds_validos{end+1} = dsName; %#ok<AGROW>
            end
        end
        if isempty(ds_validos)
            logfn('Modelo %s sin datasets compatibles con la correlacion.', modelo);
            continue;
        end
        if isfield(dataset_base.(modelo), 'session_meta')
            dataset_corr.(modelo).session_meta = dataset_base.(modelo).session_meta;
        end
        n_modelos_corregidos = n_modelos_corregidos + 1;
        logfn('Modelo %d/%d: %s (%d datasets compatibles)', ...
            mi, numel(modelos), modelo, numel(ds_validos));
        for di = 1:numel(ds_validos)
            dsName = ds_validos{di};
            ds = dataset_base.(modelo).(dsName);
            dataset_corr.(modelo).(dsName) = corregir_dataset_individual_exportador( ...
                ds, corr, config);
            n_datasets_corregidos = n_datasets_corregidos + 1;
            if mod(di, max(1, floor(numel(ds_validos) / 5))) == 0 || di == numel(ds_validos)
                logfn('  Datasets corregidos %d/%d.', di, numel(ds_validos));
            end
        end
    end
    if n_datasets_corregidos == 0
        error(['La correlacion %s no encontro datasets compatibles en el dataset base. ', ...
            'Revisa antenas/potencia/caso en nombres de correlacion y dataset.'], filtro_corr.tag);
    end
    logfn('Resumen correccion: modelos=%d | datasets=%d.', ...
        n_modelos_corregidos, n_datasets_corregidos);
end

function dataset_base = cargar_dataset_base_exportador(ruta_dataset)
    raw = load(ruta_dataset);
    if isfield(raw, 'dataset')
        dataset_base = raw.dataset;
    else
        campos = fieldnames(raw);
        dataset_base = raw.(campos{1});
    end
end

function filtro = crear_filtro_correlacion_exportador(nombre_corr, tag_corr)
    raw = lower(regexprep(char(nombre_corr), '[^\w]+', '_'));
    ant = regexp(raw, '(\d+)_?ant(?:enas)?', 'tokens', 'once');
    potencia = regexp(raw, '(\d+)_?w(?:att)?', 'tokens', 'once');
    caso = regexp(raw, '(?:^|_)c(?:aso)?_?(\d+)(?=_|$)', 'tokens', 'once');
    filtro = struct( ...
        'tag', tag_corr, ...
        'antena', '', ...
        'potencia', '', ...
        'caso', '');
    if ~isempty(ant)
        filtro.antena = sprintf('%sant', ant{1});
    end
    if ~isempty(potencia)
        filtro.potencia = sprintf('p%s', potencia{1});
    end
    if ~isempty(caso)
        filtro.caso = sprintf('c%s', caso{1});
    end
end

function tf = modelo_pasa_filtro_correlacion(nombre_modelo, filtro)
    tf = true;
    if ~isempty(filtro.antena)
        ant_modelo = regexp(lower(nombre_modelo), '\d+ant', 'match', 'once');
        tf = tf && strcmpi(ant_modelo, filtro.antena);
    end
end

function tf = dataset_pasa_filtro_correlacion(dsName, filtro)
    tag = lower(char(dsName));
    tf = true;
    if ~isempty(filtro.potencia)
        potencia = regexp(tag, 'p(\d+)', 'tokens', 'once');
        if isempty(potencia)
            tf = false;
        else
            tf = tf && strcmpi(sprintf('p%s', potencia{1}), filtro.potencia);
        end
    end
    if ~isempty(filtro.caso)
        caso = regexp(tag, 'c(\d+)', 'tokens', 'once');
        if isempty(caso)
            tf = false;
        else
            tf = tf && strcmpi(sprintf('c%s', caso{1}), filtro.caso);
        end
    end
end

function txt = valor_filtro_log_exportador(valor)
    if isempty(valor)
        txt = 'todos';
    else
        txt = valor;
    end
end

function ds_corr = corregir_dataset_individual_exportador(ds, corr, config)
    ds_corr = ds;
    t_vec = obtener_tiempos_dataset_exportador(ds);
    umbral = obtener_umbral_ablacion_exportador(ds, config);
    tiene_full = isfield(ds, 'full_field') && isfield(ds.full_field, 'points') && ...
        isfield(ds.full_field, 'T_C') && size(ds.full_field.T_C, 2) >= numel(ds.snapshots);

    if tiene_full
        puntos_full = double(ds.full_field.points);
        T_full = double(ds.full_field.T_C);
        T_base = T_full(:, 1);
        T_full_corr = nan(size(T_full), 'single');
        for ti = 1:size(T_full, 2)
            t_min = obtener_tiempo_indice_exportador(t_vec, ds.snapshots, ti);
            T_full_corr(:, ti) = single(aplicar_correccion_exportador( ...
                T_full(:, ti), T_base, t_min, puntos_full, corr, config));
        end
        ds_corr.full_field.T_C = T_full_corr;
        ds_corr.full_field.descripcion = ...
            'Campo completo corregido por exportador_masivo_correcciones.';
    end

    for ti = 1:numel(ds.snapshots)
        t_min = obtener_tiempo_indice_exportador(t_vec, ds.snapshots, ti);
        if tiene_full && size(ds_corr.full_field.T_C, 2) >= ti
            puntos = puntos_full;
            T_corr = double(ds_corr.full_field.T_C(:, ti));
        else
            if isfield(ds.snapshots(ti), 'points')
                puntos = double(ds.snapshots(ti).points);
            else
                puntos = zeros(0, 3);
            end
            if isfield(ds.snapshots(ti), 'T')
                T_orig = double(ds.snapshots(ti).T(:));
            else
                T_orig = zeros(0, 1);
            end
            if isempty(T_orig) || isempty(puntos)
                ds_corr.snapshots(ti).points = zeros(0, 3);
                ds_corr.snapshots(ti).T = zeros(0, 1);
                continue;
            end
            T_base_local = repmat(T_orig(1), size(T_orig));
            T_corr = aplicar_correccion_exportador(T_orig, T_base_local, ...
                t_min, puntos, corr, config);
        end
        validos = isfinite(T_corr) & all(isfinite(puntos), 2);
        mask = validos & T_corr >= umbral;
        ds_corr.snapshots(ti).points = puntos(mask, :);
        ds_corr.snapshots(ti).T = T_corr(mask);
        ds_corr.snapshots(ti).points_ablacion_corregida = puntos(mask, :);
        ds_corr.snapshots(ti).T_ablacion_corregida = T_corr(mask);
        ds_corr.snapshots(ti).n_pts_ablacion_corregida = sum(mask);
        ds_corr.snapshots(ti).n_pts_filtered = sum(mask);
        ds_corr.snapshots(ti).n_pts_total = sum(validos);
        ds_corr.snapshots(ti).t_correccion_rel_min = calcular_t_rel_exportador(t_min, corr);
        ds_corr.snapshots(ti).correccion_activa = true;
        if any(validos)
            ds_corr.snapshots(ti).T_min_C = min(T_corr(validos));
            ds_corr.snapshots(ti).T_max_C = max(T_corr(validos));
        else
            ds_corr.snapshots(ti).T_min_C = NaN;
            ds_corr.snapshots(ti).T_max_C = NaN;
        end
    end

    ds_corr = corregir_sondas_exportador(ds_corr, corr, config);
    if ~isfield(ds_corr, 'metadata') || ~isstruct(ds_corr.metadata)
        ds_corr.metadata = struct();
    end
    ds_corr.metadata.correccion_termica = crear_metadata_correccion_exportador(corr, config);
end

function T_corr = aplicar_correccion_exportador(T_orig, T_base, t_min, puntos, corr, config)
    intensidad = obtener_campo_config_exportador(config, 'intensidad_correccion', 1);
    aplicar_offset = obtener_campo_config_exportador(config, 'aplicar_offset_base', true);
    T_corr = T_orig;
    zonas = obtener_zonas_exportador(corr);
    if ~isempty(zonas) && ~isempty(puntos) && size(puntos, 2) >= 3
        if size(puntos, 1) == 1 && numel(T_orig) > 1
            puntos = repmat(puntos, numel(T_orig), 1);
        end
        if size(puntos, 1) == numel(T_orig)
            for zi = 1:numel(zonas)
                zona = zonas(zi);
                mask = mascara_zona_exportador(puntos, zona, zi, numel(zonas));
                if ~any(mask), continue; end
                [factor_modelo, activo] = evaluar_factor_correccion_exportador(t_min, zona);
                if ~activo, continue; end
                factor = 1 + intensidad * (factor_modelo - 1);
                offset = 0;
                if aplicar_offset && isfield(zona, 'offset_base_C')
                    offset = intensidad * zona.offset_base_C;
                elseif aplicar_offset && isfield(corr, 'offset_base_C')
                    offset = intensidad * corr.offset_base_C;
                end
                T_corr(mask) = T_base(mask) + offset + ...
                    factor .* (T_orig(mask) - T_base(mask));
            end
            return;
        end
    end

    [factor_modelo, activo] = evaluar_factor_correccion_exportador(t_min, corr);
    if ~activo
        return;
    end
    factor = 1 + intensidad * (factor_modelo - 1);
    offset = 0;
    if aplicar_offset && isfield(corr, 'offset_base_C')
        offset = intensidad * corr.offset_base_C;
    end
    T_corr = T_base + offset + factor .* (T_orig - T_base);
end

function [factor, activo] = evaluar_factor_correccion_exportador(t_min, modelo)
    factor = 1;
    activo = false;
    if ~isfield(modelo, 't_rel_min') || ~isfield(modelo, 'factor_enfriamiento')
        return;
    end
    if isfield(modelo, 't_origen_simulacion_min') && isfinite(modelo.t_origen_simulacion_min)
        t0 = modelo.t_origen_simulacion_min;
    else
        t0 = 0;
    end
    t_rel = t_min - t0;
    t_vec = modelo.t_rel_min(:);
    f_vec = modelo.factor_enfriamiento(:);
    if numel(t_vec) < 2 || numel(t_vec) ~= numel(f_vec) || t_rel < min(t_vec) - 1e-9
        return;
    end
    if t_rel <= max(t_vec) + 1e-9
        factor = interp1(t_vec, f_vec, t_rel, 'pchip');
    elseif isfield(modelo, 'extrapolacion_factor')
        factor = extrapolar_factor_exportador(t_rel, modelo.extrapolacion_factor);
    else
        factor = f_vec(end);
    end
    factor = max(0, min(1, factor));
    activo = isfinite(factor);
end

function factor = extrapolar_factor_exportador(t_rel_min, modelo)
    if isempty(modelo) || ~isstruct(modelo) || ~isfield(modelo, 'metodo')
        factor = 1;
        return;
    end
    if strcmp(modelo.metodo, 'pca_temporal_embebido_ssa') && ...
            isfield(modelo, 'paso_min')
        factor = extrapolar_factor_pca_exportador(t_rel_min, modelo);
    elseif isfield(modelo, 'factor_inicio')
        factor = modelo.factor_inicio;
    else
        factor = 1;
    end
    factor = max(0, min(1, factor));
end

function factor = extrapolar_factor_pca_exportador(t_rel_min, modelo)
    dt = max(0, t_rel_min - modelo.t_inicio_min);
    if dt == 0
        factor = modelo.factor_inicio;
        return;
    end
    n_pasos = max(1, ceil(dt / modelo.paso_min));
    historia = modelo.historia_centrada(:);
    valores = zeros(n_pasos + 1, 1);
    valores(1) = modelo.factor_inicio;
    for paso = 1:n_pasos
        pred_centrado = sum(modelo.coeficientes_recurrencia(:) .* historia(:));
        pred = modelo.media_factor + pred_centrado;
        cambio = pred - valores(paso);
        cambio = max(-modelo.max_cambio_por_paso, ...
            min(modelo.max_cambio_por_paso, cambio));
        valores(paso + 1) = valores(paso) + cambio;
        historia = [historia(2:end); valores(paso + 1) - modelo.media_factor];
    end
    factor = valores(end);
    if isfield(modelo, 'limites_extrapolacion')
        factor = max(modelo.limites_extrapolacion(1), ...
            min(modelo.limites_extrapolacion(2), factor));
    end
end

function zonas = obtener_zonas_exportador(corr)
    zonas = struct([]);
    if isfield(corr, 'zonas') && ~isempty(corr.zonas)
        zonas = corr.zonas(:);
    end
end

function mask = mascara_zona_exportador(puntos, zona, idx_zona, n_zonas)
    z_min = -Inf;
    z_max = Inf;
    if isfield(zona, 'z_min_mm'), z_min = zona.z_min_mm; end
    if isfield(zona, 'z_max_mm'), z_max = zona.z_max_mm; end
    if idx_zona == n_zonas
        mask = puntos(:, 3) >= z_min & puntos(:, 3) <= z_max;
    else
        mask = puntos(:, 3) >= z_min & puntos(:, 3) < z_max;
    end
end

function ds_corr = corregir_sondas_exportador(ds_corr, corr, config)
    if ~isfield(ds_corr, 'probes') || ~isstruct(ds_corr.probes)
        return;
    end
    nombres = fieldnames(ds_corr.probes);
    t_vec = obtener_tiempos_dataset_exportador(ds_corr);
    for pi = 1:numel(nombres)
        nombre = nombres{pi};
        sonda = ds_corr.probes.(nombre);
        if ~isfield(sonda, 'T') || isempty(sonda.T)
            continue;
        end
        T = double(sonda.T(:));
        if isfield(sonda, 't_min') && numel(sonda.t_min) == numel(T)
            tv = double(sonda.t_min(:));
        else
            tv = t_vec(:);
            tv = tv(1:min(numel(tv), numel(T)));
            T = T(1:numel(tv));
        end
        coord = obtener_coordenada_sonda_exportador(sonda);
        T_base = repmat(T(1), size(T));
        T_corr = T;
        for ti = 1:numel(T)
            T_corr(ti) = aplicar_correccion_exportador(T(ti), T_base(ti), ...
                tv(ti), coord, corr, config);
        end
        ds_corr.probes.(nombre).T_original = reshape(sonda.T, size(sonda.T));
        ds_corr.probes.(nombre).T = reshape(T_corr, size(T_corr));
    end
end

function coord = obtener_coordenada_sonda_exportador(sonda)
    coord = [];
    campos = {'coord_mm', 'coords_mm', 'point_mm', 'pos_mm', ...
        'position_mm', 'coord', 'coords', 'point', 'position'};
    for ci = 1:numel(campos)
        campo = campos{ci};
        if isfield(sonda, campo)
            valor = double(sonda.(campo));
            if numel(valor) >= 3 && all(isfinite(valor(1:3)))
                coord = reshape(valor(1:3), 1, 3);
                return;
            end
        end
    end
end

function t_vec = obtener_tiempos_dataset_exportador(ds)
    if isfield(ds, 't_min') && ~isempty(ds.t_min)
        t_vec = double(ds.t_min(:));
    else
        t_vec = (0:numel(ds.snapshots)-1)';
    end
end

function t = obtener_tiempo_indice_exportador(t_vec, snapshots, idx)
    if numel(t_vec) >= idx
        t = t_vec(idx);
    elseif numel(snapshots) >= idx && isfield(snapshots(idx), 'time_min')
        t = snapshots(idx).time_min;
    else
        t = idx - 1;
    end
end

function t_rel = calcular_t_rel_exportador(t_min, corr)
    if isfield(corr, 't_origen_simulacion_min') && isfinite(corr.t_origen_simulacion_min)
        t_rel = t_min - corr.t_origen_simulacion_min;
    else
        t_rel = t_min;
    end
end

function umbral = obtener_umbral_ablacion_exportador(ds, config)
    umbral = obtener_campo_config_exportador(config, 'umbral_ablacion_C', []);
    if isempty(umbral)
        if isfield(ds, 'metadata') && isfield(ds.metadata, 'T_ablacion')
            umbral = ds.metadata.T_ablacion;
        else
            umbral = 60;
        end
    end
end

function meta = crear_metadata_correccion_exportador(corr, config)
    meta = struct( ...
        'convencion', 'factor_sobre_incremento_termico_local', ...
        'metodo', obtener_campo_correccion_exportador(corr, ...
            'metodo_recomendado', 'factor_incremento_pchip_pca_ssa'), ...
        'modo_espacial', obtener_campo_correccion_exportador(corr, ...
            'modo_espacial', 'global'), ...
        'intensidad_correccion', obtener_campo_config_exportador(config, ...
            'intensidad_correccion', 1), ...
        'aplicar_offset_base', obtener_campo_config_exportador(config, ...
            'aplicar_offset_base', true), ...
        't_rel_min', obtener_campo_correccion_exportador(corr, 't_rel_min', []), ...
        'factor_enfriamiento', obtener_campo_correccion_exportador(corr, ...
            'factor_enfriamiento', []), ...
        'zonas', obtener_campo_correccion_exportador(corr, 'zonas', struct([])), ...
        'fecha_aplicacion', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
end

function valor = obtener_campo_config_exportador(config, campo, valor_default)
    valor = valor_default;
    if isstruct(config) && isfield(config, campo) && ~isempty(config.(campo))
        valor = config.(campo);
    end
end

function valor = obtener_campo_correccion_exportador(corr, campo, valor_default)
    valor = valor_default;
    if isstruct(corr) && isfield(corr, campo) && ~isempty(corr.(campo))
        valor = corr.(campo);
    end
end

function tag = sanitizar_tag_exportador(txt)
    raw = lower(regexprep(char(txt), '[^\w]+', '_'));
    raw = regexprep(raw, '_+', '_');
    raw = regexprep(raw, '^_|_$', '');
    ant = regexp(raw, '(\d+)_?ant(?:enas)?', 'tokens', 'once');
    watt = regexp(raw, '(\d+)_?w(?:att)?', 'tokens', 'once');
    mins = regexp(raw, '(\d+)_?min', 'tokens', 'once');
    zonas = regexp(raw, 'zonas?(\d+)', 'tokens', 'once');
    sufijo = regexp(raw, '_(\d+)$', 'tokens', 'once');
    partes = {};
    if ~isempty(ant), partes{end+1} = sprintf('%sant', ant{1}); end
    if ~isempty(watt), partes{end+1} = sprintf('%sw', watt{1}); end
    if ~isempty(mins), partes{end+1} = sprintf('%smin', mins{1}); end
    if ~isempty(zonas), partes{end+1} = sprintf('z%s', zonas{1}); end
    if ~isempty(sufijo), partes{end+1} = sprintf('r%s', sufijo{1}); end
    if isempty(partes)
        tag = raw;
        if startsWith(tag, 'corr_')
            tag = tag(6:end);
        end
        if numel(tag) > 32
            tag = tag(1:32);
        end
    else
        tag = strjoin(partes, '_');
    end
    tag = regexprep(tag, '_+$', '');
    if isempty(tag), tag = 'correccion'; end
end

function asegurar_carpeta_exportador(folder)
    if ~isfolder(folder)
        mkdir(folder);
    end
end

function vigente = dataset_corregido_vigente_exportador(ruta_mat, ruta_done, filtro_corr)
    vigente = false;
    if ~isfile(ruta_mat) || ~isfile(ruta_done)
        return;
    end
    try
        contenido = fileread(ruta_done);
        vigente = contains(contenido, 'version=dataset_corregido_filtrado_v2') && ...
            contains(contenido, ['tag=' filtro_corr.tag]) && ...
            contains(contenido, ['antena=' filtro_corr.antena]) && ...
            contains(contenido, ['potencia=' filtro_corr.potencia]) && ...
            contains(contenido, ['caso=' filtro_corr.caso]);
    catch
        vigente = false;
    end
end

function escribir_done_exportador(ruta_done, ruta_dataset, ruta_corr, filtro_corr)
    fid = fopen(ruta_done, 'w');
    if fid < 0
        return;
    end
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'done=true\n');
    fprintf(fid, 'version=dataset_corregido_filtrado_v2\n');
    fprintf(fid, 'tag=%s\n', filtro_corr.tag);
    fprintf(fid, 'antena=%s\n', filtro_corr.antena);
    fprintf(fid, 'potencia=%s\n', filtro_corr.potencia);
    fprintf(fid, 'caso=%s\n', filtro_corr.caso);
    fprintf(fid, 'created_at=%s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    fprintf(fid, 'dataset=%s\n', ruta_dataset);
    fprintf(fid, 'correccion=%s\n', ruta_corr);
end

function limpiar_salidas_por_filtro_exportador(root_salida, filtro_corr, logfn)
    if ~isfolder(root_salida)
        return;
    end
    if isempty(filtro_corr.antena)
        logfn('[WARN] Limpieza omitida: correlacion sin numero de antenas detectable.');
        return;
    end

    tipos = obtener_subdirs_exportador(root_salida);
    n_limpias = 0;
    for ti = 1:numel(tipos)
        dir_tipo = fullfile(root_salida, tipos{ti});
        antenas = obtener_subdirs_exportador(dir_tipo);
        antenas = filtrar_valores_exportador(antenas, filtro_corr.antena);
        for ai = 1:numel(antenas)
            dir_antena = fullfile(dir_tipo, antenas{ai});
            casos = obtener_subdirs_exportador(dir_antena);
            if ~isempty(filtro_corr.caso)
                casos = filtrar_valores_exportador(casos, sprintf('Caso_%s', regexprep(filtro_corr.caso, '^c', '')));
            end
            for ci = 1:numel(casos)
                dir_caso = fullfile(dir_antena, casos{ci});
                potencias = obtener_subdirs_exportador(dir_caso);
                if ~isempty(filtro_corr.potencia)
                    potencias = filtrar_valores_exportador(potencias, ...
                        sprintf('Potencia_%sW', regexprep(filtro_corr.potencia, '^p', '')));
                end
                for pi = 1:numel(potencias)
                    dir_potencia = fullfile(dir_caso, potencias{pi});
                    limpiar_carpeta_generada_exportador(dir_potencia, root_salida, logfn);
                    n_limpias = n_limpias + 1;
                end
            end
        end
    end
    if n_limpias > 0
        logfn('Salidas corregidas previas limpiadas por metadata: %d carpeta(s).', n_limpias);
    end
end

function subdirs = obtener_subdirs_exportador(folder)
    info = dir(folder);
    info = info([info.isdir]);
    nombres = {info.name};
    subdirs = nombres(~ismember(nombres, {'.', '..'}));
end

function valores = filtrar_valores_exportador(valores, esperado)
    valores = valores(strcmpi(valores, esperado));
end

function limpiar_carpeta_generada_exportador(folder, root_permitido, logfn)
    if ~isfolder(folder)
        return;
    end
    folder_abs = char(java.io.File(folder).getCanonicalPath());
    root_abs = char(java.io.File(root_permitido).getCanonicalPath());
    if ~startsWith(folder_abs, [root_abs filesep], 'IgnoreCase', true)
        error('Limpieza cancelada: carpeta fuera de raiz permitida: %s', folder);
    end
    logfn('Limpiando salida generada previa: %s', folder_abs);
    rmdir(folder_abs, 's');
end

function abrir_carpeta_exportador(folder)
    if ~isfolder(folder)
        mkdir(folder);
    end
    if ispc
        winopen(folder);
    elseif ismac
        system(sprintf('open "%s"', folder));
    else
        system(sprintf('xdg-open "%s"', folder));
    end
end
