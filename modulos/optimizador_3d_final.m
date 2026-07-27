function optimizador_3d_final(varargin)
% =========================================================================
%  OPTIMIZADOR 3D DE DISTRIBUCIONES TÉRMICAS
% =========================================================================
%
%  FUNCIONALIDAD
%  Carga una geometría tumoral STL, calibra el acceso, carga distribuciones térmicas preprocesadas y optimiza traslación/rotación mediante PSO para maximizar cobertura tumoral y penalizar ablación externa.
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

clc;

    % Permite ejecutar el modulo desde el launcher o directamente.
    carpeta_modulo = fileparts(mfilename('fullpath'));
    candidatos_aux = {fullfile(carpeta_modulo, '..', 'aux_codes')};
    for k_aux = 1:numel(candidatos_aux)
        if isfolder(candidatos_aux{k_aux}), addpath(candidatos_aux{k_aux}); end
    end
    if exist('tesis_auxiliares', 'file') == 2
        tesis_auxiliares('configurar_paths', carpeta_modulo);
    end

rng(1234);

% Parámetros Generales de distribuciones térmicas
root_proyecto = tesis_auxiliares('project_root', carpeta_modulo);
data_paths = tesis_auxiliares('dataset_paths', root_proyecto);
if nargin >= 1 && strcmpi(char(varargin{1}), 'selftest_metadata')
    ruta_1 = fullfile('Monopolo', '1ant', 'Caso_1', 'Potencia_30W', ...
        'Fecha_junio_19', 'Tiempo_20min', 'Prueba_1', 'Zonas_4');
    ruta_2 = strrep(ruta_1, 'Prueba_1', 'Prueba_2');
    meta_1 = tesis_auxiliares('metadata_ruta', ruta_1);
    meta_2 = tesis_auxiliares('metadata_ruta', ruta_2);
    assert(meta_1.completa_simulacion && meta_1.completa_adquisicion);
    assert(meta_1.numero_prueba == 1 && meta_2.numero_prueba == 2);
    clave_1 = sprintf('%s|%s|c%d|p%g|%s|t%g|r%d|z%d', ...
        meta_1.tipo, meta_1.antena, meta_1.caso, meta_1.potencia_W, ...
        meta_1.fecha_adquisicion, meta_1.tiempo_ejecucion_min, ...
        meta_1.numero_prueba, meta_1.num_zonas);
    clave_2 = sprintf('%s|%s|c%d|p%g|%s|t%g|r%d|z%d', ...
        meta_2.tipo, meta_2.antena, meta_2.caso, meta_2.potencia_W, ...
        meta_2.fecha_adquisicion, meta_2.tiempo_ejecucion_min, ...
        meta_2.numero_prueba, meta_2.num_zonas);
    assert(~strcmp(clave_1, clave_2), 'Dos pruebas distintas colisionan.');
    catalogo_prueba = crear_metadatos_archivo(2);
    catalogo_prueba(1).es_valido = true;
    catalogo_prueba(1).tipo = 'Monopolo';
    catalogo_prueba(1).arreglo = '1ant';
    catalogo_prueba(2).es_valido = true;
    catalogo_prueba(2).tipo = 'Dipolo';
    catalogo_prueba(2).arreglo = '2ant';
    filtros_prueba = crear_filtros_vacios();
    filtros_prueba.tipos = {'Monopolo'};
    assert(isequal(valores_filtro_compatibles( ...
        catalogo_prueba, filtros_prueba, 'antenas'), {'1ant'}), ...
        'Los filtros del optimizador no se encadenan.');
    fprintf('SELFTEST_OPTIMIZER_METADATA_OK %s | %s\n', clave_1, clave_2);
    return;
end
if ~isfolder(data_paths.root), mkdir(data_paths.root); end
ruta_dataset = data_paths.distribuciones_mat;
ruta_dataset_corregidas = data_paths.distribuciones_mat_corregidas;
ruta_distribuciones_stl = data_paths.distribuciones_stl;
ruta_distribuciones_stl_corregidas = data_paths.distribuciones_stl_corregidas;
ruta_historial_sesion = data_paths.historial_sesion;
ruta_historial_tejidos_voxel = data_paths.historial_tejidos_voxel;
raices_catalogo_distribuciones = struct( ...
    'origen', {'original', 'corregido'}, ...
    'mat', {ruta_dataset, ruta_dataset_corregidas}, ...
    'stl', {ruta_distribuciones_stl, ruta_distribuciones_stl_corregidas}, ...
    'omitir_legacy_corregidas', {true, false});

app = struct();
app.filtros_catalogo            = crear_filtros_vacios();
app.filtros_activos             = crear_filtros_vacios();
app.historial_sesion            = {};
app.contador_corridas           = 0;
app.ejes_a_rotar                = [1 2];
app.volumen_distribucion_optima = [];
app.caras_distribucion_optima   = [];
app.catalogo_dataset_cache      = struct( ...
    'carpetas', [], ...
    'metadatos', [], ...
    'timestamp', []);
app.profundidad_base_antena_mm  = 26.4;

%% ------------------------------------------------------------------ %%
%%  FIGURA PRINCIPAL
%% ------------------------------------------------------------------ %%
app.fig = uifigure("Name","Optimizador de Distribuciones Térmicas 3D", ...
    'Position',[50 50 1250 850], 'CloseRequestFcn', @confirmar_cierre);

gl_main = uigridlayout(app.fig, [2,2]);
gl_main.RowHeight   = {'1x', 150};
gl_main.ColumnWidth = {360, '1x'};

%% LOG
pnl_log = uipanel(gl_main, 'Title','Registro de Eventos (Consola)');
pnl_log.Layout.Row    = 2;
pnl_log.Layout.Column = [1,2];
gl_log = uigridlayout(pnl_log, [1,1]);
gl_log.Padding = [2 2 2 2];
app.txt_log = uitextarea(gl_log, 'Editable','off', 'FontName','Consolas', ...
    'FontSize',11, 'BackgroundColor',[0.07 0.07 0.07], 'FontColor',[0.85 0.85 0.85]);

    function registrar_mensaje(msg)
        t = char(datetime('now', 'Format', 'HH:mm:ss'));
        lineas = normalizar_lineas_log(app.txt_log.Value);
        app.txt_log.Value = [{sprintf('[%s] %s', t, msg)}; lineas(:)];
        drawnow;
    end

    function insertar_separacion_log()
        lineas = normalizar_lineas_log(app.txt_log.Value);
        app.txt_log.Value = [repmat({''}, 5, 1); lineas(:)];
        drawnow limitrate;
    end

    function lineas = normalizar_lineas_log(valor)
        if isempty(valor)
            lineas = {};
        elseif iscell(valor)
            lineas = valor;
        elseif isstring(valor)
            lineas = cellstr(valor);
        else
            lineas = cellstr(string(valor));
        end
    end

%% ------------------------------------------------------------------ %%
%%  SIDEBAR
%% ------------------------------------------------------------------ %%
pnl_sidebar = uipanel(gl_main, 'Title','Panel de Control', 'Scrollable','on');
pnl_sidebar.Layout.Row    = 1;
pnl_sidebar.Layout.Column = 1;

gl_sidebar = uigridlayout(pnl_sidebar, [16,1]);
gl_sidebar.RowHeight = {
    22, 22, ...
    22, 170, 30, ...
    15, ...
    22, 22, ...
    22, 22, ...
    15, ...
    35, 35, 35, 35, ...
    '1x'};
gl_sidebar.Padding    = [10 10 10 10];
gl_sidebar.RowSpacing = 4;

uilabel(gl_sidebar, 'Text','Metodo de Voxelizado:', 'FontWeight','bold');
app.dd_metodo_voxel = uidropdown(gl_sidebar, 'Items',{'mascara','sdf','tsdf'}, 'Value','sdf');

uilabel(gl_sidebar, 'Text','Filtros detectados en dataset:', 'FontWeight','bold');
gl_filtros = uigridlayout(gl_sidebar, [2,2], 'Padding',[0 0 0 0], ...
    'RowSpacing',4, 'ColumnSpacing',6);
gl_filtros.RowHeight = {26, '1x'};
gl_filtros.ColumnWidth = {'1x', '1x'};
app.dd_filtro_categoria = uidropdown(gl_filtros, ...
    'Items', {'Origen', 'Tipo', 'Antenas', 'Caso', 'Potencia', ...
        'Fecha', 'Tiempo', 'Prueba', 'Zonas'}, ...
    'Value', 'Tipo', ...
    'ValueChangedFcn', @(~,~) actualizar_listas_filtros());
uibutton(gl_filtros, 'Text','Detectar', ...
    'ButtonPushedFcn', @(~,~) actualizar_catalogo_filtros(true));
app.lst_filtros_disponibles = uilistbox(gl_filtros, ...
    'Items', {'(sin dataset)'});
app.lst_filtros_activos = uilistbox(gl_filtros, ...
    'Items', {'(sin filtros activos)'});


gl_btn_sel = uigridlayout(gl_sidebar, [1,3], 'Padding',[0 0 0 0], 'ColumnSpacing',5);
uibutton(gl_btn_sel, 'Text','Agregar', 'ButtonPushedFcn', @(~,~) agregar_filtro_activo());
uibutton(gl_btn_sel, 'Text','Remover', 'ButtonPushedFcn', @(~,~) remover_filtro_activo());
uibutton(gl_btn_sel, 'Text','Limpiar', 'ButtonPushedFcn', @(~,~) limpiar_filtros_activos());

uilabel(gl_sidebar, 'Text','');

uilabel(gl_sidebar, 'Text','Resolucion tumor fina (mm):', 'FontWeight','bold');
app.edt_res_fina   = uieditfield(gl_sidebar, 'text', 'Value','0.5');
uilabel(gl_sidebar, 'Text','Resolucion tumor gruesa (mm):', 'FontWeight','bold');
app.edt_res_gruesa = uieditfield(gl_sidebar, 'text', 'Value','1.5');

uilabel(gl_sidebar, 'Text','');

uibutton(gl_sidebar, 'Text','1. Cargar Tumor (STL)', ...
    'BackgroundColor',[0.25 0.33 0.4], 'FontColor','w', ...
    'ButtonPushedFcn', @cargar_tumor);
uibutton(gl_sidebar, 'Text','2. Calibrar Acceso STL', ...
    'BackgroundColor',[0.25 0.33 0.4], 'FontColor','w', ...
    'ButtonPushedFcn', @calibrar_acceso);
uibutton(gl_sidebar, 'Text','3. Calcular Optimo (PSO)', ...
    'BackgroundColor',[0.25 0.4 0.25], 'FontColor','w', 'FontWeight','bold', ...
    'ButtonPushedFcn', @realizar_optimizacion);
uibutton(gl_sidebar, 'Text','4. Exportar Reporte PDF', ...
    'BackgroundColor',[0.4 0.25 0.25], 'FontColor','w', ...
    'ButtonPushedFcn', @exportar_pdf);

uilabel(gl_sidebar, 'Text','');
%% ------------------------------------------------------------------ %%
%%  PANEL DERECHO — 3 columnas
%% ------------------------------------------------------------------ %%
gl_display = uigridlayout(gl_main, [1,3]);
gl_display.Layout.Row    = 1;
gl_display.Layout.Column = 2;
gl_display.ColumnWidth   = {'2x', '1.2x', '0.8x'};
gl_display.ColumnSpacing = 6;
gl_display.Padding       = [0 0 0 0];

% ── Columna 1: Vista 3D + botones de vista predeterminada ─────────────
pnl_3d = uipanel(gl_display, 'Title','Vista 3D');
gl_3d  = uigridlayout(pnl_3d, [2,1]);
gl_3d.RowHeight  = {'1x', 34};
gl_3d.Padding    = [0 0 0 0];
gl_3d.RowSpacing = 0;

app.ax = uiaxes(gl_3d);
view(app.ax, 3); grid(app.ax,'on'); axis(app.ax,'equal');
xlabel(app.ax,'X (mm)'); ylabel(app.ax,'Y (mm)'); zlabel(app.ax,'Z (mm)');
title(app.ax,'Entorno Espacial STL');

% ── Fila inferior: 4 vistas predeterminadas + Reset ───────────────────
% Vista XY  → view(0, 90)  — plano horizontal / aérea
% Vista XZ  → view(0,  0)  — plano frontal
% Vista YZ  → view(90, 0)  — plano lateral
% Vista 3D  → view(45,30)  — perspectiva estándar
pnl_vistas = uipanel(gl_3d, 'BorderType','none');
gl_vistas  = uigridlayout(pnl_vistas, [1,5]);
gl_vistas.ColumnWidth  = {'1x','1x','1x','1x','1x'};
gl_vistas.Padding      = [5 3 5 3];
gl_vistas.ColumnSpacing = 4;

uibutton(gl_vistas, 'Text','Vista XY', 'FontSize',10, ...
    'Tooltip','Plano XY (vista superior)', ...
    'ButtonPushedFcn', @(~,~) aplicar_vista([0  90]));
uibutton(gl_vistas, 'Text','Vista XZ', 'FontSize',10, ...
    'Tooltip','Plano XZ (vista frontal)', ...
    'ButtonPushedFcn', @(~,~) aplicar_vista([0   0]));
uibutton(gl_vistas, 'Text','Vista YZ', 'FontSize',10, ...
    'Tooltip','Plano YZ (vista lateral)', ...
    'ButtonPushedFcn', @(~,~) aplicar_vista([90  0]));
uibutton(gl_vistas, 'Text','Vista 3D', 'FontSize',10, ...
    'Tooltip','Perspectiva estándar', ...
    'ButtonPushedFcn', @(~,~) aplicar_vista([45 30]));
uibutton(gl_vistas, 'Text','Reset',    'FontSize',10, ...
    'Tooltip','Restablecer vista 3D', ...
    'ButtonPushedFcn', @(~,~) view(app.ax, 3));

    function aplicar_vista(az_el)
        view(app.ax, az_el(1), az_el(2));
        axis(app.ax, 'equal');
        registrar_mensaje(sprintf('Vista: Az=%d°  El=%d°', az_el(1), az_el(2)));
    end

% ── Columna 2: Convergencia + Resultados ──────────────────────────────
gl_col2 = uigridlayout(gl_display, [2,1]);
gl_col2.RowHeight  = {'1x', '1x'};
gl_col2.Padding    = [0 0 0 0];
gl_col2.RowSpacing = 6;

pnl_conv = uipanel(gl_col2, 'Title','Convergencia PSO');
gl_conv  = uigridlayout(pnl_conv, [1,1]);
app.ax_conv = uiaxes(gl_conv);
grid(app.ax_conv,'on');
xlabel(app.ax_conv,'Iteración'); ylabel(app.ax_conv,'Fitness');
title(app.ax_conv,'Evolución PSO');

pnl_res = uipanel(gl_col2, 'Title','Resultados de Optimización');
gl_res  = uigridlayout(pnl_res, [1,1]);
app.txt_resultados = uitextarea(gl_res, 'Editable','off', 'FontSize',12, ...
    'FontName','Consolas', 'Value','Esperando optimización...');

% ── Columna 3: Historial de sesión ────────────────────────────────────
pnl_hist = uipanel(gl_display, 'Title','Optimizaciones de la Sesión');
gl_hist  = uigridlayout(pnl_hist, [3,1]);
gl_hist.RowHeight = {'1x', 30, 30};
gl_hist.Padding   = [4 4 4 4];

app.lst_historial = uilistbox(gl_hist, 'Items',{});
app.lst_historial.ValueChangedFcn = @ver_corrida_historial;

uibutton(gl_hist, 'Text','Importar historial (.mat)', ...
    'BackgroundColor',[0.3 0.3 0.45], 'FontColor','w', ...
    'ButtonPushedFcn', @importar_historial);
uibutton(gl_hist, 'Text','Exportar historial (.mat)', ...
    'ButtonPushedFcn', @exportar_historial);

actualizar_listas_filtros();
registrar_mensaje('Aplicación inicializada. Pulse Detectar para cargar los filtros del dataset.');

%% ================================================================== %%
%%  CALLBACKS
%% ================================================================== %%

    function actualizar_catalogo_filtros(mostrar_log)
        if nargin < 1
            mostrar_log = false;
        end

        catalogo = crear_filtros_vacios();
        [carpetas_dataset, metadatos_dataset] = obtener_catalogo_distribuciones(mostrar_log);

        if isempty(carpetas_dataset)
            app.filtros_catalogo = catalogo;
            app.filtros_activos = crear_filtros_vacios();
            actualizar_listas_filtros();
            if mostrar_log
                registrar_mensaje(sprintf('Dataset no encontrado o sin carpetas de metadata en: %s', ...
                    resumen_raices_catalogo()));
            end
            return;
        end

        for idx_carpeta = 1:numel(carpetas_dataset)
            meta = metadatos_dataset(idx_carpeta);
            if ~meta.es_valido
                continue;
            end
            catalogo.tipos     = agregar_valor_filtro(catalogo.tipos, meta.tipo);
            catalogo.antenas   = agregar_valor_filtro(catalogo.antenas, meta.arreglo);
            catalogo.casos     = agregar_valor_filtro(catalogo.casos, meta.caso);
            catalogo.potencias = agregar_valor_filtro(catalogo.potencias, meta.potencia);
            catalogo.fechas = agregar_valor_filtro(catalogo.fechas, meta.fecha);
            catalogo.tiempos = agregar_valor_filtro(catalogo.tiempos, meta.tiempo);
            catalogo.pruebas = agregar_valor_filtro(catalogo.pruebas, meta.prueba);
            catalogo.zonas = agregar_valor_filtro(catalogo.zonas, meta.zonas);
            catalogo.origenes = agregar_valor_filtro(catalogo.origenes, meta.origen);
        end

        campos_catalogo = fieldnames(catalogo);
        for idx_campo = 1:numel(campos_catalogo)
            campo = campos_catalogo{idx_campo};
            catalogo.(campo) = ordenar_valores_filtro(catalogo.(campo));
            app.filtros_activos.(campo) = intersect( ...
                app.filtros_activos.(campo), catalogo.(campo), 'stable');
        end
        app.filtros_catalogo = catalogo;
        actualizar_listas_filtros();

        if mostrar_log
            registrar_mensaje(sprintf(['Filtros actualizados desde metadata: %d carpetas | ' ...
                'origenes=%d, tipos=%d, antenas=%d, casos=%d, potencias=%d, ' ...
                'fechas=%d, tiempos=%d, pruebas=%d, zonas=%d.'], ...
                numel(carpetas_dataset), numel(app.filtros_catalogo.origenes), ...
                numel(app.filtros_catalogo.tipos), ...
                numel(app.filtros_catalogo.antenas), numel(app.filtros_catalogo.casos), ...
                numel(app.filtros_catalogo.potencias), numel(app.filtros_catalogo.fechas), ...
                numel(app.filtros_catalogo.tiempos), numel(app.filtros_catalogo.pruebas), ...
                numel(app.filtros_catalogo.zonas)));
        end
    end

    function [carpetas_dataset, metadatos_dataset] = obtener_catalogo_distribuciones(forzar_recarga)
        if nargin < 1
            forzar_recarga = false;
        end
        if ~forzar_recarga && isfield(app, 'catalogo_dataset_cache') && ...
                ~isempty(app.catalogo_dataset_cache.carpetas)
            carpetas_dataset = app.catalogo_dataset_cache.carpetas;
            metadatos_dataset = app.catalogo_dataset_cache.metadatos;
            return;
        end

        carpetas_dataset = struct([]);
        metadatos_dataset = crear_metadatos_archivo(0);
        for idx_raiz = 1:numel(raices_catalogo_distribuciones)
            raiz = raices_catalogo_distribuciones(idx_raiz);
            if ~isfolder(raiz.mat)
                continue;
            end
            if strcmpi(raiz.origen, 'corregido')
                patron = fullfile(raiz.mat, '*', '*', 'Caso_*', 'Potencia_*', ...
                    'Fecha_*', 'Tiempo_*', 'Prueba_*', 'Zonas_*');
            else
                patron = fullfile(raiz.mat, '*', '*', 'Caso_*', 'Potencia_*');
            end
            carpetas_raiz = dir(patron);
            carpetas_raiz = carpetas_raiz([carpetas_raiz.isdir]);
            for idx_carpeta = 1:numel(carpetas_raiz)
                ruta_absoluta = fullfile( ...
                    carpetas_raiz(idx_carpeta).folder, carpetas_raiz(idx_carpeta).name);
                prefijo = [char(raiz.mat) filesep];
                if startsWith(ruta_absoluta, prefijo, 'IgnoreCase', ispc)
                    ruta_relativa = ruta_absoluta(numel(prefijo) + 1:end);
                else
                    ruta_relativa = erase(ruta_absoluta, prefijo);
                end
                partes_relativas = split(char(ruta_relativa), filesep);
                if raiz.omitir_legacy_corregidas && ~isempty(partes_relativas) && ...
                        strcmpi(partes_relativas{1}, 'corregidas')
                    continue;
                end
                if any(strcmpi(split(strrep(ruta_relativa, '\', '/'), '/'), 'repetidos'))
                    continue;
                end

                metadata_ruta = tesis_auxiliares('metadata_ruta', ruta_relativa);
                meta_actual = crear_metadatos_archivo(1);
                meta_actual.es_valido = metadata_ruta.completa_simulacion && ...
                    (~strcmpi(raiz.origen, 'corregido') || metadata_ruta.completa_adquisicion);
                meta_actual.tipo = metadata_ruta.tipo;
                meta_actual.arreglo = metadata_ruta.antena;
                if isfinite(metadata_ruta.caso)
                    meta_actual.caso = sprintf('Caso_%d', round(metadata_ruta.caso));
                end
                if isfinite(metadata_ruta.potencia_W)
                    meta_actual.potencia = sprintf('Potencia_%gW', metadata_ruta.potencia_W);
                    meta_actual.potencia = strrep(meta_actual.potencia, '.', 'p');
                end
                meta_actual.fecha = char(metadata_ruta.fecha_adquisicion);
                if isfinite(metadata_ruta.tiempo_ejecucion_min)
                    meta_actual.tiempo = sprintf('Tiempo_%gmin', metadata_ruta.tiempo_ejecucion_min);
                end
                if isfinite(metadata_ruta.numero_prueba)
                    meta_actual.prueba = sprintf('Prueba_%d', round(metadata_ruta.numero_prueba));
                end
                if isfinite(metadata_ruta.num_zonas)
                    meta_actual.zonas = sprintf('Zonas_%d', round(metadata_ruta.num_zonas));
                end
                meta_actual.origen = raiz.origen;
                meta_actual.ruta_relativa = ruta_relativa;
                meta_actual.raiz_mat = raiz.mat;
                meta_actual.raiz_stl = raiz.stl;

                carpetas_dataset = [carpetas_dataset; carpetas_raiz(idx_carpeta)]; %#ok<AGROW>
                metadatos_dataset(end+1) = meta_actual; %#ok<AGROW>
            end
        end

        app.catalogo_dataset_cache = struct( ...
            'carpetas', carpetas_dataset, ...
            'metadatos', metadatos_dataset, ...
            'timestamp', datetime('now'));
    end

    function txt = resumen_raices_catalogo()
        partes = cell(1, numel(raices_catalogo_distribuciones));
        for ri = 1:numel(raices_catalogo_distribuciones)
            partes{ri} = sprintf('%s=%s', ...
                raices_catalogo_distribuciones(ri).origen, ...
                raices_catalogo_distribuciones(ri).mat);
        end
        txt = strjoin(partes, '; ');
    end

    function actualizar_listas_filtros()
        campo = campo_filtro_actual();
        if isempty(app.catalogo_dataset_cache.metadatos)
            disponibles = app.filtros_catalogo.(campo);
        else
            disponibles = valores_filtro_compatibles( ...
                app.catalogo_dataset_cache.metadatos, app.filtros_activos, campo);
        end
        disponibles = setdiff(disponibles, app.filtros_activos.(campo), 'stable');
        activos = app.filtros_activos.(campo);

        if isempty(disponibles)
            disponibles = {'(sin filtros disponibles)'};
        end
        if isempty(activos)
            activos = {'(sin filtros activos)'};
        end

        app.lst_filtros_disponibles.Items = disponibles;
        app.lst_filtros_disponibles.Value = disponibles{1};
        app.lst_filtros_activos.Items = activos;
        app.lst_filtros_activos.Value = activos{1};
    end

    function agregar_filtro_activo()
        campo = campo_filtro_actual();
        valor = app.lst_filtros_disponibles.Value;
        if es_placeholder_filtro(valor)
            registrar_mensaje('No hay filtros disponibles para agregar en esta categoria.');
            return;
        end
        app.filtros_activos.(campo) = agregar_valor_filtro(app.filtros_activos.(campo), valor);
        app.filtros_activos.(campo) = ordenar_valores_filtro(app.filtros_activos.(campo));
        actualizar_listas_filtros();
        registrar_mensaje(sprintf('Filtro activo agregado [%s]: %s', app.dd_filtro_categoria.Value, char(valor)));
    end

    function remover_filtro_activo()
        campo = campo_filtro_actual();
        valor = app.lst_filtros_activos.Value;
        if es_placeholder_filtro(valor)
            registrar_mensaje('No hay filtros activos para remover en esta categoria.');
            return;
        end
        app.filtros_activos.(campo) = setdiff(app.filtros_activos.(campo), {char(valor)}, 'stable');
        actualizar_listas_filtros();
        registrar_mensaje(sprintf('Filtro activo removido [%s]: %s', app.dd_filtro_categoria.Value, char(valor)));
    end

    function limpiar_filtros_activos()
        app.filtros_activos = crear_filtros_vacios();
        actualizar_listas_filtros();
        registrar_mensaje('Filtros activos reiniciados. Se usara todo el dataset disponible.');
    end

    function campo = campo_filtro_actual()
        switch app.dd_filtro_categoria.Value
            case 'Origen'
                campo = 'origenes';
            case 'Tipo'
                campo = 'tipos';
            case 'Antenas'
                campo = 'antenas';
            case 'Caso'
                campo = 'casos';
            case 'Potencia'
                campo = 'potencias';
            case 'Fecha'
                campo = 'fechas';
            case 'Tiempo'
                campo = 'tiempos';
            case 'Prueba'
                campo = 'pruebas';
            case 'Zonas'
                campo = 'zonas';
            otherwise
                error('Categoria de filtro no soportada: %s', app.dd_filtro_categoria.Value);
        end
    end

    function limpiar_eje_3d(titulo)
        cla(app.ax, 'reset');
        view(app.ax, 3); grid(app.ax,'on'); axis(app.ax,'equal');
        xlabel(app.ax,'X (mm)'); ylabel(app.ax,'Y (mm)'); zlabel(app.ax,'Z (mm)');
        if nargin == 1
            title(app.ax, titulo);
        else
            title(app.ax,'Entorno Espacial STL');
        end
    end

    % ---------------------------------------------------------------- %
    %  1. Cargar Tumor
    % ---------------------------------------------------------------- %
    function cargar_tumor(~,~)
        insertar_separacion_log();
        limpiar_eje_3d('Cargando modelo...');
        [file, path] = uigetfile('*.stl');
        if isequal(file, 0), registrar_mensaje('Carga cancelada.'); return; end
        [app.vertices_tumor, app.caras_tumor] = lector_stl(fullfile(path, file));
        registrar_mensaje(sprintf('STL cargado: %s', file));
        centrar_ejes();
    end

    % ---------------------------------------------------------------- %
    %  centrar_ejes
    % ---------------------------------------------------------------- %
    function centrar_ejes(~,~)
        if ~isfield(app,'vertices_tumor'), registrar_mensaje('ERROR: Carga un tumor primero.'); return; end

        preparar_geometria_base_apoyo_z0();
        app.R_calibracion = eye(3);
        app.z_acceso      = [];
        app.desplazamiento_calibracion = [0 0 0];

        dimensiones = max(app.vertices_tumor_reorientado) - min(app.vertices_tumor_reorientado);
        [~, orden] = sort(dimensiones, 'descend');
        app.ejes_a_rotar = [orden(1) orden(2)];
        registrar_mensaje(sprintf(['Sistema base generado. Centro XY eliminado y apoyo en z=0. ' ...
            'Ejes dominantes: [%d, %d]'], app.ejes_a_rotar(1), app.ejes_a_rotar(2)));

        redibujar_geometria_actual('Sistema base apoyado en z=0');
    end

    function preparar_geometria_base_apoyo_z0()
        vertices_total = app.vertices_tumor;
        if isfield(app,'vertices_musculo'), vertices_total = [vertices_total; app.vertices_musculo]; end
        if isfield(app,'vertices_hueso'),   vertices_total = [vertices_total; app.vertices_hueso];   end

        centro_xy = mean(vertices_total(:,1:2), 1);
        z_minimo  = min(vertices_total(:,3));
        app.origen_geometria = [centro_xy z_minimo];
        app.centro_global = app.origen_geometria;

        app.vertices_tumor_base = app.vertices_tumor - app.origen_geometria;
        app.vertices_tumor_reorientado = app.vertices_tumor_base;

        if isfield(app,'vertices_musculo')
            app.vertices_musculo_base = app.vertices_musculo - app.origen_geometria;
            app.vertices_musculo_reorientado = app.vertices_musculo_base;
        else
            app.vertices_musculo_base = [];
            app.vertices_musculo_reorientado = [];
        end

        if isfield(app,'vertices_hueso')
            app.vertices_hueso_base = app.vertices_hueso - app.origen_geometria;
            app.vertices_hueso_reorientado = app.vertices_hueso_base;
        else
            app.vertices_hueso_base = [];
            app.vertices_hueso_reorientado = [];
        end

        app.plano_apoyo_z = 0;
    end

    function restaurar_geometria_base_para_calibracion()
        if ~isfield(app,'vertices_tumor_base') || isempty(app.vertices_tumor_base)
            preparar_geometria_base_apoyo_z0();
        end
        app.vertices_tumor_reorientado = app.vertices_tumor_base;
        if isfield(app,'vertices_musculo_base')
            app.vertices_musculo_reorientado = app.vertices_musculo_base;
        end
        if isfield(app,'vertices_hueso_base')
            app.vertices_hueso_reorientado = app.vertices_hueso_base;
        end
        app.R_calibracion = eye(3);
        app.z_acceso = [];
        app.desplazamiento_calibracion = [0 0 0];
    end

    function patch_tumor = redibujar_geometria_actual(titulo)
        limpiar_eje_3d(titulo);
        patch_tumor = patch(app.ax, 'Faces',app.caras_tumor, 'Vertices',app.vertices_tumor_reorientado, ...
            'FaceColor',[1 0 0], 'EdgeColor','none', 'FaceAlpha',0.3, 'DisplayName','Tumor');
        hold(app.ax, 'on');

        if isfield(app,'vertices_musculo_reorientado') && ~isempty(app.vertices_musculo_reorientado) && isfield(app,'caras_musculo') && ~isempty(app.caras_musculo)
            patch(app.ax, 'Faces',app.caras_musculo, 'Vertices',app.vertices_musculo_reorientado, ...
                'FaceColor',[0 1 0], 'EdgeColor','none', 'FaceAlpha',0.3, 'DisplayName','Musculo');
        end
        if isfield(app,'vertices_hueso_reorientado') && ~isempty(app.vertices_hueso_reorientado) && isfield(app,'caras_hueso') && ~isempty(app.caras_hueso)
            patch(app.ax, 'Faces',app.caras_hueso, 'Vertices',app.vertices_hueso_reorientado, ...
                'FaceColor',[0 1 1], 'EdgeColor','none', 'FaceAlpha',0.3, 'DisplayName','Hueso');
        end

        camlight(app.ax); lighting(app.ax,'gouraud');
        legend(app.ax, 'Location','best');
    end
    % ---------------------------------------------------------------- %
    %  2. Calibrar Acceso STL
    % ---------------------------------------------------------------- %
    function calibrar_acceso(~,~)
        if ~isfield(app,'vertices_tumor_reorientado')
            registrar_mensaje('ERROR: Carga un tumor primero.'); return;
        end
        insertar_separacion_log();
        restaurar_geometria_base_para_calibracion();
        patch_tumor = redibujar_geometria_actual('Calibracion: selecciona cara de entrada');
        registrar_mensaje(['CALIBRACION: escena reiniciada a la geometria base apoyada en z=0. ' ...
            'Haz clic en la cara de entrada de las antenas.']);
        uialert(app.fig, ['Se reinicio la vista a la geometria base apoyada en z=0.' newline ...
            'Haz clic en la cara del STL por donde entraran las antenas.'], 'Calibracion');

        fcn_previa = patch_tumor.ButtonDownFcn;
        disableDefaultInteractivity(app.ax);
        app.fig.Pointer = 'crosshair';
        patch_tumor.ButtonDownFcn = @(s,e) capturar_punto_acceso(s, e, patch_tumor, fcn_previa);
    end

    function capturar_punto_acceso(~, evt, patch_tumor, fcn_previa)
        patch_tumor.ButtonDownFcn = fcn_previa;
        enableDefaultInteractivity(app.ax);
        app.fig.Pointer = 'arrow';

        punto_clic = evt.IntersectionPoint;
        V = app.vertices_tumor_reorientado;
        F = app.caras_tumor;
        centroides_caras = (V(F(:,1),:) + V(F(:,2),:) + V(F(:,3),:)) / 3;
        [~, idx_cara] = min(vecnorm(centroides_caras - punto_clic, 2, 2));

        v1 = V(F(idx_cara,1),:);
        v2 = V(F(idx_cara,2),:);
        v3 = V(F(idx_cara,3),:);
        normal_cara = cross(v2-v1, v3-v1);
        normal_cara = normal_cara / norm(normal_cara);
        centroide_cara = (v1+v2+v3)/3;
        if dot(normal_cara, centroide_cara - mean(V)) < 0
            normal_cara = -normal_cara;
        end

        app.R_calibracion = calcular_rotacion_calibracion(normal_cara');
        app.vertices_tumor_reorientado = (app.R_calibracion * app.vertices_tumor_base')';
        desplazamiento_z = -min(app.vertices_tumor_reorientado(:,3));
        app.desplazamiento_calibracion = [0 0 desplazamiento_z];
        app.vertices_tumor_reorientado = app.vertices_tumor_reorientado + app.desplazamiento_calibracion;

        if isfield(app,'vertices_musculo_base') && ~isempty(app.vertices_musculo_base)
            app.vertices_musculo_reorientado = (app.R_calibracion * app.vertices_musculo_base')' + app.desplazamiento_calibracion;
        end
        if isfield(app,'vertices_hueso_base') && ~isempty(app.vertices_hueso_base)
            app.vertices_hueso_reorientado = (app.R_calibracion * app.vertices_hueso_base')' + app.desplazamiento_calibracion;
        end

        dimensiones = max(app.vertices_tumor_reorientado) - min(app.vertices_tumor_reorientado);
        [~, orden] = sort(dimensiones, 'descend');
        app.ejes_a_rotar = [orden(1) orden(2)];

        centroide_cara_cal = (app.R_calibracion * centroide_cara')' + app.desplazamiento_calibracion;
        app.z_acceso = centroide_cara_cal(3);

        redibujar_geometria_actual(sprintf('Calibrado | z_{acceso} = %.1f mm', app.z_acceso));
        lims = [min(app.vertices_tumor_reorientado(:,1)) max(app.vertices_tumor_reorientado(:,1)) ...
                min(app.vertices_tumor_reorientado(:,2)) max(app.vertices_tumor_reorientado(:,2))];
        [Xp, Yp] = meshgrid(linspace(lims(1),lims(2),2), linspace(lims(3),lims(4),2));
        surf(app.ax, Xp, Yp, ones(size(Xp))*app.z_acceso, ...
            'FaceColor',[0.2 0.8 0.2], 'FaceAlpha',0.25, 'EdgeColor','none', ...
            'DisplayName','Plano acceso');
        surf(app.ax, Xp, Yp, zeros(size(Xp)), ...
            'FaceColor',[0.4 0.4 0.4], 'FaceAlpha',0.12, 'EdgeColor','none', ...
            'DisplayName','Plano apoyo z=0');
        legend(app.ax, 'Location','best');
        registrar_mensaje(sprintf(['Calibracion OK. z_acceso=%.2f mm | apoyo z=0 | ' ...
            'desplazamiento_z=%.2f mm | ejes=[%d %d]'], ...
            app.z_acceso, desplazamiento_z, app.ejes_a_rotar(1), app.ejes_a_rotar(2)));
    end
    % ---------------------------------------------------------------- %
    %  3. Calcular Óptimo (PSO)
    % ---------------------------------------------------------------- %
    function realizar_optimizacion(~,~)
        enableDefaultInteractivity(app.ax);
        if ~isfield(app,'vertices_tumor_reorientado')
            registrar_mensaje('ERROR: Carga y centra el tumor primero.'); return;
        end
        insertar_separacion_log();
        if ~isfield(app,'profundidad_base_antena_mm') || isempty(app.profundidad_base_antena_mm)
            app.profundidad_base_antena_mm = 26.4;
            registrar_mensaje('AVISO: profundidad base de antena no existia en la sesion; se restauro a 26.4 mm.');
        end
        registrar_mensaje('Iniciando optimización PSO bifásica...');

        metodo_voxel = app.dd_metodo_voxel.Value;
        resolucion_fina   = str2double(app.edt_res_fina.Value);
        resolucion_gruesa = str2double(app.edt_res_gruesa.Value);
        if any(~isfinite([resolucion_fina, resolucion_gruesa])) || ...
                any([resolucion_fina, resolucion_gruesa] <= 0)
            registrar_mensaje('ERROR: las resoluciones fina y gruesa deben ser positivas.');
            return;
        end

        [carpetas_dataset, metadatos_carpetas] = obtener_catalogo_distribuciones(false);
        if isempty(carpetas_dataset)
            registrar_mensaje(sprintf('ERROR: No se encontraron carpetas de metadata en %s.', ...
                resumen_raices_catalogo()));
            return;
        end

        actualizar_catalogo_filtros(false);
        filtros_activos = app.filtros_activos;

        carpetas_validas = false(length(carpetas_dataset), 1);
        for i = 1:length(carpetas_dataset)
            meta_i = metadatos_carpetas(i);
            if ~meta_i.es_valido, continue; end
            if ~(coincide_filtro_metadata(meta_i.tipo, filtros_activos.tipos) && ...
                    coincide_filtro_metadata(meta_i.arreglo, filtros_activos.antenas) && ...
                    coincide_filtro_metadata(meta_i.caso, filtros_activos.casos) && ...
                    coincide_filtro_metadata(meta_i.potencia, filtros_activos.potencias) && ...
                    coincide_filtro_metadata(meta_i.fecha, filtros_activos.fechas) && ...
                    coincide_filtro_metadata(meta_i.tiempo, filtros_activos.tiempos) && ...
                    coincide_filtro_metadata(meta_i.prueba, filtros_activos.pruebas) && ...
                    coincide_filtro_metadata(meta_i.zonas, filtros_activos.zonas) && ...
                    coincide_filtro_metadata(meta_i.origen, filtros_activos.origenes))
                continue;
            end
            carpetas_validas(i) = true;
        end
        carpetas_filtradas = carpetas_dataset(carpetas_validas);
        metadatos_carpetas = metadatos_carpetas(carpetas_validas);

        if isempty(carpetas_filtradas)
            registrar_mensaje('ERROR: Ninguna carpeta de metadata pasa los filtros.');
            return;
        end

        archivos_filtrados = struct([]);
        metadatos_filtrados = crear_metadatos_archivo(0);
        for idx_carpeta = 1:numel(carpetas_filtradas)
            ruta_carpeta = fullfile( ...
                carpetas_filtradas(idx_carpeta).folder, carpetas_filtradas(idx_carpeta).name);
            archivos_carpeta = dir(fullfile( ...
                ruta_carpeta, sprintf('*_%s_res*.mat', metodo_voxel)));
            for idx_archivo = 1:numel(archivos_carpeta)
                meta_archivo = metadatos_carpetas(idx_carpeta);
                [~, nombre, ~] = fileparts(archivos_carpeta(idx_archivo).name);
                meta_archivo.resolucion = extraer_resolucion_nombre_mat(nombre, metodo_voxel);
                if isfinite(meta_archivo.resolucion)
                    meta_archivo.resolucion_texto = sprintf('%.2f mm', meta_archivo.resolucion);
                else
                    meta_archivo.resolucion_texto = 'sin_resolucion';
                end
                meta_archivo.ruta_relativa = fullfile( ...
                    meta_archivo.ruta_relativa, archivos_carpeta(idx_archivo).name);
                archivos_filtrados(end + 1) = archivos_carpeta(idx_archivo); %#ok<AGROW>
                metadatos_filtrados(end + 1) = meta_archivo; %#ok<AGROW>
            end
        end
        if isempty(archivos_filtrados)
            registrar_mensaje(sprintf( ...
                'ERROR: Las carpetas filtradas no contienen archivos *_%s_res*.mat.', ...
                metodo_voxel));
            return;
        end

        n_res_omitidas = 0;
        if numel(archivos_filtrados) > 1
            claves = cell(numel(archivos_filtrados), 1);
            resoluciones = nan(numel(archivos_filtrados), 1);
            for idx_archivo = 1:numel(archivos_filtrados)
                [~, nombre, ~] = fileparts(archivos_filtrados(idx_archivo).name);
                nombre_base = regexprep(nombre, ...
                    ['_' regexptranslate('escape', metodo_voxel) '_res[\d\.]+$'], '');
                resoluciones(idx_archivo) = extraer_resolucion_nombre_mat(nombre, metodo_voxel);
                meta = metadatos_filtrados(idx_archivo);
                claves{idx_archivo} = strjoin({meta.origen, meta.tipo, meta.arreglo, ...
                    meta.caso, meta.potencia, meta.fecha, meta.tiempo, ...
                    meta.prueba, meta.zonas, nombre_base}, '|');
            end
            claves_unicas = {};
            grupos = zeros(numel(claves), 1);
            for idx_clave = 1:numel(claves)
                posicion = find(strcmp(claves_unicas, claves{idx_clave}), 1);
                if isempty(posicion)
                    claves_unicas{end + 1} = claves{idx_clave}; %#ok<AGROW>
                    posicion = numel(claves_unicas);
                end
                grupos(idx_clave) = posicion;
            end
            indices_sel = zeros(numel(claves_unicas), 1);
            for idx_grupo = 1:numel(claves_unicas)
                candidatos = find(grupos == idx_grupo);
                res_candidatas = resoluciones(candidatos);
                distancia = abs(res_candidatas - resolucion_fina);
                distancia(~isfinite(distancia)) = inf;
                [~, orden] = sortrows([distancia(:), res_candidatas(:)], [1 2]);
                indices_sel(idx_grupo) = candidatos(orden(1));
            end
            indices_sel = sort(indices_sel);
            n_res_omitidas = numel(archivos_filtrados) - numel(indices_sel);
            archivos_filtrados = archivos_filtrados(indices_sel);
            metadatos_filtrados = metadatos_filtrados(indices_sel);
        end
        if n_res_omitidas > 0
            registrar_mensaje(sprintf(['Resoluciones MAT duplicadas omitidas: %d. ', ...
                'Preferencia automatica: res %.2f mm por distribucion.'], ...
                n_res_omitidas, resolucion_fina));
        end
        registrar_mensaje(sprintf( ...
            'Metadata: %d carpetas, %d compatibles | archivos %s: %d.', ...
            numel(carpetas_dataset), numel(carpetas_filtradas), ...
            metodo_voxel, numel(archivos_filtrados)));

        progDlg = uiprogressdlg(app.fig, 'Title','Calculando...', ...
            'Message','Iniciando...', 'Cancelable','on');
        tic;

        min_tumor = min(app.vertices_tumor_reorientado);
        max_tumor = max(app.vertices_tumor_reorientado);
        dimensiones = max_tumor - min_tumor;
        [~, orden_dimension] = sort(dimensiones, 'descend');
        app.ejes_a_rotar = [orden_dimension(1) orden_dimension(2)];
        app.min_tumor = min_tumor;
        app.max_tumor = max_tumor;

        % Radio máximo de gotas
        radio_max = 0;
        for i = 1:length(archivos_filtrados)
            dist_i = load(fullfile( ...
                archivos_filtrados(i).folder, ...
                archivos_filtrados(i).name), ...
                'gridX', 'gridY', 'gridZ', 'grid_x', 'grid_y', 'grid_z');
            if ~isfield(dist_i, 'gridX') && isfield(dist_i, 'grid_x')
                dist_i.gridX = dist_i.grid_x;
                dist_i.gridY = dist_i.grid_y;
                dist_i.gridZ = dist_i.grid_z;
            end
            if isfield(dist_i, 'gridX')
                r_i = max(abs([dist_i.gridX(1) dist_i.gridX(end) ...
                               dist_i.gridY(1) dist_i.gridY(end) ...
                               dist_i.gridZ(1) dist_i.gridZ(end)]));
                if r_i > radio_max, radio_max = r_i; end
            end
        end
        radio_max = radio_max + 5;
        registrar_mensaje(sprintf('Radio máximo de gotas: %.1f mm', radio_max));

        minGrid = min_tumor - radio_max;
        maxGrid = max_tumor + radio_max;

        % ── Voxelización con caché global ────────────────────────────
        archivo_cache_voxel = ruta_historial_tejidos_voxel;
        tumor_hash  = sum(app.vertices_tumor_reorientado(:)) * 1e12;
        llave_original = sprintf('tumor_%.1f_%.1f_%.1f_%.4f', ...
            resolucion_fina, resolucion_gruesa, radio_max, tumor_hash);
        llave_var = matlab.lang.makeValidName(llave_original);

        existe_en_cache = false;
        if isfile(archivo_cache_voxel)
            try
                vars_cache = whos('-file', archivo_cache_voxel);
                if ismember(llave_var, {vars_cache.name})
                    existe_en_cache = true;
                end
            catch
                registrar_mensaje('AVISO: no se pudo leer caché, se recalculará.');
            end
        end

        if existe_en_cache
            progDlg.Message = 'Cargando voxelización cacheada...';
            cd = load(archivo_cache_voxel, llave_var);
            grid_fino   = cd.(llave_var).grid_fino;
            mask_fina   = cd.(llave_var).mask_fina;
            grid_grueso = cd.(llave_var).grid_grueso;
            mask_gruesa = cd.(llave_var).mask_gruesa;
            registrar_mensaje('Voxelización cargada desde caché.');
        else
            progDlg.Message = 'Voxelizando tumor (rejilla fina)...';
            [xg,yg,zg] = meshgrid(minGrid(1):resolucion_fina:maxGrid(1), ...
                                   minGrid(2):resolucion_fina:maxGrid(2), ...
                                   minGrid(3):resolucion_fina:maxGrid(3));
            grid_fino = [xg(:) yg(:) zg(:)];
            mask_fina = inpolyhedron(app.caras_tumor, app.vertices_tumor_reorientado, grid_fino);

            progDlg.Message = 'Voxelizando tumor (rejilla gruesa)...';
            [xg_g,yg_g,zg_g] = meshgrid(minGrid(1):resolucion_gruesa:maxGrid(1), ...
                                          minGrid(2):resolucion_gruesa:maxGrid(2), ...
                                          minGrid(3):resolucion_gruesa:maxGrid(3));
            grid_grueso = [xg_g(:) yg_g(:) zg_g(:)];
            mask_gruesa = inpolyhedron(app.caras_tumor, app.vertices_tumor_reorientado, grid_grueso);

            datos_tejido.grid_fino   = grid_fino;
            datos_tejido.mask_fina   = mask_fina;
            datos_tejido.grid_grueso = grid_grueso;
            datos_tejido.mask_gruesa = mask_gruesa;

            contenedor_cache = struct();
            contenedor_cache.(llave_var) = datos_tejido;
            try
                if isfile(archivo_cache_voxel)
                    save(archivo_cache_voxel, '-struct', 'contenedor_cache', llave_var, '-append');
                else
                    save(archivo_cache_voxel, '-struct', 'contenedor_cache', llave_var);
                end
                registrar_mensaje('Voxelización calculada y guardada en caché.');
            catch ME
                registrar_mensaje(sprintf('AVISO: no se pudo guardar caché: %s', ME.message));
            end
        end

        puntos_interior_grueso = grid_grueso(mask_gruesa, :);
        centro_tumor = mean(app.vertices_tumor_reorientado);

        if isfield(app,'z_acceso') && ~isempty(app.z_acceso)
            margen_acceso  = 2 * resolucion_gruesa;
            puntos_accesibles = puntos_interior_grueso( ...
                puntos_interior_grueso(:,3) >= (app.z_acceso - margen_acceso), :);
            if isempty(puntos_accesibles)
                registrar_mensaje('ADVERTENCIA: sin puntos en zona accesible. Usando todos.');
                puntos_accesibles = puntos_interior_grueso;
            end
            registrar_mensaje(sprintf('Puntos accesibles: %d / %d (%.1f%%)', ...
                size(puntos_accesibles,1), size(puntos_interior_grueso,1), ...
                100*size(puntos_accesibles,1)/size(puntos_interior_grueso,1)));
        else
            puntos_accesibles = puntos_interior_grueso;
        end

        limite_inferior = [min_tumor, deg2rad(-15), 0  ];
        limite_superior = [max_tumor, deg2rad( 15), pi ];


        mapa_antenas = cargar_mapa_antenas_local();

        app.mejor_valor_fitness           = inf;
        app.parametros_optimizacion_final = [];
        historia_mejor    = [];
        historia_mejor_f1 = [];
        historia_mejor_f2 = [];
        historia_fitness  = [];

        function stop = guardar_historial_pso(valores_optimos, estado_pso)
            stop = false;
            if progDlg.CancelRequested, stop = true; return; end
            if strcmp(estado_pso,'iter')
                historia_fitness(end+1,1) = valores_optimos.bestfval;
            elseif strcmp(estado_pso,'init')
                historia_fitness = [];
            end
        end


        criterio_fitness = struct( ...
            'peso_fuga',        0.15, ...
            'peso_centroide',   0.02, ...
            'peso_profundidad', 0.05, ...
            'escala_espacial',  max(norm(max_tumor - min_tumor), eps), ...
            'escala_fitness',   1000);
        vol_tumor_grueso = sum(mask_gruesa) * resolucion_gruesa^3;
        registrar_mensaje(sprintf(['Fitness normalizado: %.0f*(-cobertura + %.2f*fuga ' ...
            '+ %.2f*centroide + %.2f*profundidad).'], ...
            criterio_fitness.escala_fitness, criterio_fitness.peso_fuga, ...
            criterio_fitness.peso_centroide, criterio_fitness.peso_profundidad));

        for idx = 1:length(archivos_filtrados)
            archivo_actual = archivos_filtrados(idx);
            ruta_actual    = fullfile(archivo_actual.folder, archivo_actual.name);
            meta_actual = metadatos_filtrados(idx);
            [~, nombre_archivo, ~] = fileparts(archivo_actual.name);

            datos = load(ruta_actual);
            nombre_distribucion = regexprep(nombre_archivo, ['_' metodo_voxel '_res[\d\.]+'], '');

            parte_tipo = meta_actual.tipo;
            parte_arreglo = meta_actual.arreglo;
            parte_caso = meta_actual.caso;
            parte_potencia = meta_actual.potencia;

            numero_antenas = regexp(parte_arreglo, '\d+ant', 'match', 'once');
            if isempty(numero_antenas) || ~isKey(mapa_antenas, numero_antenas)
                registrar_mensaje(sprintf('AVISO: arreglo de antenas no soportado por el optimizador: %s', parte_arreglo));
                continue;
            end
            coordenadas_antenas = mapa_antenas(numero_antenas);

            progDlg.Message = sprintf('Procesando %d/%d: %s', ...
                idx, length(archivos_filtrados), nombre_distribucion);

            funcion_fitness = @(pos) fitness_unico(pos, grid_grueso, mask_gruesa, ...
                datos, metodo_voxel, resolucion_gruesa, app.ejes_a_rotar, ...
                centro_tumor, vol_tumor_grueso, criterio_fitness);

            % FASE 1: exploración global
            particulas_fase_1 = 80;
            idx_r = randi(size(puntos_accesibles,1), particulas_fase_1, 1);
            variables_optimizadas_1        = zeros(particulas_fase_1, 5);
            variables_optimizadas_1(:,1:3) = puntos_accesibles(idx_r, :);
            variables_optimizadas_1(:,4)   = deg2rad(-15) + deg2rad(30)*rand(particulas_fase_1,1);
            variables_optimizadas_1(:,5)   = pi*rand(particulas_fase_1,1);

            pso_cfg_1 = optimoptions('particleswarm', ...
                'SwarmSize',80, 'MaxIterations',40, 'MaxStallIterations',15, ...
                'FunctionTolerance',1e-4, 'Display','iter', ...
                'InitialSwarmMatrix',variables_optimizadas_1, ...
                'OutputFcn',@guardar_historial_pso);
            [mejor_pos_f1, mejor_fit_f1] = particleswarm( ...
                funcion_fitness, 5, limite_inferior, limite_superior, pso_cfg_1);
            historia_fase_1 = historia_fitness;

            registrar_mensaje(sprintf('F1: fitness=%.4f | pos=[%.1f %.1f %.1f] | ang=[%.1f° %.1f°]', ...
                mejor_fit_f1, mejor_pos_f1(1), mejor_pos_f1(2), mejor_pos_f1(3), ...
                rad2deg(mejor_pos_f1(4)), rad2deg(mejor_pos_f1(5))));

            if progDlg.CancelRequested, registrar_mensaje('Optimización cancelada.'); break; end

            % FASE 2: explotación local
            rango   = limite_superior - limite_inferior;
            ventana = 0.10 * rango;
            lb_f2   = max(limite_inferior, mejor_pos_f1 - ventana);
            ub_f2   = min(limite_superior, mejor_pos_f1 + ventana);

            particulas_fase_2   = 60;
            enjambre_perturbado = repmat(mejor_pos_f1, particulas_fase_2-1, 1) + ...
                0.03*randn(particulas_fase_2-1, 5).*rango;
            enjambre_perturbado = max(min(enjambre_perturbado, ub_f2), lb_f2);
            enjambre_f2 = [mejor_pos_f1; enjambre_perturbado];

            pso_cfg_2 = optimoptions('particleswarm', ...
                'SwarmSize',60, 'MaxIterations',100, 'MaxStallIterations',15, ...
                'FunctionTolerance',1e-5, 'Display','iter', ...
                'InitialSwarmMatrix',enjambre_f2, ...
                'OutputFcn',@guardar_historial_pso);
            [mejor_pos_f2, mejor_fit_f2] = particleswarm( ...
                funcion_fitness, 5, lb_f2, ub_f2, pso_cfg_2);
            historia_fase_2 = historia_fitness;

            registrar_mensaje(sprintf('F2: fitness=%.4f (mejora=%.4f) | ang=[%.1f° %.1f°]', ...
                mejor_fit_f2, mejor_fit_f1 - mejor_fit_f2, ...
                rad2deg(mejor_pos_f2(4)), rad2deg(mejor_pos_f2(5))));

            if progDlg.CancelRequested, registrar_mensaje('Optimización cancelada.'); break; end

            % Evaluación final con grid FINO
            [vol_interior, vol_dist, vol_exterior] = calcular_interseccion_volumen( ...
                grid_fino, mask_fina, datos, metodo_voxel, ...
                resolucion_fina, mejor_pos_f2, app.ejes_a_rotar);

            vol_tumor_total     = sum(mask_fina) * resolucion_fina^3;
            pct_interior        = 100 * vol_interior / max(vol_tumor_total, eps);
            pct_exterior        = 100 * vol_exterior / max(vol_dist, eps);
            metricas_finas      = calcular_metricas_fitness(vol_interior, vol_dist, vol_exterior, ...
                vol_tumor_total, mejor_pos_f2, app.ejes_a_rotar, centro_tumor, criterio_fitness);
            fitness_fino        = metricas_finas.fitness;
            posicion_antena_1_local = coordenadas_antenas(1,:);
            posicion_antena_1_global = transformacion_rotacional( ...
                posicion_antena_1_local, mejor_pos_f2, app.ejes_a_rotar);
            profundidad_stl_mm = calcular_profundidad_stl(posicion_antena_1_global);
            profundidad_total_mm = app.profundidad_base_antena_mm + profundidad_stl_mm;
            registrar_mensaje(sprintf('  V_gota=%.0f | V_inter=%.0f | V_ext=%.0f mm³', ...
                vol_dist, vol_interior, vol_exterior));
            registrar_mensaje(sprintf('  %%tumor=%.1f%% | %%fuera=%.1f%%', pct_interior, pct_exterior));
            registrar_mensaje(sprintf('  Fitness fino=%.5f | fitness PSO=%.5f', ...
                fitness_fino, mejor_fit_f2));
            registrar_mensaje(sprintf('  Profundidad antena 1: base=%.1f mm | STL=%.1f mm | total=%.1f mm', ...
                app.profundidad_base_antena_mm, profundidad_stl_mm, profundidad_total_mm));

            if fitness_fino < app.mejor_valor_fitness
                app.mejor_valor_fitness = fitness_fino;
                % ── struct sin campos duplicados ──────────────────────
                app.parametros_optimizacion_final = struct( ...
                    'distribucion_termica',         nombre_distribucion, ...
                    'tipo_antena',                  parte_tipo, ...
                    'numero_antenas',               numero_antenas, ...
                    'caso',                         parte_caso, ...
                    'potencia',                     parte_potencia, ...
                    'fecha_adquisicion',             meta_actual.fecha, ...
                    'tiempo_ejecucion',              meta_actual.tiempo, ...
                    'numero_prueba',                 meta_actual.prueba, ...
                    'zonas',                         meta_actual.zonas, ...
                    'posicion',                     mejor_pos_f2, ...
                    'volumen_interior',             vol_interior, ...
                    'volumen_distribucion_termica', vol_dist, ...
                    'volumen_exterior',             vol_exterior, ...
                    'volumen_tumor',                vol_tumor_total, ...
                    'porcentaje_interior',          pct_interior, ...
                    'porcentaje_exterior',          pct_exterior, ...
                    'fitness_fino',                 fitness_fino, ...
                    'fitness_pso',                  mejor_fit_f2, ...
                    'criterio_fitness',             criterio_fitness, ...
                    'metricas_fitness',             metricas_finas, ...
                    'datos',                        datos, ...
                    'metodo_voxel',                 metodo_voxel, ...
                    'ruta',                         ruta_actual, ...
                    'ruta_relativa',                meta_actual.ruta_relativa, ...
                    'raiz_mat',                     meta_actual.raiz_mat, ...
                    'raiz_stl',                     meta_actual.raiz_stl, ...
                    'origen',                       meta_actual.origen, ...
                    'coordenadas_antenas',          coordenadas_antenas, ...
                    'posicion_antena_1_local',      posicion_antena_1_local, ...
                    'posicion_antena_1_global',     posicion_antena_1_global, ...
                    'profundidad_base_antena_mm',   app.profundidad_base_antena_mm, ...
                    'profundidad_stl_mm',           profundidad_stl_mm, ...
                    'profundidad_total_mm',         profundidad_total_mm, ...
                    'ejes_a_rotar',                 app.ejes_a_rotar);
                historia_mejor    = [historia_fase_1; historia_fase_2];
                historia_mejor_f1 = historia_fase_1;
                historia_mejor_f2 = historia_fase_2;
                registrar_mensaje(sprintf('  Nuevo mejor global por fitness fino: %.5f', fitness_fino));
            end
        end

        close(progDlg);
        if isempty(app.parametros_optimizacion_final)
            registrar_mensaje('Sin resultado válido. Verifica filtros o dataset.'); return;
        end

        parametros_optimizados = app.parametros_optimizacion_final;
        ruta_stl = resolver_ruta_stl_parametros(parametros_optimizados);

        volumen_transformado = []; caras_stl = [];
        if isfile(ruta_stl)
            [volumen_stl, caras_stl] = lector_stl(ruta_stl);
            volumen_stl = volumen_stl - mean(volumen_stl);
            volumen_transformado = transformacion_rotacional(volumen_stl, ...
                parametros_optimizados.posicion, app.ejes_a_rotar);
        end
        app.volumen_distribucion_optima = volumen_transformado;
        app.caras_distribucion_optima   = caras_stl;

        grafico_optimo = parametros_optimizados;
        grafico_optimo.vertices_musculo = []; grafico_optimo.caras_musculo = [];
        grafico_optimo.vertices_hueso   = []; grafico_optimo.caras_hueso   = [];
        if isfield(app,'vertices_musculo_reorientado') && ~isempty(app.vertices_musculo_reorientado) && isfield(app,'caras_musculo') && ~isempty(app.caras_musculo)
            grafico_optimo.vertices_musculo = app.vertices_musculo_reorientado;
            grafico_optimo.caras_musculo    = app.caras_musculo;
        end
        if isfield(app,'vertices_hueso_reorientado') && ~isempty(app.vertices_hueso_reorientado) && isfield(app,'caras_hueso') && ~isempty(app.caras_hueso)
            grafico_optimo.vertices_hueso = app.vertices_hueso_reorientado;
            grafico_optimo.caras_hueso    = app.caras_hueso;
        end

        graficar_escena(app.vertices_tumor_reorientado, app.caras_tumor, ...
            volumen_transformado, caras_stl, grafico_optimo, ...
            'Mejor configuración encontrada', eye(3));

        tiempo_total = toc;
        registrar_mensaje(sprintf('Optimización completada en %.1f s.', tiempo_total));

        mostrar_resultados_panel(parametros_optimizados, tiempo_total, false, -1, '');

        if ~isempty(historia_mejor)
            graficar_convergencia(historia_mejor_f1, historia_mejor_f2, ...
                parametros_optimizados.distribucion_termica);
        end

        % Guardar corrida
        app.contador_corridas = app.contador_corridas + 1;
        corrida.id             = app.contador_corridas;
        corrida.timestamp      = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
        corrida.parametros     = parametros_optimizados;
        corrida.historia_pso   = historia_mejor;
        corrida.historia_f1    = historia_mejor_f1;
        corrida.historia_f2    = historia_mejor_f2;
        corrida.tiempo_total   = tiempo_total;
        corrida.vertices_tumor = app.vertices_tumor_reorientado;
        corrida.caras_tumor    = app.caras_tumor;
        corrida.ejes_a_rotar   = app.ejes_a_rotar;
        corrida.es_importada   = false;
        app.historial_sesion{end+1} = corrida;

        hs = app.historial_sesion;
        save(ruta_historial_sesion, 'hs', '-v7.3');
        actualizar_panel_historial();
        registrar_mensaje(sprintf('Corrida #%d guardada en historial.', app.contador_corridas));
    end

    % ---------------------------------------------------------------- %
    %  Panel de resultados unificado
    % ---------------------------------------------------------------- %
    function mostrar_resultados_panel(p, tiempo_total, es_importada, id_corrida, timestamp)
        [rx,ry,rz] = mapear_ejes(p.ejes_a_rotar, p.posicion(4), p.posicion(5));

        if es_importada
            enc1 = sprintf('=== CORRIDA #%d (PRECARGADA) ===', id_corrida);
            enc2 = sprintf('Fecha         :  %s', timestamp);
            l_ant = sprintf('Antena        :  %s (%s)', p.tipo_antena, p.numero_antenas);
        else
            enc1  = '=================================================';
            enc2  = '         RESULTADOS DE OPTIMIZACIÓN              ';
            l_ant = sprintf('Tipo Antena   :  %s (%s)', p.tipo_antena, p.numero_antenas);
        end

        linea_vext = 'V exterior    :  n/d';
        if isfield(p,'volumen_exterior')
            linea_vext = sprintf('V exterior    :  %.0f mm^3', p.volumen_exterior);
        end

        linea_fit_fino = 'Fitness fino  :  n/d';
        if isfield(p,'fitness_fino')
            linea_fit_fino = sprintf('Fitness fino  :  %.5f', p.fitness_fino);
        end

        linea_fit_pso = 'Fitness PSO   :  n/d';
        if isfield(p,'fitness_pso')
            linea_fit_pso = sprintf('Fitness PSO   :  %.5f', p.fitness_pso);
        end

        linea_antena1_local = 'Antena 1 local :  n/d';
        if isfield(p,'posicion_antena_1_local')
            linea_antena1_local = sprintf('Antena 1 local :  [%.2f, %.2f, %.2f] mm', p.posicion_antena_1_local);
        end

        linea_antena1_global = 'Antena 1 global:  n/d';
        if isfield(p,'posicion_antena_1_global')
            linea_antena1_global = sprintf('Antena 1 global:  [%.2f, %.2f, %.2f] mm', p.posicion_antena_1_global);
        end

        linea_prof_base = 'Prof. base    :  n/d';
        if isfield(p,'profundidad_base_antena_mm')
            linea_prof_base = sprintf('Prof. base    :  %.2f mm', p.profundidad_base_antena_mm);
        end
        linea_prof_stl = 'Prof. STL     :  n/d';
        if isfield(p,'profundidad_stl_mm')
            linea_prof_stl = sprintf('Prof. STL     :  %.2f mm', p.profundidad_stl_mm);
        end
        linea_prof_total = 'Prof. total   :  n/d';
        if isfield(p,'profundidad_total_mm')
            linea_prof_total = sprintf('Prof. total   :  %.2f mm', p.profundidad_total_mm);
        end
        app.txt_resultados.Value = {
            enc1; enc2;
            '=================================================';
            '';
            sprintf('Distribución  :  %s',  p.distribucion_termica);
            l_ant;
            sprintf('Potencia      :  %s',  p.potencia);
            sprintf('Traslación    :  [%.2f, %.2f, %.2f] mm', p.posicion(1), p.posicion(2), p.posicion(3));
            sprintf('Rotación      :  Rx=%.1f°  Ry=%.1f°  Rz=%.1f°', ...
                rad2deg(rx), rad2deg(ry), rad2deg(rz));
            sprintf('Ejes rotación :  [%d, %d]', p.ejes_a_rotar(1), p.ejes_a_rotar(2));
            linea_antena1_local;
            linea_antena1_global;
            linea_prof_base;
            linea_prof_stl;
            linea_prof_total;
            '';
            '--- Volúmenes (grid fino) ---';
            sprintf('V tumor       :  %.0f mm³', p.volumen_tumor);
            sprintf('V gota        :  %.0f mm³', p.volumen_distribucion_termica);
            sprintf('V intersección:  %.0f mm³', p.volumen_interior);
            linea_vext;
            '';
            '--- Desempeño ---';
            sprintf('%% tumor cubierto :  %.1f %%', p.porcentaje_interior);
            sprintf('%% gota fuera     :  %.1f %%', p.porcentaje_exterior);
            '';
            '--- Fitness ---';
            linea_fit_fino;
            linea_fit_pso;
            sprintf('Tiempo total  :  %.1f s',      tiempo_total);
            '================================================='};
    end

    % ---------------------------------------------------------------- %
    %  Graficar convergencia
    % ---------------------------------------------------------------- %
    function graficar_convergencia(h_f1, h_f2, nombre_dist)
        cla(app.ax_conv);
        hold(app.ax_conv,'on');
        n1 = length(h_f1); n2 = length(h_f2);
        if n1 > 0
            plot(app.ax_conv, 1:n1, h_f1, 'b.-', ...
                'LineWidth',1.5, 'MarkerSize',8, 'DisplayName','Fase 1 (exploración)');
        end
        if n2 > 0
            plot(app.ax_conv, n1+(1:n2), h_f2, 'r.-', ...
                'LineWidth',1.5, 'MarkerSize',8, 'DisplayName','Fase 2 (explotación)');
        end
        legend(app.ax_conv, 'Location','best');
        hold(app.ax_conv,'off');
        xlabel(app.ax_conv,'Iteración'); ylabel(app.ax_conv,'Fitness');
        title(app.ax_conv, sprintf('Convergencia PSO: %s', nombre_dist));
    end

    % ---------------------------------------------------------------- %
    %  Historial de sesión
    % ---------------------------------------------------------------- %
    function actualizar_panel_historial()
        items = cellfun(@(c) sprintf('#%d | %s | %.1f%% | %s%s', ...
            c.id, c.parametros.distribucion_termica, ...
            c.parametros.porcentaje_interior, c.timestamp, ...
            obtener_sufijo_importada(c)), ...
            app.historial_sesion, 'UniformOutput', false);
        app.lst_historial.Items = items;
        if ~isempty(items), app.lst_historial.Value = items{end}; end
    end

    function s = obtener_sufijo_importada(c)
        if isfield(c,'es_importada') && c.es_importada
            s = ' [IMP]';
        else
            s = '';
        end
    end

    function ver_corrida_historial(~,~)
        idx = find(strcmp(app.lst_historial.Items, app.lst_historial.Value), 1);
        if isempty(idx), registrar_mensaje('Selecciona una corrida.'); return; end

        c            = app.historial_sesion{idx};
        p            = c.parametros;
        ejes_corrida = c.ejes_a_rotar;

        ruta_stl = '';
        if isfield(p,'ruta') && ~isempty(p.ruta)
            ruta_stl = resolver_ruta_stl_parametros(p);
        end

        vt = []; cs = [];
        if ~isempty(ruta_stl) && isfile(ruta_stl)
            [vs, cs] = lector_stl(ruta_stl);
            vs = vs - mean(vs);
            vt = transformacion_rotacional(vs, p.posicion, ejes_corrida);
        end

        go = p;
        go.vertices_musculo = []; go.caras_musculo = [];
        go.vertices_hueso   = []; go.caras_hueso   = [];

        graficar_escena(c.vertices_tumor, c.caras_tumor, vt, cs, go, ...
            sprintf('Corrida #%d — %s', c.id, p.distribucion_termica), eye(3));

        es_importada = isfield(c,'es_importada') && c.es_importada;
        mostrar_resultados_panel(p, c.tiempo_total, es_importada, c.id, c.timestamp);

        if isfield(c,'historia_f1') && ~isempty(c.historia_f1)
            graficar_convergencia(c.historia_f1, c.historia_f2, p.distribucion_termica);
        elseif isfield(c,'historia_pso') && ~isempty(c.historia_pso)
            cla(app.ax_conv);
            plot(app.ax_conv, 1:length(c.historia_pso), c.historia_pso, 'b.-', 'LineWidth',1.5);
            title(app.ax_conv, sprintf('Convergencia: %s', p.distribucion_termica));
        end
        registrar_mensaje(sprintf('Mostrando corrida #%d.', idx));
    end

    function ruta_stl = resolver_ruta_stl_parametros(p)
        ruta_stl = '';
        if isfield(p, 'ruta_relativa') && ~isempty(p.ruta_relativa) && ...
                isfield(p, 'raiz_stl') && ~isempty(p.raiz_stl)
            [subcarpeta, ~, ~] = fileparts(p.ruta_relativa);
            ruta_stl = fullfile(p.raiz_stl, subcarpeta, [p.distribucion_termica '.stl']);
            return;
        end

        if isfield(p, 'ruta') && ~isempty(p.ruta)
            if startsWith(p.ruta, [ruta_dataset_corregidas filesep], 'IgnoreCase', true)
                dist_rel = erase(p.ruta, [ruta_dataset_corregidas filesep]);
                raiz_stl = ruta_distribuciones_stl_corregidas;
            else
                dist_rel = erase(p.ruta, [ruta_dataset filesep]);
                raiz_stl = ruta_distribuciones_stl;
            end
            [subcarpeta, ~, ~] = fileparts(dist_rel);
            ruta_stl = fullfile(raiz_stl, subcarpeta, [p.distribucion_termica '.stl']);
        end
    end

    % Importar historial
    function importar_historial(~,~)
        [f, p] = uigetfile('*.mat','Importar historial', ruta_historial_sesion);
        if isequal(f,0), registrar_mensaje('Importación cancelada.'); return; end

        try
            di = load(fullfile(p,f), 'hs');
            if ~isfield(di,'hs') || isempty(di.hs)
                registrar_mensaje('ERROR: archivo sin historial válido.'); return;
            end
            hs_imp = di.hs;
        catch ME
            registrar_mensaje(sprintf('ERROR al importar: %s', ME.message)); return;
        end

        n_imp = 0;
        for k = 1:numel(hs_imp)
            c = hs_imp{k};
            app.contador_corridas = app.contador_corridas + 1;
            c.id          = app.contador_corridas;
            c.es_importada = true;
            if ~isfield(c,'historia_f1'),  c.historia_f1  = []; end
            if ~isfield(c,'historia_f2'),  c.historia_f2  = []; end
            if ~isfield(c,'historia_pso'), c.historia_pso = []; end
            if ~isfield(c,'tiempo_total'), c.tiempo_total  = 0; end
            if ~isfield(c,'ejes_a_rotar'), c.ejes_a_rotar  = [1 2]; end
            app.historial_sesion{end+1} = c;
            n_imp = n_imp + 1;
        end

        actualizar_panel_historial();
        registrar_mensaje(sprintf('Importadas %d corridas desde: %s', n_imp, fullfile(p,f)));
        uialert(app.fig, sprintf('%d corridas importadas.\nDoble clic en la lista para visualizarlas.', ...
            n_imp), 'Importación exitosa');
    end

    function exportar_historial(~,~)
        if isempty(app.historial_sesion), registrar_mensaje('Sin corridas.'); return; end
        [f, p] = uiputfile('*.mat','Guardar historial', ruta_historial_sesion);
        if isequal(f,0), return; end
        hs = app.historial_sesion;
        save(fullfile(p,f), 'hs', '-v7.3');
        registrar_mensaje(sprintf('Historial exportado: %s', fullfile(p,f)));
    end

    % ---------------------------------------------------------------- %
    %  4. Exportar PDF
    % ---------------------------------------------------------------- %
    function texto = formatear_vector_resultado(p, campo)
        texto = 'n/d';
        if isfield(p, campo)
            v = p.(campo);
            if isnumeric(v) && numel(v) == 3
                texto = sprintf('[%.2f, %.2f, %.2f]', v(1), v(2), v(3));
            end
        end
    end
    function valor = obtener_campo_numerico_resultado(p, campo)
        valor = NaN;
        if isfield(p, campo) && isnumeric(p.(campo)) && isscalar(p.(campo))
            valor = p.(campo);
        end
    end
    function exportar_pdf(~,~)
        if ~isfield(app,'parametros_optimizacion_final') || isempty(app.parametros_optimizacion_final)
            registrar_mensaje('ERROR: sin resultados. Ejecuta la optimización primero.'); return;
        end
        insertar_separacion_log();
        registrar_mensaje('Generando PDF...');

        import mlreportgen.dom.*
        import mlreportgen.report.*

        p = app.parametros_optimizacion_final;
        [rx,ry,rz] = mapear_ejes(p.ejes_a_rotar, p.posicion(4), p.posicion(5));

        tok = regexp(p.potencia, '(\d+)', 'tokens');
        Potencia = NaN;
        if ~isempty(tok), Potencia = str2double(tok{1}{1}); end

        datos_tabla = {
            'Coordenada X (mm)',     p.posicion(1);
            'Coordenada Y (mm)',     p.posicion(2);
            'Coordenada Z (mm)',     p.posicion(3);
            'Ángulo X (deg)',        rad2deg(rx);
            'Ángulo Y (deg)',        rad2deg(ry);
            'Ángulo Z (deg)',        rad2deg(rz);
            'Potencia (W)',          Potencia;
            'Distribución Térmica',  p.distribucion_termica;
            'Número de Antenas',     p.numero_antenas;
            'Tipo de Antenas',       p.tipo_antena;
            'Caso',                  p.caso;
            'Ejes rotación',         sprintf('[%d, %d]', p.ejes_a_rotar(1), p.ejes_a_rotar(2));
            'Antena 1 local (mm)',   formatear_vector_resultado(p, 'posicion_antena_1_local');
            'Antena 1 global (mm)',  formatear_vector_resultado(p, 'posicion_antena_1_global');
            'Profundidad base antena (mm)', obtener_campo_numerico_resultado(p, 'profundidad_base_antena_mm');
            'Profundidad STL (mm)',  obtener_campo_numerico_resultado(p, 'profundidad_stl_mm');
            'Profundidad total (mm)', obtener_campo_numerico_resultado(p, 'profundidad_total_mm');
            '% dentro tumor',        p.porcentaje_interior;
            '% fuera gota',          p.porcentaje_exterior;
            'V inter (mm³)',         p.volumen_interior;
            'V gota (mm³)',          p.volumen_distribucion_termica;
            'V tumor (mm³)',         p.volumen_tumor;
            'V exterior (mm^3)',     p.volumen_exterior;
            'Fitness fino',          p.fitness_fino;
            'Fitness PSO',           p.fitness_pso};

        reporte  = Report('Resultado_Tumor','pdf');
        capitulo = Chapter('Title','Resultados de la Optimización');
        add(capitulo, Table(datos_tabla));
        add(reporte, capitulo);
        close(reporte);
        rptview(reporte);
        registrar_mensaje('PDF exportado.');
    end

    % ---------------------------------------------------------------- %
    %  graficar_escena
    % ---------------------------------------------------------------- %
    function graficar_escena(vertices_tumor, caras_tumor, volumen_distribucion, ...
                             caras_distribucion, grafico, titulo, M_global)
        if nargin < 7, M_global = eye(3); end

        limpiar_eje_3d(titulo);
        patch(app.ax, 'Faces',caras_tumor, 'Vertices',vertices_tumor, ...
            'FaceColor',[1 0 0], 'EdgeColor','none', 'FaceAlpha',0.3, 'DisplayName','Tumor');
        hold(app.ax, 'on');

        if ~isempty(volumen_distribucion) && ~isempty(caras_distribucion)
            patch(app.ax, 'Faces',caras_distribucion, 'Vertices',volumen_distribucion, ...
                'FaceColor',[0 0 1], 'EdgeColor','none', 'FaceAlpha',0.6, ...
                'DisplayName','Gota térmica');
        end

        [puntas_locales, M_opt] = transformacion_rotacional( ...
            grafico.coordenadas_antenas, grafico.posicion, grafico.ejes_a_rotar);
        dir_antena = M_global * M_opt * [0;0;1];

        for k = 1:size(puntas_locales,1)
            punta      = M_global * puntas_locales(k,:)';
            fin_antena = punta + 80 * dir_antena;
            if k == 1
                line(app.ax, ...
                    [punta(1) fin_antena(1)], [punta(2) fin_antena(2)], [punta(3) fin_antena(3)], ...
                    'Color','y', 'LineWidth',2, 'DisplayName','Antenas');
                plot3(app.ax, punta(1), punta(2), punta(3), ...
                    'ro', 'MarkerSize',9, 'MarkerFaceColor','r', ...
                    'DisplayName','Punta antena 1');
            else
                line(app.ax, ...
                    [punta(1) fin_antena(1)], [punta(2) fin_antena(2)], [punta(3) fin_antena(3)], ...
                    'Color','y', 'LineWidth',2, 'HandleVisibility','off');
                plot3(app.ax, punta(1), punta(2), punta(3), ...
                    'yo', 'MarkerSize',7, 'MarkerFaceColor','y', 'HandleVisibility','off');
            end
        end

        if isfield(grafico,'vertices_musculo') && ~isempty(grafico.vertices_musculo) && isfield(grafico,'caras_musculo') && ~isempty(grafico.caras_musculo)
            patch(app.ax, 'Faces',grafico.caras_musculo, 'Vertices',grafico.vertices_musculo, ...
                'FaceColor',[0 1 0], 'EdgeColor','none', 'FaceAlpha',0.3, 'DisplayName','Músculo');
        end
        if isfield(grafico,'vertices_hueso') && ~isempty(grafico.vertices_hueso) && isfield(grafico,'caras_hueso') && ~isempty(grafico.caras_hueso)
            patch(app.ax, 'Faces',grafico.caras_hueso, 'Vertices',grafico.vertices_hueso, ...
                'FaceColor',[0 1 1], 'EdgeColor','none', 'FaceAlpha',0.3, 'DisplayName','Hueso');
        end

        camlight(app.ax); lighting(app.ax,'gouraud');
        view(app.ax,3); axis(app.ax,'equal');
        legend(app.ax, 'Location','best');
    end

    function mapa_antenas = cargar_mapa_antenas_local()
        claves = {'1ant','2ant','3ant','4ant'};
        valores = { ...
            [0 0 0], ...
            [-10 0 0; 10 0 0], ...
            [0 11.55 0; 10 -5.77 0; -10 -5.77 0], ...
            [-10 -10 0; 10 -10 0; -10 10 0; 10 10 0]};
        mapa_antenas = containers.Map(claves, valores);
        registrar_mensaje(['Coordenadas de antenas hardcodeadas: XY nominal del arreglo y z local=0. ' ...
            'La profundidad fisica base se reporta por separado como 26.4 mm.']);
    end

    function profundidad_stl_mm = calcular_profundidad_stl(posicion_antena_global)
        if isfield(app,'z_acceso') && ~isempty(app.z_acceso) && ...
                isnumeric(posicion_antena_global) && numel(posicion_antena_global) >= 3
            profundidad_stl_mm = max(0, app.z_acceso - posicion_antena_global(3));
        else
            profundidad_stl_mm = 0;
        end
    end

    function confirmar_cierre(src,~)
        sel = uiconfirm(src, '¿Cerrar la aplicación?', 'Confirmar', ...
            'Options',{'Sí','No'}, 'DefaultOption',2, 'CancelOption',2);
        if strcmp(sel,'Sí'), delete(src); end
    end

%% ================================================================== %%
%%  FUNCIÓN FITNESS
%% ================================================================== %%

    function [valor_fitness, metricas] = fitness_unico(posicion, grid, mask, datos, campo, ...
            resolucion_actual, ejes_a_rotar, centro_tumor, vol_tumor_ref, criterio_fitness)

        [vol_interior, vol_dist, vol_exterior] = calcular_interseccion_volumen( ...
            grid, mask, datos, campo, resolucion_actual, posicion, ejes_a_rotar);

        metricas = calcular_metricas_fitness(vol_interior, vol_dist, vol_exterior, ...
            vol_tumor_ref, posicion, ejes_a_rotar, centro_tumor, criterio_fitness);
        valor_fitness = metricas.fitness;
    end

    function metricas = calcular_metricas_fitness(vol_interior, vol_dist, vol_exterior, ...
            vol_tumor_ref, posicion, ejes_a_rotar, centro_tumor, criterio_fitness)

        if vol_dist <= 0 || ~isfinite(vol_dist)
            metricas = struct( ...
                'fitness', 1e6, ...
                'cobertura', 0, ...
                'fuga', 1, ...
                'dist_centro_norm', 1, ...
                'profundidad_norm', 1, ...
                'penalizacion_fuga', criterio_fitness.peso_fuga, ...
                'penalizacion_centroide', criterio_fitness.peso_centroide, ...
                'penalizacion_profundidad', criterio_fitness.peso_profundidad);
            return;
        end

        cobertura = vol_interior / max(vol_tumor_ref, eps);
        fuga      = vol_exterior / max(vol_dist, eps);

        centro_gota = transformacion_rotacional([0 0 0], posicion, ejes_a_rotar);
        escala      = max(criterio_fitness.escala_espacial, eps);
        dist_centro_norm = norm(centro_gota - centro_tumor) / escala;

        profundidad_norm = 0;
        if isfield(app,'z_acceso') && ~isempty(app.z_acceso)
            profundidad = max(0, app.z_acceso - centro_gota(3));
            profundidad_norm = profundidad / escala;
        end

        penalizacion_fuga        = criterio_fitness.peso_fuga        * fuga;
        penalizacion_centroide   = criterio_fitness.peso_centroide   * dist_centro_norm^2;
        penalizacion_profundidad = criterio_fitness.peso_profundidad * profundidad_norm^2;

        fitness = criterio_fitness.escala_fitness * ( ...
            -cobertura + penalizacion_fuga + penalizacion_centroide + penalizacion_profundidad);

        metricas = struct( ...
            'fitness', fitness, ...
            'cobertura', cobertura, ...
            'fuga', fuga, ...
            'dist_centro_norm', dist_centro_norm, ...
            'profundidad_norm', profundidad_norm, ...
            'penalizacion_fuga', penalizacion_fuga, ...
            'penalizacion_centroide', penalizacion_centroide, ...
            'penalizacion_profundidad', penalizacion_profundidad);
    end

%% ================================================================== %%
%%  FUNCIONES AUXILIARES MATEMATICAS
%% ================================================================== %%
    function [puntos_salida, M_rot] = transformacion_rotacional(puntos_entrada, posicion, ejes_a_rotar)
        [rx, ry, rz] = mapear_ejes(ejes_a_rotar, posicion(4), posicion(5));
        M_rot        = hacer_matriz_rotacion(rx, ry, rz);
        puntos_salida = (M_rot * puntos_entrada')' + [posicion(1) posicion(2) posicion(3)];
    end

    function [vol_interior, vol_dist, vol_exterior] = ...
            calcular_interseccion_volumen(grid, mask, datos, metodo_voxel, ...
            resolucion_actual, posicion, ejes_a_rotar)

        if ~isfield(datos,'esquinas_locales')
            ex = [datos.gridX(1) datos.gridX(end)];
            ey = [datos.gridY(1) datos.gridY(end)];
            ez = [datos.gridZ(1) datos.gridZ(end)];
            [Xe, Ye, Ze] = meshgrid(ex, ey, ez);
            datos.esquinas_locales = [Xe(:), Ye(:), Ze(:)];
        end

        [esquinas_globales, M_rot] = transformacion_rotacional( ...
            datos.esquinas_locales, posicion, ejes_a_rotar);
        minG = min(esquinas_globales);
        maxG = max(esquinas_globales);

        idx = grid(:,1) >= minG(1) & grid(:,1) <= maxG(1) & ...
              grid(:,2) >= minG(2) & grid(:,2) <= maxG(2) & ...
              grid(:,3) >= minG(3) & grid(:,3) <= maxG(3);
        if ~any(idx)
            vol_interior = 0; vol_dist = 0; vol_exterior = 0; return;
        end

        grid_f = grid(idx,:);
        coords_locales = (M_rot' * (grid_f' - [posicion(1);posicion(2);posicion(3)]))';

        if strcmp(metodo_voxel,'mascara')
            d = interp3(datos.gridX, datos.gridY, datos.gridZ, double(datos.mascara), ...
                coords_locales(:,1), coords_locales(:,2), coords_locales(:,3), 'nearest', 0);
            dentro_gota = d > 0.5;
        else
            d = interp3(datos.gridX, datos.gridY, datos.gridZ, datos.(metodo_voxel), ...
                coords_locales(:,1), coords_locales(:,2), coords_locales(:,3), 'linear', 1e6);
            dentro_gota = d < 0;
        end

        vol_dist     = sum(dentro_gota) * resolucion_actual^3;
        vol_interior = sum(dentro_gota & mask(idx)) * resolucion_actual^3;
        vol_exterior = vol_dist - vol_interior;
    end

    function M = hacer_matriz_rotacion(rx, ry, rz)
        Rx = [1 0 0; 0 cos(rx) -sin(rx); 0 sin(rx) cos(rx)];
        Ry = [cos(ry) 0 sin(ry); 0 1 0; -sin(ry) 0 cos(ry)];
        Rz = [cos(rz) -sin(rz) 0; sin(rz) cos(rz) 0; 0 0 1];
        M  = Rz * Ry * Rx;
    end

    function [V, F] = lector_stl(filename)
        fid = fopen(filename,'rb');
        fseek(fid, 80,'bof');
        numFaces = fread(fid, 1,'uint32');
        Vraw = zeros(numFaces*3, 3);
        for i = 1:numFaces
            fread(fid, 3,'float32');
            v1 = fread(fid, 3,'float32')';
            v2 = fread(fid, 3,'float32')';
            v3 = fread(fid, 3,'float32')';
            fread(fid, 1,'uint16');
            k = (i-1)*3;
            Vraw(k+1,:) = v1; Vraw(k+2,:) = v2; Vraw(k+3,:) = v3;
        end
        fclose(fid);
        [V, ~, ic] = unique(Vraw,'rows','stable');
        F = reshape(ic, 3, numFaces)';
    end

    function [rx, ry, rz] = mapear_ejes(ejes_a_rotar, r1, r2)
        rx = 0; ry = 0; rz = 0;
        angulos = [r1, r2];
        for k = 1:2
            switch ejes_a_rotar(k)
                case 1, rx = angulos(k);
                case 2, ry = angulos(k);
                otherwise, rz = angulos(k);
            end
        end
    end

    function R_cal = calcular_rotacion_calibracion(N)
        N = N(:) / norm(N);
        Z = [0; 0; 1];
        eje    = cross(N, Z);
        seno   = norm(eje);
        coseno = dot(N, Z);
        if seno < 1e-6
            if coseno > 0, R_cal = eye(3);
            else,          R_cal = diag([1 -1 -1]);
            end
            return;
        end
        eje    = eje / seno;
        angulo = atan2(seno, coseno);
        K = [   0      -eje(3)  eje(2); ...
              eje(3)    0      -eje(1); ...
             -eje(2)   eje(1)   0    ];
        R_cal = eye(3) + sin(angulo)*K + (1 - cos(angulo))*(K*K);
    end

end

function metadatos = crear_metadatos_archivo(n)
plantilla = struct( ...
    'es_valido', false, ...
    'tipo', '', ...
    'arreglo', '', ...
    'caso', '', ...
    'potencia', '', ...
    'fecha', '', ...
    'tiempo', '', ...
    'prueba', '', ...
    'zonas', '', ...
    'resolucion', NaN, ...
    'resolucion_texto', '', ...
    'origen', 'original', ...
    'ruta_relativa', '', ...
    'raiz_mat', '', ...
    'raiz_stl', '');
metadatos = repmat(plantilla, n, 1);
end

function resolucion = extraer_resolucion_nombre_mat(nombre_archivo, metodo_voxel)
patron = ['_' regexptranslate('escape', metodo_voxel) '_res([0-9]+(?:\.[0-9]+)?)$'];
token = regexp(nombre_archivo, patron, 'tokens', 'once');
if isempty(token)
    resolucion = NaN;
else
    resolucion = str2double(token{1});
end
end

function filtros = crear_filtros_vacios()
filtros = struct( ...
    'tipos', {{}}, ...
    'antenas', {{}}, ...
    'casos', {{}}, ...
    'potencias', {{}}, ...
    'fechas', {{}}, ...
    'tiempos', {{}}, ...
    'pruebas', {{}}, ...
    'zonas', {{}}, ...
    'origenes', {{}});
end

function valores = valores_filtro_compatibles(metadatos, filtros_activos, campo_excluido)
campos_filtro = {'tipos', 'antenas', 'casos', 'potencias', 'fechas', ...
    'tiempos', 'pruebas', 'zonas', 'origenes'};
campos_metadata = {'tipo', 'arreglo', 'caso', 'potencia', 'fecha', ...
    'tiempo', 'prueba', 'zonas', 'origen'};
idx_excluido = find(strcmp(campos_filtro, campo_excluido), 1);
if isempty(metadatos) || isempty(idx_excluido)
    valores = {};
    return;
end

mask = [metadatos.es_valido];
for idx_campo = 1:numel(campos_filtro)
    seleccion = filtros_activos.(campos_filtro{idx_campo});
    if idx_campo == idx_excluido || isempty(seleccion)
        continue;
    end
    datos = {metadatos.(campos_metadata{idx_campo})};
    mask = mask & ismember(lower(string(datos)), lower(string(seleccion)));
end
valores = unique({metadatos(mask).(campos_metadata{idx_excluido})}, 'stable');
valores = valores(~cellfun('isempty', valores));
valores = ordenar_valores_filtro(valores);
end

function valores = agregar_valor_filtro(valores, valor)
valor = char(valor);
if isempty(valor)
    return;
end
if ~any(strcmp(valores, valor))
    valores{end+1} = valor;
end
end

function valores = ordenar_valores_filtro(valores)
if isempty(valores)
    return;
end

valores = valores(:)';
numeros = nan(size(valores));
for idx_valor = 1:numel(valores)
    token = regexp(valores{idx_valor}, '[-+]?\d+\.?\d*', 'match', 'once');
    if ~isempty(token)
        numeros(idx_valor) = str2double(token);
    end
end

if all(~isnan(numeros))
    [~, orden] = sort(numeros);
else
    [~, orden] = sort(lower(string(valores)));
end
valores = valores(orden);
end

function pasa = coincide_filtro_metadata(valor, filtros_activos)
if isempty(filtros_activos)
    pasa = true;
else
    pasa = any(strcmpi(char(valor), filtros_activos));
end
end

function tf = es_placeholder_filtro(valor)
valor = char(valor);
tf = startsWith(valor, '(sin filtros') || strcmp(valor, '(sin dataset)');
end
