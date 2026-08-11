function varargout = tesis_auxiliares(accion, varargin)
%TESIS_AUXILIARES Punto unico para helpers de infraestructura y UI.
%
% Este archivo concentra funciones auxiliares que no son modulos del flujo.
% Los modulos finales deben llamarlo mediante acciones explicitas:
%   tesis_auxiliares('configurar_paths', ruta)
%   tesis_auxiliares('project_root', ruta)
%   tesis_auxiliares('dataset_paths', root)
%   tesis_auxiliares('asegurar_dataset_paths', root)
%   tesis_auxiliares('dataset_masivo_reciente', root_o_paths)
%   tesis_auxiliares('metadata_ruta', ruta, struct_opcional)
%   tesis_auxiliares('planos_termicos_centrales', puntos_xyz, temperatura)
%   tesis_auxiliares('modulos_catalogo')
%   tesis_auxiliares('tema_ui', ...)
%   tesis_auxiliares('crear_dashboard_modulo', ...)

    if nargin == 0 || isempty(accion)
        accion = 'tema_ui';
    end

    switch lower(string(accion))
        case {"configurar_paths", "configurar_paths_proyecto"}
            if nargout == 0
                configurar_paths_proyecto_impl(varargin{:});
            else
                [varargout{1:nargout}] = configurar_paths_proyecto_impl(varargin{:});
            end

        case {"project_root", "tesis_project_root"}
            [varargout{1:nargout}] = tesis_project_root_impl(varargin{:});

        case {"dataset_paths", "tesis_dataset_paths"}
            [varargout{1:nargout}] = tesis_dataset_paths_impl(varargin{:});

        case {"asegurar_dataset_paths", "tesis_asegurar_dataset_paths"}
            [varargout{1:nargout}] = tesis_asegurar_dataset_paths_impl(varargin{:});

        case {"dataset_masivo_reciente", "ultimo_dataset_masivo", "latest_dataset_mat"}
            [varargout{1:nargout}] = dataset_masivo_reciente_impl(varargin{:});

        case {"metadata_ruta", "metadata_dataset"}
            [varargout{1:nargout}] = metadata_ruta_impl(varargin{:});

        case {"planos_termicos_centrales", "cortes_termicos_centrales"}
            [varargout{1:nargout}] = planos_termicos_centrales_impl(varargin{:});

        case "selftest_planos_termicos"
            selftest_planos_termicos_impl();

        case {"modulos_catalogo", "tesis_modulos_catalogo"}
            [varargout{1:nargout}] = tesis_modulos_catalogo_impl();

        case {"tema_ui", "tema_tesis_ui", "theme"}
            if nargout == 0
                tema_tesis_ui_impl(varargin{:});
            else
                [varargout{1:nargout}] = tema_tesis_ui_impl(varargin{:});
            end

        case {"crear_dashboard_modulo", "dashboard_modulo"}
            if nargout == 0
                crear_dashboard_modulo_impl(varargin{:});
            else
                [varargout{1:nargout}] = crear_dashboard_modulo_impl(varargin{:});
            end

        otherwise
            error('tesis_auxiliares:accion_desconocida', ...
                'Accion auxiliar no reconocida: %s', accion);
    end
end

function planos = planos_termicos_centrales_impl(puntos, temperatura)
    puntos = double(puntos);
    temperatura = double(temperatura(:));
    if size(puntos, 2) ~= 3 || size(puntos, 1) ~= numel(temperatura)
        error('Los puntos deben ser N x 3 y coincidir con N temperaturas.');
    end
    validos = all(isfinite(puntos), 2) & isfinite(temperatura);
    puntos = puntos(validos, :);
    temperatura = temperatura(validos);
    if size(puntos, 1) < 8
        error('Se requieren al menos ocho puntos termicos validos.');
    end

    [x, ~, ix] = unique(puntos(:, 1), 'sorted');
    [y, ~, iy] = unique(puntos(:, 2), 'sorted');
    [z, ~, iz] = unique(puntos(:, 3), 'sorted');
    dimensiones = [numel(x), numel(y), numel(z)];
    n_grilla = prod(double(dimensiones));
    if n_grilla > max(2e6, 4 * size(puntos, 1))
        error(['Los puntos no forman una malla cartesiana parcial; ', ...
            'no se puede obtener un corte central sin reconstruccion volumetrica.']);
    end

    indices = sub2ind(dimensiones, ix, iy, iz);
    valores = accumarray(indices, temperatura, [n_grilla, 1], @mean, NaN);
    volumen = reshape(valores, dimensiones);
    centro = (min(puntos, [], 1) + max(puntos, [], 1)) ./ 2;

    planos = struct( ...
        'x', x(:), 'y', y(:), 'z', z(:), ...
        'centro', centro, ...
        'xy', interpolar_corte_central_impl(volumen, z, centro(3), 3).', ...
        'xz', interpolar_corte_central_impl(volumen, y, centro(2), 2).', ...
        'yz', interpolar_corte_central_impl(volumen, x, centro(1), 1).');
    temperaturas_planos = [planos.xy(:); planos.xz(:); planos.yz(:)];
    temperaturas_planos = temperaturas_planos(isfinite(temperaturas_planos));
    if isempty(temperaturas_planos)
        planos.limites_C = [];
    else
        limites = [min(temperaturas_planos), max(temperaturas_planos)];
        if limites(1) == limites(2)
            margen = max(1, abs(limites(1)) * 0.01);
            limites = limites + [-margen, margen];
        end
        planos.limites_C = limites;
    end
end

function corte = interpolar_corte_central_impl(volumen, eje, centro, dimension)
    superior = find(eje >= centro, 1, 'first');
    inferior = find(eje <= centro, 1, 'last');
    if isempty(inferior), inferior = 1; end
    if isempty(superior), superior = numel(eje); end
    if inferior == superior
        peso = 0;
    else
        peso = (centro - eje(inferior)) / (eje(superior) - eje(inferior));
    end
    switch dimension
        case 1
            a = squeeze(volumen(inferior, :, :));
            b = squeeze(volumen(superior, :, :));
        case 2
            a = squeeze(volumen(:, inferior, :));
            b = squeeze(volumen(:, superior, :));
        otherwise
            a = squeeze(volumen(:, :, inferior));
            b = squeeze(volumen(:, :, superior));
    end
    corte = (1 - peso) .* a + peso .* b;
    solo_a = isfinite(a) & ~isfinite(b);
    solo_b = ~isfinite(a) & isfinite(b);
    corte(solo_a) = a(solo_a);
    corte(solo_b) = b(solo_b);
end

function selftest_planos_termicos_impl()
    x = [-1, 1]; y = [-2, 2]; z = [0, 2];
    [X, Y, Z] = ndgrid(x, y, z);
    puntos = [X(:), Y(:), Z(:)];
    temperatura = X(:) + 2 .* Y(:) + 3 .* Z(:);
    p = planos_termicos_centrales_impl(puntos, temperatura);
    [Xxy, Yxy] = meshgrid(x, y);
    [Xxz, Zxz] = meshgrid(x, z);
    [Yyz, Zyz] = meshgrid(y, z);
    assert(max(abs(p.xy(:) - (Xxy(:) + 2 .* Yxy(:) + 3))) < 1e-12);
    assert(max(abs(p.xz(:) - (Xxz(:) + 3 .* Zxz(:)))) < 1e-12);
    assert(max(abs(p.yz(:) - (2 .* Yyz(:) + 3 .* Zyz(:)))) < 1e-12);
    fprintf('SELFTEST_PLANOS_TERMICOS_OK\n');
end

function meta = metadata_ruta_impl(ruta, fuente)
    if nargin < 1 || isempty(ruta), ruta = ''; end
    if nargin < 2 || ~isstruct(fuente), fuente = struct(); end
    texto = strrep(char(ruta), '\', '/');
    for campo = {'tag_correccion', 'ruta_relativa', 'ruta_stl', 'ruta_correccion'}
        if isfield(fuente, campo{1}) && ~isempty(fuente.(campo{1}))
            texto = [texto '/' char(string(fuente.(campo{1})))]; %#ok<AGROW>
        end
    end

    meta = struct('tipo', '', 'antena', '', 'num_antenas', NaN, ...
        'caso', NaN, 'potencia_W', NaN, 'fecha_adquisicion', '', ...
        'tiempo_ejecucion_min', NaN, 'numero_prueba', NaN, ...
        'num_zonas', NaN, 'zona_experimental', '', ...
        'completa_simulacion', false, 'completa_adquisicion', false);

    tipos = {'Doble_slot', 'Monopolo', 'Un_slot'};
    for k = 1:numel(tipos)
        if contains(texto, tipos{k}, 'IgnoreCase', true)
            meta.tipo = tipos{k};
            break;
        end
    end
    token = regexp(texto, '(?:^|/|_)(\d+)\s*_?ant(?:enas)?(?:/|_|$)', ...
        'tokens', 'once', 'ignorecase');
    if isempty(token)
        palabras = {'una', 'dos', 'tres', 'cuatro'};
        for k = 1:numel(palabras)
            if ~isempty(regexp(texto, ['(?:^|/)' palabras{k} '\s+antenas?'], ...
                    'once', 'ignorecase'))
                token = {num2str(k)};
                break;
            end
        end
    end
    if ~isempty(token), meta.num_antenas = str2double(token{1}); end

    token = regexp(texto, '(?:^|/|_)(?:Caso_|c)(\d+)(?:/|_|$)', ...
        'tokens', 'once', 'ignorecase');
    if ~isempty(token), meta.caso = str2double(token{1}); end
    token = regexp(texto, '(?:Potencia_)?([\d]+(?:[p.][\d]+)?)\s*W', ...
        'tokens', 'once', 'ignorecase');
    if isempty(token)
        token = regexp(texto, '(?:^|/|_)(?:p|potencia_)([\d]+(?:[p.][\d]+)?)(?:/|_|$)', ...
            'tokens', 'once', 'ignorecase');
    end
    if ~isempty(token)
        meta.potencia_W = str2double(strrep(lower(token{1}), 'p', '.'));
    end

    token = regexp(texto, '(?:^|/)Fecha_([^/]+)(?:/|$)', ...
        'tokens', 'once', 'ignorecase');
    if ~isempty(token), meta.fecha_adquisicion = token{1}; end
    token = regexp(texto, '(?:^|/)Tiempo_([\d]+(?:[p.][\d]+)?)min(?:/|$)', ...
        'tokens', 'once', 'ignorecase');
    if isempty(token)
        token = regexp(texto, '(?:^|_)([\d]+(?:[p.][\d]+)?)min(?:/|_|$)', ...
            'tokens', 'once', 'ignorecase');
    end
    if ~isempty(token)
        meta.tiempo_ejecucion_min = str2double(strrep(lower(token{1}), 'p', '.'));
    end
    token = regexp(texto, '(?:^|/)Prueba_(\d+)(?:/|$)', ...
        'tokens', 'once', 'ignorecase');
    if ~isempty(token), meta.numero_prueba = str2double(token{1}); end
    if ~isfinite(meta.numero_prueba)
        ordinales = {'primer', 'segundo', 'tercer', 'cuarto', 'quinto', ...
            'sexto', 'septimo', 'octavo', 'noveno', 'decimo'};
        for k = 1:numel(ordinales)
            if ~isempty(regexp(texto, [ordinales{k} '\s+experimento'], ...
                    'once', 'ignorecase'))
                meta.numero_prueba = k;
                break;
            end
        end
    end
    token = regexp(texto, '(?:^|/)Zonas_(\d+)(?:/|$)', ...
        'tokens', 'once', 'ignorecase');
    if ~isempty(token), meta.num_zonas = str2double(token{1}); end

    token = regexp(texto, ...
        'correccion_(.+?)_([\d]+(?:p[\d]+)?)min_prueba_(\d+)_zonas_(\d+)', ...
        'tokens', 'once', 'ignorecase');
    if ~isempty(token)
        if isempty(meta.fecha_adquisicion), meta.fecha_adquisicion = token{1}; end
        if ~isfinite(meta.tiempo_ejecucion_min)
            meta.tiempo_ejecucion_min = str2double(strrep(lower(token{2}), 'p', '.'));
        end
        if ~isfinite(meta.numero_prueba), meta.numero_prueba = str2double(token{3}); end
        if ~isfinite(meta.num_zonas), meta.num_zonas = str2double(token{4}); end
    end

    textos = {'tipo', 'antena', 'fecha_adquisicion', 'zona_experimental'};
    numeros = {'num_antenas', 'caso', 'potencia_W', ...
        'tiempo_ejecucion_min', 'numero_prueba', 'num_zonas'};
    for k = 1:numel(textos)
        campo = textos{k};
        if isfield(fuente, campo) && ~isempty(fuente.(campo))
            meta.(campo) = char(string(fuente.(campo)));
        end
    end
    if isempty(meta.tipo) && isfield(fuente, 'tipo_antena') && ~isempty(fuente.tipo_antena)
        meta.tipo = char(string(fuente.tipo_antena));
    end
    for k = 1:numel(numeros)
        campo = numeros{k};
        if isfield(fuente, campo) && isnumeric(fuente.(campo)) && ...
                isscalar(fuente.(campo)) && isfinite(double(fuente.(campo)))
            meta.(campo) = double(fuente.(campo));
        end
    end
    if ~isfinite(meta.caso) && isfield(fuente, 'idx_caso') && ...
            isnumeric(fuente.idx_caso) && isscalar(fuente.idx_caso)
        meta.caso = double(fuente.idx_caso);
    end
    if ~isfinite(meta.num_antenas) && ~isempty(meta.antena)
        token = regexp(meta.antena, '(\d+)', 'tokens', 'once');
        if ~isempty(token), meta.num_antenas = str2double(token{1}); end
    end
    if isempty(meta.antena) && isfinite(meta.num_antenas)
        meta.antena = sprintf('%dant', round(meta.num_antenas));
    end
    if isempty(meta.zona_experimental) && isfinite(meta.num_zonas)
        meta.zona_experimental = sprintf('Zonas_%d', round(meta.num_zonas));
    end
    meta.completa_simulacion = ~isempty(meta.tipo) && ...
        isfinite(meta.num_antenas) && isfinite(meta.caso) && isfinite(meta.potencia_W);
    meta.completa_adquisicion = ~isempty(meta.fecha_adquisicion) && ...
        isfinite(meta.tiempo_ejecucion_min) && isfinite(meta.numero_prueba) && ...
        isfinite(meta.num_zonas);
end

function root_proyecto = configurar_paths_proyecto_impl(ruta_inicio)
    if nargin < 1 || isempty(ruta_inicio)
        ruta_inicio = pwd;
    end

    root_proyecto = tesis_project_root_impl(ruta_inicio);

    rutas = {
        root_proyecto
        fullfile(root_proyecto, 'modulos')
        fullfile(root_proyecto, 'aux_codes')
    };

    for k = 1:numel(rutas)
        if isfolder(rutas{k})
            addpath(rutas{k});
        end
    end
end

function root_proyecto = tesis_project_root_impl(ruta_inicio)
    if nargin < 1 || isempty(ruta_inicio)
        ruta_inicio = fileparts(mfilename('fullpath'));
    end
    if isempty(ruta_inicio)
        ruta_inicio = pwd;
    end

    ruta_actual = char(java.io.File(ruta_inicio).getCanonicalPath());
    while true
        es_root_codigo = isfile(fullfile(ruta_actual, 'iniciar_tesis.m')) && ...
            isfolder(fullfile(ruta_actual, 'modulos')) && ...
            isfolder(fullfile(ruta_actual, 'aux_codes'));
        if es_root_codigo || isfolder(fullfile(ruta_actual, 'datasets'))
            root_proyecto = ruta_actual;
            return;
        end

        ruta_padre = char(java.io.File(ruta_actual, '..').getCanonicalPath());
        if strcmpi(ruta_padre, ruta_actual)
            break;
        end
        ruta_actual = ruta_padre;
    end

    root_proyecto = char(java.io.File(ruta_inicio).getCanonicalPath());
end

function paths = tesis_dataset_paths_impl(root_proyecto)
    if nargin < 1 || isempty(root_proyecto)
        root_proyecto = tesis_project_root_impl(fileparts(mfilename('fullpath')));
    else
        root_proyecto = tesis_project_root_impl(root_proyecto);
    end

    paths = struct();
    paths.root_proyecto = root_proyecto;
    paths.root = fullfile(root_proyecto, 'datasets');
    paths.datasets_masivos = fullfile(paths.root, 'datasets_masivos');
    paths.datasets_masivos_por_metadata = fullfile(paths.root, 'datasets_masivos_por_metadata');
    paths.datasets_masivos_repetidos = fullfile(paths.datasets_masivos_por_metadata, 'repetidos');
    paths.datasets_corregidos = fullfile(paths.root, 'datasets_corregidos');
    paths.datasets_corregidos_por_metadata = fullfile(paths.root, 'datasets_corregidos_por_metadata');
    paths.datasets_corregidos_repetidos = fullfile(paths.datasets_corregidos_por_metadata, 'repetidos');
    paths.correlaciones = fullfile(paths.root, 'correlaciones');
    paths.distribuciones_stl = fullfile(paths.root, 'distribuciones_stl');
    paths.distribuciones_mat = fullfile(paths.root, 'distribuciones_mat');
    paths.distribuciones_stl_corregidas = fullfile(paths.root, 'distribuciones_stl_corregidas');
    paths.distribuciones_mat_corregidas = fullfile(paths.root, 'distribuciones_mat_corregidas');
    paths.volumen_4d = fullfile(paths.root, 'volumen_4d');
    paths.experimentales = fullfile(paths.root, 'experimentales');
    paths.reconstrucciones = fullfile(paths.root, 'Reconstrucciones');
    paths.verificacion_alpha_shape = paths.reconstrucciones;
    paths.hueso_escaneado = fullfile(paths.root, 'hueso_escaneado');
    paths.logs = fullfile(paths.root, 'logs');
    paths.historial_sesion = fullfile(paths.root, 'historial_sesion.mat');
    paths.historial_tejidos_voxel = fullfile(paths.root, 'historial_tejidos_voxel.mat');
    paths.dataset_termico_masivo_base = fullfile(paths.datasets_masivos, ...
        'Dataset_Termico_Masivo.mat');
    paths.dataset_termico_masivo = paths.dataset_termico_masivo_base;
    paths.dataset_termico_masivo_reciente = paths.dataset_termico_masivo_base;
end

function paths = tesis_asegurar_dataset_paths_impl(root_proyecto)
    if nargin < 1 || isempty(root_proyecto)
        root_proyecto = tesis_project_root_impl(fileparts(mfilename('fullpath')));
    else
        root_proyecto = tesis_project_root_impl(root_proyecto);
    end

    paths = tesis_dataset_paths_impl(root_proyecto);
    nombres = fieldnames(paths);
    for k = 1:numel(nombres)
        valor = paths.(nombres{k});
        if ischar(valor) || isstring(valor)
            valor = char(valor);
            [~, ~, ext] = fileparts(valor);
            if isempty(ext) && ~isfolder(valor)
                mkdir(valor);
            end
        end
    end
    paths.dataset_termico_masivo_reciente = dataset_masivo_reciente_impl(paths);
end

function ruta = dataset_masivo_reciente_impl(root_o_paths, preferir_particiones)
    if nargin < 1 || isempty(root_o_paths)
        paths = tesis_dataset_paths_impl();
    elseif isstruct(root_o_paths)
        paths = root_o_paths;
    else
        paths = tesis_dataset_paths_impl(root_o_paths);
    end
    if nargin < 2 || isempty(preferir_particiones)
        preferir_particiones = true;
    end

    % El catalogo puede contener miles de MAT. El indice ofrece una ruta
    % valida sin ejecutar dir('**') en cada apertura de un modulo.
    if preferir_particiones && isfield(paths, 'datasets_masivos_por_metadata')
        ruta_indice = fullfile(paths.datasets_masivos_por_metadata, ...
            'Indice_Datasets_Metadata.mat');
        ruta_indexada = dataset_reciente_desde_indice_impl(ruta_indice);
        if ~isempty(ruta_indexada)
            ruta = ruta_indexada;
            return;
        end
    end

    candidatos = struct('folder', {}, 'name', {}, 'datenum', {});
    if preferir_particiones && isfield(paths, 'datasets_masivos_por_metadata')
        candidatos = agregar_archivos_dataset_reciente( ...
            candidatos, paths.datasets_masivos_por_metadata, true);
    end
    candidatos = agregar_archivos_dataset_reciente( ...
        candidatos, paths.datasets_masivos, false);

    if isempty(candidatos)
        ruta = paths.dataset_termico_masivo_base;
        return;
    end

    [~, idx] = max([candidatos.datenum]);
    ruta = fullfile(candidatos(idx).folder, candidatos(idx).name);
end

function ruta = dataset_reciente_desde_indice_impl(ruta_indice)
    ruta = '';
    if ~isfile(ruta_indice)
        return;
    end
    try
        raw = load(ruta_indice, 'particiones');
        if ~isfield(raw, 'particiones') || ~isstruct(raw.particiones) || ...
                ~isfield(raw.particiones, 'ruta')
            return;
        end
        for k = numel(raw.particiones):-1:1
            candidata = raw.particiones(k).ruta;
            if isstring(candidata) && isscalar(candidata)
                candidata = char(candidata);
            end
            if ischar(candidata)
                candidata = resolver_ruta_indice_portable_impl( ...
                    fileparts(ruta_indice), candidata);
            end
            if ~isempty(candidata)
                ruta = candidata;
                return;
            end
        end
    catch
        ruta = '';
    end
end

function ruta = resolver_ruta_indice_portable_impl(root_catalogo, ruta_guardada)
    ruta = char(ruta_guardada);
    if isfile(ruta)
        return;
    end
    normalizada = strrep(ruta, '\', '/');
    marcador = '/datasets_masivos_por_metadata/';
    posiciones = strfind(lower(normalizada), marcador);
    if isempty(posiciones)
        ruta = '';
        return;
    end
    relativa = normalizada(posiciones(end) + numel(marcador):end);
    partes = regexp(relativa, '/', 'split');
    candidata = fullfile(root_catalogo, partes{:});
    if isfile(candidata)
        ruta = candidata;
    else
        ruta = '';
    end
end

function candidatos = agregar_archivos_dataset_reciente(candidatos, carpeta, recursivo)
    if nargin < 3
        recursivo = false;
    end
    if ~isfolder(carpeta)
        return;
    end
    if recursivo
        archivos = dir(fullfile(carpeta, '**', '*.mat'));
    else
        archivos = dir(fullfile(carpeta, '*.mat'));
    end
    archivos = archivos(~[archivos.isdir]);
    keep = false(numel(archivos), 1);
    for k = 1:numel(archivos)
        ruta_archivo = fullfile(archivos(k).folder, archivos(k).name);
        keep(k) = es_archivo_dataset_mat(archivos(k).name) && ...
            ~ruta_esta_en_repetidos_impl(ruta_archivo);
    end
    archivos = archivos(keep);
    n_previos = numel(candidatos);
    n_nuevos = numel(archivos);
    if n_nuevos == 0
        return;
    end
    candidatos(n_previos + n_nuevos).folder = '';
    for k = 1:n_nuevos
        idx = n_previos + k;
        candidatos(idx) = struct( ...
            'folder', archivos(k).folder, ...
            'name', archivos(k).name, ...
            'datenum', archivos(k).datenum);
    end
end

function tf = ruta_esta_en_repetidos_impl(ruta)
    partes = regexp(strrep(lower(char(ruta)), '\', '/'), '/', 'split');
    tf = any(strcmp(partes, 'repetidos'));
end

function tf = es_archivo_dataset_mat(nombre)
    nombre = lower(char(nombre));
    tf = endsWith(nombre, '.mat') && ...
        ~startsWith(nombre, 'indice_') && ...
        ~startsWith(nombre, 'reporte_') && ...
        ~contains(nombre, 'historial');
end

function modulos = tesis_modulos_catalogo_impl()
    modulos = struct( ...
        'orden', {}, ...
        'nombre_corto', {}, ...
        'nombre', {}, ...
        'funcion', {}, ...
        'descripcion', {});

    modulos(end + 1) = crear_modulo_catalogo(1, ...
        'COMSOL', ...
        'Interacción con COMSOL', ...
        'modulo_interaccion_comsol', ...
        'Genera modelos de COMSOL, completa simulaciones faltantes y extrae en archivos MAT un dataset termico por solucion, incluyendo sondas y puntos de calor en el espacio.');

    modulos(end + 1) = crear_modulo_catalogo(2, ...
        'Procesamiento', ...
        'Procesamiento de Datos', ...
        'modulo_procesamiento_datos', ...
        'Convierte los datasets a STL y archivos TXT, voxeliza los STL, calcula las correcciones termicas y exporta los datasets corregidos.');

    modulos(end + 1) = crear_modulo_catalogo(3, ...
        'Visualizador', ...
        'Manejador visual de datos', ...
        'modulo_manejador_visual_datos', ...
        'Visualiza simulaciones originales/corregidas, sondas, funciones de correccion, volumen 4D y resumen grafico de los datos procesados.');

    modulos(end + 1) = crear_modulo_catalogo(4, ...
        'Optimizador', ...
        'Optimizador 3D', ...
        'optimizador_3d_final', ...
        'Optimiza posicion y orientacion usando distribuciones termicas procesadas.');

    modulos(end + 1) = crear_modulo_catalogo(5, ...
        'Verificacion', ...
        'Verificación experimental', ...
        'Interfaz_Ablacion_AlphaShape', ...
        'Segmenta imagenes experimentales y reconstruye geometria de ablacion 3D.');
end
function modulo = crear_modulo_catalogo(orden, nombre_corto, nombre, funcion, descripcion)
    modulo = struct( ...
        'orden', orden, ...
        'nombre_corto', nombre_corto, ...
        'nombre', nombre, ...
        'funcion', funcion, ...
        'descripcion', descripcion);
end

function varargout = tema_tesis_ui_impl(action, varargin)
    if nargin == 0 || isempty(action)
        action = 'theme';
    end

    theme = construir_tema();

    switch lower(string(action))
        case {"theme", "get"}
            result = theme;

        case "apply"
            obj = varargin{1};
            aplicar_tema_recursivo(obj, theme);
            result = obj;

        case "figure"
            obj = varargin{1};
            aplicar_propiedad_ui(obj, 'Color', theme.colors.bg);
            result = obj;

        case "panel"
            obj = varargin{1};
            aplicar_propiedad_ui(obj, 'BackgroundColor', theme.colors.panel);
            aplicar_propiedad_ui(obj, 'ForegroundColor', theme.colors.text);
            aplicar_propiedad_ui(obj, 'FontWeight', 'bold');
            result = obj;

        case "card"
            obj = varargin{1};
            aplicar_propiedad_ui(obj, 'BackgroundColor', theme.colors.card);
            aplicar_propiedad_ui(obj, 'ForegroundColor', theme.colors.text);
            result = obj;

        case "label"
            obj = varargin{1};
            estilo = obtener_argumento_ui(varargin, 2, 'normal');
            aplicar_label(obj, estilo, theme);
            result = obj;

        case "button"
            obj = varargin{1};
            variante = obtener_argumento_ui(varargin, 2, 'secondary');
            aplicar_boton(obj, variante, theme);
            result = obj;

        case "dropdown"
            obj = varargin{1};
            aplicar_propiedad_ui(obj, 'BackgroundColor', theme.colors.input);
            aplicar_propiedad_ui(obj, 'FontColor', theme.colors.text);
            result = obj;

        case "edit"
            obj = varargin{1};
            aplicar_propiedad_ui(obj, 'BackgroundColor', theme.colors.input);
            aplicar_propiedad_ui(obj, 'FontColor', theme.colors.text);
            result = obj;

        case "textarea"
            obj = varargin{1};
            aplicar_propiedad_ui(obj, 'BackgroundColor', theme.colors.console);
            aplicar_propiedad_ui(obj, 'FontColor', theme.colors.consoleText);
            aplicar_propiedad_ui(obj, 'FontName', theme.fonts.mono);
            aplicar_propiedad_ui(obj, 'FontSize', theme.fonts.logSize);
            result = obj;

        case "axes"
            obj = varargin{1};
            aplicar_propiedad_ui(obj, 'Color', theme.colors.axes);
            aplicar_propiedad_ui(obj, 'XColor', theme.colors.textMuted);
            aplicar_propiedad_ui(obj, 'YColor', theme.colors.textMuted);
            aplicar_propiedad_ui(obj, 'ZColor', theme.colors.textMuted);
            aplicar_propiedad_ui(obj, 'GridColor', theme.colors.grid);
            result = obj;

        otherwise
            error('tesis_auxiliares:tema_accion_desconocida', ...
                'Accion de tema no reconocida: %s', action);
    end

    if nargout > 0
        varargout{1} = result;
    end
end

function theme = construir_tema()
    theme = struct();
    theme.name = 'Tesis MATLAB Dark Optimizer';

    theme.colors = struct( ...
        'bg',        [0.10 0.10 0.11], ...
        'panel',     [0.15 0.15 0.16], ...
        'card',      [0.17 0.17 0.18], ...
        'border',    [0.26 0.27 0.30], ...
        'axes',      [0.08 0.08 0.10], ...
        'grid',      [0.35 0.36 0.38], ...
        'input',     [0.18 0.18 0.20], ...
        'console',   [0.07 0.07 0.07], ...
        'consoleText', [0.85 0.85 0.85], ...
        'text',      [0.92 0.92 0.92], ...
        'textMuted', [0.72 0.72 0.72], ...
        'disabled',  [0.58 0.60 0.64], ...
        'primary',   [0.25 0.33 0.40], ...
        'secondary', [0.24 0.24 0.27], ...
        'success',   [0.25 0.40 0.25], ...
        'warning',   [0.50 0.30 0.06], ...
        'danger',    [0.40 0.25 0.25], ...
        'accent',    [0.95 0.62 0.12], ...
        'corrected', [0.55 0.20 0.55], ...
        'thermalBlue',   [0.48 0.70 0.96], ...
        'thermalYellow', [0.92 0.62 0.12], ...
        'thermalRed',    [0.74 0.20 0.12]);

    theme.fonts = struct( ...
        'ui', 'Segoe UI', ...
        'mono', 'Consolas', ...
        'titleSize', 18, ...
        'sectionSize', 12, ...
        'bodySize', 10, ...
        'smallSize', 9, ...
        'logSize', 11);

    theme.layout = struct( ...
        'launcherPosition', [50 50 1250 850], ...
        'sidebarWidth', 360, ...
        'headerHeight', 64, ...
        'logHeight', 150, ...
        'buttonHeight', 30, ...
        'padding', 10);

    theme.variants = struct( ...
        'primary', theme.colors.primary, ...
        'secondary', theme.colors.secondary, ...
        'success', theme.colors.success, ...
        'warning', theme.colors.warning, ...
        'danger', theme.colors.danger, ...
        'accent', theme.colors.accent);
end

function aplicar_boton(obj, variante, theme)
    variante = char(variante);
    if isfield(theme.variants, variante)
        color = theme.variants.(variante);
    else
        color = theme.colors.secondary;
    end
    aplicar_propiedad_ui(obj, 'BackgroundColor', color);
    if strcmp(variante, 'secondary')
        aplicar_propiedad_ui(obj, 'FontColor', theme.colors.text);
    else
        aplicar_propiedad_ui(obj, 'FontColor', [1 1 1]);
    end
    aplicar_propiedad_ui(obj, 'FontWeight', 'bold');
end

function aplicar_tema_recursivo(obj, theme)
    if ~isgraphics(obj)
        return;
    end

    tipo = class(obj);
    if contains(tipo, 'Figure')
        tema_tesis_ui_impl('figure', obj);
    elseif contains(tipo, 'Panel')
        tema_tesis_ui_impl('panel', obj);
    elseif contains(tipo, 'GridLayout')
        aplicar_propiedad_ui(obj, 'BackgroundColor', theme.colors.bg);
    elseif contains(tipo, 'Button')
        if isprop(obj, 'BackgroundColor') && ...
                (norm(double(obj.BackgroundColor) - [0.94 0.94 0.94]) < 0.08 || ...
                 mean(double(obj.BackgroundColor)) > 0.62)
            tema_tesis_ui_impl('button', obj, 'secondary');
        else
            aplicar_propiedad_ui(obj, 'FontColor', [1 1 1]);
            aplicar_propiedad_ui(obj, 'FontWeight', 'bold');
        end
    elseif contains(tipo, 'UIControl')
        aplicar_uicontrol_clasico(obj, theme);
    elseif contains(tipo, 'DropDown') || contains(tipo, 'ListBox')
        tema_tesis_ui_impl('dropdown', obj);
    elseif contains(tipo, 'EditField') || contains(tipo, 'Spinner')
        tema_tesis_ui_impl('edit', obj);
    elseif contains(tipo, 'TextArea')
        tema_tesis_ui_impl('textarea', obj);
    elseif contains(tipo, 'Label')
        tema_tesis_ui_impl('label', obj, 'normal');
    elseif contains(tipo, 'Axes')
        tema_tesis_ui_impl('axes', obj);
    end

    if isprop(obj, 'Children')
        hijos = obj.Children;
        for idx_hijo = 1:numel(hijos)
            aplicar_tema_recursivo(hijos(idx_hijo), theme);
        end
    else
        try
            hijos = allchild(obj);
            for idx_hijo = 1:numel(hijos)
                aplicar_tema_recursivo(hijos(idx_hijo), theme);
            end
        catch
        end
    end
end

function aplicar_uicontrol_clasico(obj, theme)
    if ~isprop(obj, 'Style')
        return;
    end
    estilo = lower(string(obj.Style));
    switch estilo
        case "pushbutton"
            aplicar_propiedad_ui(obj, 'BackgroundColor', theme.colors.secondary);
            aplicar_propiedad_ui(obj, 'ForegroundColor', theme.colors.text);
            aplicar_propiedad_ui(obj, 'FontWeight', 'bold');
        case {"text", "checkbox", "radiobutton"}
            aplicar_propiedad_ui(obj, 'BackgroundColor', theme.colors.panel);
            aplicar_propiedad_ui(obj, 'ForegroundColor', theme.colors.text);
        case {"edit", "popupmenu", "listbox"}
            aplicar_propiedad_ui(obj, 'BackgroundColor', theme.colors.input);
            aplicar_propiedad_ui(obj, 'ForegroundColor', theme.colors.text);
        otherwise
    end
end

function aplicar_label(obj, estilo, theme)
    estilo = char(estilo);
    aplicar_propiedad_ui(obj, 'FontColor', theme.colors.text);
    switch estilo
        case 'title'
            aplicar_propiedad_ui(obj, 'FontSize', theme.fonts.titleSize);
            aplicar_propiedad_ui(obj, 'FontWeight', 'bold');
            aplicar_propiedad_ui(obj, 'FontColor', theme.colors.accent);
        case 'section'
            aplicar_propiedad_ui(obj, 'FontSize', theme.fonts.sectionSize);
            aplicar_propiedad_ui(obj, 'FontWeight', 'bold');
            aplicar_propiedad_ui(obj, 'FontColor', theme.colors.accent);
        case 'muted'
            aplicar_propiedad_ui(obj, 'FontSize', theme.fonts.smallSize);
            aplicar_propiedad_ui(obj, 'FontColor', theme.colors.textMuted);
        case 'status'
            aplicar_propiedad_ui(obj, 'FontSize', theme.fonts.smallSize);
            aplicar_propiedad_ui(obj, 'FontColor', theme.colors.thermalBlue);
        otherwise
            aplicar_propiedad_ui(obj, 'FontSize', theme.fonts.bodySize);
    end
end

function aplicar_propiedad_ui(obj, propiedad, valor)
    if isprop(obj, propiedad)
        try
            obj.(propiedad) = valor;
        catch
            % Algunos controles tienen propiedades de solo lectura segun version.
        end
    end
end

function valor = obtener_argumento_ui(args, idx, predeterminado)
    if numel(args) >= idx
        valor = args{idx};
    else
        valor = predeterminado;
    end
end

function ui = crear_dashboard_modulo_impl(titulo, descripcion, entradas, ejecutar_cb)
    theme = tema_tesis_ui_impl();
    valores = struct();
    labels = struct();

    fig = uifigure('Name', titulo, ...
        'Position', [120 90 980 620], ...
        'Color', theme.colors.bg);

    gl_main = uigridlayout(fig, [2, 2]);
    gl_main.RowHeight = {'1x', 130};
    gl_main.ColumnWidth = {340, '1x'};
    gl_main.Padding = [10 10 10 10];
    gl_main.RowSpacing = 8;
    gl_main.ColumnSpacing = 8;

    pnl_control = uipanel(gl_main, 'Title', 'Panel de Control', ...
        'Scrollable', 'on');
    pnl_control.Layout.Row = 1;
    pnl_control.Layout.Column = 1;

    n_entradas = numel(entradas);
    gl_control = uigridlayout(pnl_control, [max(7, 2*n_entradas + 5), 1]);
    gl_control.RowHeight = repmat({28}, 1, max(7, 2*n_entradas + 5));
    gl_control.RowHeight{1} = 48;
    gl_control.RowHeight{2} = 40;
    gl_control.Padding = [10 10 10 10];
    gl_control.RowSpacing = 6;

    lbl_titulo = uilabel(gl_control, 'Text', titulo, ...
        'FontWeight', 'bold', 'WordWrap', 'on');
    tema_tesis_ui_impl('label', lbl_titulo, 'section');

    lbl_desc = uilabel(gl_control, 'Text', descripcion, 'WordWrap', 'on');
    tema_tesis_ui_impl('label', lbl_desc, 'muted');

    for i = 1:n_entradas
        ent = entradas(i);
        valores.(ent.key) = ent.default;

        if isfield(ent, 'kind') && strcmpi(ent.kind, 'choice')
            lbl_choice = uilabel(gl_control, 'Text', ent.label, 'FontWeight', 'bold');
            tema_tesis_ui_impl('label', lbl_choice, 'normal');
            dd_choice = uidropdown(gl_control, ...
                'Items', ent.items, ...
                'Value', ent.default, ...
                'ValueChangedFcn', @(src, ~) cambiar_opcion(ent, src.Value));
            labels.(ent.key) = dd_choice;
        elseif isfield(ent, 'kind') && strcmpi(ent.kind, 'numeric')
            lbl_numeric = uilabel(gl_control, 'Text', ent.label, 'FontWeight', 'bold');
            tema_tesis_ui_impl('label', lbl_numeric, 'normal');
            args_numeric = {'Value', ent.default, ...
                'ValueChangedFcn', @(src, ~) cambiar_opcion(ent, src.Value)};
            if isfield(ent, 'limits') && ~isempty(ent.limits)
                args_numeric = [args_numeric, {'Limits', ent.limits}]; %#ok<AGROW>
            end
            ed_numeric = uieditfield(gl_control, 'numeric', args_numeric{:});
            labels.(ent.key) = ed_numeric;
        else
            btn = uibutton(gl_control, 'Text', ['Subir ' ent.label], ...
                'ButtonPushedFcn', @(~, ~) seleccionar_entrada(ent));
            tema_tesis_ui_impl('button', btn, 'primary');

            labels.(ent.key) = uilabel(gl_control, ...
                'Text', texto_ruta_dashboard(ent.default), ...
                'WordWrap', 'on');
            tema_tesis_ui_impl('label', labels.(ent.key), 'muted');
        end
    end

    btn_run = uibutton(gl_control, 'Text', 'Ejecutar modulo', ...
        'ButtonPushedFcn', @(~, ~) ejecutar_modulo());
    tema_tesis_ui_impl('button', btn_run, 'success');

    btn_export = uibutton(gl_control, 'Text', 'Exportar log', ...
        'ButtonPushedFcn', @(~, ~) exportar_log());
    tema_tesis_ui_impl('button', btn_export, 'secondary');

    btn_close = uibutton(gl_control, 'Text', 'Cerrar', ...
        'ButtonPushedFcn', @(~, ~) close(fig));
    tema_tesis_ui_impl('button', btn_close, 'danger');

    pnl_info = uipanel(gl_main, 'Title', 'Dashboard');
    pnl_info.Layout.Row = 1;
    pnl_info.Layout.Column = 2;
    gl_info = uigridlayout(pnl_info, [3, 1]);
    gl_info.RowHeight = {40, '1x', 30};
    gl_info.Padding = [10 10 10 10];

    lbl_estado = uilabel(gl_info, ...
        'Text', 'Seleccione entradas y ejecute el modulo.', ...
        'FontWeight', 'bold');
    tema_tesis_ui_impl('label', lbl_estado, 'status');

    txt_resumen = uitextarea(gl_info, ...
        'Editable', 'off', ...
        'Value', {'Entradas pendientes.'});
    tema_tesis_ui_impl('textarea', txt_resumen);

    btn_root = uibutton(gl_info, 'Text', 'Abrir carpeta actual', ...
        'ButtonPushedFcn', @(~, ~) abrir_carpeta_dashboard(pwd));
    tema_tesis_ui_impl('button', btn_root, 'secondary');

    pnl_log = uipanel(gl_main, 'Title', 'Registro de Eventos (Consola)');
    pnl_log.Layout.Row = 2;
    pnl_log.Layout.Column = [1 2];
    gl_log = uigridlayout(pnl_log, [1, 1]);
    gl_log.Padding = [2 2 2 2];
    txt_log = uitextarea(gl_log, ...
        'Editable', 'off', ...
        'Value', {'Listo.'});
    tema_tesis_ui_impl('textarea', txt_log);

    tema_tesis_ui_impl('apply', fig);
    tema_tesis_ui_impl('textarea', txt_log);
    tema_tesis_ui_impl('textarea', txt_resumen);

    ui = struct('figure', fig, 'log', txt_log, 'values', valores);
    log_evento('Dashboard inicializado.');
    actualizar_resumen();

    function seleccionar_entrada(ent)
        switch lower(ent.kind)
            case 'folder'
                seleccionado = uigetdir(pwd, ent.title);
                if isequal(seleccionado, 0)
                    log_evento('Seleccion cancelada: %s.', ent.label);
                    return;
                end
            otherwise
                [archivo, carpeta] = uigetfile(ent.filter, ent.title);
                if isequal(archivo, 0)
                    log_evento('Seleccion cancelada: %s.', ent.label);
                    return;
                end
                seleccionado = fullfile(carpeta, archivo);
        end

        valores.(ent.key) = seleccionado;
        labels.(ent.key).Text = texto_ruta_dashboard(seleccionado);
        log_evento('%s: %s', ent.label, seleccionado);
        actualizar_resumen();
    end

    function cambiar_opcion(ent, valor)
        valores.(ent.key) = valor;
        log_evento('%s: %s', ent.label, texto_valor(valor));
        actualizar_resumen();
    end

    function ejecutar_modulo()
        try
            lbl_estado.Text = 'Ejecutando...';
            insertar_separacion_log();
            log_evento('Inicio de ejecucion.');
            drawnow;
            ejecutar_cb(valores, @log_evento);
            lbl_estado.Text = 'Modulo finalizado.';
            log_evento('Ejecucion finalizada.');
        catch ME
            lbl_estado.Text = 'Error durante la ejecucion.';
            log_evento('ERROR: %s', ME.message);
            uialert(fig, ME.message, 'Error del modulo');
        end
    end

    function insertar_separacion_log()
        txt_log.Value = [repmat({''}, 5, 1); txt_log.Value(:)];
        drawnow limitrate;
    end

    function exportar_log()
        [archivo, carpeta] = uiputfile('*.txt', ...
            'Exportar log', sprintf('%s_log.txt', normalizar_nombre_dashboard(titulo)));
        if isequal(archivo, 0)
            return;
        end
        ruta = fullfile(carpeta, archivo);
        fid = fopen(ruta, 'w');
        limpieza = onCleanup(@() fclose(fid));
        lineas = flipud(txt_log.Value(:));
        for k = 1:numel(lineas)
            fprintf(fid, '%s\n', lineas{k});
        end
        log_evento('Log exportado: %s', ruta);
    end

    function actualizar_resumen()
        lineas = cell(n_entradas + 1, 1);
        lineas{1} = descripcion;
        for j = 1:n_entradas
            ent_j = entradas(j);
            if isfield(ent_j, 'kind') && strcmpi(ent_j.kind, 'choice')
                lineas{j + 1} = sprintf('%s: %s', ent_j.label, texto_valor(valores.(ent_j.key)));
            elseif isfield(ent_j, 'kind') && strcmpi(ent_j.kind, 'numeric')
                lineas{j + 1} = sprintf('%s: %s', ent_j.label, texto_valor(valores.(ent_j.key)));
            else
                lineas{j + 1} = sprintf('%s: %s', ...
                    ent_j.label, texto_ruta_dashboard(valores.(ent_j.key)));
            end
        end
        txt_resumen.Value = lineas;
    end

    function log_evento(formato, varargin)
        marca = char(datetime('now', 'Format', 'HH:mm:ss'));
        linea = sprintf('[%s] %s', marca, sprintf(formato, varargin{:}));
        txt_log.Value = [{linea}; txt_log.Value(:)];
        drawnow limitrate;
    end

    function texto = texto_valor(valor)
        if isnumeric(valor)
            texto = num2str(valor);
        elseif isstring(valor)
            texto = char(valor);
        else
            texto = char(valor);
        end
    end
end

function texto = texto_ruta_dashboard(ruta)
    if isempty(ruta)
        texto = '(sin seleccionar)';
    else
        texto = ruta;
    end
end

function abrir_carpeta_dashboard(ruta)
    if isfolder(ruta) && ispc
        winopen(ruta);
    end
end

function nombre = normalizar_nombre_dashboard(texto)
    nombre = regexprep(lower(texto), '[^a-z0-9]+', '_');
    nombre = regexprep(nombre, '^_|_$', '');
end
