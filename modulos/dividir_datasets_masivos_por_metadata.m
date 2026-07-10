function resumen = dividir_datasets_masivos_por_metadata(varargin)
%DIVIDIR_DATASETS_MASIVOS_POR_METADATA Divide MAT masivos en archivos pequenos.
%
% Uso rapido:
%   dividir_datasets_masivos_por_metadata()  % procesa todos los MAT masivos
%
% Uso con configuracion:
%   cfg = struct('ruta_entrada', 'DATASETS/datasets_masivos/Dataset.mat');
%   resumen = dividir_datasets_masivos_por_metadata('run', cfg);
%
% Salida por defecto:
%   DATASETS/datasets_masivos_por_metadata/<Tipo>/<Nant>/Caso_X/Potencia_YW/*.mat
%
% Cada archivo generado conserva el contrato esperado por los modulos:
%   dataset.(modelo).(tag_dataset)

    bootstrap_modulo();
    paths = tesis_auxiliares('asegurar_dataset_paths');
    config = normalizar_configuracion(varargin{:});

    logfn = obtener_campo_config(config, 'logfn', []);
    if isempty(logfn)
        logfn = @(varargin) fprintf([varargin{1} '\n'], varargin{2:end});
    end

    rutas_entrada = resolver_rutas_entrada(config, paths);
    carpeta_salida = obtener_campo_config(config, ...
        'carpeta_salida', paths.datasets_masivos_por_metadata);
    agrupar_por = lower(char(obtener_campo_config(config, ...
        'agrupar_por', 'tipo_antenas_caso_potencia')));
    sobrescribir = logical(obtener_campo_config(config, 'sobrescribir', false));
    incluir_sin_metadata = logical(obtener_campo_config(config, ...
        'incluir_sin_metadata', true));
    fusionar_indice = logical(obtener_campo_config(config, 'fusionar_indice', true));

    crear_carpeta_si_no_existe(carpeta_salida);

    resumen = struct();
    resumen.fecha = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    resumen.carpeta_salida = carpeta_salida;
    resumen.agrupar_por = agrupar_por;
    resumen.archivos_entrada = rutas_entrada;
    resumen.particiones = crear_resumen_particion(0);
    resumen.omitidos = {};

    logfn('Divisor por metadata iniciado.');
    logfn('Archivos de entrada: %d', numel(rutas_entrada));
    logfn('Salida: %s', carpeta_salida);

    for idx_archivo = 1:numel(rutas_entrada)
        ruta_entrada = rutas_entrada{idx_archivo};
        logfn('---');
        logfn('[%d/%d] Explorando: %s', idx_archivo, numel(rutas_entrada), ruta_entrada);
        if es_mat_v73_con_dataset(ruta_entrada)
            resumen = dividir_archivo_por_hdf5( ...
                ruta_entrada, resumen, carpeta_salida, agrupar_por, ...
                sobrescribir, incluir_sin_metadata, logfn);
        else
            logfn('[WARN] MAT no v7.3 o sin /dataset HDF5. Usando carga completa de respaldo.');
            resumen = dividir_archivo_por_load( ...
                ruta_entrada, resumen, carpeta_salida, agrupar_por, ...
                sobrescribir, incluir_sin_metadata, logfn);
        end
    end

    resumen = escribir_indice_particiones( ...
        carpeta_salida, resumen, logfn, fusionar_indice);
    logfn('Particiones registradas: %d', numel(resumen.particiones));
    logfn('Omitidos: %d', numel(resumen.omitidos));
end

function bootstrap_modulo()
    carpeta_modulo = fileparts(mfilename('fullpath'));
    candidatos_aux = {fullfile(carpeta_modulo, '..', 'Aux_Codes'), ...
        fullfile(carpeta_modulo, '..', '..', 'Aux_Codes')};
    for k = 1:numel(candidatos_aux)
        if isfolder(candidatos_aux{k})
            addpath(candidatos_aux{k});
        end
    end
    if exist('tesis_auxiliares', 'file') == 2
        tesis_auxiliares('configurar_paths', carpeta_modulo);
    end
end

function config = normalizar_configuracion(varargin)
    config = struct();
    if nargin == 0
        return;
    end
    if nargin >= 2 && ischar(varargin{1}) && strcmpi(varargin{1}, 'run')
        config = varargin{2};
    elseif nargin >= 1 && isstruct(varargin{1})
        config = varargin{1};
    elseif nargin >= 1 && (ischar(varargin{1}) || isstring(varargin{1}))
        config.ruta_entrada = char(varargin{1});
    end
end

function rutas = resolver_rutas_entrada(config, paths)
    if isfield(config, 'rutas_entrada') && ~isempty(config.rutas_entrada)
        rutas = normalizar_lista_rutas(config.rutas_entrada);
    elseif isfield(config, 'ruta_entrada') && ~isempty(config.ruta_entrada)
        rutas = normalizar_lista_rutas(config.ruta_entrada);
    else
        procesar_todos = logical(obtener_campo_config(config, 'procesar_todos', true));
        if procesar_todos
            rutas = buscar_archivos_mat(paths.datasets_masivos);
        else
            rutas = {tesis_auxiliares('dataset_masivo_reciente', paths, false)};
        end
    end

    if isscalar(rutas) && isfolder(rutas{1})
        rutas = buscar_archivos_mat(rutas{1});
    end
    rutas = rutas(cellfun(@isfile, rutas));
    if isempty(rutas)
        error('No se encontraron archivos .mat de entrada para dividir.');
    end
end

function rutas = normalizar_lista_rutas(valor)
    if isstring(valor)
        valor = cellstr(valor(:));
    elseif ischar(valor)
        valor = {valor};
    end
    rutas = valor(:)';
    rutas = cellfun(@char, rutas, 'UniformOutput', false);
end

function rutas = buscar_archivos_mat(carpeta)
    archivos = dir(fullfile(carpeta, '*.mat'));
    archivos = archivos(~[archivos.isdir]);
    keep = true(numel(archivos), 1);
    for k = 1:numel(archivos)
        nombre = lower(archivos(k).name);
        keep(k) = endsWith(nombre, '.mat') && ...
            ~startsWith(nombre, 'indice_') && ...
            ~contains(nombre, 'historial');
    end
    archivos = archivos(keep);
    [~, orden] = sort([archivos.datenum], 'descend');
    archivos = archivos(orden);
    rutas = arrayfun(@(a) fullfile(a.folder, a.name), archivos, 'UniformOutput', false);
end

function tf = es_mat_v73_con_dataset(ruta)
    fid = [];
    gid = [];
    try
        fid = H5F.open(ruta, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
        gid = H5G.open(fid, '/dataset');
        tf = true;
    catch
        tf = false;
    end
    try
        H5G.close(gid);
    catch
    end
    try
        H5F.close(fid);
    catch
    end
end

function resumen = dividir_archivo_por_hdf5(ruta_entrada, resumen, carpeta_salida, ...
        agrupar_por, sobrescribir, incluir_sin_metadata, logfn)
    fid = H5F.open(ruta_entrada, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
    cleanup = onCleanup(@() H5F.close(fid));
    modelos = listar_hijos_grupo_hdf5(fid, '/dataset', 'group');
    logfn('Modelos detectados via HDF5: %d', numel(modelos));

    for idx_modelo = 1:numel(modelos)
        modelo = modelos{idx_modelo};
        if strcmp(modelo, 'session_meta')
            continue;
        end

        ruta_modelo = unir_ruta_hdf5('/dataset', modelo);
        tags_dataset = listar_hijos_grupo_hdf5(fid, ruta_modelo, 'group');
        for idx_dataset = 1:numel(tags_dataset)
            tag_dataset = tags_dataset{idx_dataset};
            if ismember(tag_dataset, {'session_meta', 'datasets_omitidos', 'source_signature'})
                continue;
            end

            ruta_tag = unir_ruta_hdf5(ruta_modelo, tag_dataset);
            if ~es_grupo_dataset_termico_hdf5(fid, ruta_tag)
                resumen.omitidos{end + 1, 1} = sprintf( ...
                    '%s/%s: estructura HDF5 sin snapshots/full_field/probes', ...
                    modelo, tag_dataset);
                continue;
            end

            meta = extraer_metadata_particion_hdf5( ...
                modelo, tag_dataset, ruta_entrada, ruta_tag);
            if ~meta.es_util && ~incluir_sin_metadata
                resumen.omitidos{end + 1, 1} = sprintf( ...
                    '%s/%s: %s', modelo, tag_dataset, meta.motivo);
                continue;
            end

            [carpeta_particion, archivo_particion] = construir_destino_particion( ...
                carpeta_salida, ruta_entrada, modelo, tag_dataset, meta, agrupar_por);
            crear_carpeta_si_no_existe(carpeta_particion);
            ruta_salida = fullfile(carpeta_particion, archivo_particion);

            partition_key = clave_particion_metadata(ruta_entrada, modelo, tag_dataset);
            adoptar_particion_legacy( ...
                carpeta_particion, ruta_salida, ruta_entrada, modelo, tag_dataset, logfn);
            if ~sobrescribir && particion_vigente(ruta_salida, partition_key)
                registrar_alias_particion(ruta_salida, ruta_entrada, partition_key);
                logfn('Omitido vigente: %s', ruta_salida);
                resumen = agregar_particion_resumen(resumen, crear_item_resumen( ...
                    ruta_salida, ruta_entrada, modelo, tag_dataset, meta));
                continue;
            end

            partition_meta = crear_partition_meta( ...
                ruta_entrada, modelo, tag_dataset, meta, agrupar_por);
            inicializar_mat_particion(ruta_salida, modelo, tag_dataset, partition_meta);
            copiar_dataset_hdf5( ...
                ruta_entrada, ruta_tag, ruta_salida, ...
                sprintf('/dataset/%s/%s', modelo, tag_dataset));

            item = crear_item_resumen(ruta_salida, ruta_entrada, modelo, tag_dataset, meta);
            resumen = agregar_particion_resumen(resumen, item);
            logfn('Generado: %s', ruta_salida);
        end
    end
    clear cleanup;
end

function resumen = dividir_archivo_por_load(ruta_entrada, resumen, carpeta_salida, ...
        agrupar_por, sobrescribir, incluir_sin_metadata, logfn)
    logfn('Cargando MAT completo de respaldo: %s', ruta_entrada);
    raw = load(ruta_entrada);
    dataset_origen = extraer_dataset_desde_struct(raw);
    clear raw;

    modelos = fieldnames(dataset_origen);
    modelos = modelos(~strcmp(modelos, 'session_meta'));
    logfn('Modelos detectados por load: %d', numel(modelos));

    for idx_modelo = 1:numel(modelos)
        modelo = modelos{idx_modelo};
        if ~isstruct(dataset_origen.(modelo))
            resumen.omitidos{end + 1, 1} = sprintf('%s: modelo no estructurado', modelo);
            continue;
        end

        tags_dataset = fieldnames(dataset_origen.(modelo));
        tags_dataset = tags_dataset(~ismember(tags_dataset, ...
            {'session_meta', 'datasets_omitidos', 'source_signature'}));

        for idx_dataset = 1:numel(tags_dataset)
            tag_dataset = tags_dataset{idx_dataset};
            datos_solucion = dataset_origen.(modelo).(tag_dataset);
            if ~es_dataset_termico_valido(datos_solucion)
                resumen.omitidos{end + 1, 1} = sprintf( ...
                    '%s/%s: estructura sin snapshots/full_field', modelo, tag_dataset);
                continue;
            end

            meta = extraer_metadata_particion(modelo, tag_dataset, datos_solucion);
            if ~meta.es_util && ~incluir_sin_metadata
                resumen.omitidos{end + 1, 1} = sprintf( ...
                    '%s/%s: %s', modelo, tag_dataset, meta.motivo);
                continue;
            end

            [carpeta_particion, archivo_particion] = construir_destino_particion( ...
                carpeta_salida, ruta_entrada, modelo, tag_dataset, meta, agrupar_por);
            crear_carpeta_si_no_existe(carpeta_particion);
            ruta_salida = fullfile(carpeta_particion, archivo_particion);

            partition_key = clave_particion_metadata(ruta_entrada, modelo, tag_dataset);
            adoptar_particion_legacy( ...
                carpeta_particion, ruta_salida, ruta_entrada, modelo, tag_dataset, logfn);
            if ~sobrescribir && particion_vigente(ruta_salida, partition_key)
                registrar_alias_particion(ruta_salida, ruta_entrada, partition_key);
                logfn('Omitido vigente: %s', ruta_salida);
                resumen = agregar_particion_resumen(resumen, crear_item_resumen( ...
                    ruta_salida, ruta_entrada, modelo, tag_dataset, meta));
                continue;
            end

            dataset = construir_dataset_particion( ...
                dataset_origen, modelo, tag_dataset, datos_solucion);
            partition_meta = crear_partition_meta( ...
                ruta_entrada, modelo, tag_dataset, meta, agrupar_por);
            save(ruta_salida, 'dataset', 'partition_meta', '-v7.3');
            item = crear_item_resumen(ruta_salida, ruta_entrada, modelo, tag_dataset, meta);
            resumen = agregar_particion_resumen(resumen, item);
            logfn('Generado: %s', ruta_salida);
        end
    end

    clear dataset_origen;
end

function ruta = unir_ruta_hdf5(parent, name)
    if strcmp(parent, '/')
        ruta = ['/' char(name)];
    else
        ruta = [char(parent) '/' char(name)];
    end
end

function nombres = listar_hijos_grupo_hdf5(fid, ruta_grupo, tipo)
    nombres = {};
    gid = H5G.open(fid, ruta_grupo);
    cleanup_gid = onCleanup(@() H5G.close(gid));
    info = H5G.get_info(gid);
    tipo_grupo = H5ML.get_constant_value('H5G_GROUP');
    tipo_dataset = H5ML.get_constant_value('H5G_DATASET');
    for idx = 0:double(info.nlinks) - 1
        nombre = H5L.get_name_by_idx(fid, ruta_grupo, ...
            'H5_INDEX_NAME', 'H5_ITER_INC', idx, 'H5P_DEFAULT');
        ruta_objeto = unir_ruta_hdf5(ruta_grupo, nombre);
        obj_id = H5O.open(fid, ruta_objeto, 'H5P_DEFAULT');
        cleanup_obj = onCleanup(@() H5O.close(obj_id));
        obj_info = H5O.get_info(obj_id);
        incluir = (strcmp(tipo, 'group') && obj_info.type == tipo_grupo) || ...
            (strcmp(tipo, 'dataset') && obj_info.type == tipo_dataset) || ...
            strcmp(tipo, 'any');
        clear cleanup_obj;
        if incluir
            nombres{end + 1} = nombre; %#ok<AGROW>
        end
    end
    clear cleanup_gid;
end

function tf = es_grupo_dataset_termico_hdf5(fid, ruta_tag)
    grupos = listar_hijos_grupo_hdf5(fid, ruta_tag, 'group');
    datos = listar_hijos_grupo_hdf5(fid, ruta_tag, 'dataset');
    tf = any(ismember({'snapshots', 'full_field', 'probes'}, grupos)) || ...
        any(strcmp(datos, 't_min'));
end

function meta = extraer_metadata_particion_hdf5(modelo, tag_dataset, ruta_entrada, ruta_tag_hdf5)
    meta = crear_metadata_base(modelo, tag_dataset);
    [tiene_tag, caso_tag, potencia_tag] = extraer_metadata_tag(tag_dataset);
    if tiene_tag
        meta.caso = caso_tag;
        meta.potencia_W = potencia_tag;
    end

    caso_md = leer_escalar_hdf5(ruta_entrada, [ruta_tag_hdf5 '/metadata/idx_caso']);
    if isfinite_num(caso_md)
        meta.caso = double(caso_md);
    end
    potencia_md = leer_escalar_hdf5(ruta_entrada, [ruta_tag_hdf5 '/metadata/potencia_W']);
    if isfinite_num(potencia_md)
        meta.potencia_W = double(potencia_md);
    end
    caso_mds = leer_escalar_hdf5(ruta_entrada, [ruta_tag_hdf5 '/metadata/metadata_dataset/caso']);
    if isfinite_num(caso_mds)
        meta.caso = double(caso_mds);
    end
    potencia_mds = leer_escalar_hdf5(ruta_entrada, [ruta_tag_hdf5 '/metadata/metadata_dataset/potencia_W']);
    if isfinite_num(potencia_mds)
        meta.potencia_W = double(potencia_mds);
    end

    meta = finalizar_metadata_util(meta);
end

function valor = leer_escalar_hdf5(ruta, ruta_dataset)
    valor = NaN;
    try
        datos = h5read(ruta, ruta_dataset);
        if isnumeric(datos) && isscalar(datos)
            valor = double(datos);
        end
    catch
        valor = NaN;
    end
end

function inicializar_mat_particion(ruta_salida, modelo, tag_dataset, partition_meta)
    dataset = struct();
    dataset.(modelo).(tag_dataset) = struct();
    save(ruta_salida, 'dataset', 'partition_meta', '-v7.3');
end

function tf = particion_vigente(ruta_salida, partition_key)
    tf = false;
    if ~isfile(ruta_salida)
        return;
    end
    [~, nombre_archivo, ~] = fileparts(ruta_salida);
    if strcmpi(nombre_archivo, sanitizar_nombre(partition_key))
        tf = true;
        return;
    end
    try
        raw = load(ruta_salida, 'partition_meta');
        if ~isfield(raw, 'partition_meta') || ~isstruct(raw.partition_meta)
            return;
        end
        pm = raw.partition_meta;
        if isfield(pm, 'partition_key') && ~isempty(pm.partition_key)
            tf = strcmpi(char(pm.partition_key), char(partition_key));
        else
            tf = strcmpi(nombre_archivo, sanitizar_nombre(partition_key));
        end
    catch
        tf = false;
    end
end

function copiar_dataset_hdf5(ruta_entrada, ruta_tag_entrada, ruta_salida, ruta_tag_salida)
    src_f = H5F.open(ruta_entrada, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
    dst_f = H5F.open(ruta_salida, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
    ocpl = H5P.create('H5P_OBJECT_COPY');
    lcpl = H5P.create('H5P_LINK_CREATE');
    cleanup = onCleanup(@() cerrar_recursos_hdf5(src_f, dst_f, ocpl, lcpl));

    expand_ref = H5ML.get_constant_value('H5O_COPY_EXPAND_REFERENCE_FLAG');
    H5P.set_copy_object(ocpl, expand_ref);
    H5P.set_create_intermediate_group(lcpl, true);

    try
        H5L.delete(dst_f, ruta_tag_salida, 'H5P_DEFAULT');
    catch
    end
    H5O.copy(src_f, ruta_tag_entrada, dst_f, ruta_tag_salida, ocpl, lcpl);
    clear cleanup;

    mover_referencias_copiadas_a_refs(ruta_salida);
end

function cerrar_recursos_hdf5(src_f, dst_f, ocpl, lcpl)
    try
        H5P.close(lcpl);
    catch
    end
    try
        H5P.close(ocpl);
    catch
    end
    try
        H5F.close(dst_f);
    catch
    end
    try
        H5F.close(src_f);
    catch
    end
end

function mover_referencias_copiadas_a_refs(ruta_salida)
    fid = H5F.open(ruta_salida, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
    cleanup = onCleanup(@() H5F.close(fid));
    nombres = listar_hijos_grupo_hdf5(fid, '/', 'any');
    nombres = nombres(startsWith(nombres, '~obj_pointed_by_'));
    if isempty(nombres)
        clear cleanup;
        return;
    end

    refs_existentes = nombres_refs_existentes(fid);
    siguiente = numel(refs_existentes) + 1;
    for k = 1:numel(nombres)
        destino = sprintf('copied_ref_%06d', siguiente);
        while ismember(destino, refs_existentes)
            siguiente = siguiente + 1;
            destino = sprintf('copied_ref_%06d', siguiente);
        end
        H5L.move(fid, ['/' nombres{k}], fid, ['/#refs#/' destino], ...
            'H5P_DEFAULT', 'H5P_DEFAULT');
        refs_existentes{end + 1} = destino; %#ok<AGROW>
        siguiente = siguiente + 1;
    end
    clear cleanup;
end

function nombres = nombres_refs_existentes(fid)
    try
        nombres = listar_hijos_grupo_hdf5(fid, '/#refs#', 'any');
    catch
        nombres = {};
    end
end

function dataset = extraer_dataset_desde_struct(raw)
    if isfield(raw, 'dataset') && isstruct(raw.dataset)
        dataset = raw.dataset;
        return;
    end
    campos = fieldnames(raw);
    for k = 1:numel(campos)
        if isstruct(raw.(campos{k}))
            dataset = raw.(campos{k});
            return;
        end
    end
    error('El MAT no contiene una estructura dataset reconocible.');
end

function tf = es_dataset_termico_valido(datos)
    tf = isstruct(datos) && ...
        (isfield(datos, 'snapshots') || isfield(datos, 'full_field') || isfield(datos, 'probes'));
end

function meta = extraer_metadata_particion(modelo, tag_dataset, datos_solucion)
    meta = crear_metadata_base(modelo, tag_dataset);
    [tiene_tag, caso_tag, potencia_tag] = extraer_metadata_tag(tag_dataset);
    if tiene_tag
        meta.caso = caso_tag;
        meta.potencia_W = potencia_tag;
    end

    meta = completar_metadata_desde_struct(meta, datos_solucion);
    meta = finalizar_metadata_util(meta);
end

function meta = crear_metadata_base(modelo, tag_dataset)
    meta = struct();
    meta.modelo = char(modelo);
    meta.tag_dataset = char(tag_dataset);
    meta.tipo = extraer_primer_match(modelo, {'Doble_slot', 'Monopolo', 'Un_slot'}, '');
    meta.num_antenas = NaN;
    meta.antena = '';
    meta.caso = NaN;
    meta.potencia_W = NaN;
    meta.es_util = false;
    meta.motivo = '';

    antena_token = regexp(char(modelo), '(\d+)ant', 'tokens', 'once');
    if ~isempty(antena_token)
        meta.num_antenas = str2double(antena_token{1});
        meta.antena = sprintf('%dant', meta.num_antenas);
    end
end

function meta = finalizar_metadata_util(meta)
    faltantes = {};
    if isempty(meta.tipo), faltantes{end + 1} = 'tipo'; end
    if ~isfinite(meta.num_antenas), faltantes{end + 1} = 'antenas'; end
    if ~isfinite(meta.caso), faltantes{end + 1} = 'caso'; end
    if ~isfinite(meta.potencia_W), faltantes{end + 1} = 'potencia'; end

    if isempty(faltantes)
        meta.es_util = true;
        meta.motivo = 'metadata valida';
    else
        meta.motivo = ['metadata incompleta: ' strjoin(faltantes, ', ')];
    end
end

function meta = completar_metadata_desde_struct(meta, datos_solucion)
    if ~isfield(datos_solucion, 'metadata') || ~isstruct(datos_solucion.metadata)
        return;
    end
    md = datos_solucion.metadata;
    if isfield(md, 'metadata_dataset') && isstruct(md.metadata_dataset)
        mds = md.metadata_dataset;
        if isfield(mds, 'caso') && isfinite_num(mds.caso)
            meta.caso = double(mds.caso);
        end
        if isfield(mds, 'potencia_W') && isfinite_num(mds.potencia_W)
            meta.potencia_W = double(mds.potencia_W);
        end
    end
    if isfield(md, 'idx_caso') && isfinite_num(md.idx_caso)
        meta.caso = double(md.idx_caso);
    end
    if isfield(md, 'potencia_W') && isfinite_num(md.potencia_W)
        meta.potencia_W = double(md.potencia_W);
    end
end

function tf = isfinite_num(valor)
    tf = isnumeric(valor) && isscalar(valor) && isfinite(double(valor));
end

function [tiene_metadata, caso, potencia] = extraer_metadata_tag(tag_dataset)
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
    texto = char(texto);
    for k = 1:numel(candidatos)
        if contains(texto, candidatos{k})
            valor = candidatos{k};
            return;
        end
    end
end

function [carpeta, archivo] = construir_destino_particion( ...
        root_salida, ruta_entrada, modelo, tag_dataset, meta, agrupar_por)
    tipo = valor_o_default(meta.tipo, 'Tipo_desconocido');
    antena = valor_o_default(meta.antena, 'antenas_desconocidas');
    caso = texto_caso(meta.caso);
    potencia = texto_potencia(meta.potencia_W);

    switch agrupar_por
        case 'tipo'
            carpeta = fullfile(root_salida, tipo);
        case {'tipo_antenas', 'tipo_antena'}
            carpeta = fullfile(root_salida, tipo, antena);
        otherwise
            carpeta = fullfile(root_salida, tipo, antena, caso, potencia);
    end

    archivo = [sanitizar_nombre(clave_particion_metadata( ...
        ruta_entrada, modelo, tag_dataset)) '.mat'];
end

function clave = clave_particion_metadata(~, modelo, tag_dataset)
    clave = strjoin({char(modelo), char(tag_dataset)}, '__');
end

function clave = clave_particion_fuente(ruta_entrada, modelo, tag_dataset)
    [~, fuente] = fileparts(char(ruta_entrada));
    if isempty(fuente)
        fuente = 'fuente_desconocida';
    end
    clave = strjoin({fuente, char(modelo), char(tag_dataset)}, '__');
end

function adoptar_particion_legacy( ...
        carpeta_particion, ruta_salida, ruta_entrada, modelo, tag_dataset, logfn)
    if isfile(ruta_salida)
        return;
    end
    archivo_legacy = [sanitizar_nombre(clave_particion_fuente( ...
        ruta_entrada, modelo, tag_dataset)) '.mat'];
    ruta_legacy = fullfile(carpeta_particion, archivo_legacy);
    if ~isfile(ruta_legacy)
        return;
    end
    [ok, msg] = movefile(ruta_legacy, ruta_salida, 'f');
    if ok
        logfn('Particion legacy adoptada como canonica: %s', ruta_salida);
    else
        logfn('[WARN] No se pudo adoptar particion legacy: %s', msg);
    end
end

function registrar_alias_particion(ruta_salida, ruta_entrada, partition_key)
    try
        raw = load(ruta_salida, 'partition_meta');
        if isfield(raw, 'partition_meta') && isstruct(raw.partition_meta)
            partition_meta = raw.partition_meta;
        else
            partition_meta = struct();
        end
        partition_meta.partition_key = char(partition_key);
        if ~isfield(partition_meta, 'ruta_entrada') || isempty(partition_meta.ruta_entrada)
            partition_meta.ruta_entrada = char(ruta_entrada);
        end
        partition_meta.fuentes_equivalentes = fusionar_aliases( ...
            obtener_aliases(partition_meta), {char(ruta_entrada)});
        save(ruta_salida, 'partition_meta', '-append');
    catch
    end
end

function texto = valor_o_default(valor, predeterminado)
    if isempty(valor)
        texto = predeterminado;
    else
        texto = char(valor);
    end
end

function texto = texto_caso(caso)
    if isfinite_num(caso)
        texto = sprintf('Caso_%d', round(double(caso)));
    else
        texto = 'Caso_desconocido';
    end
end

function texto = texto_potencia(potencia)
    if isfinite_num(potencia)
        texto = sprintf('Potencia_%gW', double(potencia));
        texto = strrep(texto, '.', 'p');
    else
        texto = 'Potencia_desconocida';
    end
end

function nombre = sanitizar_nombre(nombre)
    nombre = regexprep(char(nombre), '[^\w.-]+', '_');
    nombre = regexprep(nombre, '_+', '_');
    nombre = regexprep(nombre, '^_+|_+$', '');
end

function dataset = construir_dataset_particion(dataset_origen, modelo, tag_dataset, datos_solucion)
    dataset = struct();
    if isfield(dataset_origen, 'session_meta')
        dataset.session_meta = dataset_origen.session_meta;
    end
    if isfield(dataset_origen.(modelo), 'session_meta')
        dataset.(modelo).session_meta = dataset_origen.(modelo).session_meta;
    end
    if isfield(dataset_origen.(modelo), 'source_signature')
        dataset.(modelo).source_signature = dataset_origen.(modelo).source_signature;
    end
    dataset.(modelo).(tag_dataset) = datos_solucion;
end

function partition_meta = crear_partition_meta(ruta_entrada, modelo, tag_dataset, meta, agrupar_por)
    partition_meta = meta;
    partition_meta.ruta_entrada = ruta_entrada;
    partition_meta.modelo = char(modelo);
    partition_meta.tag_dataset = char(tag_dataset);
    partition_meta.partition_key = clave_particion_metadata( ...
        ruta_entrada, modelo, tag_dataset);
    partition_meta.fuentes_equivalentes = {char(ruta_entrada)};
    partition_meta.agrupar_por = agrupar_por;
    partition_meta.fecha_generacion = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function resumen = crear_resumen_particion(n)
    if nargin < 1
        n = 1;
    end
    plantilla = struct( ...
        'ruta', '', ...
        'fuente', '', ...
        'modelo', '', ...
        'dataset', '', ...
        'partition_key', '', ...
        'fuentes_equivalentes', '', ...
        'tipo', '', ...
        'antena', '', ...
        'num_antenas', NaN, ...
        'caso', NaN, ...
        'potencia_W', NaN);
    if n == 0
        resumen = plantilla([]);
    else
        resumen = repmat(plantilla, n, 1);
    end
end

function item = crear_item_resumen(ruta, fuente, modelo, tag_dataset, meta)
    item = crear_resumen_particion(1);
    item.ruta = ruta;
    item.fuente = fuente;
    item.modelo = char(modelo);
    item.dataset = char(tag_dataset);
    item.partition_key = clave_particion_metadata(fuente, modelo, tag_dataset);
    item.fuentes_equivalentes = char(fuente);
    item.tipo = meta.tipo;
    item.antena = meta.antena;
    item.num_antenas = meta.num_antenas;
    item.caso = meta.caso;
    item.potencia_W = meta.potencia_W;
end

function resumen = agregar_particion_resumen(resumen, item)
    if isempty(resumen.particiones)
        resumen.particiones = item;
        return;
    end
    claves = {resumen.particiones.partition_key};
    idx = find(strcmpi(claves, item.partition_key), 1, 'first');
    if ~isempty(idx)
        resumen.particiones(idx) = fusionar_item_resumen(resumen.particiones(idx), item);
        return;
    end
    resumen.particiones(end + 1) = item;
end

function item = fusionar_item_resumen(item, nuevo)
    aliases = fusionar_aliases(obtener_aliases(item), obtener_aliases(nuevo));
    item.fuentes_equivalentes = strjoin(aliases, '|');
    if isempty(item.fuente)
        item.fuente = nuevo.fuente;
    end
    if ruta_item_canonica(nuevo) || ~ruta_item_canonica(item)
        item.ruta = nuevo.ruta;
        item.fuente = nuevo.fuente;
        item.modelo = nuevo.modelo;
        item.dataset = nuevo.dataset;
        item.partition_key = nuevo.partition_key;
        item.tipo = nuevo.tipo;
        item.antena = nuevo.antena;
        item.num_antenas = nuevo.num_antenas;
        item.caso = nuevo.caso;
        item.potencia_W = nuevo.potencia_W;
        item.fuentes_equivalentes = strjoin(aliases, '|');
    end
end

function tf = ruta_item_canonica(item)
    tf = false;
    if isempty(item.ruta) || isempty(item.partition_key)
        return;
    end
    [~, nombre, ~] = fileparts(item.ruta);
    tf = strcmpi(nombre, sanitizar_nombre(item.partition_key));
end

function aliases = obtener_aliases(valor)
    aliases = {};
    if isstruct(valor)
        if isfield(valor, 'fuentes_equivalentes') && ~isempty(valor.fuentes_equivalentes)
            aliases = obtener_aliases(valor.fuentes_equivalentes);
        end
        if isfield(valor, 'fuente') && ~isempty(valor.fuente)
            aliases = fusionar_aliases(aliases, {char(valor.fuente)});
        elseif isfield(valor, 'ruta_entrada') && ~isempty(valor.ruta_entrada)
            aliases = fusionar_aliases(aliases, {char(valor.ruta_entrada)});
        end
    elseif iscell(valor)
        aliases = valor(:)';
    elseif isstring(valor)
        aliases = cellstr(valor(:))';
    elseif ischar(valor) && ~isempty(valor)
        aliases = regexp(valor, '\|', 'split');
    end
    aliases = aliases(~cellfun(@isempty, aliases));
end

function aliases = fusionar_aliases(a, b)
    aliases = [obtener_aliases(a), obtener_aliases(b)];
    aliases = aliases(~cellfun(@isempty, aliases));
    if ~isempty(aliases)
        aliases = unique(aliases, 'stable');
    end
end

function resumen = escribir_indice_particiones( ...
        carpeta_salida, resumen, logfn, fusionar_indice)
    particiones = resumen.particiones;
    omitidos = resumen.omitidos;
    if fusionar_indice
        [particiones, omitidos] = fusionar_indice_existente( ...
            carpeta_salida, particiones, omitidos, logfn);
        resumen.indice_fusionado = true;
    else
        resumen.indice_fusionado = false;
    end
    resumen.particiones = particiones;
    resumen.omitidos = omitidos;

    ruta_mat = fullfile(carpeta_salida, 'Indice_Datasets_Metadata.mat');
    guardar_mat_atomicamente(ruta_mat, particiones, omitidos, resumen);

    ruta_csv = fullfile(carpeta_salida, 'Indice_Datasets_Metadata.csv');
    ruta_csv_tmp = ruta_temporal_indice(ruta_csv);
    fid = fopen(ruta_csv_tmp, 'w');
    if fid < 0
        logfn('[WARN] No se pudo escribir CSV de indice: %s', ruta_csv_tmp);
        return;
    end
    fprintf(fid, ['ruta,fuente,modelo,dataset,partition_key,fuentes_equivalentes,' ...
        'tipo,antena,num_antenas,caso,potencia_W\n']);
    for k = 1:numel(particiones)
        p = particiones(k);
        fprintf(fid, '%s,%s,%s,%s,%s,%s,%s,%s,%g,%g,%g\n', ...
            csv(p.ruta), csv(p.fuente), csv(p.modelo), csv(p.dataset), ...
            csv(p.partition_key), csv(p.fuentes_equivalentes), ...
            csv(p.tipo), csv(p.antena), ...
            p.num_antenas, p.caso, p.potencia_W);
    end
    fclose(fid);
    mover_archivo_indice(ruta_csv_tmp, ruta_csv);
    logfn('Indice escrito: %s', ruta_mat);
    logfn('CSV escrito: %s', ruta_csv);
end

function [particiones, omitidos] = fusionar_indice_existente( ...
        carpeta_salida, particiones_nuevas, omitidos_nuevos, logfn)
    particiones = crear_resumen_particion(0);
    omitidos = {};

    ruta_mat = fullfile(carpeta_salida, 'Indice_Datasets_Metadata.mat');
    if isfile(ruta_mat)
        try
            raw = load(ruta_mat);
            if isfield(raw, 'particiones')
                particiones = normalizar_particiones(raw.particiones);
                particiones = particiones(arrayfun(@(p) isfile(p.ruta), particiones));
            end
            if isfield(raw, 'omitidos') && iscell(raw.omitidos)
                omitidos = raw.omitidos(:);
            end
        catch ME
            logfn('[WARN] Indice MAT corrupto o ilegible, se regenerara: %s', ME.message);
            respaldar_indice_corrupto(ruta_mat, logfn);
        end
    end

    particiones_nuevas = normalizar_particiones(particiones_nuevas);
    for k = 1:numel(particiones_nuevas)
        resumen_tmp = struct('particiones', particiones);
        resumen_tmp = agregar_particion_resumen(resumen_tmp, particiones_nuevas(k));
        particiones = resumen_tmp.particiones;
    end

    omitidos = [omitidos; omitidos_nuevos(:)];
    if ~isempty(omitidos)
        omitidos = unique(omitidos, 'stable');
    end
end

function guardar_mat_atomicamente(ruta_mat, particiones, omitidos, resumen)
    ruta_tmp = ruta_temporal_indice(ruta_mat);
    cleanup = onCleanup(@() borrar_si_existe(ruta_tmp));
    save(ruta_tmp, 'particiones', 'omitidos', 'resumen', '-v7.3');
    mover_archivo_indice(ruta_tmp, ruta_mat);
    clear cleanup;
end

function ruta_tmp = ruta_temporal_indice(ruta_final)
    marca = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
    ruta_tmp = sprintf('%s.tmp_%s_%06d', ruta_final, marca, randi(999999));
end

function mover_archivo_indice(origen, destino)
    [ok, msg] = movefile(origen, destino, 'f');
    if ~ok
        error('No se pudo mover indice temporal a destino: %s', msg);
    end
end

function respaldar_indice_corrupto(ruta_mat, logfn)
    if ~isfile(ruta_mat)
        return;
    end
    respaldo = sprintf('%s.corrupto_%s', ruta_mat, ...
        char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
    [ok, msg] = movefile(ruta_mat, respaldo, 'f');
    if ok
        logfn('[WARN] Indice corrupto respaldado como: %s', respaldo);
    else
        logfn('[WARN] No se pudo respaldar indice corrupto: %s', msg);
    end
end

function borrar_si_existe(ruta)
    if isfile(ruta)
        delete(ruta);
    end
end

function particiones = normalizar_particiones(particiones)
    plantilla = crear_resumen_particion(1);
    campos = fieldnames(plantilla);
    salida = crear_resumen_particion(0);
    if ~isstruct(particiones)
        particiones = salida;
        return;
    end

    for k = 1:numel(particiones)
        item = plantilla;
        for idx_campo = 1:numel(campos)
            campo = campos{idx_campo};
            if isfield(particiones, campo)
                item.(campo) = particiones(k).(campo);
            end
        end
        item.partition_key = clave_particion_metadata( ...
            item.fuente, item.modelo, item.dataset);
        if isempty(item.fuentes_equivalentes)
            item.fuentes_equivalentes = item.fuente;
        end
        if isempty(item.ruta) || isempty(item.fuente) || ...
                isempty(item.modelo) || isempty(item.dataset)
            continue;
        end
        resumen_tmp = struct('particiones', salida);
        resumen_tmp = agregar_particion_resumen(resumen_tmp, item);
        salida = resumen_tmp.particiones;
    end

    particiones = salida;
end

function texto = csv(valor)
    texto = char(valor);
    texto = strrep(texto, '"', '""');
    texto = ['"' texto '"'];
end

function crear_carpeta_si_no_existe(ruta)
    if ~isfolder(ruta)
        mkdir(ruta);
    end
end

function valor = obtener_campo_config(config, campo, valor_default)
    valor = valor_default;
    if isstruct(config) && isfield(config, campo) && ~isempty(config.(campo))
        valor = config.(campo);
    end
end
