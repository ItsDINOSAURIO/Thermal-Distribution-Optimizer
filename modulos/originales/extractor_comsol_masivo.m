function extractor_comsol_masivo(varargin)
% =========================================================================
%  EXTRACTOR COMSOL MASIVO DE DATOS TÉRMICOS
% =========================================================================
%
%  FUNCIONALIDAD
%  Recorre modelos .mph, identifica datasets transitorios y extrae dos canales de datos: snapshots 3D de ablación y sondas puntuales T(t), guardando un .mat estructurado para postprocesamiento.
%
%  ESTÁNDAR DE LIMPIEZA
%  - Nombre principal y funciones auxiliares en snake_case.
%  - Variables de control y callbacks normalizados a español cuando no afectan
%    el esquema externo de datos.
%  - Se conserva la lógica numérica/original del módulo.
%  - Se conservan nombres de campos externos usados por archivos .mat, COMSOL
%    o módulos dependientes: dataset, snapshots, points, T, t_min, probes,
%    p_arreglo, entre otros.
% =========================================================================

% =========================================================================
%  COMSOL_EXTRACTOR_MASIVO
%
%  Extracción automática y masiva de datos térmicos desde modelos .mph.
%  Recorre todos los modelos de la carpeta raíz y genera UN ÚNICO .mat
%  con la información completa de cada modelo para postprocesado.
%
%  ESTRUCTURA DEL .mat DE SALIDA:
%    dataset.(nombre_modelo).(tag_dataset)
%      .snapshots(k)           Instante k (Canal A — zona de ablación)
%        .t_min                  Escalar — minuto
%        .points  [Nk x 3]       Coordenadas mm de puntos en zona de ablación
%        .T       [Nk x 1]       Temperatura en esos puntos (°C)
%        .T_min_C / .T_max_C     Rango global del instante
%        .n_pts_total / _filtered
%      .t_min     [nT x 1]     Minutos de todos los instantes
%      .probes                 Canal B — struct por sonda
%      .full_field
%        .points  [N x 3]       Rejilla compartida en mm (single)
%        .T_C     [N x nT]      Campo completo; NaN fuera del dominio
%        .label                  String identificador
%        .coord_mm [1x3]         Coordenada pedida (mm)
%        .coord_real [1x3]       Punto real más cercano (mm)
%        .t_min    [nT x 1]      Minutos
%        .T        [nT x 1]      Temperatura (°C), sin filtrar
%        .in_domain              true si el punto está dentro del dominio
%        .min_dist_mm            Distancia al nodo más cercano de la malla
%      .metadata               Parámetros de extracción y timestamps
%
%  NOTAS DE DISEÑO:
%    - Canal A: snapshot compatible con todos los puntos T >= temperatura_ablacion
%    - El campo completo se conserva sin eliminar temperaturas carbonizadas
%    - temperatura_carbonizacion se usa como indicador, no como filtro
%    - Canal B: sonda sin filtrar, réplica exacta del CutPoint de COMSOL
%    - Si una sonda queda fuera del dominio se hace snap al nodo más cercano
%    - Los modelos se liberan de memoria tras cada extracción
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
        lanzar_ui_extractor_comsol_masivo();
        return;
    end

    config_ui = struct();
    if nargin >= 2 && strcmpi(varargin{1}, 'run')
        config_ui = varargin{2};
    end
    configurar_log_extractor(obtener_campo_config(config_ui, 'logfn', []));
    limpieza_logger = onCleanup(@() configurar_log_extractor([]));

    clc;
    import com.comsol.model.*
    import com.comsol.model.util.*
    % Configuracion normalizada desde UI/CLI.
    config_extractor = normalizar_config_extractor(config_ui);
    ruta_raiz = obtener_campo_config(config_ui, 'ruta_raiz', '');
    archivo_salida_mat = obtener_campo_config(config_ui, ...
        'archivo_salida_mat', 'Dataset_Termico_Masivo.mat');
    ruta_salida_mat = obtener_campo_config(config_ui, 'ruta_salida_mat', '');
    temperatura_ablacion = config_extractor.temperatura_ablacion;
    temperatura_carbonizacion = config_extractor.temperatura_carbonizacion;
    numero_grilla = config_extractor.numero_grilla;
    dominio_hueso = config_extractor.dominio_hueso;
    tiempos_min = config_extractor.tiempos_min;
    puntos_sonda = config_extractor.puntos_sonda;
    etiquetas_sonda = config_extractor.etiquetas_sonda;
    numero_iteraciones_suavizado = config_extractor.numero_iteraciones_suavizado;
    radio_alpha = config_extractor.radio_alpha;
    desfase_1antena = config_extractor.desfase_1antena;
    sep = @() log_extractor('%s\n', repmat('─', 1, 72));
    log_extractor('\n╔════════════════════════════════════════════════════════════╗\n');
    log_extractor('║        COMSOL EXTRACTOR MASIVO — dual-canal               ║\n');
    log_extractor('╚════════════════════════════════════════════════════════════╝\n\n');
    % ── Selección de carpeta raíz ─────────────────────────────────────────
    if isempty(ruta_raiz)
        ruta_raiz = uigetdir(pwd, 'Selecciona la carpeta raíz con los modelos .mph');
        if isequal(ruta_raiz, 0)
            log_extractor('Cancelado por el usuario.\n');
            return;
        end
    end
    log_extractor('Carpeta raíz : %s\n', ruta_raiz);
    % ── Validar etiquetas de sondas ──────────────────────────────────────
    nProbes = size(puntos_sonda, 1);
    if isempty(etiquetas_sonda) || numel(etiquetas_sonda) ~= nProbes
        etiquetas_sonda = arrayfun(@(k) sprintf('P%d', k), 1:nProbes, 'UniformOutput', false);
    end
    % ── Buscar todos los .mph de forma recursiva ─────────────────────────
    mph_list = dir(fullfile(ruta_raiz, '**', '*.mph'));
    mph_list = mph_list(~[mph_list.isdir]);
    n_modelos_total = numel(mph_list);
    [mph_list, resumen_filtros] = aplicar_filtros_modelos_mph(mph_list, config_extractor);
    log_extractor('Modelos .mph detectados antes de filtros: %d\n', n_modelos_total);
    log_extractor('Filtros de seleccion: %s\n', resumen_filtros);
    n_modelos = numel(mph_list);
    if n_modelos == 0
        log_extractor('[ERROR] No se encontraron archivos .mph en:\n  %s\n', ruta_raiz);
        return;
    end
    log_extractor('Modelos encontrados: %d\n\n', n_modelos);
    % ── Cargar .mat existente o iniciar uno nuevo ─────────────────────────
    if isempty(ruta_salida_mat)
        data_paths = tesis_auxiliares('asegurar_dataset_paths');
        out_path = fullfile(data_paths.datasets_masivos, archivo_salida_mat);
    else
        out_path = ruta_salida_mat;
        carpeta_out = fileparts(out_path);
        if ~isempty(carpeta_out) && ~isfolder(carpeta_out)
            mkdir(carpeta_out);
        end
    end
    if exist(out_path, 'file')
        log_extractor('Archivo de salida existente detectado — se agregarán nuevos modelos.\n');
        S = load(out_path);
        if isfield(S, 'dataset')
            dataset = S.dataset;
        else
            dataset = struct();
        end
    else
        dataset = struct();
    end
    % ── Metadatos globales de la sesión ───────────────────────────────────
    session_meta = struct( ...
        'fecha',          datestr(now), ...
        'ruta_raiz',      ruta_raiz, ...
        'T_ablacion',     temperatura_ablacion, ...
        'T_carboniz',     temperatura_carbonizacion, ...
        'n_grilla',       numero_grilla, ...
        'dominio_extraccion', dominio_hueso, ...
        'tiempos_min',    tiempos_min, ...
        'probe_points',   puntos_sonda, ...
        'probe_labels',   {etiquetas_sonda}, ...
        'n_smooth_iter',  numero_iteraciones_suavizado, ...
        'alpha_radius',   radio_alpha, ...
        'config_extractor', config_extractor);
    % =====================================================================
    %  BUCLE PRINCIPAL — un modelo a la vez
    % =====================================================================
    errores = {};
    for mi = 1:n_modelos
        mph_path   = fullfile(mph_list(mi).folder, mph_list(mi).name);
        model_name = crear_nombre_campo(mph_list(mi).name);
        firma_origen = crear_firma_archivo_mph(mph_path);
        sep();
        log_extractor('[Modelo %d/%d]  %s\n', mi, n_modelos, mph_list(mi).name);
        % Saltar si ya fue extraído en una sesión anterior, excepto cuando
        % sea un modelo 1ant con datos heredados sin el desfase corregido.
        if isfield(dataset, model_name)
            [reextraer_modelo, motivo_reextraccion] = debe_reextraer_modelo_existente( ...
                dataset.(model_name), mph_path, config_extractor, firma_origen);
            if reextraer_modelo
                log_extractor('  [AVISO] Modelo existente requiere reextraccion: %s\n', motivo_reextraccion);
            else
                log_extractor('  → Ya extraído. Saltando.\n');
                continue;
            end
        end
        % Cargar modelo
        try
            model = mphload(mph_path);
            log_extractor('  Modelo cargado OK.\n');
        catch ME_load
            log_extractor('  [ERROR] No se pudo cargar: %s\n', ME_load.message);
            errores{end+1} = sprintf('%s — carga: %s', model_name, ME_load.message); %#ok
            continue;
        end
        
        % ── TRATAMIENTO DE EXCEPCIÓN: MODELOS DE 1 ANTENA ─────────────────
        % Se genera una copia local para este modelo. Si la ruta o archivo
        % contiene '1ant', movemos dinámicamente el punto [0,0,34] a [1,1,34].
        [p_points, meta_desfase_1antena] = aplicar_desfase_1antena( ...
            puntos_sonda, mph_path, desfase_1antena);
        % ─────────────────────────────────────────────────────────────────
        
        % Resultado acumulado de este modelo
        model_data = struct();
        % ── Recorrer datasets del modelo ──────────────────────────────────
        try
            ds_tags = model.result.dataset.tags();
        catch
            ds_tags = {};
        end
        log_extractor('  Datasets detectados en el modelo: %d\n', numel(ds_tags));
        datasets_omitidos = struct('tag_dataset', {}, 'motivo', {}, ...
            'caso', {}, 'potencia_W', {});
        n_datasets_extraidos = 0;

        for di = 1:numel(ds_tags)
            tag = char(ds_tags(di));
            [debe_extraer, motivo_omision, metadata_dataset] = debe_extraer_dataset_por_config(tag, config_extractor);
            if ~debe_extraer
                datasets_omitidos(end + 1) = struct( ...
                    'tag_dataset', tag, ...
                    'motivo', motivo_omision, ...
                    'caso', metadata_dataset.caso, ...
                    'potencia_W', metadata_dataset.potencia_W); %#ok<AGROW>
                log_extractor('  [DS %d/%d %s] Omitido: %s\n', ...
                    di, numel(ds_tags), tag, motivo_omision);
                continue;
            end

            log_extractor('  [DS %d/%d %s] Metadata OK: caso=%d | potencia=%d W\n', ...
                di, numel(ds_tags), tag, metadata_dataset.caso, metadata_dataset.potencia_W);
            [t_sol_s, tag_sol] = extraer_tiempos(model, tag);
            if isempty(t_sol_s) || numel(t_sol_s) <= 1
                log_extractor('    Omitido: sin vector temporal transitorio util.\n');
                datasets_omitidos(end + 1) = struct( ...
                    'tag_dataset', tag, ...
                    'motivo', 'sin vector temporal transitorio util', ...
                    'caso', metadata_dataset.caso, ...
                    'potencia_W', metadata_dataset.potencia_W); %#ok<AGROW>
                continue;
            end
            t_sol_min = t_sol_s / 60;
            log_extractor('    Transitorio: %d pasos [%.4f - %.4f] min\n', ...
                numel(t_sol_min), min(t_sol_min), max(t_sol_min));
            log_extractor('    Dataset util: %s\n', tag);
            idx_ext = seleccionar_indices(t_sol_min, tiempos_min);
            nT      = numel(idx_ext);
            log_extractor('    Instantes a extraer: %d\n', nT);
            log_extractor('    Canal B - Sondas...\n');
            probes = extraer_sondas(model, tag, idx_ext, t_sol_min, ...
                p_points, etiquetas_sonda);
            log_extractor('    Canal A - Snapshots 3D...\n');
            [snapshots, bbox, campo_completo] = extraer_snapshots( ...
                model, tag, idx_ext, t_sol_min, ...
                numero_grilla, temperatura_ablacion, temperatura_carbonizacion, ...
                dominio_hueso);

            tag_field = crear_nombre_campo(tag);
            model_data.(tag_field).snapshots = snapshots;
            model_data.(tag_field).t_min     = t_sol_min(idx_ext);
            model_data.(tag_field).probes    = probes;
            model_data.(tag_field).bbox      = bbox;
            model_data.(tag_field).full_field = campo_completo;
            model_data.(tag_field).metadata  = struct( ...
                'model_file',    mph_path, ...
                'tag_dataset',   tag, ...
                'tag_sol',       tag_sol, ...
                'metadata_dataset', metadata_dataset, ...
                'idx_caso',      metadata_dataset.caso, ...
                'potencia_W',    metadata_dataset.potencia_W, ...
                'n_instantes',   nT, ...
                'T_ablacion',    temperatura_ablacion, ...
                'T_carboniz',    temperatura_carbonizacion, ...
                'n_grilla',      numero_grilla, ...
                'dominio_extraccion', dominio_hueso, ...
                'probe_points',  p_points, ...
                'desfase_1antena', meta_desfase_1antena, ...
                'n_smooth_iter', numero_iteraciones_suavizado, ...
                'alpha_radius',  radio_alpha, ...
                'unidades_coords', 'mm', ...
                'unidades_T',    'Celsius', ...
                'full_field_disponible', true, ...
                'snapshot_filtra_carbonizacion', false, ...
                'fecha_extraccion', datestr(now));
            n_datasets_extraidos = n_datasets_extraidos + 1;
            log_extractor('    Dataset "%s": %d snaps, %d sondas OK\n', tag, nT, nProbes);
        end % datasets

        model_data.datasets_omitidos = datasets_omitidos;
        model_data.source_signature = firma_origen;
        log_extractor('  Datasets extraidos: %d | omitidos: %d\n', ...
            n_datasets_extraidos, numel(datasets_omitidos));
        if ~isempty(datasets_omitidos)
            log_extractor('  Datasets omitidos del .mat:\n');
            for oi = 1:numel(datasets_omitidos)
                log_extractor('    - %s: %s\n', ...
                    datasets_omitidos(oi).tag_dataset, datasets_omitidos(oi).motivo);
            end
        end
        % Guardar datos del modelo en la estructura global
        dataset.(model_name) = model_data;
        dataset.(model_name).session_meta = session_meta;
        % Liberar modelo de memoria
        try
            ModelUtil.remove(model.tag());
        catch
        end
        log_extractor('\n  Modelo "%s" liberado.\n', model_name);
        % Guardado incremental tras cada modelo
        log_extractor('  Guardando: %s\n', out_path);
        save(out_path, 'dataset', '-v7.3');
    end % modelos
    % =====================================================================
    %  RESUMEN FINAL
    % =====================================================================
    sep();
    log_extractor('\nRESUMEN DE EXTRACCIÓN\n');
    sep();
    nombres = fieldnames(dataset);
    for k = 1:numel(nombres)
        nm  = nombres{k};
        if strcmp(nm, 'session_meta'); continue; end
        md  = dataset.(nm);
        ds_names = fieldnames(md);
        omitidos_resumen = struct([]);
        if isfield(md, 'datasets_omitidos')
            omitidos_resumen = md.datasets_omitidos;
        end
        ds_names = ds_names(~ismember(ds_names, {'session_meta', 'datasets_omitidos', 'source_signature'}));
        log_extractor('  %-28s  %d dataset(s)\n', nm, numel(ds_names));
        for j = 1:numel(ds_names)
            dn = ds_names{j};
            r  = md.(dn);
            if ~isfield(r, 'snapshots'); continue; end
            nf_v = [r.snapshots.n_pts_filtered];
            log_extractor('    %-20s  snaps=%d  abl:[%d–%d] mesh zones  t:[%.3f–%.3f] min\n', ...
                dn, numel(nf_v), min(nf_v), max(nf_v), min(r.t_min), max(r.t_min));
        end
        if ~isempty(omitidos_resumen)
            log_extractor('    omitidos=%d\n', numel(omitidos_resumen));
        end
    end
    if ~isempty(errores)
        sep();
        log_extractor('\nMODELOS CON ERRORES (%d):\n', numel(errores));
        for k = 1:numel(errores)
            log_extractor('  • %s\n', errores{k});
        end
    end
    sep();
    log_extractor('\nArchivo de salida: %s\n', out_path);
    log_extractor('Extracción masiva completada.\n\n');
end
% =========================================================================
%  FUNCIONES AUXILIARES
% =========================================================================
function [t_sol_s, tag_sol] = extraer_tiempos(model, tag)
    t_sol_s = [];
    tag_sol = '';
    try
        tag_sol = char(model.result.dataset(tag).getString('solution'));
        info    = mphsolinfo(model, 'soltag', tag_sol);
        if ~isempty(info.solvals)
            t_sol_s = info.solvals(:);
            return;
        end
    catch
    end
    try
        d_t = mpheval(model, 'T', 'dataset', tag, 'solnum', 1, 'edim', 2);
        if isfield(d_t, 't') && numel(d_t.t) > 1
            tv = double(d_t.t(:));
            if     max(tv) > 5000; t_sol_s = tv / 1000;
            elseif max(tv) > 60;   t_sol_s = tv;
            else;                  t_sol_s = tv * 60;
            end
        end
    catch
    end
end
function idx_ext = seleccionar_indices(t_sol_min, tiempos_min)
    if isempty(tiempos_min)
        idx_ext = (1:numel(t_sol_min))';
    else
        idx_ext = zeros(numel(tiempos_min), 1);
        for kk = 1:numel(tiempos_min)
            [~, idx_ext(kk)] = min(abs(t_sol_min - tiempos_min(kk)));
        end
        idx_ext = unique(idx_ext);
    end
end
function probes = extraer_sondas(model, tag, idx_ext, t_sol_min, ...
        puntos_sonda, etiquetas_sonda)
    nProbes = size(puntos_sonda, 1);
    probes  = struct();
    for p = 1:nProbes
        coord_mm   = puntos_sonda(p, :);
        lbl        = etiquetas_sonda{p};
        nT         = numel(idx_ext);
        min_d      = Inf;
        coord_real = coord_mm;   
        snap_usado = false;
        log_extractor('      [B%d] %-14s  [%.3g %.3g %.3g] mm\n', ...
            p, lbl, coord_mm(1), coord_mm(2), coord_mm(3));
        T_serie = interpolar_sonda(model, tag, idx_ext, coord_mm);
        if any(~isfinite(T_serie))
            log_extractor('        coords fuera del dominio → buscando nodo más cercano...\n');
            [coord_real, min_d, ok_snap, T_snap, n_finitos_snap] = nodo_mas_cercano(model, tag, idx_ext, coord_mm);
            if ok_snap
                log_extractor('        nodo cercano: [%.4g %.4g %.4g] mm  dist=%.4g mm\n', ...
                    coord_real(1), coord_real(2), coord_real(3), min_d);
                T_serie   = T_snap;
                snap_usado = true;
                if n_finitos_snap < nT
                    log_extractor('        [WARN] Nodo fallback parcial: %d/%d tiempos finitos.\n', ...
                        n_finitos_snap, nT);
                end
            else
                log_extractor('        [WARN] No se pudo obtener la malla para el snap.\n');
            end
        end
        if es_kelvin(T_serie)
            T_serie = T_serie - 273.15;
        end
        fin    = T_serie(isfinite(T_serie));
        in_dom = ~isempty(fin);
        if in_dom
            if snap_usado
                log_extractor('        T=[%.2f – %.2f] C  ✓ (snap a nodo cercano)\n', min(fin), max(fin));
            else
                log_extractor('        T=[%.2f – %.2f] C  ✓\n', min(fin), max(fin));
            end
        else
            log_extractor('        [WARN] Sin datos finitos tras snap. Sonda sin datos.\n');
        end
        probes.(lbl).label       = lbl;
        probes.(lbl).coord_mm    = coord_mm;
        probes.(lbl).coord_real  = coord_real;
        probes.(lbl).snap_usado  = snap_usado;
        probes.(lbl).t_min       = t_sol_min(idx_ext);
        probes.(lbl).T           = T_serie;
        probes.(lbl).in_domain   = in_dom;
        probes.(lbl).min_dist_mm = min_d;
    end
end
function T_serie = interpolar_sonda(model, tag, idx_ext, coord_mm)
    nT      = numel(idx_ext);
    T_serie = NaN(nT, 1);
    try
        T_raw = mphinterp(model, 'T', ...
            'coord',   coord_mm', ...
            'dataset', tag, ...
            'solnum',  idx_ext', ...
            'unit',    'degC');
        T_serie = T_raw(:);
        return;   
    catch
    end
    for k = 1:nT
        try
            T_k = mphinterp(model, 'T', ...
                'coord',   coord_mm', ...
                'dataset', tag, ...
                'solnum',  idx_ext(k), ...
                'unit',    'degC');
            T_serie(k) = T_k;
        catch
        end
    end
end
function [coord_real, min_d, ok, T_serie, n_finitos] = nodo_mas_cercano(model, tag, idx_ext, coord_mm)
    coord_real = coord_mm;
    min_d      = Inf;
    nT         = numel(idx_ext);
    T_serie    = NaN(nT, 1);
    n_finitos  = 0;
    max_candidatos = 250;

    for edim = [3 2]
        try
            d_geo = mpheval(model, {'x','y','z'}, ...
                'dataset', tag, ...
                'solnum',  idx_ext(1), ...
                'unit',    {'mm','mm','mm'}, ...
                'edim',    edim);
            Xm = d_geo.d1(:);
            Ym = d_geo.d2(:);
            Zm = d_geo.d3(:);
            if isempty(Xm); continue; end
            dv = sqrt((Xm - coord_mm(1)).^2 + ...
                       (Ym - coord_mm(2)).^2 + ...
                       (Zm - coord_mm(3)).^2);
            [~, orden] = sort(dv, 'ascend');
            orden = orden(1:min(numel(orden), max_candidatos));

            for ci = 1:numel(orden)
                ni = orden(ci);
                coord_candidata = [Xm(ni), Ym(ni), Zm(ni)];
                T_candidata = interpolar_sonda(model, tag, idx_ext, coord_candidata);
                finitos = sum(isfinite(T_candidata));

                if finitos > n_finitos || (finitos == n_finitos && dv(ni) < min_d)
                    n_finitos = finitos;
                    min_d = dv(ni);
                    coord_real = coord_candidata;
                    T_serie = T_candidata;
                end

                if finitos == nT
                    ok = true;
                    return;
                end
            end
        catch
        end
    end
    ok = n_finitos > 0;
end
function [snapshots, bbox, campo_completo] = extraer_snapshots( ...
        model, tag, idx_ext, t_sol_min, ...
        numero_grilla, temperatura_ablacion, temperatura_carbonizacion, dominio_hueso)
    if nargin < 8 || isempty(dominio_hueso)
        dominio_hueso = struct('habilitado', false, ...
            'z_min_mm', -Inf, 'z_max_mm', Inf, 'radio_mm', Inf, ...
            'descripcion', 'Dominio completo');
    end
    nT        = numel(idx_ext);
    snap_tmpl = crear_snapshot_vacio();
    snapshots = repmat(snap_tmpl, nT, 1);
    bbox      = struct('xmin', NaN, 'xmax', NaN, 'ymin', NaN, ...
                       'ymax', NaN, 'zmin', NaN, 'zmax', NaN);
    campo_completo = struct( ...
        'points', single(zeros(0, 3)), ...
        'T_C', single(zeros(0, nT)), ...
        't_min', t_sol_min(idx_ext(:)), ...
        'grid_size', [0, 0, 0], ...
        'x_mm', single([]), ...
        'y_mm', single([]), ...
        'z_mm', single([]), ...
        'dominio_extraccion', dominio_hueso, ...
        'descripcion', ...
            'Campo termico sobre rejilla compartida recortada al dominio de extraccion.');
    try
        d_b = mpheval(model, {'x','y','z'}, ...
            'dataset', tag, 'solnum', idx_ext(1), ...
            'unit', {'mm','mm','mm'}, 'edim', 2);
        Xb = d_b.d1(:); Yb = d_b.d2(:); Zb = d_b.d3(:);
    catch
        try
            d_b = mpheval(model, {'x','y','z'}, ...
                'dataset', tag, 'solnum', idx_ext(1), ...
                'unit', {'mm','mm','mm'}, 'edim', 3);
            Xb = d_b.d1(:); Yb = d_b.d2(:); Zb = d_b.d3(:);
        catch ME_b
            log_extractor('    [Canal A] Error bbox: %s\n', ME_b.message);
            return;
        end
    end
    bbox = struct('xmin', min(Xb), 'xmax', max(Xb), ...
                  'ymin', min(Yb), 'ymax', max(Yb), ...
                  'zmin', min(Zb), 'zmax', max(Zb));
    if dominio_hueso.habilitado
        x_lim = [max(min(Xb), -dominio_hueso.radio_mm), ...
                 min(max(Xb),  dominio_hueso.radio_mm)];
        y_lim = [max(min(Yb), -dominio_hueso.radio_mm), ...
                 min(max(Yb),  dominio_hueso.radio_mm)];
        z_lim = [max(min(Zb), dominio_hueso.z_min_mm), ...
                 min(max(Zb), dominio_hueso.z_max_mm)];
    else
        x_lim = [min(Xb), max(Xb)];
        y_lim = [min(Yb), max(Yb)];
        z_lim = [min(Zb), max(Zb)];
    end
    if any(~isfinite([x_lim y_lim z_lim])) || x_lim(2) <= x_lim(1) || ...
            y_lim(2) <= y_lim(1) || z_lim(2) <= z_lim(1)
        log_extractor('    [Canal A] Dominio de extraccion invalido o vacio.\n');
        return;
    end
    xg = linspace(x_lim(1), x_lim(2), numero_grilla);
    yg = linspace(y_lim(1), y_lim(2), numero_grilla);
    zg = linspace(z_lim(1), z_lim(2), numero_grilla);
    [Xg, Yg, Zg] = meshgrid(xg, yg, zg);
    mascara_dominio = true(size(Xg));
    if dominio_hueso.habilitado
        tol = 1e-9;
        mascara_dominio = hypot(Xg, Yg) <= dominio_hueso.radio_mm + tol & ...
            Zg >= dominio_hueso.z_min_mm - tol & ...
            Zg <= dominio_hueso.z_max_mm + tol;
    end
    pts_eval = [Xg(mascara_dominio), Yg(mascara_dominio), Zg(mascara_dominio)];
    if isempty(pts_eval)
        log_extractor('    [Canal A] Dominio de extraccion sin puntos utiles.\n');
        return;
    end
    campo_completo.points = single(pts_eval);
    campo_completo.T_C = nan(size(pts_eval, 1), nT, 'single');
    campo_completo.grid_size = size(Xg);
    campo_completo.x_mm = single(xg(:));
    campo_completo.y_mm = single(yg(:));
    campo_completo.z_mm = single(zg(:));
    log_extractor('    Grilla %d^3 -> %d pts utiles  dominio X:[%.1f %.1f] Y:[%.1f %.1f] Z:[%.1f %.1f] mm\n', ...
        numero_grilla, size(pts_eval, 1), ...
        x_lim(1), x_lim(2), y_lim(1), y_lim(2), z_lim(1), z_lim(2));
    if dominio_hueso.habilitado
        log_extractor('    Dominio hueso activo: radio %.1f mm | z %.1f..%.1f mm\n', ...
            dominio_hueso.radio_mm, dominio_hueso.z_min_mm, dominio_hueso.z_max_mm);
    end
    for k = 1:nT
        solnum = idx_ext(k);
        t_act  = t_sol_min(solnum);
        log_extractor('    [A %d/%d] t=%.4f min  ', k, nT, t_act);
        try
            T_n = mphinterp(model, 'T', ...
                'coord',  pts_eval', ...
                'dataset', tag, ...
                'solnum',  solnum, ...
                'unit',    'degC');
            T_n = T_n(:);
            validos = isfinite(T_n);
            if es_kelvin(T_n(validos))
                T_n(validos) = T_n(validos) - 273.15;
            end
            campo_completo.T_C(:, k) = single(T_n);

            if ~any(validos)
                snapshots(k) = crear_snapshot_vacio();
                snapshots(k).t_min  = t_act;
                snapshots(k).solnum = solnum;
                log_extractor('sin puntos finitos en dominio.\n');
                continue;
            end

            T_v     = T_n(validos);
            X_v     = pts_eval(validos, 1);
            Y_v     = pts_eval(validos, 2);
            Z_v     = pts_eval(validos, 3);
            mask_ablacion = T_v >= temperatura_ablacion;
            mask_carbonizacion = T_v >= temperatura_carbonizacion;
            nf = sum(mask_ablacion);
            nc = sum(mask_carbonizacion);
            snapshots(k).t_min          = t_act;
            snapshots(k).solnum         = solnum;
            snapshots(k).points         = [ ...
                X_v(mask_ablacion), Y_v(mask_ablacion), Z_v(mask_ablacion)];
            snapshots(k).T              = T_v(mask_ablacion);
            snapshots(k).T_min_C        = min(T_v);
            snapshots(k).T_max_C        = max(T_v);
            snapshots(k).n_pts_total    = numel(T_v);
            snapshots(k).n_pts_filtered = nf;
            snapshots(k).n_pts_carbonizacion = nc;
            if     nf >= 10;  st = '✓';
            elseif nf > 0;    st = '(pocos)';
            else;             st = '(sin ablación)';
            end
            log_extractor('T:[%.1f,%.1f]°C  abl:%d/%d  carbon:%d  %s\n', ...
                min(T_v), max(T_v), nf, numel(T_v), nc, st);
        catch ME_k
            log_extractor('ERROR: %s\n', ME_k.message);
            snapshots(k) = crear_snapshot_vacio();
            snapshots(k).t_min  = t_act;
            snapshots(k).solnum = solnum;
        end
    end
end
function s = crear_snapshot_vacio()
    s = struct('t_min', 0, 'solnum', 0, ...
        'points',       zeros(0, 3), ...
        'T',            zeros(0, 1), ...
        'T_min_C',      NaN, ...
        'T_max_C',      NaN, ...
        'n_pts_total',  0, ...
        'n_pts_filtered', 0, ...
        'n_pts_carbonizacion', 0);
end
function name = crear_nombre_campo(raw)
    name = regexprep(raw, '\.mph$', '', 'ignorecase');
    name = regexprep(name, '[^a-zA-Z0-9_]', '_');
    if ~isempty(name) && ~isnan(str2double(name(1)))
        name = ['m_', name];
    end
    if isempty(name)
        name = 'modelo_sin_nombre';
    end
end
function tf = es_kelvin(T)
    fin = T(isfinite(T));
    if isempty(fin)
        tf = false;
        return;
    end
    if any(fin < 0)
        tf = false;
        return;
    end
    tf = min(fin) > 200;
end

function config = normalizar_config_extractor(config_ui)
    puntos_default = [
        0, 0, 18.6;
        0, 0, 25.2;
        0, 0, 31.8;
        0, 0, 38.4];
    etiquetas_default = {'P1', 'P2', 'P3', 'P4'};

    config = struct();
    config.temperatura_ablacion = obtener_campo_config(config_ui, 'temperatura_ablacion', 55);
    config.temperatura_carbonizacion = obtener_campo_config(config_ui, 'temperatura_carbonizacion', 300);
    config.numero_grilla = round(obtener_campo_config(config_ui, 'numero_grilla', 60));
    config.dominio_hueso = struct( ...
        'habilitado', logical(obtener_campo_config(config_ui, 'extraer_solo_hueso', true)), ...
        'z_min_mm', obtener_campo_config(config_ui, 'hueso_z_min_mm', 0), ...
        'z_max_mm', obtener_campo_config(config_ui, 'hueso_z_max_mm', 45), ...
        'radio_mm', obtener_campo_config(config_ui, 'hueso_radio_mm', 50), ...
        'descripcion', 'Cilindro Hueso del generador: radio 50 mm, z 0..45 mm');
    config.tiempos_min = normalizar_tiempos_min(obtener_campo_config(config_ui, 'tiempos_min', []));
    config.requiere_metadata_dataset = logical(obtener_campo_config(config_ui, ...
        'requiere_metadata_dataset', true));
    config.puntos_sonda = obtener_campo_config(config_ui, 'puntos_sonda', puntos_default);
    config.etiquetas_sonda = obtener_campo_config(config_ui, 'etiquetas_sonda', etiquetas_default);
    config.numero_iteraciones_suavizado = round(obtener_campo_config(config_ui, 'numero_iteraciones_suavizado', 4));
    config.radio_alpha = obtener_campo_config(config_ui, 'radio_alpha', 0);
    config.desfase_1antena = struct( ...
        'habilitado', logical(obtener_campo_config(config_ui, 'desfase_1antena_habilitado', true)), ...
        'x_mm', obtener_campo_config(config_ui, 'desfase_1antena_x_mm', 1), ...
        'y_mm', obtener_campo_config(config_ui, 'desfase_1antena_y_mm', 1), ...
        'z_objetivo_mm', obtener_campo_config(config_ui, 'desfase_1antena_z_objetivo_mm', []), ...
        'aplicar_a_todo_eje', logical(obtener_campo_config(config_ui, 'desfase_1antena_aplicar_a_todo_eje', true)));
    config.reextraer_1antena_con_nan = logical(obtener_campo_config(config_ui, ...
        'reextraer_1antena_con_nan', true));
    config.filtro_nombre = normalizar_lista_texto(obtener_campo_config(config_ui, 'filtro_nombre', {}));
    config.ignorar_filtros_modelo = logical(obtener_campo_config(config_ui, 'ignorar_filtros_modelo', false));
    config.tipos_antena = normalizar_lista_texto(obtener_campo_config(config_ui, 'tipos_antena', {}));
    config.num_antenas = normalizar_lista_entera( ...
        obtener_campo_config(config_ui, 'num_antenas_lista', []), 1, 4);
    if isempty(config.num_antenas)
        config.num_antenas = normalizar_rango_entero( ...
            obtener_campo_config(config_ui, 'num_antenas_inicio', []), ...
            obtener_campo_config(config_ui, 'num_antenas_fin', []), 1, 1, 4);
    end
    config.casos = normalizar_lista_entera( ...
        obtener_campo_config(config_ui, 'casos_lista', []), 0, 8);
    if isempty(config.casos)
        config.casos = normalizar_rango_entero( ...
            obtener_campo_config(config_ui, 'caso_inicio', []), ...
            obtener_campo_config(config_ui, 'caso_fin', []), 1, 0, 8);
    end
    config.potencias = normalizar_lista_entera( ...
        obtener_campo_config(config_ui, 'potencias_lista', []), 0, Inf);
    if isempty(config.potencias)
        config.potencias = normalizar_rango_entero( ...
            obtener_campo_config(config_ui, 'potencia_inicio', []), ...
            obtener_campo_config(config_ui, 'potencia_fin', []), ...
            max(1, round(obtener_campo_config(config_ui, 'potencia_paso', 5))), 0, Inf);
    end

    validar_config_extractor(config);
end

function validar_config_extractor(config)
    if config.temperatura_ablacion < 55
        error('La temperatura minima para STL no puede ser menor que 55 C.');
    end
    if config.temperatura_carbonizacion < config.temperatura_ablacion
        error('La temperatura de carbonizacion debe ser mayor o igual que la de ablacion.');
    end
    if config.numero_grilla < 5
        error('El numero de grilla debe ser al menos 5.');
    end
    if config.dominio_hueso.habilitado
        if config.dominio_hueso.z_max_mm <= config.dominio_hueso.z_min_mm
            error('El dominio de hueso debe cumplir z_max_mm > z_min_mm.');
        end
        if config.dominio_hueso.radio_mm <= 0
            error('El radio del dominio de hueso debe ser positivo.');
        end
    end
    if size(config.puntos_sonda, 2) ~= 3
        error('Las sondas deben ser una matriz N x 3 en milimetros.');
    end
    if numel(config.etiquetas_sonda) ~= size(config.puntos_sonda, 1)
        error('Debe existir una etiqueta por cada sonda.');
    end
end

function [puntos_ajustados, meta] = aplicar_desfase_1antena(puntos_sonda, mph_path, desfase)
    puntos_ajustados = puntos_sonda;
    es_1antena = contains(mph_path, '1ant', 'IgnoreCase', true);
    if nargin < 3 || isempty(desfase)
        desfase = struct('habilitado', true, 'x_mm', 1, 'y_mm', 1, ...
            'z_objetivo_mm', [], 'aplicar_a_todo_eje', true);
    end
    habilitado = logical(obtener_campo_config(desfase, 'habilitado', true));
    x_mm = obtener_campo_config(desfase, 'x_mm', 1);
    y_mm = obtener_campo_config(desfase, 'y_mm', 1);
    z_objetivo_mm = obtener_campo_config(desfase, 'z_objetivo_mm', []);
    aplicar_a_todo_eje = logical(obtener_campo_config(desfase, 'aplicar_a_todo_eje', true));

    meta = struct( ...
        'es_modelo_1antena', es_1antena, ...
        'habilitado', habilitado, ...
        'x_mm', x_mm, ...
        'y_mm', y_mm, ...
        'z_objetivo_mm', z_objetivo_mm, ...
        'aplicar_a_todo_eje', aplicar_a_todo_eje, ...
        'aplicado', false, ...
        'indices_ajustados', [], ...
        'regla', '1ant: forzar X/Y configurados y conservar Z original de cada sonda');

    if ~es_1antena || ~habilitado
        return;
    end

    if aplicar_a_todo_eje || isempty(z_objetivo_mm)
        idx = (1:size(puntos_sonda, 1))';
    else
        idx = find(abs(puntos_sonda(:, 3) - z_objetivo_mm) <= 1e-9);
    end

    if isempty(idx)
        log_extractor('  [AVISO] Modelo 1ant detectado, pero no hubo sondas que cumplieran la regla de desfase.\n');
        return;
    end

    puntos_ajustados(idx, 1) = x_mm;
    puntos_ajustados(idx, 2) = y_mm;
    meta.aplicado = true;
    meta.indices_ajustados = idx(:)';
    log_extractor('  [AVISO] Detectado modelo de 1 antena. Sondas ajustadas a X=%.4g, Y=%.4g; Z se conserva desde la tabla.\n', ...
        x_mm, y_mm);
end
function [reextraer, motivo] = debe_reextraer_modelo_existente(model_data, mph_path, config, firma_origen)
    reextraer = false;
    motivo = '';

    if nargin < 4
        firma_origen = struct();
    end

    if ~isstruct(model_data)
        reextraer = true;
        motivo = 'estructura previa invalida';
        return;
    end

    [firma_invalida, motivo_firma] = firma_origen_invalida(model_data, firma_origen);
    if firma_invalida
        reextraer = true;
        motivo = motivo_firma;
        return;
    end

    [incompleto, motivo_incompleto] = modelo_tiene_registros_incompletos(model_data, config);
    if incompleto
        reextraer = true;
        motivo = motivo_incompleto;
        return;
    end

    if isfield(config, 'requiere_metadata_dataset') && config.requiere_metadata_dataset
        [tiene_invalidos, motivo_metadata] = modelo_tiene_datasets_sin_metadata(model_data);
        if tiene_invalidos
            reextraer = true;
            motivo = motivo_metadata;
            return;
        end
    end

    if ~contains(mph_path, '1ant', 'IgnoreCase', true)
        return;
    end
    if isfield(config, 'reextraer_1antena_con_nan') && ~config.reextraer_1antena_con_nan
        return;
    end

    datasets = fieldnames(model_data);
    datasets = datasets(~ismember(datasets, {'session_meta', 'datasets_omitidos', 'source_signature'}));
    if isempty(datasets)
        reextraer = true;
        motivo = 'modelo 1ant existente sin datasets';
        return;
    end

    for di = 1:numel(datasets)
        tag = datasets{di};
        if ~isstruct(model_data.(tag))
            continue;
        end
        registro = model_data.(tag);

        if isfield(registro, 'metadata')
            [meta_invalida, motivo_meta, xy_esperado] = metadata_1ant_invalida(registro.metadata);
            if meta_invalida
                reextraer = true;
                motivo = sprintf('%s: %s', tag, motivo_meta);
                return;
            end
        else
            reextraer = true;
            motivo = sprintf('%s: sin metadata de desfase 1ant', tag);
            return;
        end

        if isfield(registro, 'probes')
            [probes_invalidas, motivo_probes] = probes_1ant_invalidas(registro.probes, xy_esperado);
            if probes_invalidas
                reextraer = true;
                motivo = sprintf('%s: %s', tag, motivo_probes);
                return;
            end
        end
    end
end

function firma = crear_firma_archivo_mph(ruta_archivo)
    info = dir(ruta_archivo);
    if isempty(info)
        firma = struct('name', '', 'bytes', NaN, 'datenum', NaN);
        return;
    end
    firma = struct( ...
        'name', info(1).name, ...
        'bytes', info(1).bytes, ...
        'datenum', info(1).datenum);
end

function [invalida, motivo] = firma_origen_invalida(model_data, firma_origen)
    invalida = false;
    motivo = '';
    if isempty(fieldnames(firma_origen))
        return;
    end
    if ~isfield(model_data, 'source_signature')
        invalida = true;
        motivo = 'modelo existente sin firma de archivo .mph';
        return;
    end
    firma_previa = model_data.source_signature;
    if ~isstruct(firma_previa) || ...
            ~isfield(firma_previa, 'bytes') || ~isfield(firma_previa, 'datenum') || ...
            firma_previa.bytes ~= firma_origen.bytes || ...
            abs(firma_previa.datenum - firma_origen.datenum) > 1e-7
        invalida = true;
        motivo = 'archivo .mph cambiado respecto al .mat existente';
    end
end

function [incompleto, motivo] = modelo_tiene_registros_incompletos(model_data, config)
    incompleto = false;
    motivo = '';
    if ~isstruct(model_data)
        incompleto = true;
        motivo = 'estructura de modelo no valida';
        return;
    end
    datasets = fieldnames(model_data);
    datasets = datasets(~ismember(datasets, {'session_meta', 'datasets_omitidos', 'source_signature'}));
    if isempty(datasets)
        incompleto = true;
        motivo = 'modelo existente sin datasets extraidos';
        return;
    end
    for di = 1:numel(datasets)
        tag = datasets{di};
        [registro_invalido, motivo_registro] = registro_dataset_incompleto(model_data.(tag), config);
        if registro_invalido
            incompleto = true;
            motivo = sprintf('%s: %s', tag, motivo_registro);
            return;
        end
    end
end

function [invalido, motivo] = registro_dataset_incompleto(registro, config)
    invalido = false;
    motivo = '';
    campos_requeridos = {'snapshots', 't_min', 'probes', 'bbox', 'full_field', 'metadata'};
    if ~isstruct(registro)
        invalido = true;
        motivo = 'registro no estructurado';
        return;
    end
    for ci = 1:numel(campos_requeridos)
        if ~isfield(registro, campos_requeridos{ci})
            invalido = true;
            motivo = sprintf('falta campo %s', campos_requeridos{ci});
            return;
        end
    end
    t_min = double(registro.t_min(:));
    if isempty(t_min) || any(~isfinite(t_min))
        invalido = true;
        motivo = 'vector temporal invalido';
        return;
    end
    if numel(registro.snapshots) ~= numel(t_min)
        invalido = true;
        motivo = 'numero de snapshots distinto al vector temporal';
        return;
    end
    [ff_invalido, motivo_ff] = full_field_incompleto(registro.full_field, t_min);
    if ff_invalido
        invalido = true;
        motivo = motivo_ff;
        return;
    end
    [probes_invalidas, motivo_probes] = probes_incompletas(registro.probes, t_min);
    if probes_invalidas
        invalido = true;
        motivo = motivo_probes;
        return;
    end
    [metadata_invalida, motivo_metadata] = metadata_incompatible(registro.metadata, config);
    if metadata_invalida
        invalido = true;
        motivo = motivo_metadata;
    end
end

function [invalido, motivo] = full_field_incompleto(full_field, t_min)
    invalido = false;
    motivo = '';
    campos_requeridos = {'points', 'T_C', 't_min', 'grid_size'};
    if ~isstruct(full_field)
        invalido = true;
        motivo = 'full_field no estructurado';
        return;
    end
    for ci = 1:numel(campos_requeridos)
        if ~isfield(full_field, campos_requeridos{ci})
            invalido = true;
            motivo = sprintf('full_field sin %s', campos_requeridos{ci});
            return;
        end
    end
    puntos = full_field.points;
    T_C = full_field.T_C;
    if isempty(puntos) || size(puntos, 2) ~= 3 || isempty(T_C)
        invalido = true;
        motivo = 'full_field vacio o con dimensiones invalidas';
        return;
    end
    if size(T_C, 1) ~= size(puntos, 1) || size(T_C, 2) ~= numel(t_min)
        invalido = true;
        motivo = 'full_field T_C no coincide con puntos/tiempos';
        return;
    end
    if ~any(isfinite(T_C(:)))
        invalido = true;
        motivo = 'full_field sin temperaturas finitas';
    end
end

function [invalidas, motivo] = probes_incompletas(probes, t_min)
    invalidas = false;
    motivo = '';
    if ~isstruct(probes)
        invalidas = true;
        motivo = 'probes no estructurado';
        return;
    end
    nombres = fieldnames(probes);
    if isempty(nombres)
        invalidas = true;
        motivo = 'sin sondas extraidas';
        return;
    end
    for pi = 1:numel(nombres)
        nombre = nombres{pi};
        probe = probes.(nombre);
        if ~isstruct(probe) || ~isfield(probe, 'T') || ~isfield(probe, 't_min')
            invalidas = true;
            motivo = sprintf('sonda %s incompleta', nombre);
            return;
        end
        if numel(probe.T) ~= numel(t_min) || numel(probe.t_min) ~= numel(t_min)
            invalidas = true;
            motivo = sprintf('sonda %s no coincide con tiempos', nombre);
            return;
        end
        if isempty(probe.T) || any(~isfinite(probe.T(:)))
            invalidas = true;
            motivo = sprintf('sonda %s contiene NaN/Inf', nombre);
            return;
        end
    end
end

function [invalida, motivo] = metadata_incompatible(metadata, config)
    invalida = false;
    motivo = '';
    if ~isstruct(metadata)
        invalida = true;
        motivo = 'metadata no estructurada';
        return;
    end
    if ~isfield(metadata, 'full_field_disponible') || ~valor_logico_es_verdadero(metadata.full_field_disponible)
        invalida = true;
        motivo = 'metadata sin full_field disponible';
        return;
    end
    if ~isfield(metadata, 'n_grilla') || metadata.n_grilla ~= config.numero_grilla
        invalida = true;
        motivo = 'resolucion de grilla distinta a la configuracion actual';
        return;
    end
    if ~isfield(metadata, 'T_ablacion') || ~valores_iguales(metadata.T_ablacion, config.temperatura_ablacion)
        invalida = true;
        motivo = 'umbral de ablacion distinto a la configuracion actual';
        return;
    end
    if ~isfield(metadata, 'T_carboniz') || ~valores_iguales(metadata.T_carboniz, config.temperatura_carbonizacion)
        invalida = true;
        motivo = 'umbral de carbonizacion distinto a la configuracion actual';
        return;
    end
    if ~isfield(metadata, 'dominio_extraccion') || dominio_incompatible(metadata.dominio_extraccion, config.dominio_hueso)
        invalida = true;
        motivo = 'dominio de extraccion distinto a la configuracion actual';
    end
end

function incompatible = dominio_incompatible(dominio_previo, dominio_actual)
    incompatible = true;
    campos = {'habilitado', 'z_min_mm', 'z_max_mm', 'radio_mm'};
    if ~isstruct(dominio_previo) || ~isstruct(dominio_actual)
        return;
    end
    for ci = 1:numel(campos)
        campo = campos{ci};
        if ~isfield(dominio_previo, campo) || ~isfield(dominio_actual, campo)
            return;
        end
    end
    incompatible = logical(dominio_previo.habilitado) ~= logical(dominio_actual.habilitado) || ...
        ~valores_iguales(dominio_previo.z_min_mm, dominio_actual.z_min_mm) || ...
        ~valores_iguales(dominio_previo.z_max_mm, dominio_actual.z_max_mm) || ...
        ~valores_iguales(dominio_previo.radio_mm, dominio_actual.radio_mm);
end

function tf = valores_iguales(a, b)
    tf = false;
    if isempty(a) || isempty(b) || ~isscalar(a) || ~isscalar(b)
        return;
    end
    a = double(a);
    b = double(b);
    tf = isfinite(a) && isfinite(b) && abs(a - b) <= 1e-9;
end

function [tiene_invalidos, motivo] = modelo_tiene_datasets_sin_metadata(model_data)
    tiene_invalidos = false;
    motivo = '';
    if ~isstruct(model_data)
        return;
    end
    datasets = fieldnames(model_data);
    datasets = datasets(~ismember(datasets, {'session_meta', 'datasets_omitidos', 'source_signature'}));
    for di = 1:numel(datasets)
        metadata_dataset = extraer_metadata_dataset(datasets{di});
        if ~metadata_dataset.tiene_metadata
            tiene_invalidos = true;
            motivo = sprintf('dataset existente sin metadata util: %s', datasets{di});
            return;
        end
    end
end

function [invalida, motivo, xy_esperado] = metadata_1ant_invalida(metadata)
    invalida = false;
    motivo = '';
    xy_esperado = [1, 1];

    if ~isfield(metadata, 'desfase_1antena')
        invalida = true;
        motivo = 'metadata sin desfase_1antena';
        return;
    end

    meta_desfase = metadata.desfase_1antena;
    if isfield(meta_desfase, 'x_mm') && isfield(meta_desfase, 'y_mm')
        xy_esperado = [double(meta_desfase.x_mm), double(meta_desfase.y_mm)];
    end
    if ~isfield(meta_desfase, 'aplicado') || ~valor_logico_es_verdadero(meta_desfase.aplicado)
        invalida = true;
        motivo = 'desfase_1antena no aplicado';
        return;
    end

    if isfield(metadata, 'probe_points') && ~isempty(metadata.probe_points)
        puntos = double(metadata.probe_points);
        if size(puntos, 2) >= 2
            xy_ok = abs(puntos(:, 1) - xy_esperado(1)) <= 1e-9 & ...
                abs(puntos(:, 2) - xy_esperado(2)) <= 1e-9;
            if any(~xy_ok)
                invalida = true;
                motivo = sprintf('probe_points no estan en [X,Y]=[%.4g,%.4g] para modelo 1ant', ...
                    xy_esperado(1), xy_esperado(2));
            end
        end
    end
end

function [invalidas, motivo] = probes_1ant_invalidas(probes, xy_esperado)
    invalidas = false;
    motivo = '';
    if nargin < 2 || isempty(xy_esperado)
        xy_esperado = [1, 1];
    end
    nombres = fieldnames(probes);
    for pi = 1:numel(nombres)
        nombre = nombres{pi};
        probe = probes.(nombre);
        if ~isstruct(probe)
            continue;
        end
        if isfield(probe, 'in_domain') && ~valor_logico_es_verdadero(probe.in_domain)
            invalidas = true;
            motivo = sprintf('sonda %s marcada fuera de dominio', nombre);
            return;
        end
        if isfield(probe, 'T')
            serie = probe.T;
            if isempty(serie) || any(~isfinite(serie(:)))
                invalidas = true;
                motivo = sprintf('sonda %s contiene NaN/Inf en T', nombre);
                return;
            end
        end
        if isfield(probe, 'coord_mm') && numel(probe.coord_mm) >= 2
            coord = double(probe.coord_mm(:))';
            if abs(coord(1) - xy_esperado(1)) > 1e-9 || abs(coord(2) - xy_esperado(2)) > 1e-9
                invalidas = true;
                motivo = sprintf('sonda %s no fue desplazada a [%.4g,%.4g,Z]', ...
                    nombre, xy_esperado(1), xy_esperado(2));
                return;
            end
        end
    end
end

function tf = valor_logico_es_verdadero(valor)
    tf = false;
    if isempty(valor)
        return;
    end
    try
        tf = logical(valor(1));
    catch
        tf = false;
    end
end

function valores = normalizar_tiempos_min(valor)
    if isempty(valor)
        valores = [];
    elseif isnumeric(valor)
        valores = unique(valor(:));
    else
        txt = strtrim(char(valor));
        if isempty(txt) || strcmpi(txt, 'todos')
            valores = [];
        else
            valores = sscanf(strrep(txt, ',', ' '), '%f');
            valores = unique(valores(:));
        end
    end
end

function lista = normalizar_lista_texto(valor)
    if isempty(valor)
        lista = {};
    elseif ischar(valor) || isstring(valor)
        partes = regexp(char(valor), '[,;\n]+', 'split');
        partes = strtrim(partes);
        lista = partes(~cellfun('isempty', partes));
    elseif iscell(valor)
        lista = cellfun(@char, valor(:)', 'UniformOutput', false);
        lista = strtrim(lista);
        lista = lista(~cellfun('isempty', lista));
    else
        lista = {};
    end
end

function valores = normalizar_lista_entera(valor, minimo, maximo)
    if isempty(valor)
        valores = [];
        return;
    end
    if isnumeric(valor)
        nums = valor(:);
    else
        if iscell(valor)
            partes = string(valor(:));
        elseif isstring(valor)
            partes = valor(:);
        else
            txt = strtrim(char(valor));
            if isempty(txt) || strcmpi(txt, 'todos')
                valores = [];
                return;
            end
            partes = string(regexp(txt, '[,;\s]+', 'split'));
        end
        partes = strtrim(partes);
        partes = partes(strlength(partes) > 0);
        nums = str2double(partes);
    end
    nums = round(nums(:));
    nums = nums(isfinite(nums));
    if isempty(nums)
        valores = [];
        return;
    end
    if any(nums < minimo) || any(nums > maximo)
        error('Lista fuera de limites permitidos.');
    end
    valores = unique(nums, 'stable');
end

function valores = normalizar_rango_entero(inicio, fin, paso, minimo, maximo)
    if isempty(inicio) || isempty(fin)
        valores = [];
        return;
    end
    inicio = round(inicio);
    fin = round(fin);
    paso = max(1, round(paso));
    if inicio > fin
        error('El inicio de un rango no puede ser mayor que el fin.');
    end
    if inicio < minimo || fin > maximo
        error('Rango fuera de limites permitidos.');
    end
    if inicio == fin
        valores = inicio;
    else
        valores = unique([inicio:paso:fin, fin], 'stable');
    end
end

function [mph_filtrados, resumen] = aplicar_filtros_modelos_mph(mph_list, config)
    mph_filtrados = mph_list;
    if config.ignorar_filtros_modelo
        resumen = 'Ignorados por switch: se procesan todos los .mph detectados.';
        return;
    end
    n_mph = numel(mph_list);
    keep = true(n_mph, 1);
    if n_mph == 0
        resumen = '0/0 modelos detectados.';
        return;
    end
    nombres = lower(string({mph_list.name}));
    nombres = nombres(:);
    rutas = lower(string(arrayfun(@(x) fullfile(x.folder, x.name), mph_list, 'UniformOutput', false)));
    rutas = rutas(:);

    if ~isempty(config.filtro_nombre)
        for fi = 1:numel(config.filtro_nombre)
            patron = lower(string(config.filtro_nombre{fi}));
            keep = keep & (contains(nombres, patron) | contains(rutas, patron));
        end
    end

    if ~isempty(config.tipos_antena)
        keep_tipo = false(n_mph, 1);
        for ti = 1:numel(config.tipos_antena)
            patron = lower(string(config.tipos_antena{ti}));
            keep_tipo = keep_tipo | contains(rutas, patron);
        end
        keep = keep & keep_tipo;
    end

    if ~isempty(config.num_antenas)
        keep_num = false(n_mph, 1);
        for n = config.num_antenas(:)'
            keep_num = keep_num | contains(rutas, string(sprintf('%dant', n)));
        end
        keep = keep & keep_num;
    end

    mph_filtrados = mph_list(keep);
    resumen = sprintf(['%d/%d modelos tras filtros | tipos=%s | antenas=%s | patron=%s | ', ...
        'datasets=metadata c#/p# | potencias=%s'], ...
        numel(mph_filtrados), numel(mph_list), ...
        texto_lista(config.tipos_antena), mat2str(config.num_antenas), ...
        texto_lista(config.filtro_nombre), mat2str(config.potencias));
end

function [tf, motivo, metadata_dataset] = debe_extraer_dataset_por_config(tag_dataset, config)
    metadata_dataset = extraer_metadata_dataset(tag_dataset);
    tf = true;
    motivo = '';

    if config.requiere_metadata_dataset && ~metadata_dataset.tiene_metadata
        tf = false;
        motivo = metadata_dataset.motivo;
        return;
    end

    if config.ignorar_filtros_modelo
        return;
    end

    if ~isempty(config.casos) && ~ismember(metadata_dataset.caso, config.casos)
        tf = false;
        motivo = sprintf('caso %d fuera de filtros %s', ...
            metadata_dataset.caso, mat2str(config.casos));
        return;
    end

    if ~isempty(config.potencias) && ~ismember(metadata_dataset.potencia_W, config.potencias)
        tf = false;
        motivo = sprintf('potencia %d W fuera de filtros %s', ...
            metadata_dataset.potencia_W, mat2str(config.potencias));
    end
end

function metadata_dataset = extraer_metadata_dataset(tag_dataset)
    tag_original = char(tag_dataset);
    tag = lower(tag_original);
    caso_token = regexp(tag, '(?:^|[_-])(?:c|caso)_?(\d+)(?=$|[_-])', 'tokens', 'once');
    potencia_token = regexp(tag, '(?:^|[_-])(?:p|potencia)_?(\d+)(?:w)?(?=$|[_-])', 'tokens', 'once');
    if isempty(potencia_token)
        potencia_token = regexp(tag, '(\d+)\s*w', 'tokens', 'once');
    end

    metadata_dataset = struct( ...
        'tag_dataset', tag_original, ...
        'tiene_metadata', false, ...
        'caso', NaN, ...
        'potencia_W', NaN, ...
        'motivo', '');

    if isempty(caso_token) || isempty(potencia_token)
        metadata_dataset.motivo = 'sin metadata requerida de caso/potencia en el tag';
        return;
    end

    metadata_dataset.tiene_metadata = true;
    metadata_dataset.caso = str2double(caso_token{1});
    metadata_dataset.potencia_W = str2double(potencia_token{1});
    metadata_dataset.motivo = 'metadata valida';
end

function txt = texto_lista(lista)
    if isempty(lista)
        txt = '(todos)';
    elseif iscell(lista)
        partes = cellfun(@char, lista(:)', 'UniformOutput', false);
        txt = strjoin(partes, ',');
    elseif isstring(lista)
        txt = strjoin(cellstr(lista(:)'), ',');
    else
        txt = mat2str(lista);
    end
end

function [puntos, etiquetas] = parsear_sondas_tabla(datos)
    if isempty(datos)
        error('Debe definirse al menos una sonda.');
    end
    if istable(datos)
        datos = table2cell(datos);
    end
    puntos = zeros(0, 3);
    etiquetas = {};
    for k = 1:size(datos, 1)
        etiqueta = strtrim(char(datos{k, 1}));
        if isempty(etiqueta)
            etiqueta = sprintf('P%d', k);
        end
        coords = zeros(1, 3);
        for c = 1:3
            valor = datos{k, c + 1};
            if isnumeric(valor)
                coords(c) = valor;
            else
                coords(c) = str2double(char(valor));
            end
        end
        if any(~isfinite(coords))
            error('Coordenadas invalidas en la sonda %d. Use valores numericos X, Y, Z.', k);
        end
        etiquetas{end+1} = matlab.lang.makeValidName(etiqueta); %#ok<AGROW>
        puntos(end+1, :) = coords; %#ok<AGROW>
    end
end

function lanzar_ui_extractor_comsol_masivo()
    theme = tesis_auxiliares('tema_ui');
    fig = uifigure('Name', 'Extractor COMSOL Masivo', ...
        'Position', theme.layout.launcherPosition, ...
        'Color', theme.colors.bg);

    gl = uigridlayout(fig, [1, 2]);
    gl.RowHeight = {'1x'};
    gl.ColumnWidth = {620, '1x'};
    gl.Padding = [12 12 12 12];
    gl.RowSpacing = 12;
    gl.ColumnSpacing = 12;

    pnl_control = uipanel(gl, 'Title', 'Panel de Control');
    pnl_control.Layout.Row = 1;
    pnl_control.Layout.Column = 1;
    pnl_control.Scrollable = 'on';

    ctrl = uigridlayout(pnl_control, [15, 2]);
    ctrl.RowHeight = repmat({36}, 1, 15);
    ctrl.RowHeight{1} = 52;
    ctrl.RowHeight{5} = 42;
    ctrl.RowHeight{11} = 36;
    ctrl.RowHeight{12} = 40;
    ctrl.RowHeight{13} = '1x';
    ctrl.ColumnWidth = {170, '1x'};
    ctrl.Padding = [14 14 14 14];
    ctrl.RowSpacing = 10;
    ctrl.ColumnSpacing = 12;

    titulo = uilabel(ctrl, 'Text', 'Configuracion de extraccion termica', 'FontWeight', 'bold');
    titulo.Layout.Column = [1 2];
    tesis_auxiliares('tema_ui', 'label', titulo, 'section');

    crear_label(ctrl, 2, 'Root modelos .mph');
    gl_root = uigridlayout(ctrl, [1, 2]);
    gl_root.Layout.Row = 2;
    gl_root.Layout.Column = 2;
    gl_root.ColumnWidth = {'1x', 125};
    gl_root.Padding = [0 3 0 3];
    gl_root.ColumnSpacing = 10;
    ed_raiz = uieditfield(gl_root, 'text');
    btn_raiz = uibutton(gl_root, 'Text', 'Seleccionar...');
    tesis_auxiliares('tema_ui', 'button', btn_raiz, 'secondary');

    crear_label(ctrl, 3, 'Salida .mat');
    ed_salida = uieditfield(ctrl, 'text', 'Value', 'Dataset_Termico_Masivo.mat');
    ed_salida.Layout.Row = 3;
    ed_salida.Layout.Column = 2;

    crear_label(ctrl, 4, 'Patron nombre');
    ed_patron = uieditfield(ctrl, 'text', 'Placeholder', 'Opcional: Monopolo, 2ant, etc.');
    ed_patron.Layout.Row = 4;
    ed_patron.Layout.Column = 2;

    chk_inhabilitar_filtros = uicheckbox(ctrl, ...
        'Text', 'Inhabilitar filtros (extraer todo, STL >=55 C)', ...
        'Value', false, ...
        'Tooltip', ['Ignora filtros de antena, numero y potencia. ', ...
        'Tambien fija T ablacion/carbonizacion en 55/500 C para evitar STL con temperaturas menores a 55 C.']);
    chk_inhabilitar_filtros.Layout.Row = 5;
    chk_inhabilitar_filtros.Layout.Column = [1 2];

    crear_label(ctrl, 6, 'Tipo de antena');
    dd_tipo_antena = uidropdown(ctrl, ...
        'Items', {'Todos', 'Doble_slot', 'Monopolo', 'Un_slot'}, ...
        'Value', 'Todos', ...
        'Tooltip', 'Seleccione Todos para no filtrar por tipo de antena.');
    dd_tipo_antena.Layout.Row = 6;
    dd_tipo_antena.Layout.Column = 2;

    crear_label(ctrl, 7, 'Num. antenas');
    dd_num_antenas = uidropdown(ctrl, ...
        'Items', {'Todos', '1', '2', '3', '4'}, ...
        'Value', 'Todos', ...
        'Tooltip', 'Seleccione Todos para no filtrar por numero de antenas.');
    dd_num_antenas.Layout.Row = 7;
    dd_num_antenas.Layout.Column = 2;

    crear_label(ctrl, 8, 'Potencia W min/max');
    gl_pot = uigridlayout(ctrl, [1, 2]);
    gl_pot.Layout.Row = 8;
    gl_pot.Layout.Column = 2;
    gl_pot.ColumnWidth = {'1x', '1x'};
    gl_pot.Padding = [0 3 0 3];
    gl_pot.ColumnSpacing = 10;
    items_potencia = cellstr(string(5:5:100));
    dd_pot_ini = uidropdown(gl_pot, 'Items', items_potencia, 'Value', '5', ...
        'Tooltip', 'Limite inferior. El paso interno es siempre de 5 W.');
    dd_pot_fin = uidropdown(gl_pot, 'Items', items_potencia, 'Value', '100', ...
        'Tooltip', 'Limite superior. El paso interno es siempre de 5 W.');

    crear_label(ctrl, 9, 'T ablacion / carbon C');
    gl_temp = crear_grupo_numerico(ctrl, 9, 2);
    ed_Tabl = uieditfield(gl_temp, 'numeric', 'Value', 55);
    ed_Tcarb = uieditfield(gl_temp, 'numeric', 'Value', 300);

    crear_label(ctrl, 10, 'Grilla / suavizado');
    gl_grid = crear_grupo_numerico(ctrl, 10, 2);
    ed_grilla = uieditfield(gl_grid, 'numeric', 'Value', 60, 'Limits', [5 Inf], 'RoundFractionalValues', 'on');
    ed_suavizado = uieditfield(gl_grid, 'numeric', 'Value', 4, 'Limits', [0 Inf], 'RoundFractionalValues', 'on');

    crear_label(ctrl, 11, 'Desfase modelos 1ant');
    gl_desfase_1ant = uigridlayout(ctrl, [1, 5]);
    gl_desfase_1ant.Layout.Row = 11;
    gl_desfase_1ant.Layout.Column = 2;
    gl_desfase_1ant.ColumnWidth = {78, 18, '1x', 18, '1x'};
    gl_desfase_1ant.Padding = [0 3 0 3];
    gl_desfase_1ant.ColumnSpacing = 6;
    chk_desfase_1ant = uicheckbox(gl_desfase_1ant, ...
        'Text', 'Aplicar', ...
        'Value', true, ...
        'Tooltip', 'Si el modelo contiene 1ant, fuerza X/Y y conserva la Z de cada sonda.');
    lbl_desfase_x = uilabel(gl_desfase_1ant, 'Text', 'X');
    ed_desfase_x = uieditfield(gl_desfase_1ant, 'numeric', ...
        'Value', 1, ...
        'Tooltip', 'Coordenada X usada para sondas en modelos 1ant.');
    lbl_desfase_y = uilabel(gl_desfase_1ant, 'Text', 'Y');
    ed_desfase_y = uieditfield(gl_desfase_1ant, 'numeric', ...
        'Value', 1, ...
        'Tooltip', 'Coordenada Y usada para sondas en modelos 1ant.');
    tesis_auxiliares('tema_ui', 'label', lbl_desfase_x, 'muted');
    tesis_auxiliares('tema_ui', 'label', lbl_desfase_y, 'muted');

    gl_sondas_header = uigridlayout(ctrl, [1, 3]);
    gl_sondas_header.Layout.Row = 12;
    gl_sondas_header.Layout.Column = [1 2];
    gl_sondas_header.ColumnWidth = {'1x', 128, 112};
    gl_sondas_header.Padding = [0 2 0 2];
    gl_sondas_header.ColumnSpacing = 8;
    lbl_sondas = uilabel(gl_sondas_header, 'Text', 'Sondas explicitas [mm]: etiqueta, X, Y, Z');
    tesis_auxiliares('tema_ui', 'label', lbl_sondas, 'section');
    btn_add_sonda = uibutton(gl_sondas_header, 'Text', 'Anadir sonda');
    btn_rem_sonda = uibutton(gl_sondas_header, 'Text', 'Remover');
    tesis_auxiliares('tema_ui', 'button', btn_add_sonda, 'secondary');
    tesis_auxiliares('tema_ui', 'button', btn_rem_sonda, 'secondary');

    tbl_sondas = uitable(ctrl, ...
        'Data', {'P1', 0, 0, 18.6; 'P2', 0, 0, 25.2; 'P3', 0, 0, 31.8; 'P4', 0, 0, 38.4}, ...
        'ColumnName', {'Etiqueta', 'X', 'Y', 'Z'}, ...
        'ColumnEditable', [true true true true], ...
        'ColumnFormat', {'char', 'numeric', 'numeric', 'numeric'}, ...
        'RowName', []);
    tbl_sondas.Layout.Row = 13;
    tbl_sondas.Layout.Column = [1 2];

    crear_label(ctrl, 14, 'Tipo preprocesamiento');
    dd_tipo_preprocesamiento = uidropdown(ctrl, ...
        'Items', {'sdf', 'mascara', 'tsdf'}, ...
        'Value', 'sdf', ...
        'Tooltip', 'Metodo volumetrico que usara el boton Preprocesar STL a MAT.');
    dd_tipo_preprocesamiento.Layout.Row = 14;
    dd_tipo_preprocesamiento.Layout.Column = 2;

    crear_label(ctrl, 15, 'Resolucion STL->MAT');
    ed_res_pre = uieditfield(ctrl, 'numeric', 'Value', 0.5, 'Limits', [eps Inf]);
    ed_res_pre.Layout.Row = 15;
    ed_res_pre.Layout.Column = 2;

    pnl_dash = uipanel(gl, 'Title', 'Acciones y Consola');
    pnl_dash.Layout.Row = 1;
    pnl_dash.Layout.Column = 2;
    dash = uigridlayout(pnl_dash, [4, 1]);
    dash.RowHeight = {30, 66, 240, '1x'};
    dash.Padding = [12 12 12 12];
    dash.RowSpacing = 8;
    lbl_estado = uilabel(dash, 'Text', 'Seleccione carpeta e inspeccione modelos.');
    tesis_auxiliares('tema_ui', 'label', lbl_estado, 'status');
    lbl_config = uilabel(dash, 'Text', 'Configuracion activa pendiente.');
    lbl_config.WordWrap = 'on';
    tesis_auxiliares('tema_ui', 'label', lbl_config, 'muted');

    pnl_acciones = uipanel(dash, 'Title', 'Acciones del flujo');
    tesis_auxiliares('tema_ui', 'panel', pnl_acciones);
    gl_acciones = uigridlayout(pnl_acciones, [6, 1]);
    gl_acciones.RowHeight = {30, 30, 30, 30, 30, 30};
    gl_acciones.Padding = [8 6 8 8];
    gl_acciones.RowSpacing = 6;

    btn_inspeccionar = uibutton(gl_acciones, 'Text', 'Inspeccionar modelos .mph', ...
        'ButtonPushedFcn', @(~,~) inspeccionar_modelos());
    tesis_auxiliares('tema_ui', 'button', btn_inspeccionar, 'primary');

    btn_ejecutar = uibutton(gl_acciones, 'Text', 'Ejecutar extractor', ...
        'ButtonPushedFcn', @(~,~) ejecutar_desde_ui());
    tesis_auxiliares('tema_ui', 'button', btn_ejecutar, 'success');

    btn_flujo_completo = uibutton(gl_acciones, 'Text', 'Ejecutar flujo completo', ...
        'ButtonPushedFcn', @(~,~) ejecutar_flujo_completo_desde_ui());
    tesis_auxiliares('tema_ui', 'button', btn_flujo_completo, 'success');

    btn_exportar_mat = uibutton(gl_acciones, 'Text', 'Exportar STL/TXT desde MAT', ...
        'ButtonPushedFcn', @(~,~) exportar_mat_desde_ui());
    tesis_auxiliares('tema_ui', 'button', btn_exportar_mat, 'secondary');

    btn_preprocesar_stl = uibutton(gl_acciones, 'Text', 'Preprocesar STL a MAT', ...
        'ButtonPushedFcn', @(~,~) preprocesar_stl_desde_ui());
    tesis_auxiliares('tema_ui', 'button', btn_preprocesar_stl, 'secondary');

    btn_export_log = uibutton(gl_acciones, 'Text', 'Exportar log', ...
        'ButtonPushedFcn', @(~,~) exportar_log());
    tesis_auxiliares('tema_ui', 'button', btn_export_log, 'secondary');

    txt_log = uitextarea(dash, 'Editable', 'off', 'Value', {'Listo.'});
    tesis_auxiliares('tema_ui', 'textarea', txt_log);

    btn_raiz.ButtonPushedFcn = @(~,~) seleccionar_carpeta_raiz();
    chk_inhabilitar_filtros.ValueChangedFcn = @(~,~) aplicar_estado_filtros();
    dd_tipo_antena.ValueChangedFcn = @(~,~) actualizar_config_label();
    dd_num_antenas.ValueChangedFcn = @(~,~) actualizar_config_label();
    dd_pot_ini.ValueChangedFcn = @(~,~) actualizar_config_label();
    dd_pot_fin.ValueChangedFcn = @(~,~) actualizar_config_label();
    dd_tipo_preprocesamiento.ValueChangedFcn = @(~,~) actualizar_config_label();
    chk_desfase_1ant.ValueChangedFcn = @(~,~) actualizar_estado_desfase();
    idx_sonda_seleccionada = [];
    tbl_sondas.CellSelectionCallback = @(~,evento) seleccionar_sonda(evento);
    tbl_sondas.CellEditCallback = @(~,~) actualizar_config_label();
    btn_add_sonda.ButtonPushedFcn = @(~,~) agregar_sonda();
    btn_rem_sonda.ButtonPushedFcn = @(~,~) remover_sonda();
    campos_actualizan = {ed_salida, ed_patron, ed_Tabl, ed_Tcarb, ed_grilla, ...
        ed_suavizado, ed_res_pre, ed_desfase_x, ed_desfase_y};
    for k = 1:numel(campos_actualizan)
        campos_actualizan{k}.ValueChangedFcn = @(~,~) actualizar_config_label();
    end

    tesis_auxiliares('tema_ui', 'apply', fig);
    tesis_auxiliares('tema_ui', 'textarea', txt_log);
    aplicar_estado_filtros();
    actualizar_estado_desfase();
    actualizar_config_label();

    function crear_label(parent, row, texto)
        lbl = uilabel(parent, 'Text', texto, 'FontWeight', 'bold');
        lbl.Layout.Row = row;
        lbl.Layout.Column = 1;
        tesis_auxiliares('tema_ui', 'label', lbl, 'normal');
    end

    function grupo = crear_grupo_numerico(parent, row, ncols)
        grupo = uigridlayout(parent, [1, ncols]);
        grupo.Layout.Row = row;
        grupo.Layout.Column = 2;
        grupo.ColumnWidth = repmat({'1x'}, 1, ncols);
        grupo.Padding = [0 3 0 3];
        grupo.ColumnSpacing = 10;
    end

    function seleccionar_carpeta_raiz()
        ruta = uigetdir(pwd, 'Selecciona la carpeta raiz con modelos .mph');
        if isequal(ruta, 0)
            return;
        end
        ed_raiz.Value = ruta;
        log_evento('Carpeta raiz seleccionada: %s', ruta);
        inspeccionar_modelos();
    end

    function aplicar_estado_filtros()
        filtros_inhabilitados = chk_inhabilitar_filtros.Value;
        estado_filtro = iff(filtros_inhabilitados, 'off', 'on');
        dd_tipo_antena.Enable = estado_filtro;
        dd_num_antenas.Enable = estado_filtro;
        dd_pot_ini.Enable = estado_filtro;
        dd_pot_fin.Enable = estado_filtro;
        ed_patron.Enable = estado_filtro;
        ed_Tabl.Enable = estado_filtro;
        ed_Tcarb.Enable = estado_filtro;
        if filtros_inhabilitados
            dd_tipo_antena.Value = 'Todos';
            dd_num_antenas.Value = 'Todos';
            dd_pot_ini.Value = '5';
            dd_pot_fin.Value = '100';
            ed_Tabl.Value = 55;
            ed_Tcarb.Value = 500;
            log_evento('Filtros inhabilitados: modelos completos, datasets solo con metadata c#/p#, STL >=55 C y max 500 C.');
        else
            if ed_Tabl.Value < 55 && ed_Tcarb.Value == 500
                ed_Tabl.Value = 55;
                ed_Tcarb.Value = 300;
            end
            log_evento('Filtros habilitados: se usan los controles compactos del panel.');
        end
        actualizar_config_label();
    end

    function actualizar_estado_desfase()
        estado = iff(chk_desfase_1ant.Value, 'on', 'off');
        lbl_desfase_x.Enable = estado;
        lbl_desfase_y.Enable = estado;
        ed_desfase_x.Enable = estado;
        ed_desfase_y.Enable = estado;
        actualizar_config_label();
    end

    function valores = obtener_valores_ui()
        [puntos, etiquetas] = parsear_sondas_tabla(tbl_sondas.Data);
        tipos = {};
        filtros_inhabilitados = chk_inhabilitar_filtros.Value;
        if ~filtros_inhabilitados && ~strcmp(dd_tipo_antena.Value, 'Todos')
            tipos = {dd_tipo_antena.Value};
        end
        num_antenas = [];
        if ~filtros_inhabilitados && ~strcmp(dd_num_antenas.Value, 'Todos')
            num_antenas = str2double(dd_num_antenas.Value);
        end
        if filtros_inhabilitados
            potencia_inicio = 5;
            potencia_fin = 100;
            temperatura_ablacion_ui = 55;
            temperatura_carbonizacion_ui = 500;
        else
            potencia_inicio = str2double(dd_pot_ini.Value);
            potencia_fin = str2double(dd_pot_fin.Value);
            temperatura_ablacion_ui = ed_Tabl.Value;
            temperatura_carbonizacion_ui = ed_Tcarb.Value;
        end
        if potencia_inicio > potencia_fin
            error('La potencia minima no puede ser mayor que la potencia maxima.');
        end
        if ~isfinite(ed_res_pre.Value) || ed_res_pre.Value <= 0
            error('La resolucion de preprocesamiento debe ser positiva.');
        end
        if ~isfinite(ed_desfase_x.Value) || ~isfinite(ed_desfase_y.Value)
            error('El desfase 1ant debe tener coordenadas X/Y finitas.');
        end
        valores = struct( ...
            'ruta_raiz', strtrim(ed_raiz.Value), ...
            'archivo_salida_mat', strtrim(ed_salida.Value), ...
            'filtro_nombre', strtrim(ed_patron.Value), ...
            'ignorar_filtros_modelo', filtros_inhabilitados, ...
            'tipos_antena', {tipos}, ...
            'num_antenas_lista', num_antenas, ...
            'casos_lista', [], ...
            'potencia_inicio', potencia_inicio, ...
            'potencia_fin', potencia_fin, ...
            'potencia_paso', 5, ...
            'potencias_lista', [], ...
            'temperatura_ablacion', temperatura_ablacion_ui, ...
            'temperatura_carbonizacion', temperatura_carbonizacion_ui, ...
            'numero_grilla', ed_grilla.Value, ...
            'numero_iteraciones_suavizado', ed_suavizado.Value, ...
            'resolucion_preprocesamiento', ed_res_pre.Value, ...
            'radio_alpha', 0, ...
            'requiere_metadata_dataset', true, ...
            'desfase_1antena_habilitado', chk_desfase_1ant.Value, ...
            'desfase_1antena_x_mm', ed_desfase_x.Value, ...
            'desfase_1antena_y_mm', ed_desfase_y.Value, ...
            'desfase_1antena_z_objetivo_mm', [], ...
            'desfase_1antena_aplicar_a_todo_eje', true, ...
            'reextraer_1antena_con_nan', true, ...
            'tiempos_min', [], ...
            'puntos_sonda', puntos, ...
            'etiquetas_sonda', {etiquetas});
    end

    function seleccionar_sonda(evento)
        idx_sonda_seleccionada = [];
        try
            if ~isempty(evento.Indices)
                idx_sonda_seleccionada = evento.Indices(1);
            end
        catch
            idx_sonda_seleccionada = [];
        end
    end

    function agregar_sonda()
        datos = tbl_sondas.Data;
        nueva = size(datos, 1) + 1;
        datos(end + 1, :) = {sprintf('P%d', nueva), 0, 0, 0};
        tbl_sondas.Data = datos;
        idx_sonda_seleccionada = nueva;
        log_evento('Sonda agregada: P%d [0 0 0] mm', nueva);
        actualizar_config_label();
    end

    function remover_sonda()
        datos = tbl_sondas.Data;
        if size(datos, 1) <= 1
            uialert(fig, 'Debe conservarse al menos una sonda.', 'Sondas');
            return;
        end
        idx = idx_sonda_seleccionada;
        if isempty(idx) || idx < 1 || idx > size(datos, 1)
            idx = size(datos, 1);
        end
        etiqueta = char(datos{idx, 1});
        datos(idx, :) = [];
        tbl_sondas.Data = datos;
        idx_sonda_seleccionada = [];
        log_evento('Sonda removida: %s', etiqueta);
        actualizar_config_label();
    end

    function inspeccionar_modelos()
        try
            valores = obtener_valores_ui();
            if isempty(valores.ruta_raiz) || ~isfolder(valores.ruta_raiz)
                uialert(fig, 'Selecciona una carpeta raiz valida.', 'Ruta requerida');
                return;
            end
            cfg = normalizar_config_extractor(valores);
            mph_list = dir(fullfile(valores.ruta_raiz, '**', '*.mph'));
            mph_list = mph_list(~[mph_list.isdir]);
            [filtrados, resumen] = aplicar_filtros_modelos_mph(mph_list, cfg);
            lineas = cell(max(4, min(numel(filtrados), 50) + 4), 1);
            lineas{1} = sprintf('Root: %s', valores.ruta_raiz);
            lineas{2} = sprintf('Modelos detectados: %d | Tras filtros: %d', numel(mph_list), numel(filtrados));
            lineas{3} = resumen;
            lineas{4} = sprintf(['Sondas: %d | Datasets utiles: tag con c#/p# | Tiempos: todo el vector simulado | ', ...
                'T ablacion %.1f C | T carbon %.1f C | grilla %d^3 | dominio hueso z 0-45 mm | 1ant %s'], ...
                size(cfg.puntos_sonda, 1), cfg.temperatura_ablacion, ...
                cfg.temperatura_carbonizacion, cfg.numero_grilla, texto_desfase_1ant(cfg.desfase_1antena));
            for i = 1:min(numel(filtrados), 50)
                lineas{i + 4} = sprintf('%02d. %s', i, fullfile(filtrados(i).folder, filtrados(i).name));
            end
            if numel(filtrados) > 50
                lineas{end+1} = sprintf('... %d modelos adicionales no mostrados.', numel(filtrados) - 50);
            end
            escribir_bloque_log('Resumen de inspeccion', lineas(~cellfun('isempty', lineas)));
            lbl_estado.Text = 'Inspeccion completada.';
            actualizar_config_label();
            log_evento('Inspeccion: %d modelos detectados, %d tras filtros.', numel(mph_list), numel(filtrados));
        catch ME
            log_evento('ERROR inspeccion: %s', ME.message);
            uialert(fig, ME.message, 'Error de configuracion');
        end
    end

    function ejecutar_desde_ui()
        try
            valores = obtener_valores_ui();
            if isempty(valores.ruta_raiz) || ~isfolder(valores.ruta_raiz)
                error('Selecciona una carpeta raiz valida antes de ejecutar.');
            end
            normalizar_config_extractor(valores);
            data_paths = tesis_auxiliares('asegurar_dataset_paths');
            valores.ruta_salida_mat = fullfile(data_paths.datasets_masivos, ...
                valores.archivo_salida_mat);
            valores.logfn = @log_evento;
            insertar_separacion_log();
            log_evento('Inicio de extraccion.');
            log_evento('Carpeta raiz: %s', valores.ruta_raiz);
            log_evento('Salida esperada: %s', valores.ruta_salida_mat);
            extractor_comsol_masivo('run', valores);
            lbl_estado.Text = 'Extraccion finalizada.';
            log_evento('Extraccion masiva finalizada.');
        catch ME
            lbl_estado.Text = 'Error durante extraccion.';
            log_evento('ERROR ejecucion: %s', ME.message);
            uialert(fig, ME.message, 'Error del extractor');
        end
    end

    function ejecutar_flujo_completo_desde_ui()
        try
            valores = obtener_valores_ui();
            if isempty(valores.ruta_raiz) || ~isfolder(valores.ruta_raiz)
                error('Selecciona una carpeta raiz valida antes de ejecutar el flujo completo.');
            end
            normalizar_config_extractor(valores);
            data_paths = tesis_auxiliares('asegurar_dataset_paths');
            valores.ruta_salida_mat = fullfile(data_paths.datasets_masivos, ...
                valores.archivo_salida_mat);
            valores.logfn = @log_evento;

            insertar_separacion_log();
            lbl_estado.Text = 'Ejecutando flujo completo...';
            log_evento('Inicio de flujo completo: extractor -> STL/TXT -> MAT.');
            log_evento('Carpeta raiz: %s', valores.ruta_raiz);
            log_evento('MAT masivo: %s', valores.ruta_salida_mat);

            log_evento('[1/3] Ejecutando extractor masivo.');
            extractor_comsol_masivo('run', valores);
            if ~isfile(valores.ruta_salida_mat)
                error('La extraccion no genero el MAT esperado: %s', valores.ruta_salida_mat);
            end

            log_evento('[2/3] Exportando STL/TXT desde MAT.');
            carpeta_stl_opt = data_paths.distribuciones_stl;
            cfg_export = struct( ...
                'ruta_mat_entrada', valores.ruta_salida_mat, ...
                'carpeta_exportacion', carpeta_stl_opt, ...
                'mantener_figuras', true, ...
                'temperatura_min_stl', max(55, valores.temperatura_ablacion), ...
                'radio_alpha', valores.radio_alpha, ...
                'iteraciones_suavizado', valores.numero_iteraciones_suavizado, ...
                'logfn', @log_evento);
            comsol_mat_exportador_masivo('run', cfg_export);

            log_evento('[3/3] Preprocesando STL a MAT.');
            carpeta_mat = data_paths.distribuciones_mat;
            cfg_pre = struct( ...
                'carpeta_stl', carpeta_stl_opt, ...
                'carpeta_salida', carpeta_mat, ...
                'resolucion', valores.resolucion_preprocesamiento, ...
                'tipo_procesamiento', dd_tipo_preprocesamiento.Value, ...
                'logfn', @log_evento);
            preprocesar_stl_a_mat('run', cfg_pre);

            lbl_estado.Text = 'Flujo completo finalizado.';
            log_evento('Flujo completo finalizado correctamente.');
        catch ME
            lbl_estado.Text = 'Error durante flujo completo.';
            log_evento('ERROR flujo completo: %s', ME.message);
            uialert(fig, ME.message, 'Error del flujo completo');
        end
    end

    function exportar_mat_desde_ui()
        try
            valores = obtener_valores_ui();
            if isempty(valores.ruta_raiz) || ~isfolder(valores.ruta_raiz)
                error('Selecciona una carpeta raiz valida antes de exportar.');
            end
            data_paths = tesis_auxiliares('asegurar_dataset_paths');
            ruta_mat = fullfile(data_paths.datasets_masivos, valores.archivo_salida_mat);
            if ~isfile(ruta_mat)
                error('No existe el MAT del extractor: %s', ruta_mat);
            end
            insertar_separacion_log();
            log_evento('Inicio de exportacion STL/TXT desde MAT.');
            log_evento('MAT de entrada: %s', ruta_mat);
            carpeta_stl_opt = data_paths.distribuciones_stl;
            cfg_export = struct( ...
                'ruta_mat_entrada', ruta_mat, ...
                'carpeta_exportacion', carpeta_stl_opt, ...
                'mantener_figuras', true, ...
                'temperatura_min_stl', max(55, valores.temperatura_ablacion), ...
                'logfn', @log_evento);
            log_evento('Salida STL para optimizador: %s', carpeta_stl_opt);
            log_evento('Umbral minimo STL: %.1f C', cfg_export.temperatura_min_stl);
            comsol_mat_exportador_masivo('run', cfg_export);
            lbl_estado.Text = 'Exportacion STL/TXT finalizada.';
            log_evento('Exportacion STL/TXT finalizada.');
        catch ME
            lbl_estado.Text = 'Error durante exportacion.';
            log_evento('ERROR exportacion MAT: %s', ME.message);
            uialert(fig, ME.message, 'Error del exportador MAT');
        end
    end

    function preprocesar_stl_desde_ui()
        try
            valores = obtener_valores_ui();
            if isempty(valores.ruta_raiz) || ~isfolder(valores.ruta_raiz)
                error('Selecciona una carpeta raiz valida antes de preprocesar.');
            end
            data_paths = tesis_auxiliares('asegurar_dataset_paths');
            carpeta_stl = data_paths.distribuciones_stl;
            if ~isfolder(carpeta_stl)
                error(['No existe la carpeta de STL exportados: %s\n', ...
                    'Ejecuta primero "Exportar STL/TXT desde MAT".'], carpeta_stl);
            end
            carpeta_mat = data_paths.distribuciones_mat;
            insertar_separacion_log();
            log_evento('Inicio de preprocesamiento STL a MAT.');
            log_evento('Carpeta STL: %s', carpeta_stl);
            log_evento('Salida MAT para optimizador: %s', carpeta_mat);
            cfg_pre = struct( ...
                'carpeta_stl', carpeta_stl, ...
                'carpeta_salida', carpeta_mat, ...
                'resolucion', valores.resolucion_preprocesamiento, ...
                'tipo_procesamiento', dd_tipo_preprocesamiento.Value, ...
                'logfn', @log_evento);
            log_evento('Resolucion: %.2f mm | Metodo: %s', ...
                cfg_pre.resolucion, cfg_pre.tipo_procesamiento);
            preprocesar_stl_a_mat('run', cfg_pre);
            lbl_estado.Text = 'Preprocesamiento STL a MAT finalizado.';
            log_evento('Preprocesamiento STL a MAT finalizado.');
        catch ME
            lbl_estado.Text = 'Error durante preprocesamiento.';
            log_evento('ERROR preprocesamiento STL: %s', ME.message);
            uialert(fig, ME.message, 'Error de preprocesamiento STL');
        end
    end

    function actualizar_config_label()
        try
            valores = obtener_valores_ui();
            cfg = normalizar_config_extractor(valores);
            lbl_config.Text = sprintf(['Modo=%s | tipo=%s | antenas=%s | potencias=%s W (paso 5) | ', ...
                'datasets=metadata c#/p# | tiempos=completos | sondas=%d | T=[%.1f, %.1f] C | ', ...
                'dom=hueso z0-45 | grilla=%d^3 | prepro=%s | res=%.2f mm | 1ant: %s'], ...
                iff(cfg.ignorar_filtros_modelo, 'sin filtros', 'filtrado'), ...
                texto_lista(cfg.tipos_antena), mat2str(cfg.num_antenas), mat2str(cfg.potencias), ...
                size(cfg.puntos_sonda, 1), cfg.temperatura_ablacion, ...
                cfg.temperatura_carbonizacion, cfg.numero_grilla, dd_tipo_preprocesamiento.Value, ...
                valores.resolucion_preprocesamiento, texto_desfase_1ant(cfg.desfase_1antena));
        catch
            lbl_config.Text = 'Configuracion incompleta o invalida.';
        end
    end

    function texto = texto_desfase_1ant(desfase)
        if ~isfield(desfase, 'habilitado') || ~desfase.habilitado
            texto = 'sin desfase';
            return;
        end
        texto = sprintf('X=%.4g, Y=%.4g, Z=tabla', desfase.x_mm, desfase.y_mm);
    end

    function escribir_bloque_log(titulo, lineas)
        marca = char(datetime('now', 'Format', 'HH:mm:ss'));
        if ischar(lineas) || isstring(lineas)
            lineas = cellstr(lineas);
        end
        lineas = lineas(:);
        bloque = [{sprintf('[%s] %s', marca, titulo)}; ...
            cellfun(@(s) sprintf('    %s', s), lineas, 'UniformOutput', false)];
        txt_log.Value = [bloque; txt_log.Value(:)];
        drawnow limitrate;
    end

    function insertar_separacion_log()
        txt_log.Value = [repmat({''}, 5, 1); txt_log.Value(:)];
        drawnow limitrate;
    end

    function exportar_log()
        [archivo, carpeta] = uiputfile('*.txt', 'Exportar log', 'extractor_comsol_masivo_log.txt');
        if isequal(archivo, 0)
            return;
        end
        ruta = fullfile(carpeta, archivo);
        fid = fopen(ruta, 'w');
        if fid < 0
            uialert(fig, 'No se pudo crear el archivo de log.', 'Error');
            return;
        end
        limpieza = onCleanup(@() fclose(fid));
        lineas = flipud(txt_log.Value(:));
        for k = 1:numel(lineas)
            fprintf(fid, '%s\n', lineas{k});
        end
        log_evento('Log exportado: %s', ruta);
    end

    function log_evento(formato, varargin)
        marca = char(datetime('now', 'Format', 'HH:mm:ss'));
        linea = sprintf('[%s] %s', marca, sprintf(formato, varargin{:}));
        txt_log.Value = [{linea}; txt_log.Value(:)];
        drawnow limitrate;
    end
end

function out = iff(condicion, verdadero, falso)
    if condicion
        out = verdadero;
    else
        out = falso;
    end
end

function valor = obtener_campo_config(config, campo, valor_default)
    valor = valor_default;
    if isstruct(config) && isfield(config, campo) && ~isempty(config.(campo))
        valor = config.(campo);
    end
end

function logger = configurar_log_extractor(nuevo_logger)
    persistent logger_actual
    if nargin > 0
        logger_actual = nuevo_logger;
    end
    logger = logger_actual;
end

function log_extractor(formato, varargin)
    logger = configurar_log_extractor();
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
