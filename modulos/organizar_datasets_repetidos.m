function resumen = organizar_datasets_repetidos(varargin)
%ORGANIZAR_DATASETS_REPETIDOS Conserva un MAT canonico por identidad termica.
%
% Las variantes semanticamente repetidas se comparan sin hashes: se carga el
% registro termico, se retiran exclusivamente campos volatiles de procedencia
% y se usa ISEQUALN. Ningun archivo se elimina. Las copias equivalentes se
% mueven a repetidos/equivalentes y las que difieren a repetidos/conflictos.

    bootstrap_organizador();
    paths = tesis_auxiliares('asegurar_dataset_paths');
    config = normalizar_config_organizador(varargin{:});
    root = campo_config_organizador(config, 'carpeta_catalogo', ...
        paths.datasets_masivos_por_metadata);
    root_repetidos = campo_config_organizador(config, 'carpeta_repetidos', ...
        fullfile(root, 'repetidos'));
    ejecutar_movimientos = logical(campo_config_organizador( ...
        config, 'ejecutar_movimientos', false));
    comparar_contenido = logical(campo_config_organizador( ...
        config, 'comparar_contenido', true));
    logfn = campo_config_organizador(config, 'logfn', []);
    if isempty(logfn)
        logfn = @(varargin) fprintf([varargin{1} '\n'], varargin{2:end});
    end

    if ~isfolder(root)
        error('No existe el catalogo por metadata: %s', root);
    end
    root = ruta_canonica_organizador(root);
    root_repetidos = ruta_canonica_organizador(root_repetidos);
    if ~esta_dentro_de_organizador(root_repetidos, root)
        error('La carpeta repetidos debe permanecer dentro del catalogo.');
    end
    if ejecutar_movimientos && ~isfolder(root_repetidos)
        mkdir(root_repetidos);
    end

    entradas = catalogar_archivos_organizador(root, root_repetidos, logfn);
    resumen = struct( ...
        'fecha', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
        'carpeta_catalogo', root, ...
        'carpeta_repetidos', root_repetidos, ...
        'ejecutar_movimientos', ejecutar_movimientos, ...
        'archivos_detectados', numel(entradas), ...
        'canonicos', crear_movimiento_organizador(0), ...
        'renombrados', crear_movimiento_organizador(0), ...
        'equivalentes', crear_movimiento_organizador(0), ...
        'conflictos', crear_movimiento_organizador(0), ...
        'errores', {{}});
    if isempty(entradas)
        logfn('No se encontraron particiones MAT activas.');
        return;
    end

    claves = {entradas.clave_semantica};
    [claves_unicas, ~, grupos] = unique(claves, 'stable');
    activos = false(size(entradas));
    logfn('Identidades termicas normalizadas: %d.', numel(claves_unicas));
    for gi = 1:numel(claves_unicas)
        idx_grupo = find(grupos == gi);
        idx_grupo = ordenar_candidatos_organizador(entradas, idx_grupo);
        idx_canonico = idx_grupo(1);
        activos(idx_canonico) = true;
        canonico = entradas(idx_canonico);
        resumen.canonicos(end + 1) = movimiento_desde_entrada_organizador( ...
            canonico, canonico.ruta, 'canonico', true, 'seleccionado');
        if isscalar(idx_grupo)
            continue;
        end

        registro_canonico = [];
        error_canonico = '';
        if comparar_contenido
            try
                registro_canonico = cargar_registro_comparable_organizador(canonico);
            catch ME
                error_canonico = ME.message;
            end
        end
        for ii = 2:numel(idx_grupo)
            idx_variante = idx_grupo(ii);
            variante = entradas(idx_variante);
            equivalente = false;
            detalle = '';
            if comparar_contenido && isempty(error_canonico)
                try
                    registro_variante = cargar_registro_comparable_organizador(variante);
                    equivalente = isequaln(registro_canonico, registro_variante);
                    clear registro_variante;
                catch ME
                    detalle = ['comparacion fallida: ' ME.message];
                end
            elseif ~comparar_contenido
                detalle = 'comparacion deshabilitada';
            else
                detalle = ['canonico ilegible: ' error_canonico];
            end

            if equivalente
                categoria = 'equivalentes';
                motivo = 'contenido termico identico';
            else
                categoria = 'conflictos';
                motivo = 'misma metadata con contenido diferente o no verificable';
                if ~isempty(detalle)
                    motivo = sprintf('%s (%s)', motivo, detalle);
                end
            end
            destino = destino_repetido_organizador( ...
                root, root_repetidos, variante.ruta, categoria);
            movimiento = movimiento_desde_entrada_organizador( ...
                variante, destino, categoria, equivalente, motivo);
            if ejecutar_movimientos
                try
                    destino = mover_a_repetidos_organizador( ...
                        variante.ruta, destino, root, root_repetidos);
                    movimiento.destino = destino;
                catch ME
                    resumen.errores{end + 1, 1} = sprintf('%s: %s', ...
                        variante.ruta, ME.message);
                    activos(idx_variante) = true;
                    continue;
                end
            end
            if equivalente
                resumen.equivalentes(end + 1) = movimiento;
            else
                resumen.conflictos(end + 1) = movimiento;
            end
        end
        clear registro_canonico;
        if mod(gi, 50) == 0 || gi == numel(claves_unicas)
            logfn('Identidades revisadas: %d/%d.', gi, numel(claves_unicas));
            drawnow limitrate;
        end
    end

    if ejecutar_movimientos
        [entradas, resumen] = normalizar_nombres_canonicos_organizador( ...
            entradas, activos, root, root_repetidos, resumen, logfn);
        entradas_activas = entradas(activos & arrayfun(@(e) isfile(e.ruta), entradas));
        escribir_indice_limpio_organizador(root, entradas_activas, resumen, logfn);
        escribir_reporte_repetidos_organizador(root_repetidos, resumen);
    end
    logfn(['Organizacion terminada: canonicos=%d | renombrados=%d | ', ...
        'equivalentes=%d | conflictos=%d | errores=%d.'], ...
        numel(resumen.canonicos), numel(resumen.renombrados), ...
        numel(resumen.equivalentes), numel(resumen.conflictos), ...
        numel(resumen.errores));
end

function bootstrap_organizador()
    carpeta = fileparts(mfilename('fullpath'));
    aux = fullfile(carpeta, '..', 'Aux_Codes');
    if isfolder(aux), addpath(aux); end
    tesis_auxiliares('configurar_paths', carpeta);
end

function config = normalizar_config_organizador(varargin)
    config = struct();
    if nargin >= 2 && ischar(varargin{1}) && strcmpi(varargin{1}, 'run')
        config = varargin{2};
    elseif nargin >= 1 && isstruct(varargin{1})
        config = varargin{1};
    end
end

function valor = campo_config_organizador(config, campo, predeterminado)
    valor = predeterminado;
    if isstruct(config) && isfield(config, campo) && ~isempty(config.(campo))
        valor = config.(campo);
    end
end

function entradas = catalogar_archivos_organizador(root, root_repetidos, logfn)
    plantilla = crear_entrada_organizador(0);
    entradas = plantilla;
    indice = cargar_indice_organizador(root);
    rutas_indexadas = string({indice.ruta});
    archivos = dir(fullfile(root, '**', '*.mat'));
    archivos = archivos(~[archivos.isdir]);
    for k = 1:numel(archivos)
        ruta = fullfile(archivos(k).folder, archivos(k).name);
        if esta_dentro_de_organizador(ruta, root_repetidos) || ...
                es_auxiliar_organizador(archivos(k).name)
            continue;
        end
        try
            entrada = leer_entrada_organizador(ruta);
            entrada.indexada = any(strcmpi(rutas_indexadas, string(ruta)));
            entrada.bytes = double(archivos(k).bytes);
            entrada.datenum = double(archivos(k).datenum);
            entrada.puntaje_limpieza = puntaje_limpieza_organizador(entrada);
            entradas(end + 1) = entrada; %#ok<AGROW>
        catch ME
            logfn('[WARN] MAT no catalogable omitido: %s (%s)', ruta, ME.message);
        end
    end
end

function indice = cargar_indice_organizador(root)
    indice = struct('ruta', {});
    ruta_indice = fullfile(root, 'Indice_Datasets_Metadata.mat');
    if ~isfile(ruta_indice), return; end
    try
        raw = load(ruta_indice, 'particiones');
        if isfield(raw, 'particiones') && isstruct(raw.particiones)
            indice = raw.particiones;
        end
    catch
        indice = struct('ruta', {});
    end
end

function tf = es_auxiliar_organizador(nombre)
    nombre = lower(char(nombre));
    tf = startsWith(nombre, 'indice_') || startsWith(nombre, 'reporte_') || ...
        contains(nombre, 'historial');
end

function entrada = leer_entrada_organizador(ruta)
    entrada = crear_entrada_organizador(1);
    entrada.ruta = ruta;
    raw = load(ruta, 'partition_meta');
    if isfield(raw, 'partition_meta') && isstruct(raw.partition_meta)
        pm = raw.partition_meta;
    else
        pm = struct();
    end
    entrada.modelo = texto_pm_organizador(pm, 'modelo');
    entrada.dataset = texto_pm_organizador(pm, 'tag_dataset');
    entrada.tipo = texto_pm_organizador(pm, 'tipo');
    entrada.antena = texto_pm_organizador(pm, 'antena');
    entrada.num_antenas = numero_pm_organizador(pm, 'num_antenas');
    entrada.caso = numero_pm_organizador(pm, 'caso');
    entrada.potencia_W = numero_pm_organizador(pm, 'potencia_W');
    entrada.fuente = texto_pm_organizador(pm, 'ruta_entrada');
    entrada = completar_desde_ruta_organizador(entrada);
    entrada.modelo_normalizado = normalizar_modelo_organizador(entrada.modelo);
    entrada.dataset_normalizado = normalizar_dataset_organizador( ...
        entrada.dataset, entrada.caso, entrada.potencia_W);
    if isempty(entrada.modelo) || isempty(entrada.dataset) || ...
            isempty(entrada.tipo) || ~isfinite(entrada.num_antenas) || ...
            ~isfinite(entrada.caso) || ~isfinite(entrada.potencia_W)
        error('metadata incompleta');
    end
    entrada.clave_semantica = lower(strjoin({entrada.modelo_normalizado, ...
        entrada.dataset_normalizado, entrada.tipo, entrada.antena, ...
        sprintf('c%g', entrada.caso), sprintf('p%g', entrada.potencia_W)}, '|'));
end

function entrada = completar_desde_ruta_organizador(entrada)
    normal = strrep(entrada.ruta, '\', '/');
    [~, base] = fileparts(entrada.ruta);
    if isempty(entrada.tipo)
        entrada.tipo = primer_match_organizador(normal, ...
            {'Doble_slot', 'Monopolo', 'Un_slot'});
    end
    if ~isfinite(entrada.num_antenas)
        token = regexp(normal, '(\d+)ant', 'tokens', 'once');
        if ~isempty(token), entrada.num_antenas = str2double(token{1}); end
    end
    if isempty(entrada.antena) && isfinite(entrada.num_antenas)
        entrada.antena = sprintf('%dant', round(entrada.num_antenas));
    end
    if ~isfinite(entrada.caso)
        token = regexp(normal, 'Caso_(\d+)', 'tokens', 'once', 'ignorecase');
        if ~isempty(token), entrada.caso = str2double(token{1}); end
    end
    if ~isfinite(entrada.potencia_W)
        token = regexp(normal, 'Potencia_([\d.p]+)W', 'tokens', 'once', 'ignorecase');
        if ~isempty(token), entrada.potencia_W = str2double(strrep(token{1}, 'p', '.')); end
    end
    if isempty(entrada.modelo)
        token = regexp(base, '(modelo_.+?\d+ant(?:_pendientes|__src_[^_]+(?:_r\d+)?)?)_(?:dset|src_)', ...
            'tokens', 'once', 'ignorecase');
        if ~isempty(token), entrada.modelo = token{1}; end
    end
    if isempty(entrada.dataset) && isfinite(entrada.caso) && isfinite(entrada.potencia_W)
        entrada.dataset = sprintf('dset_c%d_p%g', round(entrada.caso), entrada.potencia_W);
    end
end

function modelo = normalizar_modelo_organizador(modelo)
    modelo = char(modelo);
    modelo = regexprep(modelo, '__src_[^_]+(?:_r\d+)?$', '', 'ignorecase');
    modelo = regexprep(modelo, '_pendientes$', '', 'ignorecase');
    modelo = regexprep(modelo, '_r\d+$', '', 'ignorecase');
end

function dataset = normalizar_dataset_organizador(dataset, caso, potencia)
    if isfinite(caso) && isfinite(potencia)
        dataset = sprintf('dset_c%d_p%g', round(caso), potencia);
    else
        dataset = lower(char(dataset));
    end
end

function puntaje = puntaje_limpieza_organizador(entrada)
    puntaje = 0;
    if entrada.indexada, puntaje = puntaje + 1000; end
    if strcmpi(entrada.modelo, entrada.modelo_normalizado), puntaje = puntaje + 200; end
    [~, base] = fileparts(entrada.ruta);
    esperado = sanitizar_organizador([entrada.modelo_normalizado '__' entrada.dataset_normalizado]);
    if strcmpi(base, esperado), puntaje = puntaje + 100; end
    if ~contains(lower(base), 'pendientes'), puntaje = puntaje + 30; end
    if ~contains(lower(base), '_src_'), puntaje = puntaje + 20; end
    if isempty(regexp(base, '_r\d+$', 'once')), puntaje = puntaje + 10; end
    puntaje = puntaje - numel(base) / 1000;
end

function idx = ordenar_candidatos_organizador(entradas, idx)
    puntajes = [entradas(idx).puntaje_limpieza]';
    fechas = [entradas(idx).datenum]';
    tabla = [-puntajes, -fechas, idx(:)];
    [~, orden] = sortrows(tabla, [1 2 3]);
    idx = idx(orden);
end

function registro = cargar_registro_comparable_organizador(entrada)
    raw = load(entrada.ruta, 'dataset');
    if ~isfield(raw, 'dataset') || ~isstruct(raw.dataset)
        error('sin variable dataset');
    end
    modelos = fieldnames(raw.dataset);
    modelos = modelos(~strcmp(modelos, 'session_meta'));
    if isempty(modelos), error('sin modelo'); end
    modelo = entrada.modelo;
    if ~isfield(raw.dataset, modelo)
        modelo = modelos{1};
    end
    tags = fieldnames(raw.dataset.(modelo));
    tags = tags(~ismember(tags, {'session_meta', 'source_signature', 'datasets_omitidos'}));
    if isempty(tags), error('sin dataset termico'); end
    tag = entrada.dataset;
    if ~isfield(raw.dataset.(modelo), tag)
        tag = tags{1};
    end
    registro = raw.dataset.(modelo).(tag);
    registro = quitar_procedencia_organizador(registro);
end

function valor = quitar_procedencia_organizador(valor)
    if ~isstruct(valor), return; end
    campos = {'fecha_extraccion', 'fecha_generacion', 'ruta_entrada', ...
        'archivo_origen', 'source_signature', 'partition_meta', ...
        'fuentes_equivalentes', 'partition_key'};
    presentes = intersect(fieldnames(valor), campos, 'stable');
    if ~isempty(presentes), valor = rmfield(valor, presentes); end
    if isfield(valor, 'metadata') && isstruct(valor.metadata)
        metadata = valor.metadata;
        presentes = intersect(fieldnames(metadata), campos, 'stable');
        if ~isempty(presentes), metadata = rmfield(metadata, presentes); end
        valor.metadata = metadata;
    end
end

function destino = destino_repetido_organizador(root, root_repetidos, ruta, categoria)
    relativa = erase(ruta, [root filesep]);
    destino = fullfile(root_repetidos, categoria, relativa);
end

function destino = mover_a_repetidos_organizador(origen, destino, root, root_repetidos)
    origen = ruta_canonica_organizador(origen);
    if ~esta_dentro_de_organizador(origen, root) || ...
            esta_dentro_de_organizador(origen, root_repetidos)
        error('Origen fuera del catalogo activo: %s', origen);
    end
    carpeta = fileparts(destino);
    if ~isfolder(carpeta), mkdir(carpeta); end
    destino = destino_disponible_organizador(destino);
    [ok, msg] = movefile(origen, destino);
    if ~ok, error('No se pudo mover a repetidos: %s', msg); end
end

function ruta = destino_disponible_organizador(ruta)
    if ~isfile(ruta), return; end
    [folder, base, ext] = fileparts(ruta);
    revision = 2;
    while isfile(ruta)
        ruta = fullfile(folder, sprintf('%s_r%d%s', base, revision, ext));
        revision = revision + 1;
    end
end

function [entradas, resumen] = normalizar_nombres_canonicos_organizador( ...
        entradas, activos, root, root_repetidos, resumen, logfn)
% Deja limpio el nombre fisico sin alterar los campos internos del MAT.
    indices = find(activos);
    for k = 1:numel(indices)
        idx = indices(k);
        origen = entradas(idx).ruta;
        if ~isfile(origen), continue; end
        [carpeta, base, ext] = fileparts(origen);
        base_limpia = sanitizar_organizador([entradas(idx).modelo_normalizado ...
            '__' entradas(idx).dataset_normalizado]);
        if strcmpi(base, base_limpia), continue; end
        destino = ruta_canonica_organizador(fullfile(carpeta, [base_limpia ext]));
        if ~esta_dentro_de_organizador(destino, root) || ...
                esta_dentro_de_organizador(destino, root_repetidos)
            resumen.errores{end + 1, 1} = sprintf( ...
                '%s: destino canonico fuera del catalogo activo', origen);
            continue;
        end
        if isfile(destino)
            resumen.errores{end + 1, 1} = sprintf( ...
                '%s: ya existe el nombre canonico %s', origen, destino);
            continue;
        end
        [ok, msg] = movefile(origen, destino);
        if ~ok
            resumen.errores{end + 1, 1} = sprintf( ...
                '%s: no se pudo normalizar el nombre (%s)', origen, msg);
            continue;
        end
        entradas(idx).ruta = destino;
        mov = movimiento_desde_entrada_organizador(entradas(idx), destino, ...
            'renombrado', true, 'nombre fisico normalizado por metadata');
        mov.origen = origen;
        resumen.renombrados(end + 1) = mov;
    end
    if ~isempty(resumen.renombrados)
        logfn('Nombres fisicos normalizados: %d.', numel(resumen.renombrados));
    end
end

function escribir_indice_limpio_organizador(root, entradas, resumen, logfn)
    particiones = crear_item_indice_organizador(0);
    for k = 1:numel(entradas)
        particiones(end + 1) = item_indice_desde_entrada_organizador(entradas(k)); %#ok<AGROW>
    end
    omitidos = resumen.errores;
    resumen_indice = struct('fecha', resumen.fecha, 'carpeta_salida', root, ...
        'particiones', particiones, 'omitidos', {omitidos}, ...
        'organizado_repetidos', true);
    ruta_mat = fullfile(root, 'Indice_Datasets_Metadata.mat');
    ruta_tmp = [ruta_mat '.tmp_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'))];
    cleanup = onCleanup(@() borrar_temporal_organizador(ruta_tmp));
    save(ruta_tmp, 'particiones', 'omitidos', 'resumen_indice', '-v7.3');
    [ok, msg] = movefile(ruta_tmp, ruta_mat, 'f');
    if ~ok, error('No se pudo actualizar el indice limpio: %s', msg); end
    clear cleanup;
    escribir_csv_indice_organizador(fullfile(root, 'Indice_Datasets_Metadata.csv'), particiones);
    logfn('Indice activo reconstruido con %d archivos canonicos.', numel(particiones));
end

function item = crear_item_indice_organizador(n)
    plantilla = struct('ruta', '', 'fuente', '', 'modelo', '', 'dataset', '', ...
        'partition_key', '', 'fuentes_equivalentes', '', 'tipo', '', ...
        'antena', '', 'num_antenas', NaN, 'caso', NaN, 'potencia_W', NaN);
    if n == 0, item = plantilla([]); else, item = repmat(plantilla, n, 1); end
end

function item = item_indice_desde_entrada_organizador(e)
    item = crear_item_indice_organizador(1);
    item.ruta = e.ruta;
    item.fuente = e.fuente;
    item.modelo = e.modelo;
    item.dataset = e.dataset;
    item.partition_key = [e.modelo '__' e.dataset];
    item.fuentes_equivalentes = e.fuente;
    item.tipo = e.tipo;
    item.antena = e.antena;
    item.num_antenas = e.num_antenas;
    item.caso = e.caso;
    item.potencia_W = e.potencia_W;
end

function escribir_csv_indice_organizador(ruta, particiones)
    temporal = [ruta '.tmp'];
    cleanup = onCleanup(@() borrar_temporal_organizador(temporal));
    fid = fopen(temporal, 'w');
    if fid < 0, error('No se pudo escribir el CSV temporal.'); end
    cierre = onCleanup(@() fclose(fid));
    fprintf(fid, ['ruta,fuente,modelo,dataset,partition_key,fuentes_equivalentes,' ...
        'tipo,antena,num_antenas,caso,potencia_W\n']);
    for k = 1:numel(particiones)
        p = particiones(k);
        fprintf(fid, '%s,%s,%s,%s,%s,%s,%s,%s,%g,%g,%g\n', ...
            csv_organizador(p.ruta), csv_organizador(p.fuente), ...
            csv_organizador(p.modelo), csv_organizador(p.dataset), ...
            csv_organizador(p.partition_key), csv_organizador(p.fuentes_equivalentes), ...
            csv_organizador(p.tipo), csv_organizador(p.antena), ...
            p.num_antenas, p.caso, p.potencia_W);
    end
    clear cierre;
    [ok, msg] = movefile(temporal, ruta, 'f');
    if ~ok, error('No se pudo actualizar el CSV limpio: %s', msg); end
    clear cleanup;
end

function escribir_reporte_repetidos_organizador(root_repetidos, resumen)
    if ~isfolder(root_repetidos), mkdir(root_repetidos); end
    ruta = fullfile(root_repetidos, 'Indice_Repetidos.mat');
    hay_nuevos = ~isempty(resumen.equivalentes) || ~isempty(resumen.conflictos);
    if isfile(ruta) && ~hay_nuevos
        return;
    end
    if isfile(ruta)
        try
            anterior = load(ruta, 'resumen');
            if isfield(anterior, 'resumen') && isstruct(anterior.resumen)
                if isfield(anterior.resumen, 'equivalentes')
                    resumen.equivalentes = [anterior.resumen.equivalentes(:); ...
                        resumen.equivalentes(:)];
                end
                if isfield(anterior.resumen, 'conflictos')
                    resumen.conflictos = [anterior.resumen.conflictos(:); ...
                        resumen.conflictos(:)];
                end
            end
        catch
            % Si el reporte previo no es legible, se reemplaza por el actual.
        end
    end
    save(ruta, 'resumen', '-v7.3');
    ruta_csv = fullfile(root_repetidos, 'Indice_Repetidos.csv');
    fid = fopen(ruta_csv, 'w');
    if fid < 0, return; end
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'categoria,equivalente,origen,destino,clave_semantica,motivo\n');
    movimientos = [resumen.equivalentes(:); resumen.conflictos(:)];
    for k = 1:numel(movimientos)
        m = movimientos(k);
        fprintf(fid, '%s,%d,%s,%s,%s,%s\n', csv_organizador(m.categoria), ...
            m.equivalente, csv_organizador(m.origen), csv_organizador(m.destino), ...
            csv_organizador(m.clave_semantica), csv_organizador(m.motivo));
    end
end

function entrada = crear_entrada_organizador(n)
    plantilla = struct('ruta', '', 'fuente', '', 'modelo', '', 'dataset', '', ...
        'modelo_normalizado', '', 'dataset_normalizado', '', 'tipo', '', ...
        'antena', '', 'num_antenas', NaN, 'caso', NaN, 'potencia_W', NaN, ...
        'clave_semantica', '', 'indexada', false, 'bytes', NaN, 'datenum', NaN, ...
        'puntaje_limpieza', 0);
    if n == 0, entrada = plantilla([]); else, entrada = repmat(plantilla, n, 1); end
end

function movimiento = crear_movimiento_organizador(n)
    plantilla = struct('origen', '', 'destino', '', 'categoria', '', ...
        'equivalente', false, 'clave_semantica', '', 'motivo', '');
    if n == 0, movimiento = plantilla([]); else, movimiento = repmat(plantilla, n, 1); end
end

function m = movimiento_desde_entrada_organizador(e, destino, categoria, equivalente, motivo)
    m = crear_movimiento_organizador(1);
    m.origen = e.ruta;
    m.destino = destino;
    m.categoria = categoria;
    m.equivalente = equivalente;
    m.clave_semantica = e.clave_semantica;
    m.motivo = motivo;
end

function texto = texto_pm_organizador(pm, campo)
    texto = '';
    if isstruct(pm) && isfield(pm, campo) && ~isempty(pm.(campo))
        valor = pm.(campo);
        if isstring(valor), valor = char(valor); end
        if ischar(valor), texto = valor; end
    end
end

function valor = numero_pm_organizador(pm, campo)
    valor = NaN;
    if isstruct(pm) && isfield(pm, campo) && isnumeric(pm.(campo)) && ...
            isscalar(pm.(campo)) && isfinite(double(pm.(campo)))
        valor = double(pm.(campo));
    end
end

function valor = primer_match_organizador(texto, candidatos)
    valor = '';
    for k = 1:numel(candidatos)
        if contains(texto, candidatos{k}, 'IgnoreCase', true)
            valor = candidatos{k};
            return;
        end
    end
end

function nombre = sanitizar_organizador(nombre)
    nombre = regexprep(char(nombre), '[^\w.-]+', '_');
    nombre = regexprep(nombre, '_+', '_');
    nombre = regexprep(nombre, '^_+|_+$', '');
end

function ruta = ruta_canonica_organizador(ruta)
    ruta = char(java.io.File(char(ruta)).getCanonicalPath());
end

function tf = esta_dentro_de_organizador(ruta, root)
    ruta = ruta_canonica_organizador(ruta);
    root = ruta_canonica_organizador(root);
    tf = strcmpi(ruta, root) || startsWith(ruta, [root filesep], 'IgnoreCase', true);
end

function borrar_temporal_organizador(ruta)
    if isfile(ruta), delete(ruta); end
end

function texto = csv_organizador(valor)
    if isnumeric(valor), valor = sprintf('%g', valor); end
    if islogical(valor), valor = sprintf('%d', valor); end
    texto = ['"' strrep(char(valor), '"', '""') '"'];
end
