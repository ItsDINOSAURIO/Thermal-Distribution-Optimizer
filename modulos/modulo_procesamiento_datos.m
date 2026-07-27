function modulo_procesamiento_datos(varargin)
%MODULO_PROCESAMIENTO_DATOS App unica para procesamientos de datasets.

    bootstrap_modulo();
    if nargin >= 1 && (ischar(varargin{1}) || (isstring(varargin{1}) && isscalar(varargin{1})))
        switch lower(char(varargin{1}))
            case 'selftest_volumen'
                ejecutar_correlador_volumen_integrado('selftest_limite_volumen');
                return;
            case 'selftest_metadata'
                ejecutar_correlador_volumen_integrado('selftest_metadata_corr');
                ejecutar_exportador_correcciones_integrado('selftest_metadata');
                ejecutar_exportador_mat_integrado('selftest_metadata_paths');
                ejecutar_preprocesador_stl_integrado('selftest_metadata_paths');
                ejecutar_selftest_carga_correcciones_filtrada();
                return;
        end
    end
    theme = tesis_auxiliares('tema_ui');
    paths = tesis_auxiliares('dataset_paths');
    dataset_default = tesis_auxiliares('dataset_masivo_reciente', paths);
    if hay_mats_particionados(paths.datasets_masivos_por_metadata)
        dataset_default = paths.datasets_masivos_por_metadata;
    end
    mostrar_temporal_avanzado = false; % Source-only: reactiva Nt fino / N extrap si vuelve el remuestreo temporal.
    dataset_stl_default = dataset_default;
    state = struct('exp', [], 'sim', [], 'corr', [], 'dataset', [], ...
        'dataset_catalog', [], 'dataset_catalog_filtrado', [], ...
        'dataset_catalog_indices', [], 'actualizando_filtros_ext', false, ...
        'actualizando_filtros_corr', false, 'actualizando_extrap_ext', false, ...
        'dataset_ruta', '', 'dataset_key', '', 'volumen', [], ...
        'corr_catalog', [], 'corr_catalog_cargado', false, 'corr_ruta', '');

    fig = uifigure('Name', 'Modulo Procesamiento de Datos', ...
        'Position', [55 45 1360 820], 'Color', theme.colors.bg);
    gl = uigridlayout(fig, [3, 1]);
    gl.RowHeight = {68, '1x', 170};
    gl.ColumnWidth = {'1x'};
    gl.Padding = [10 10 10 10]; gl.RowSpacing = 10; gl.ColumnSpacing = 10;
    activar_scroll(gl);

    ribbon = uipanel(gl, 'BorderType', 'none');
    ribbon.Layout.Row = 1; ribbon.Layout.Column = 1;
    tesis_auxiliares('tema_ui', 'card', ribbon);
    gm = uigridlayout(ribbon, [1, 4]);
    gm.RowHeight = {32};
    gm.ColumnWidth = {310, 145, 220, '1x'};
    gm.Padding = [14 8 14 8]; gm.ColumnSpacing = 8;

    % Massive corrections stay in this file for later, but are hidden for now.
    dd = uidropdown(gm, 'Items', {'STL/TXT desde MAT', 'Voxelizar STL', 'Correlacion', 'Extrapolacion 4D'}, ...
        'ItemsData', {'STL/TXT desde MAT', 'Voxelizar STL', 'Correlacion', 'Extrapolacion 4D'}, ...
        'Value', 'STL/TXT desde MAT', 'ValueChangedFcn', @(~,~) mostrar());
    dd.Layout.Row = 1; dd.Layout.Column = 1;
    tesis_auxiliares('tema_ui', 'dropdown', dd);
    b_data = uibutton(gm, 'Text', 'Abrir datasets', 'ButtonPushedFcn', @(~,~) abrir(paths.root));
    b_data.Layout.Row = 1; b_data.Layout.Column = 2;
    tesis_auxiliares('tema_ui', 'button', b_data, 'secondary');
    b_root = uibutton(gm, 'Text', 'Abrir carpeta del proyecto', 'ButtonPushedFcn', @(~,~) abrir(tesis_auxiliares('project_root')));
    b_root.Layout.Row = 1; b_root.Layout.Column = 3;
    tesis_auxiliares('tema_ui', 'button', b_root, 'secondary');
    estado = uilabel(gm, 'Text', 'Listo.'); estado.Layout.Row = 1; estado.Layout.Column = 4;
    tesis_auxiliares('tema_ui', 'label', estado, 'status');

    work = uipanel(gl, 'Title', 'Herramientas internas'); work.Layout.Row = 2; work.Layout.Column = 1;
    tesis_auxiliares('tema_ui', 'panel', work); activar_scroll(work);
    gw = uigridlayout(work, [1, 1]); gw.Padding = [8 8 8 8]; activar_scroll(gw);
    p_stl = panel(gw, 'MAT masivo -> STL/TXT');
    p_mat = panel(gw, 'STL -> MAT voxelizado');
    p_corr = panel(gw, 'Correlacion termica');
    p_ext = panel(gw, 'Extrapolacion 4D y correccion termica');
    p_exp = panel(gw, 'Exportador masivo de correcciones');
    c_stl = ui_stl(p_stl);
    c_mat = ui_mat(p_mat);
    c_corr = ui_corr(p_corr);
    c_ext = ui_extrap(p_ext);
    c_exp = ui_export(p_exp);
    plog = uipanel(gl, 'Title', 'Registro de eventos'); plog.Layout.Row = 3; plog.Layout.Column = 1;
    tesis_auxiliares('tema_ui', 'panel', plog); activar_scroll(plog);
    glog = uigridlayout(plog, [1, 1]); glog.Padding = [6 6 6 6]; activar_scroll(glog);
    logbox = uitextarea(glog, 'Editable', 'off', 'Value', {'Listo.'}); tesis_auxiliares('tema_ui', 'textarea', logbox);
    tesis_auxiliares('tema_ui', 'apply', fig); mostrar(); logmsg('Modulo de procesamiento iniciado.');
    precargar_ext_catalogo_si_hay();

    function p = panel(parent, titulo)
        p = uipanel(parent, 'Title', titulo); p.Layout.Row = 1; p.Layout.Column = 1;
        tesis_auxiliares('tema_ui', 'panel', p);
        activar_scroll(p);
    end

    function c = ui_stl(p)
        g = crear_grid_control(p, 10);
        c.fuente = drop(g, 1, 'Fuente', {'Simulados', 'Corregidos'});
        c.mat = row_path(g, 2, 'MAT/catalogo', dataset_stl_default, 'catalogo');
        c.out = row_path(g, 3, 'Salida STL/TXT', paths.distribuciones_stl, 'dir');
        c.tmin = num(g, 4, 'T min C', 55); c.tmax0 = num(g, 5, 'T max caso0', 500);
        c.tmax = num(g, 6, 'T max casos>0', 120); c.alpha = num(g, 7, 'Alpha radius', 0);
        c.smooth = num(g, 8, 'Suavizado', 4);
        b = uibutton(g, 'Text', 'Exportar STL/TXT', 'ButtonPushedFcn', @(~,~) run_stl());
        b.Layout.Row = 9; b.Layout.Column = [1 2]; tesis_auxiliares('tema_ui', 'button', b, 'success');
        c.fuente.ValueChangedFcn = @(~,~) aplicar_fuente_stl();
    end

    function c = ui_mat(p)
        g = crear_grid_control(p, 8);
        c.fuente = drop(g, 1, 'Fuente', {'Simulados', 'Corregidos'});
        c.stl = row_path(g, 2, 'Carpeta STL', paths.distribuciones_stl, 'dir');
        c.out = row_path(g, 3, 'Salida MAT', paths.distribuciones_mat, 'dir');
        c.res = num(g, 4, 'Resolucion mm', 0.5);
        lab = uilabel(g, 'Text', 'Tipo'); lab.Layout.Row = 5; lab.Layout.Column = 1;
        c.tipo = uidropdown(g, 'Items', {'sdf', 'mascara', 'tsdf'}, 'Value', 'sdf'); c.tipo.Layout.Row = 5; c.tipo.Layout.Column = 2;
        tesis_auxiliares('tema_ui', 'dropdown', c.tipo);
        b = uibutton(g, 'Text', 'Voxelizar STL a MAT', 'ButtonPushedFcn', @(~,~) run_mat());
        b.Layout.Row = 6; b.Layout.Column = [1 2]; tesis_auxiliares('tema_ui', 'button', b, 'success');
        c.fuente.ValueChangedFcn = @(~,~) aplicar_fuente_mat();
    end

    function c = ui_corr(p)
        gp = uigridlayout(p, [1, 2]);
        gp.ColumnWidth = {390, '1x'};
        gp.Padding = [8 8 8 8];
        activar_scroll(gp);

        ctrl = uipanel(gp, 'Title', 'Configuracion de correlacion');
        ctrl.Layout.Column = 1;
        tesis_auxiliares('tema_ui', 'panel', ctrl);
        activar_scroll(ctrl);
        g = crear_grid_control(ctrl, 13);
        c.exp = row_path(g, 1, 'Experimental', paths.experimentales, {'*.csv;*.xlsx;*.xls', 'Datos'}, @cargar_corr_exp);
        c.sim = row_path(g, 2, 'TXT sondas', paths.distribuciones_stl, '*.txt', @cargar_corr_sim);
        c.sonda = drop(g, 3, 'Sonda', {'P1'});
        c.exp_i = num(g, 4, 'Exp inicio min', 0); c.exp_f = num(g, 5, 'Exp fin min', 0);
        c.sim_i = num(g, 6, 'Sim inicio min', 0); c.sim_f = num(g, 7, 'Sim fin min', 0);
        c.grado = num(g, 8, 'Grado', 6); c.n = num(g, 9, 'N comun', 1000);
        gb = uigridlayout(g, [1, 2]); gb.Layout.Row = 10; gb.Layout.Column = [1 3];
        gb.RowHeight = {28}; gb.ColumnWidth = {'1x', '1x'}; gb.Padding = [0 0 0 0]; gb.ColumnSpacing = 6;
        b1 = uibutton(gb, 'Text', 'Calcular correccion', 'ButtonPushedFcn', @(~,~) run_corr());
        b1.Layout.Row = 1; b1.Layout.Column = 1; tesis_auxiliares('tema_ui', 'button', b1, 'success');
        b2 = uibutton(gb, 'Text', 'Guardar .mat', 'ButtonPushedFcn', @(~,~) run_save_corr());
        b2.Layout.Row = 1; b2.Layout.Column = 2; tesis_auxiliares('tema_ui', 'button', b2, 'secondary');
        c.sonda.ValueChangedFcn = @(~,~) actualizar_corr_reactiva();
        c.exp_i.ValueChangedFcn = @(~,~) actualizar_corr_reactiva();
        c.exp_f.ValueChangedFcn = @(~,~) actualizar_corr_reactiva();
        c.sim_i.ValueChangedFcn = @(~,~) actualizar_corr_reactiva();
        c.sim_f.ValueChangedFcn = @(~,~) actualizar_corr_reactiva();
        c.grado.ValueChangedFcn = @(~,~) actualizar_corr_reactiva();
        c.n.ValueChangedFcn = @(~,~) actualizar_corr_reactiva();

        plots = uipanel(gp, 'Title', 'Graficas de correlacion');
        plots.Layout.Column = 2;
        tesis_auxiliares('tema_ui', 'panel', plots);
        activar_scroll(plots);
        g2 = uigridlayout(plots, [2, 1]);
        g2.RowHeight = {'1.45x', '1x'};
        g2.Padding = [8 8 8 8];
        activar_scroll(g2);
        c.ax1 = uiaxes(g2); c.ax1.Layout.Row = 1; c.ax1.Layout.Column = 1; title(c.ax1, 'Correlacion simulacion vs experimento');
        c.ax2 = uiaxes(g2); c.ax2.Layout.Row = 2; c.ax2.Layout.Column = 1; title(c.ax2, 'Funcion de correccion');
    end

    function c = ui_extrap(p)
        gp = uigridlayout(p, [1, 2]);
        gp.ColumnWidth = {405, '1x'};
        gp.Padding = [8 8 8 8];
        activar_scroll(gp);

        ctrl = uipanel(gp, 'Title', 'Configuracion de extrapolacion 4D');
        ctrl.Layout.Column = 1;
        tesis_auxiliares('tema_ui', 'panel', ctrl);
        activar_scroll(ctrl);
        n_filas_ext = 24 + 2 * double(mostrar_temporal_avanzado);
        g = crear_grid_control(ctrl, n_filas_ext);
        c.dataset = row_path(g, 1, 'Dataset/catalogo', dataset_default, 'catalogo', @cargar_ext_dataset);
        c.tipo = drop(g, 2, 'Tipo', {'Todos'}); c.tipo.ValueChangedFcn = @(~,~) aplicar_filtros_ext();
        c.antena = drop(g, 3, 'Antenas', {'Todos'}); c.antena.ValueChangedFcn = @(~,~) aplicar_filtros_ext();
        c.caso = drop(g, 4, 'Caso', {'Todos'}); c.caso.ValueChangedFcn = @(~,~) aplicar_filtros_ext();
        c.potencia = drop(g, 5, 'Potencia', {'Todos'}); c.potencia.ValueChangedFcn = @(~,~) aplicar_filtros_ext();
        c.corr_fecha = drop(g, 6, 'Fecha adquisicion', {'Todos'});
        c.corr_tiempo = drop(g, 7, 'Tiempo ejecucion', {'Todos'});
        c.corr_prueba = drop(g, 8, 'Numero de prueba', {'Todos'});
        c.corr_zona = drop(g, 9, 'Zona experimental', {'Todos'});
        c.corr_fecha.ValueChangedFcn = @(~,~) aplicar_filtros_correccion_ext();
        c.corr_tiempo.ValueChangedFcn = @(~,~) aplicar_filtros_correccion_ext();
        c.corr_prueba.ValueChangedFcn = @(~,~) aplicar_filtros_correccion_ext();
        c.corr_zona.ValueChangedFcn = @(~,~) aplicar_filtros_correccion_ext();
        c.modelo = drop(g, 10, 'Modelo', {'(sin dataset)'}); c.modelo.ValueChangedFcn = @(~,~) modelo_ext_cambiado();
        c.ds = drop(g, 11, 'Dataset', {'(sin dataset)'});
        c.nxyz = num(g, 12, 'Nx=Ny=Nz', 45);
        fila = 13;
        if mostrar_temporal_avanzado
            c.nt = num(g, fila, 'Nt fino', 200);
            fila = fila + 1;
        end
        c.tabl = num(g, fila, 'T ablacion C', 60);
        fila = fila + 1;
        c.t_extra = num(g, fila, 'T extra max min', 0);
        fila = fila + 1;
        if mostrar_temporal_avanzado
            c.nt_ext = num(g, fila, 'Nt extrap', 80);
            fila = fila + 1;
        end
        lab = uilabel(g, 'Text', 'Metodo'); lab.Layout.Row = fila; lab.Layout.Column = 1;
        c.estrategia = uidropdown(g, 'Items', {'PCA temporal', 'LOWESS', 'Gradiente local'}, 'Value', 'PCA temporal');
        c.estrategia.Layout.Row = fila; c.estrategia.Layout.Column = [2 3]; tesis_auxiliares('tema_ui', 'dropdown', c.estrategia);
        fila = fila + 1;
        c.out = row_path(g, fila, 'Salida dataset', paths.datasets_corregidos_por_metadata, 'dir');
        fila = fila + 1;
        c.usar_corr = uicheckbox(g, 'Text', 'Aplicar correccion termica', 'Value', true); c.usar_corr.Layout.Row = fila; c.usar_corr.Layout.Column = [1 3];
        fila = fila + 1;
        c.offset = uicheckbox(g, 'Text', 'Aplicar offset basal', 'Value', true); c.offset.Layout.Row = fila; c.offset.Layout.Column = [1 3];
        fila = fila + 1;
        c.intensidad = num(g, fila, 'Intensidad 0-1', 1);
        fila = fila + 1;
        c.vista = drop(g, fila, 'Vista', {'Analisis 2D', 'Campo termico 4D'});
        fila = fila + 1;
        c.tiempo = drop(g, fila, 'Tiempo 4D', {'(sin volumen)'});
        c.tiempo.Enable = 'off';
        fila = fila + 1;
        gb = uigridlayout(g, [2, 2]); gb.Layout.Row = [fila fila + 1]; gb.Layout.Column = [1 3];
        gb.RowHeight = {28, 28}; gb.ColumnWidth = {'1x', '1x'}; gb.Padding = [0 0 0 0]; gb.RowSpacing = 6; gb.ColumnSpacing = 6;
        b1 = uibutton(gb, 'Text', 'Construir / actualizar volumen 4D', 'ButtonPushedFcn', @(~,~) run_vol());
        b1.Layout.Row = 1; b1.Layout.Column = [1 2]; tesis_auxiliares('tema_ui', 'button', b1, 'success');
        c.build = b1;
        b2 = uibutton(gb, 'Text', 'Exportar dataset corregido', 'ButtonPushedFcn', @(~,~) run_export_vol());
        b2.Layout.Row = 2; b2.Layout.Column = 1; tesis_auxiliares('tema_ui', 'button', b2, 'secondary');
        b3 = uibutton(gb, 'Text', 'Abrir salida', 'ButtonPushedFcn', @(~,~) abrir(c.out.Value));
        b3.Layout.Row = 2; b3.Layout.Column = 2; tesis_auxiliares('tema_ui', 'button', b3, 'secondary');

        plots = uipanel(gp, 'Title', 'Analisis de extrapolacion');
        plots.Layout.Column = 2;
        tesis_auxiliares('tema_ui', 'panel', plots);
        activar_scroll(plots);
        gviews = uigridlayout(plots, [1, 1]);
        gviews.Padding = [0 0 0 0];
        gviews.RowSpacing = 0; gviews.ColumnSpacing = 0;
        c.panel_2d = uipanel(gviews);
        c.panel_2d.Layout.Row = 1; c.panel_2d.Layout.Column = 1;
        tesis_auxiliares('tema_ui', 'panel', c.panel_2d);
        c.panel_termico = uipanel(gviews);
        c.panel_termico.Layout.Row = 1; c.panel_termico.Layout.Column = 1;
        c.panel_termico.Visible = 'off';
        tesis_auxiliares('tema_ui', 'panel', c.panel_termico);

        g2 = uigridlayout(c.panel_2d, [2, 2]);
        g2.Padding = [8 8 8 8];
        activar_scroll(g2);
        c.ax_vol = uiaxes(g2); c.ax_vol.Layout.Row = 1; c.ax_vol.Layout.Column = 1; title(c.ax_vol, 'Volumen seleccionado');
        c.ax_methods = uiaxes(g2); c.ax_methods.Layout.Row = 1; c.ax_methods.Layout.Column = 2; title(c.ax_methods, 'Comparacion de metodos');
        c.ax_sigma = uiaxes(g2); c.ax_sigma.Layout.Row = 2; c.ax_sigma.Layout.Column = 1; title(c.ax_sigma, 'Incertidumbre / sigma');
        c.ax_factor = uiaxes(g2); c.ax_factor.Layout.Row = 2; c.ax_factor.Layout.Column = 2; title(c.ax_factor, 'Factor de correccion');
        gt = uigridlayout(c.panel_termico, [1, 2]);
        gt.Padding = [8 8 8 8]; gt.ColumnWidth = {'1x', '1x'};
        gt.RowSpacing = 8; gt.ColumnSpacing = 8;
        gplanes = uigridlayout(gt, [2, 2]);
        gplanes.Layout.Row = 1; gplanes.Layout.Column = 1;
        gplanes.Padding = [0 0 0 0]; gplanes.RowSpacing = 8; gplanes.ColumnSpacing = 8;
        c.ax_xy = uiaxes(gplanes); c.ax_xy.Layout.Row = 1; c.ax_xy.Layout.Column = 1; title(c.ax_xy, 'Plano XY');
        c.ax_xz = uiaxes(gplanes); c.ax_xz.Layout.Row = 1; c.ax_xz.Layout.Column = 2; title(c.ax_xz, 'Plano XZ');
        c.ax_yz = uiaxes(gplanes); c.ax_yz.Layout.Row = 2; c.ax_yz.Layout.Column = [1 2]; title(c.ax_yz, 'Plano YZ');
        c.ax_3d = uiaxes(gt); c.ax_3d.Layout.Row = 1; c.ax_3d.Layout.Column = 2; title(c.ax_3d, 'Campo 3D');
        c.ds.ValueChangedFcn = @(~,~) invalidar_extrap_reactiva();
        c.nxyz.ValueChangedFcn = @(~,~) invalidar_extrap_reactiva();
        c.tabl.ValueChangedFcn = @(~,~) invalidar_extrap_reactiva();
        c.t_extra.ValueChangedFcn = @(~,~) invalidar_extrap_reactiva();
        if mostrar_temporal_avanzado
            c.nt.ValueChangedFcn = @(~,~) invalidar_extrap_reactiva();
            c.nt_ext.ValueChangedFcn = @(~,~) invalidar_extrap_reactiva();
        end
        c.estrategia.ValueChangedFcn = @(~,~) invalidar_extrap_reactiva();
        c.usar_corr.ValueChangedFcn = @(~,~) actualizar_correccion_ext_reactiva();
        c.offset.ValueChangedFcn = @(~,~) actualizar_correccion_ext_reactiva();
        c.intensidad.ValueChangedFcn = @(~,~) actualizar_correccion_ext_reactiva();
        c.vista.ValueChangedFcn = @(~,~) plot_vol();
        c.tiempo.ValueChangedFcn = @(~,~) plot_vol();
    end

    function c = ui_export(p)
        g = crear_grid_control(p, 10);
        c.dataset = row_path(g, 1, 'Dataset/catalogo', dataset_default, '*.mat');
        c.corr = row_path(g, 2, 'Correlaciones', paths.correlaciones, 'dir');
        c.tmin = num(g, 3, 'T min STL C', 55); c.alpha = num(g, 4, 'Alpha radius', 0);
        c.smooth = num(g, 5, 'Suavizado', 1); c.res = num(g, 6, 'Resolucion MAT', 0.5);
        c.tipo = drop(g, 7, 'Tipo MAT', {'sdf', 'mascara', 'tsdf'});
        c.over = uicheckbox(g, 'Text', 'Sobrescribir existentes', 'Value', false); c.over.Layout.Row = 8; c.over.Layout.Column = [1 2];
        b1 = uibutton(g, 'Text', '1 Dataset corregido', 'ButtonPushedFcn', @(~,~) run_export('dataset'));
        b1.Layout.Row = 9; b1.Layout.Column = 1; tesis_auxiliares('tema_ui', 'button', b1, 'secondary');
        b2 = uibutton(g, 'Text', 'Todo corregido', 'ButtonPushedFcn', @(~,~) run_export('todo'));
        b2.Layout.Row = 9; b2.Layout.Column = 2; tesis_auxiliares('tema_ui', 'button', b2, 'success');
    end

    function g = crear_grid_control(p, n)
        g = uigridlayout(p, [n, 3]); g.RowHeight = repmat({30}, 1, n); g.RowHeight{end} = '1x';
        g.ColumnWidth = {135, '1x', 95}; g.Padding = [12 12 12 12]; g.RowSpacing = 7;
        activar_scroll(g);
    end

    function ed = row_path(g, r, label, val, filter, callback)
        if nargin < 6, callback = []; end
        lab = uilabel(g, 'Text', label); lab.Layout.Row = r; lab.Layout.Column = 1;
        ed = uieditfield(g, 'text', 'Value', char(val)); ed.Layout.Row = r; ed.Layout.Column = 2;
        if ~isempty(callback), ed.ValueChangedFcn = @(~,~) feval(callback, ed); end
        btn = uibutton(g, 'Text', 'Buscar...', 'ButtonPushedFcn', @(~,~) pick(ed, filter, label, callback));
        btn.Layout.Row = r; btn.Layout.Column = 3;
        tesis_auxiliares('tema_ui', 'edit', ed); tesis_auxiliares('tema_ui', 'button', btn, 'secondary');
    end

    function ed = num(g, r, label, val)
        lab = uilabel(g, 'Text', label); lab.Layout.Row = r; lab.Layout.Column = 1;
        ed = uieditfield(g, 'numeric', 'Value', val); ed.Layout.Row = r; ed.Layout.Column = [2 3];
    end

    function ddx = drop(g, r, label, items)
        lab = uilabel(g, 'Text', label); lab.Layout.Row = r; lab.Layout.Column = 1;
        ddx = uidropdown(g, 'Items', items, 'Value', items{1}); ddx.Layout.Row = r; ddx.Layout.Column = [2 3];
        tesis_auxiliares('tema_ui', 'dropdown', ddx);
    end

    function pick(ed, filter, titleText, callback)
        if nargin < 4, callback = []; end
        if ischar(filter) && strcmp(filter, 'catalogo')
            startDir = ed.Value; if isfile(startDir), startDir = fileparts(startDir); end
            if ~isfolder(startDir), startDir = pwd; end
            ruta = uigetdir(startDir, titleText); if isequal(ruta, 0), return; end
            ed.Value = ruta;
        elseif ischar(filter) && strcmp(filter, 'dir')
            ruta = uigetdir(ed.Value, titleText); if isequal(ruta, 0), return; end
            ed.Value = ruta;
        else
            startDir = ed.Value; if ~isfolder(startDir), startDir = fileparts(startDir); end
            if isempty(startDir), startDir = pwd; end
            [a, c] = uigetfile(filter, titleText, startDir); if isequal(a, 0), return; end
            ed.Value = fullfile(c, a);
        end
        logmsg('Seleccionado: %s', ed.Value);
        if ~isempty(callback), feval(callback, ed); end
    end

    function mostrar()
        v = dd.Value;
        p_stl.Visible = vis(strcmp(v, 'STL/TXT desde MAT'));
        p_mat.Visible = vis(strcmp(v, 'Voxelizar STL'));
        p_corr.Visible = vis(strcmp(v, 'Correlacion'));
        p_ext.Visible = vis(strcmp(v, 'Extrapolacion 4D'));
        p_exp.Visible = 'off';
        estado.Text = sprintf('Vista activa: %s', v);
        logmsg('Vista activa: %s', v);
    end

    function s = vis(tf), if tf, s = 'on'; else, s = 'off'; end, end
    function activar_scroll(obj)
        if isprop(obj, 'Scrollable')
            try
                obj.Scrollable = 'on';
            catch
                obj.Scrollable = true;
            end
        end
    end

    function precargar_ext_catalogo_si_hay()
        ruta = normalizar_ruta_ext_catalogo(c_ext.dataset.Value);
        if isfolder(ruta) && isfile(fullfile(ruta, 'Indice_Datasets_Metadata.mat'))
            cargar_ext_dataset(c_ext.dataset);
        end
    end

    function aplicar_fuente_stl()
        if strcmp(c_stl.fuente.Value, 'Corregidos')
            c_stl.mat.Value = paths.datasets_corregidos_por_metadata;
            c_stl.out.Value = paths.distribuciones_stl_corregidas;
        else
            c_stl.mat.Value = dataset_stl_default;
            c_stl.out.Value = paths.distribuciones_stl;
        end
    end

    function aplicar_fuente_mat()
        if strcmp(c_mat.fuente.Value, 'Corregidos')
            c_mat.stl.Value = paths.distribuciones_stl_corregidas;
            c_mat.out.Value = paths.distribuciones_mat_corregidas;
        else
            c_mat.stl.Value = paths.distribuciones_stl;
            c_mat.out.Value = paths.distribuciones_mat;
        end
    end

    function run_stl()
        try
            cfg = struct('ruta_mat_entrada', c_stl.mat.Value, 'carpeta_exportacion', c_stl.out.Value, ...
                'temperatura_min_stl', c_stl.tmin.Value, 'temperatura_max_stl_caso0', c_stl.tmax0.Value, ...
                'temperatura_max_stl_termo', c_stl.tmax.Value, 'radio_alpha', c_stl.alpha.Value, ...
                'iteraciones_suavizado', round(c_stl.smooth.Value), 'mantener_figuras', true, 'logfn', @logmsg);
            sep(); estado.Text = 'Exportando STL/TXT...'; ejecutar_exportador_mat_integrado('run', cfg);
            estado.Text = 'STL/TXT finalizado.'; logmsg('STL/TXT finalizado.');
        catch ME
            fail('STL/TXT', ME);
        end
    end

    function run_mat()
        try
            cfg = struct('carpeta_stl', c_mat.stl.Value, 'carpeta_salida', c_mat.out.Value, ...
                'resolucion', c_mat.res.Value, 'tipo_procesamiento', c_mat.tipo.Value, 'logfn', @logmsg);
            sep(); estado.Text = 'Voxelizando...'; ejecutar_preprocesador_stl_integrado('run', cfg);
            estado.Text = 'Voxelizado finalizado.'; logmsg('Voxelizado finalizado.');
        catch ME
            fail('Voxelizado', ME);
        end
    end

    function run_corr()
        try
            sep(); asegurar_corr_cargada(); actualizar_corr_reactiva();
            if isempty(state.corr), error('No se pudo calcular la correccion con los filtros actuales.'); end
            logmsg('Correccion calculada en memoria. RMSE factor %.4f C.', state.corr.correccion_termica.rmse_factor_C);
            estado.Text = 'Correccion calculada.';
        catch ME
            fail('Correlacion', ME);
        end
    end

    function run_save_corr()
        try
            if isempty(state.corr), run_corr(); end
            if isempty(state.corr), error('No hay correccion valida para guardar.'); end
            if ~isfolder(paths.correlaciones), mkdir(paths.correlaciones); end
            relativa = ejecutar_correlador_volumen_integrado( ...
                'ruta_relativa_correccion', state.corr);
            out = fullfile(paths.correlaciones, relativa);
            out = ejecutar_correlador_volumen_integrado('guardar_correccion', out, state.corr);
            state.corr_catalog = [];
            state.corr_catalog_cargado = false;
            logmsg('Correccion guardada: %s', out); estado.Text = 'Correccion guardada.';
        catch ME
            fail('Guardar correlacion', ME);
        end
    end

    function run_vol()
        try
            construir_volumen_ext(true);
        catch ME
            fail('Extrapolacion 4D', ME);
        end
    end

    function construir_volumen_ext(registrar_separador)
        if nargin < 1
            registrar_separador = false;
        end
        if state.actualizando_extrap_ext
            logmsg('Construccion 4D ya en curso.');
            return;
        end
        state.actualizando_extrap_ext = true;
        limpieza = onCleanup(@() finalizar_construccion_ext());
        set_boton_construccion_ext(false);
        asegurar_ext_dataset_seleccionado();
        if isempty(state.dataset)
            error('Carga un Dataset MAT antes de construir la extrapolacion.');
        end
        corr = [];
        if c_ext.usar_corr.Value
            asegurar_ext_corr_cargada();
            if isempty(state.corr)
                error('Completa los filtros de metadata antes de aplicar la correccion termica.');
            end
            corr = state.corr;
        end
        n = max(5, round(c_ext.nxyz.Value));
        cfg = cfg_volumen(n);
        if registrar_separador
            sep();
        end
        estado.Text = 'Construyendo extrapolacion 4D...';
        drawnow limitrate;
        state.volumen = ejecutar_correlador_volumen_integrado('construir_volumen', cfg, corr, @logmsg);
        plot_vol();
        estado.Text = sprintf('Extrapolacion 4D construida con %s.', cfg.estrategia);
        logmsg('Extrapolacion 4D construida: metodo=%s | modelo=%s | dataset=%s.', ...
            cfg.estrategia, cfg.modelo, cfg.dsName);
    end

    function finalizar_construccion_ext()
        state.actualizando_extrap_ext = false;
        set_boton_construccion_ext(true);
        drawnow limitrate;
    end

    function set_boton_construccion_ext(habilitado)
        if isfield(c_ext, 'build') && isvalid(c_ext.build)
            if habilitado
                c_ext.build.Enable = 'on';
            else
                c_ext.build.Enable = 'off';
            end
        end
    end

    function run_export_vol()
        try
            asegurar_ext_dataset_seleccionado();
            if isempty(state.dataset), error('Carga un Dataset MAT antes de exportar el dataset corregido.'); end
            asegurar_ext_corr_cargada();
            if isempty(state.corr)
                error('Completa los filtros de metadata antes de exportar el dataset corregido.');
            end
            n = max(5, round(c_ext.nxyz.Value));
            cfg = cfg_volumen(n);
            cfg.correccion = state.corr;
            cfg.carpeta_salida_dataset = c_ext.out.Value;
            sep();
            resumen = ejecutar_exportador_correcciones_integrado('selected', cfg);
            if ~isempty(state.volumen)
                state.volumen.archivos.dataset_corregido = resumen.ruta;
                plot_vol();
            end
            estado.Text = 'Dataset corregido exportado.';
            logmsg('Dataset corregido exportado: %s', resumen.ruta);
        catch ME
            fail('Exportar dataset corregido', ME);
        end
    end

    function cfg = cfg_volumen(n)
        modelo = modelo_ext_actual();
        dsName = dataset_ext_actual();
        if isempty(modelo) || startsWith(modelo, '(')
            error('Selecciona un modelo valido para extrapolacion.');
        end
        if isempty(dsName) || startsWith(dsName, '(')
            error('Selecciona un dataset valido para extrapolacion.');
        end
        intensidad = max(0, min(1, c_ext.intensidad.Value));
        nt_ext_cfg = NaN;
        if mostrar_temporal_avanzado && isfield(c_ext, 'nt_ext')
            nt_ext_cfg = max(0, round(c_ext.nt_ext.Value));
        end
        cfg = struct('dataset', state.dataset, 'modelo', modelo, 'dsName', dsName, ...
            'ruta_dataset', ruta_ext_dataset_actual(), ...
            'ruta_correccion', state.corr_ruta, ...
            'nx', n, 'ny', n, 'nz', n, 'nt_fine', NaN, ...
            'T_abl', c_ext.tabl.Value, 't_extra_max', c_ext.t_extra.Value, ...
            'nt_ext', nt_ext_cfg, 'estrategia', c_ext.estrategia.Value, ...
            'carpeta_exportacion', c_ext.out.Value, 'export_mat', true, 'export_m', true, ...
            'export_rbf', false, 'n_rbf_max', 1000, ...
            'temperatura_max_corregida_C', 120, ...
            'aplicar_offset_base', c_ext.offset.Value, 'intensidad_correccion', intensidad);
    end

    function run_export(modo)
        try
            export_stl = ~strcmpi(modo, 'dataset'); export_mat = strcmpi(modo, 'todo') || strcmpi(modo, 'mat');
            cfg = struct('ruta_dataset', c_exp.dataset.Value, 'carpeta_correlaciones', c_exp.corr.Value, ...
                'temperatura_min_stl', c_exp.tmin.Value, 'radio_alpha', c_exp.alpha.Value, ...
                'iteraciones_suavizado', round(c_exp.smooth.Value), 'resolucion_preprocesamiento', c_exp.res.Value, ...
                'tipo_preprocesamiento', c_exp.tipo.Value, 'exportar_stl', export_stl, 'exportar_mat', export_mat, ...
                'temperatura_max_corregida_C', 120, ...
                'sobrescribir', c_exp.over.Value, 'logfn', @logmsg);
            sep(); ejecutar_exportador_correcciones_integrado('run', cfg); estado.Text = 'Correcciones finalizadas.';
        catch ME
            fail('Correcciones', ME);
        end
    end

    function modelos_to_ui()
        if ~isempty(state.dataset_catalog)
            catalogo = catalogo_ext_actual();
            modelos = unique({catalogo.modelo}, 'stable');
            if isempty(modelos), modelos = {'(sin dataset)'}; end
            c_ext.modelo.Items = modelos; c_ext.modelo.Value = modelos{1}; modelos_to_datasets();
            return;
        end
        modelos = fieldnames(state.dataset); modelos = modelos(~strcmp(modelos, 'session_meta'));
        if isempty(modelos), modelos = {'(sin dataset)'}; end
        c_ext.modelo.Items = modelos; c_ext.modelo.Value = modelos{1}; modelos_to_datasets();
    end

    function modelos_to_datasets()
        if ~isempty(state.dataset_catalog)
            catalogo = catalogo_ext_actual();
            idx = find(strcmp({catalogo.modelo}, c_ext.modelo.Value));
            state.dataset_catalog_indices = idx;
            if isempty(idx)
                c_ext.ds.Items = {'(sin dataset)'};
                c_ext.ds.Value = '(sin dataset)';
                return;
            end
            items = cell(1, numel(idx));
            for ii = 1:numel(idx)
                entrada = catalogo(idx(ii));
                partes = {entrada.modelo, entrada.dataset, entrada.tipo, ...
                    entrada.antena, entrada.caso, entrada.potencia};
                items{ii} = strjoin(partes(~cellfun(@isempty, partes)), ' | ');
            end
            c_ext.ds.Items = items;
            c_ext.ds.Value = items{1};
            return;
        end
        if isempty(state.dataset) || ~isfield(state.dataset, c_ext.modelo.Value), return; end
        ds = fieldnames(state.dataset.(c_ext.modelo.Value)); ds = ds(~strcmp(ds, 'session_meta'));
        if isempty(ds), ds = {'(sin dataset)'}; end
        c_ext.ds.Items = ds; c_ext.ds.Value = ds{1};
    end

    function modelo_ext_cambiado()
        modelos_to_datasets();
        invalidar_extrap_reactiva();
    end

    function poblar_filtros_ext()
        if isempty(state.dataset_catalog), return; end
        state.actualizando_filtros_ext = true;
        limpieza = onCleanup(@() set_actualizando_filtros_ext(false));
        controles = controles_filtros_ext();
        for k = 1:numel(controles)
            poblar_filtro_ext(controles(k).control, valores_catalogo_ext(state.dataset_catalog, controles(k).campo));
        end
        clear limpieza;
    end

    function poblar_filtro_ext(control, valores)
        previo = control.Value;
        valores = valores(~cellfun(@isempty, valores));
        valores = unique(valores, 'stable');
        items = [{'Todos'}, valores];
        if any(strcmp(items, previo))
            control.Items = items;
            control.Value = previo;
        else
            control.Value = 'Todos';
            control.Items = items;
            control.Value = 'Todos';
        end
    end

    function aplicar_filtros_ext()
        if isempty(state.dataset_catalog), return; end
        if state.actualizando_filtros_ext, return; end
        state.actualizando_filtros_ext = true;
        limpieza = onCleanup(@() set_actualizando_filtros_ext(false));
        actualizar_opciones_filtros_ext();
        state.dataset_catalog_filtrado = filtrar_catalogo_ext(state.dataset_catalog, '');
        state.dataset_catalog_indices = [];
        modelos_to_ui();
        if isempty(state.dataset_catalog_filtrado)
            estado.Text = 'Sin particiones para los filtros seleccionados.';
        else
            estado.Text = sprintf('Catalogo filtrado: %d particiones.', numel(state.dataset_catalog_filtrado));
        end
        clear limpieza;
        invalidar_extrap_reactiva();
        aplicar_filtros_correccion_ext();
    end

    function actualizar_opciones_filtros_ext()
        controles = controles_filtros_ext();
        for k = 1:numel(controles)
            base = filtrar_catalogo_ext(state.dataset_catalog, controles(k).campo);
            poblar_filtro_ext(controles(k).control, valores_catalogo_ext(base, controles(k).campo));
        end
    end

    function controles = controles_filtros_ext()
        controles = struct( ...
            'campo', {'tipo', 'antena', 'caso', 'potencia'}, ...
            'control', {c_ext.tipo, c_ext.antena, c_ext.caso, c_ext.potencia});
    end

    function catalogo = filtrar_catalogo_ext(catalogo, campo_excluido)
        controles = controles_filtros_ext();
        mask = true(size(catalogo));
        for k = 1:numel(controles)
            if strcmp(controles(k).campo, campo_excluido)
                continue;
            end
            valores = valores_catalogo_ext(catalogo, controles(k).campo);
            filtro = controles(k).control.Value;
            if ~isempty(filtro) && ~strcmp(filtro, 'Todos')
                mask = mask & strcmp(valores, filtro);
            end
        end
        catalogo = catalogo(mask);
    end

    function valores = valores_catalogo_ext(catalogo, campo)
        if isempty(catalogo)
            valores = {};
        else
            valores = {catalogo.(campo)};
        end
    end

    function set_actualizando_filtros_ext(valor)
        state.actualizando_filtros_ext = valor;
    end

    function catalogo = catalogo_ext_actual()
        if isstruct(state.dataset_catalog_filtrado)
            catalogo = state.dataset_catalog_filtrado;
        else
            catalogo = state.dataset_catalog;
        end
    end

    function cargar_corr_exp(ed)
        try
            if ~isfile(ed.Value), logmsg('Experimental no encontrado: %s', ed.Value); return; end
            state.exp = ejecutar_correlador_volumen_integrado('leer_experimental', ed.Value, true);
            ajustar_rango_tiempo(c_corr.exp_i, c_corr.exp_f, state.exp.t_min);
            logmsg('Experimental importado y normalizado a minutos: %d muestras, %d columnas.', numel(state.exp.t_min), size(state.exp.T, 2));
            actualizar_corr_reactiva();
        catch ME
            fail('Experimental', ME);
        end
    end

    function cargar_corr_sim(ed)
        try
            if ~isfile(ed.Value), logmsg('TXT de sondas no encontrado: %s', ed.Value); return; end
            state.sim = ejecutar_correlador_volumen_integrado('leer_txt_sondas', ed.Value);
            if isfield(state.sim, 'labels') && ~isempty(state.sim.labels)
                c_corr.sonda.Items = state.sim.labels; c_corr.sonda.Value = state.sim.labels{1};
            end
            ajustar_rango_tiempo(c_corr.sim_i, c_corr.sim_f, state.sim.t_min);
            logmsg('TXT de sondas importado: %d tiempos, %d sondas.', numel(state.sim.t_min), numel(state.sim.labels));
            actualizar_corr_reactiva();
        catch ME
            fail('TXT sondas', ME);
        end
    end

    function cargar_ext_dataset(ed)
        try
            ruta = normalizar_ruta_ext_catalogo(ed.Value);
            if ruta_esta_en_repetidos_global(ruta)
                error('El dataset seleccionado esta en repetidos y no es procesable: %s', ruta);
            end
            ed.Value = ruta;
            state.dataset = [];
            state.dataset_catalog = leer_catalogo_ext_ligero(ruta);
            state.dataset_catalog_filtrado = [];
            state.dataset_catalog_indices = [];
            state.dataset_ruta = '';
            state.dataset_key = '';
            state.volumen = [];
            if ~(isfile(ruta) || isfolder(ruta)), logmsg('Dataset MAT/catalogo no encontrado: %s', ruta); return; end
            if ~isempty(state.dataset_catalog)
                poblar_filtros_ext();
                aplicar_filtros_ext();
                logmsg('Catalogo termico importado para extrapolacion: %d entradas, %d modelos.', ...
                    numel(state.dataset_catalog), numel(c_ext.modelo.Items));
                estado.Text = 'Catalogo de extrapolacion cargado.';
                return;
            end
            state.dataset = ejecutar_correlador_volumen_integrado('cargar_dataset', ruta);
            state.dataset_ruta = ruta;
            modelos_to_ui();
            logmsg('Dataset termico importado para extrapolacion: %d modelos.', numel(c_ext.modelo.Items));
            estado.Text = 'Dataset de extrapolacion cargado.';
        catch ME
            fail('Dataset MAT', ME);
        end
    end

    function ruta = normalizar_ruta_ext_catalogo(ruta)
        ruta = char(ruta);
        if isfile(ruta)
            [folder, name, ext] = fileparts(ruta);
            if strcmpi([name ext], 'Indice_Datasets_Metadata.mat')
                ruta = folder;
            end
        end
    end

    function catalogo = leer_catalogo_ext_ligero(ruta)
        catalogo = crear_catalogo_ext(0);
        if ~isfolder(ruta)
            return;
        end
        idx = fullfile(ruta, 'Indice_Datasets_Metadata.mat');
        if ~isfile(idx)
            return;
        end
        raw = load(idx, 'particiones');
        if ~isfield(raw, 'particiones') || ~isstruct(raw.particiones)
            return;
        end
        keys = {};
        for k = 1:numel(raw.particiones)
            p = raw.particiones(k);
            ruta_mat = resolver_ruta_ext_indexada( ...
                ruta, texto_catalogo_ext(p, 'ruta'));
            if isempty(ruta_mat)
                continue;
            end
            entrada = crear_catalogo_ext(1);
            entrada.ruta = ruta_mat;
            entrada.modelo = texto_catalogo_ext(p, 'modelo');
            entrada.dataset = texto_catalogo_ext(p, 'dataset');
            entrada.tipo = texto_catalogo_ext(p, 'tipo');
            entrada.antena = texto_catalogo_ext(p, 'antena');
            entrada.caso = texto_num_catalogo_ext(valor_catalogo_ext(p, 'caso', NaN), 'Caso_%g');
            entrada.potencia = texto_num_catalogo_ext(valor_catalogo_ext(p, 'potencia_W', NaN), 'Potencia_%gW');
            if isempty(entrada.modelo) || isempty(entrada.dataset)
                continue;
            end
            entrada.clave = lower([entrada.modelo '__' entrada.dataset]);
            key = entrada.clave;
            if any(strcmp(keys, key))
                continue;
            end
            keys{end+1} = key; %#ok<AGROW>
            catalogo(end+1) = entrada; %#ok<AGROW>
        end
    end

    function ruta_mat = resolver_ruta_ext_indexada(root_catalogo, ruta_guardada)
        ruta_mat = char(ruta_guardada);
        if isfile(ruta_mat)
            if ruta_esta_en_repetidos_global(ruta_mat), ruta_mat = ''; end
            return;
        end

        normalizada = strrep(ruta_mat, '\', '/');
        marcador = '/datasets_masivos_por_metadata/';
        posiciones = strfind(lower(normalizada), marcador);
        if isempty(posiciones)
            ruta_mat = '';
            return;
        end
        relativa = normalizada(posiciones(end) + numel(marcador):end);
        partes = regexp(relativa, '/', 'split');
        candidata = fullfile(root_catalogo, partes{:});
        if isfile(candidata)
            ruta_mat = candidata;
        else
            ruta_mat = '';
        end
    end

    function catalogo = crear_catalogo_ext(n)
        plantilla = struct('ruta', '', 'modelo', '', 'dataset', '', ...
            'tipo', '', 'antena', '', 'caso', '', 'potencia', '', 'clave', '');
        if n == 0
            catalogo = plantilla([]);
        else
            catalogo = repmat(plantilla, n, 1);
        end
    end

    function valor = valor_catalogo_ext(s, campo, predeterminado)
        valor = predeterminado;
        if isstruct(s) && isfield(s, campo) && ~isempty(s.(campo))
            valor = s.(campo);
        end
        if iscell(valor) && ~isempty(valor)
            valor = valor{1};
        end
        if isstring(valor)
            valor = char(valor);
        end
    end

    function txt = texto_catalogo_ext(s, campo)
        valor = valor_catalogo_ext(s, campo, '');
        if ischar(valor)
            txt = valor;
        elseif isnumeric(valor) && isscalar(valor) && isfinite(double(valor))
            txt = sprintf('%g', double(valor));
        else
            txt = '';
        end
    end

    function texto = texto_num_catalogo_ext(valor, formato)
        if isnumeric(valor) && isscalar(valor) && isfinite(double(valor))
            texto = sprintf(formato, double(valor));
            texto = strrep(texto, '.000000', '');
        elseif ischar(valor) || isstring(valor)
            texto = char(valor);
        else
            texto = '';
        end
    end

    function asegurar_ext_dataset_seleccionado()
        if isempty(state.dataset_catalog) && isempty(state.dataset)
            cargar_ext_dataset(c_ext.dataset);
        end
        if isempty(state.dataset_catalog)
            return;
        end
        entrada = entrada_catalogo_ext_actual();
        if isempty(entrada)
            error('Selecciona un modelo/dataset valido para extrapolacion.');
        end
        modelo = entrada.modelo;
        dsName = entrada.dataset;
        if startsWith(modelo, '(') || startsWith(dsName, '(')
            error('Selecciona un modelo/dataset valido para extrapolacion.');
        end
        ruta = entrada.ruta;
        key = [modelo '|' dsName '|' ruta];
        if strcmp(state.dataset_key, key) && ~isempty(state.dataset) && ...
                isfield(state.dataset, modelo) && isfield(state.dataset.(modelo), dsName)
            return;
        end
        state.dataset = ejecutar_correlador_volumen_integrado('cargar_dataset', ruta);
        state.dataset_ruta = ruta;
        state.dataset_key = key;
        logmsg('Particion termica cargada: %s / %s.', modelo, dsName);
    end

    function entrada = entrada_catalogo_ext_actual()
        entrada = crear_catalogo_ext(0);
        if isempty(state.dataset_catalog_indices) || isempty(c_ext.ds.Value)
            return;
        end
        pos = find(strcmp(c_ext.ds.Items, c_ext.ds.Value), 1, 'first');
        if isempty(pos) || pos > numel(state.dataset_catalog_indices)
            return;
        end
        catalogo = catalogo_ext_actual();
        idx = state.dataset_catalog_indices(pos);
        if idx > numel(catalogo)
            return;
        end
        entrada = catalogo(idx);
    end

    function modelo = modelo_ext_actual()
        entrada = entrada_catalogo_ext_actual();
        if ~isempty(entrada)
            modelo = entrada.modelo;
        else
            modelo = c_ext.modelo.Value;
        end
    end

    function dsName = dataset_ext_actual()
        entrada = entrada_catalogo_ext_actual();
        if ~isempty(entrada)
            dsName = entrada.dataset;
        else
            dsName = c_ext.ds.Value;
        end
    end

    function ruta = ruta_ext_dataset_actual()
        ruta = c_ext.dataset.Value;
        if ~isempty(state.dataset_ruta)
            ruta = state.dataset_ruta;
        end
    end

    function corr = cargar_correccion_local(ruta)
        raw = load(ruta);
        if ~isfield(raw, 'correccion_termica')
            error('El archivo no contiene correccion_termica.');
        end
        [~, nombre_corr] = fileparts(ruta);
        raw.ruta_correccion_mat = ruta;
        raw.nombre_corr = nombre_corr;
        corr = raw;
    end

    function asegurar_ext_corr_cargada()
        if isempty(state.corr)
            aplicar_filtros_correccion_ext();
        end
        if isempty(state.corr)
            error(['Selecciona metadata completa de correccion: fecha, tiempo, ', ...
                'numero de prueba y zona experimental.']);
        end
        validar_correccion_ext_metadata(state.corr);
    end

    function validar_correccion_ext_metadata(corr)
        entrada = entrada_catalogo_ext_actual();
        if isempty(entrada) || ~isstruct(corr)
            return;
        end
        meta = metadata_correccion_ext_unificada(corr);
        if isempty(meta.tipo_antena) || ~isfinite(meta.num_antenas) || ...
                ~isfinite(meta.caso) || ~isfinite(meta.potencia_W)
            error('La correccion no contiene metadata completa de tipo/antenas/caso/potencia.');
        end
        esperado_antena = sprintf('%dant', round(meta.num_antenas));
        esperado_caso = sprintf('Caso_%d', round(meta.caso));
        esperado_potencia = sprintf('Potencia_%gW', meta.potencia_W);
        if ~strcmpi(entrada.tipo, meta.tipo_antena) || ...
                ~strcmpi(entrada.antena, esperado_antena) || ...
                ~strcmpi(entrada.caso, esperado_caso) || ...
                ~strcmpi(entrada.potencia, esperado_potencia)
            error(['Correccion incompatible. Correccion=%s/%s/%s/%s; ', ...
                'dataset=%s/%s/%s/%s.'], meta.tipo_antena, esperado_antena, ...
                esperado_caso, esperado_potencia, entrada.tipo, entrada.antena, ...
                entrada.caso, entrada.potencia);
        end
    end

    function asegurar_catalogo_correcciones_ext()
        if ~state.corr_catalog_cargado
            state.corr_catalog = catalogar_correcciones_metadata_ext(paths.correlaciones);
            state.corr_catalog_cargado = true;
            logmsg('Catalogo de correcciones cargado: %d archivo(s) con metadata completa.', ...
                numel(state.corr_catalog));
        end
    end

    function aplicar_filtros_correccion_ext()
        if state.actualizando_filtros_corr, return; end
        asegurar_catalogo_correcciones_ext();
        state.actualizando_filtros_corr = true;
        limpieza = onCleanup(@() set_actualizando_filtros_corr(false));
        controles = controles_filtros_correccion_ext();
        for k = 1:numel(controles)
            base = filtrar_catalogo_correccion_ui( ...
                state.corr_catalog, controles(k).campo);
            if isempty(base)
                valores = {};
            else
                valores = {base.(controles(k).campo)};
            end
            poblar_filtro_ext(controles(k).control, valores);
        end
        clear limpieza;
        sincronizar_correccion_ext_filtrada();
    end

    function controles = controles_filtros_correccion_ext()
        controles = struct( ...
            'campo', {'fecha', 'tiempo', 'prueba', 'zona'}, ...
            'control', {c_ext.corr_fecha, c_ext.corr_tiempo, ...
                c_ext.corr_prueba, c_ext.corr_zona});
    end

    function catalogo = filtrar_catalogo_correccion_ui(catalogo, campo_excluido)
        if isempty(catalogo), return; end
        mask = true(size(catalogo));
        if ~strcmp(c_ext.tipo.Value, 'Todos')
            mask = mask & strcmpi({catalogo.tipo}, c_ext.tipo.Value);
        end
        if ~strcmp(c_ext.antena.Value, 'Todos')
            mask = mask & strcmpi({catalogo.antena}, c_ext.antena.Value);
        end
        caso = numero_filtro_correccion_ext(c_ext.caso.Value, 'Caso_');
        if isfinite(caso), mask = mask & abs([catalogo.caso] - caso) < 1e-9; end
        potencia = numero_filtro_correccion_ext(c_ext.potencia.Value, 'Potencia_', 'W');
        if isfinite(potencia)
            mask = mask & abs([catalogo.potencia_W] - potencia) < 1e-9;
        end
        controles = controles_filtros_correccion_ext();
        for k = 1:numel(controles)
            if strcmp(controles(k).campo, campo_excluido) || ...
                    strcmp(controles(k).control.Value, 'Todos')
                continue;
            end
            mask = mask & strcmpi({catalogo.(controles(k).campo)}, ...
                controles(k).control.Value);
        end
        catalogo = catalogo(mask);
    end

    function sincronizar_correccion_ext_filtrada()
        tipo = char(c_ext.tipo.Value);
        antena = char(c_ext.antena.Value);
        caso = numero_filtro_correccion_ext(c_ext.caso.Value, 'Caso_');
        potencia = numero_filtro_correccion_ext(c_ext.potencia.Value, 'Potencia_', 'W');
        completo = ~strcmp(tipo, 'Todos') && ~strcmp(antena, 'Todos') && ...
            isfinite(caso) && isfinite(potencia);
        filtros_corr = controles_filtros_correccion_ext();
        completo = completo && all(arrayfun(@(x) ...
            ~strcmp(x.control.Value, 'Todos'), filtros_corr));
        if ~completo
            descargar_correccion_ext_filtrada();
            estado.Text = 'Completa los filtros especificos de correccion.';
            return;
        end
        candidatas = filtrar_catalogo_correccion_ui(state.corr_catalog, '');
        if isempty(candidatas)
            descargar_correccion_ext_filtrada();
            logmsg(['Sin correccion para filtros: %s/%s/Caso_%d/Potencia_%gW/', ...
                '%s/%s/%s/%s.'], tipo, antena, caso, potencia, ...
                c_ext.corr_fecha.Value, c_ext.corr_tiempo.Value, ...
                c_ext.corr_prueba.Value, c_ext.corr_zona.Value);
            estado.Text = 'Sin correccion compatible con los filtros.';
            return;
        end
        if numel(candidatas) > 1
            descargar_correccion_ext_filtrada();
            logmsg(['Metadata ambigua: %d correcciones coinciden exactamente; ', ...
                'no se eligio la mas reciente.'], numel(candidatas));
            estado.Text = 'Correccion ambigua; revisa duplicados de correlacion.';
            return;
        end
        seleccionada = candidatas.ruta;
        if strcmpi(state.corr_ruta, seleccionada) && ~isempty(state.corr)
            return;
        end
        try
            corr = cargar_correccion_local(seleccionada);
            validar_correccion_ext_metadata(corr);
            state.corr = corr;
            state.corr_ruta = seleccionada;
            horizonte = horizonte_correccion_min(corr);
            if isfinite(horizonte) && horizonte > 0
                c_ext.t_extra.Value = horizonte;
            end
            logmsg('Correccion resuelta por metadata: %s', seleccionada);
            estado.Text = 'Correccion resuelta por metadata.';
            actualizar_correccion_ext_reactiva();
        catch ME
            descargar_correccion_ext_filtrada();
            logmsg('Correccion filtrada invalida: %s', ME.message);
            estado.Text = 'Error en correccion filtrada.';
        end
    end

    function valor = numero_filtro_correccion_ext(texto, prefijo, sufijo)
        if nargin < 3, sufijo = ''; end
        texto = char(texto);
        texto = regexprep(texto, ['^' regexptranslate('escape', prefijo)], '', 'ignorecase');
        if ~isempty(sufijo)
            texto = regexprep(texto, [regexptranslate('escape', sufijo) '$'], '', 'ignorecase');
        end
        texto = strrep(lower(texto), 'p', '.');
        valor = str2double(texto);
    end

    function descargar_correccion_ext_filtrada()
        if ~isempty(state.corr) || ~isempty(state.corr_ruta)
            state.corr = [];
            state.corr_ruta = '';
            actualizar_correccion_ext_reactiva();
        end
    end

    function set_actualizando_filtros_corr(valor)
        state.actualizando_filtros_corr = valor;
    end

    function tmax_abs = horizonte_correccion_min(corr)
        tmax_abs = NaN;
        if isempty(corr) || ~isfield(corr, 'correccion_termica')
            return;
        end
        ct = corr.correccion_termica;
        candidatos = horizonte_ct_abs(ct);
        zonas = zonas_correccion_ui(ct);
        for hz = 1:numel(zonas)
            candidatos(end+1, 1) = horizonte_ct_abs(zonas(hz)); %#ok<AGROW>
        end
        candidatos = candidatos(isfinite(candidatos) & candidatos > 0);
        if ~isempty(candidatos)
            tmax_abs = max(candidatos);
        end
    end

    function tmax_abs = horizonte_ct_abs(ct)
        tmax_abs = NaN;
        vals = [];
        if isstruct(ct) && isfield(ct, 't_rel_min')
            vals = [vals; double(ct.t_rel_min(:))];
        end
        if isstruct(ct) && isfield(ct, 'intervalo_valido_min')
            vals = [vals; double(ct.intervalo_valido_min(:))];
        end
        if isstruct(ct) && isfield(ct, 'intervalo_relativo_valido_min')
            vals = [vals; double(ct.intervalo_relativo_valido_min(:))];
        end
        vals = vals(isfinite(vals));
        if isempty(vals)
            return;
        end
        t0 = 0;
        if isfield(ct, 't_origen_simulacion_min') && isscalar(ct.t_origen_simulacion_min) && isfinite(ct.t_origen_simulacion_min)
            t0 = double(ct.t_origen_simulacion_min);
        end
        tmax_abs = t0 + max(vals);
    end

    function zonas = zonas_correccion_ui(ct)
        zonas = struct([]);
        if isstruct(ct) && isfield(ct, 'zonas') && ~isempty(ct.zonas)
            zonas = ct.zonas(:);
        end
    end

    function actualizar_extrap_reactiva()
        try
            mostrar_vista_ext();
            if state.actualizando_extrap_ext
                plot_vol();
                return;
            end
            if ~isempty(state.volumen) && volumen_no_coincide_con_seleccion()
                state.volumen = [];
            end
            if es_vista_termica_ext()
                plot_vol();
            else
                plot_ext_factor();
            end
            if isempty(state.volumen)
                estado.Text = sprintf('Listo para construir: %s / %s.', ...
                    modelo_ext_actual(), dataset_ext_actual());
            else
                estado.Text = sprintf('Vista actualizada: %s.', c_ext.estrategia.Value);
            end
        catch ME
            estado.Text = sprintf('Previsualizacion no disponible: %s', ME.message);
        end
        drawnow limitrate;
    end

    function actualizar_correccion_ext_reactiva()
        try
            mostrar_vista_ext();
            if isempty(state.volumen)
                plot_ext_factor();
                estado.Text = 'Correccion lista; construye el volumen 4D para aplicarla.';
                return;
            end
            if ~isfield(state.volumen, 'T_export_base_nd') || isempty(state.volumen.T_export_base_nd)
                invalidar_extrap_reactiva();
                return;
            end
            res = state.volumen;
            cfg = res.cfg;
            cfg.aplicar_offset_base = c_ext.offset.Value;
            cfg.intensidad_correccion = max(0, min(1, c_ext.intensidad.Value));
            cfg.ruta_correccion = state.corr_ruta;
            cfg.carpeta_exportacion = c_ext.out.Value;
            cfg.export_mat = true;
            cfg.export_m = true;
            cfg.export_rbf = false;
            res.cfg = cfg;
            if c_ext.usar_corr.Value
                asegurar_ext_corr_cargada();
                if isempty(state.corr)
                    res = ejecutar_correlador_volumen_integrado( ...
                        'reaplicar_correccion_volumen', res, cfg, []);
                    state.volumen = res;
                    estado.Text = 'Completa los filtros de correccion para aplicarla al volumen.';
                    plot_vol();
                    return;
                end
                res = ejecutar_correlador_volumen_integrado( ...
                    'reaplicar_correccion_volumen', res, cfg, state.corr);
                estado.Text = 'Correccion reaplicada sobre el volumen construido.';
            else
                res = ejecutar_correlador_volumen_integrado( ...
                    'reaplicar_correccion_volumen', res, cfg, []);
                estado.Text = 'Correccion desactivada; se conserva el volumen base construido.';
            end
            state.volumen = res;
            plot_vol();
        catch ME
            estado.Text = sprintf('No se pudo actualizar la correccion: %s', ME.message);
        end
        drawnow limitrate;
    end

    function invalidar_extrap_reactiva()
        state.volumen = [];
        actualizar_tiempos_ext([]);
        actualizar_extrap_reactiva();
    end

    function tf = volumen_no_coincide_con_seleccion()
        tf = false;
        if isempty(state.volumen) || ~isfield(state.volumen, 'cfg')
            return;
        end
        cfg = state.volumen.cfg;
        if isfield(cfg, 'modelo')
            tf = tf || ~strcmp(cfg.modelo, modelo_ext_actual());
        end
        if isfield(cfg, 'dsName')
            tf = tf || ~strcmp(cfg.dsName, dataset_ext_actual());
        end
    end

    function ajustar_rango_tiempo(edIni, edFin, t)
        t = t(:); t = t(isfinite(t));
        if isempty(t), return; end
        edIni.Value = min(t);
        edFin.Value = max(t);
    end

    function asegurar_corr_cargada()
        if isempty(state.exp), cargar_corr_exp(c_corr.exp); end
        if isempty(state.sim), cargar_corr_sim(c_corr.sim); end
    end

    function actualizar_corr_reactiva()
        if isempty(state.exp) || isempty(state.sim)
            cla(c_corr.ax1); cla(c_corr.ax2);
            title(c_corr.ax1, 'Carga experimental y TXT de sondas');
            drawnow limitrate;
            return;
        end
        try
            cfg = cfg_corr();
            state.corr = ejecutar_correlador_volumen_integrado('calcular_correlacion', cfg);
            plot_corr();
            estado.Text = sprintf('Correccion actualizada: RMSE %.4f C', state.corr.correccion_termica.rmse_factor_C);
        catch ME
            state.corr = [];
            estado.Text = sprintf('Correlacion no disponible: %s', ME.message);
            cla(c_corr.ax2); plot_corr_base();
        end
        drawnow limitrate;
    end

    function cfg = cfg_corr()
        [exp_i, exp_f] = indices_por_ventana_min(state.exp.t_min, c_corr.exp_i.Value, c_corr.exp_f.Value, 'experimental');
        [sim_i, sim_f] = indices_por_ventana_min(state.sim.t_min, c_corr.sim_i.Value, c_corr.sim_f.Value, 'simulacion');
        cfg = struct('exp', state.exp, 'sim', state.sim, 'sonda', c_corr.sonda.Value, ...
            'exp_inicio', exp_i, 'exp_fin', exp_f, ...
            'sim_inicio', sim_i, 'sim_fin', sim_f, ...
            'grado', round(c_corr.grado.Value), 'n_comun', round(c_corr.n.Value), ...
            'nombre_exp', c_corr.exp.Value, 'nombre_sim', c_corr.sim.Value);
    end

    function [i0, i1] = indices_por_ventana_min(t, t0, t1, etiqueta)
        t = t(:);
        validos = find(isfinite(t));
        if numel(validos) < 2, error('Tiempo %s insuficiente.', etiqueta); end
        tv = t(validos);
        if ~isfinite(t0), t0 = min(tv); end
        if ~isfinite(t1) || t1 <= t0, t1 = max(tv); end
        i0v = find(tv >= t0, 1, 'first');
        i1v = find(tv <= t1, 1, 'last');
        if isempty(i0v) || isempty(i1v) || i0v >= i1v
            error('Ventana temporal invalida para %s: %.4g a %.4g min.', etiqueta, t0, t1);
        end
        i0 = validos(i0v);
        i1 = validos(i1v);
    end

    function plot_corr()
        r = state.corr;
        if isempty(r), plot_corr_base(); return; end
        cla(c_corr.ax1, 'reset'); tesis_auxiliares('tema_ui', 'axes', c_corr.ax1);
        yyaxis(c_corr.ax1, 'left'); hold(c_corr.ax1, 'on');
        plot(c_corr.ax1, r.t_exp_zero, r.y_exp, '-', 'LineWidth', 1.1, 'DisplayName', 'Exp recortado');
        plot(c_corr.ax1, r.t_sim_zero, r.y_sim, '-', 'LineWidth', 1.1, 'DisplayName', 'Sim recortada');
        plot(c_corr.ax1, r.t_comun, r.y_exp_interp, '--', 'LineWidth', 1.1, 'DisplayName', 'Exp interp');
        plot(c_corr.ax1, r.t_comun, r.y_sim_interp, '--', 'LineWidth', 1.1, 'DisplayName', 'Sim interp');
        if isfield(r.correccion_termica, 'simulacion_corregida_factor_C')
            plot(c_corr.ax1, r.t_comun, r.correccion_termica.simulacion_corregida_factor_C, 'LineWidth', 1.8, 'DisplayName', 'Sim corregida');
        end
        ylabel(c_corr.ax1, 'Temperatura (C)');
        ajuste = ajuste_aplicado_corr(r);
        if ~isempty(ajuste)
            yyaxis(c_corr.ax1, 'right');
            plot(c_corr.ax1, r.t_comun, ajuste, ':', 'LineWidth', 1.6, 'DisplayName', 'Funcion aplicada');
            yline(c_corr.ax1, 0, ':', 'HandleVisibility', 'off');
            ylabel(c_corr.ax1, 'Correccion aplicada (C)');
            yyaxis(c_corr.ax1, 'left');
        end
        hold(c_corr.ax1, 'off'); grid_ui(c_corr.ax1);
        xlabel(c_corr.ax1, 'Tiempo relativo (min)'); title(c_corr.ax1, 'Correlacion');
        legend(c_corr.ax1, 'show', 'Location', 'best');

        cla(c_corr.ax2, 'reset'); tesis_auxiliares('tema_ui', 'axes', c_corr.ax2);
        yyaxis(c_corr.ax2, 'left');
        plot(c_corr.ax2, r.t_comun, r.y_delta, 'LineWidth', 1.2, 'DisplayName', 'Delta T');
        ylabel(c_corr.ax2, 'Delta T (C)');
        yyaxis(c_corr.ax2, 'right');
        plot(c_corr.ax2, r.correccion_termica.t_rel_min, r.correccion_termica.factor_enfriamiento, 'LineWidth', 1.2, 'DisplayName', 'Factor');
        ylabel(c_corr.ax2, 'Factor');
        grid_ui(c_corr.ax2); xlabel(c_corr.ax2, 'Tiempo relativo (min)');
        title(c_corr.ax2, 'Funcion de correccion'); legend(c_corr.ax2, 'show', 'Location', 'best');
    end

    function plot_corr_base()
        cla(c_corr.ax1, 'reset'); tesis_auxiliares('tema_ui', 'axes', c_corr.ax1); hold(c_corr.ax1, 'on');
        if ~isempty(state.exp)
            T = matriz_T_ui(state.exp.T);
            plot(c_corr.ax1, state.exp.t_min, T(:, 1:min(4, size(T, 2))), 'LineWidth', 1.0);
        end
        if ~isempty(state.sim)
            T = matriz_T_ui(state.sim.T);
            plot(c_corr.ax1, state.sim.t_min, T(:, 1:min(4, size(T, 2))), '--', 'LineWidth', 1.0);
        end
        hold(c_corr.ax1, 'off'); grid_ui(c_corr.ax1);
        xlabel(c_corr.ax1, 'Tiempo absoluto (min)'); ylabel(c_corr.ax1, 'Temperatura (C)');
        title(c_corr.ax1, 'Datos importados');
    end

    function ajuste = ajuste_aplicado_corr(r)
        ajuste = [];
        if isempty(r) || ~isfield(r, 'y_sim_interp'), return; end
        if isfield(r, 'correccion_termica') && isfield(r.correccion_termica, 'simulacion_corregida_factor_C') && ...
                numel(r.correccion_termica.simulacion_corregida_factor_C) == numel(r.y_sim_interp)
            ajuste = r.correccion_termica.simulacion_corregida_factor_C(:) - r.y_sim_interp(:);
        elseif isfield(r, 'p_arreglo') && ~isempty(r.p_arreglo)
            ajuste = -polyval(r.p_arreglo, r.t_comun(:));
        end
    end

    function T = matriz_T_ui(T)
        if isempty(T)
            T = zeros(0, 1);
        elseif isvector(T)
            T = T(:);
        end
    end

    function grid_ui(ax)
        try
            ax.XGrid = 'on'; ax.YGrid = 'on'; ax.ZGrid = 'on';
        catch
            try
                grid(ax, 'on');
            catch
            end
        end
    end

    function tf = es_vista_termica_ext()
        tf = isfield(c_ext, 'vista') && strcmp(c_ext.vista.Value, 'Campo termico 4D');
    end

    function mostrar_vista_ext()
        c_ext.panel_2d.Visible = vis(~es_vista_termica_ext());
        c_ext.panel_termico.Visible = vis(es_vista_termica_ext());
    end

    function plot_vol()
        mostrar_vista_ext();
        r = state.volumen;
        if isempty(r)
            actualizar_tiempos_ext([]);
            if es_vista_termica_ext()
                limpiar_ext_termico('Construye el volumen 4D.');
            end
            return;
        end
        actualizar_tiempos_ext(r);
        if es_vista_termica_ext()
            plot_ext_termico(r);
            return;
        end
        [V_sel, sigma_sel, modelo_label] = curva_extrap_actual(r);
        cla(c_ext.ax_vol, 'reset'); tesis_auxiliares('tema_ui', 'axes', c_ext.ax_vol); hold(c_ext.ax_vol, 'on');
        ley = {};
        if isfield(r, 't_fine') && isfield(r, 'V_base')
            plot(c_ext.ax_vol, r.t_fine, r.V_base, 'LineWidth', 1.2); ley{end+1} = 'Base';
        end
        if isfield(r, 't_ext') && ~isempty(r.t_ext) && ~isempty(V_sel)
            plot(c_ext.ax_vol, r.t_ext, V_sel, '--', 'LineWidth', 1.2); ley{end+1} = modelo_label;
        end
        if isfield(r, 'V_corr') && ~isempty(r.V_corr)
            plot(c_ext.ax_vol, r.t_full, r.V_corr, 'LineWidth', 1.2);
            if isfield(r, 'modelo_tipo') && ~strcmp(modelo_label, r.modelo_tipo)
                ley{end+1} = sprintf('Corregido (%s)', r.modelo_tipo);
            else
                ley{end+1} = 'Corregido';
            end
        end
        hold(c_ext.ax_vol, 'off'); grid_ui(c_ext.ax_vol);
        xlabel(c_ext.ax_vol, 'Tiempo (min)'); ylabel(c_ext.ax_vol, 'Volumen');
        title(c_ext.ax_vol, sprintf('Volumen seleccionado: %s', modelo_label));
        if ~isempty(ley), legend(c_ext.ax_vol, ley, 'Location', 'best'); end

        plot_extrap_methods(r);
        plot_extrap_sigma(r, sigma_sel, modelo_label);
        plot_ext_factor();
    end

    function actualizar_tiempos_ext(r)
        if ~isfield(c_ext, 'tiempo')
            return;
        end
        if isempty(r) || ~isfield(r, 't_full') || isempty(r.t_full)
            c_ext.tiempo.Items = {'(sin volumen)'};
            c_ext.tiempo.Value = '(sin volumen)';
            c_ext.tiempo.Enable = 'off';
            return;
        end
        t = double(r.t_full(:));
        items = cell(1, numel(t));
        for ti = 1:numel(t)
            items{ti} = sprintf('%04d | %.4f min | %s', ti, t(ti), etiqueta_tramo_ext(r, ti));
        end
        anterior = c_ext.tiempo.Value;
        c_ext.tiempo.Items = items;
        if any(strcmp(items, anterior))
            c_ext.tiempo.Value = anterior;
        else
            idx = indice_fin_sim_ext(r);
            c_ext.tiempo.Value = items{idx};
        end
        c_ext.tiempo.Enable = 'on';
    end

    function idx = indice_fin_sim_ext(r)
        n = numel(r.t_full);
        idx = 1;
        if isfield(r, 't_fine') && ~isempty(r.t_fine)
            idx = numel(r.t_fine);
        end
        idx = max(1, min(n, idx));
    end

    function idx = indice_tiempo_ext(r)
        idx = find(strcmp(c_ext.tiempo.Items, c_ext.tiempo.Value), 1, 'first');
        if isempty(idx)
            idx = indice_fin_sim_ext(r);
        end
        idx = max(1, min(numel(r.t_full), idx));
    end

    function txt = etiqueta_tramo_ext(r, idx)
        if isfield(r, 't_fine') && idx <= numel(r.t_fine)
            txt = 'simulado';
        else
            txt = 'extrapolado';
        end
    end

    function plot_ext_termico(r)
        if isempty(r) || ~isfield(r, 'Fgrid_ext') || isempty(r.Fgrid_ext)
            limpiar_ext_termico('Sin campo 4D.');
            return;
        end
        try
            V = r.Fgrid_ext.Values;
        catch
            limpiar_ext_termico('Campo 4D no legible.');
            return;
        end
        idx_t = indice_tiempo_ext(r);
        try
            T = squeeze(V(:,:,:,idx_t));
        catch
            limpiar_ext_termico('Tiempo 4D fuera de rango.');
            return;
        end
        if ndims(T) ~= 3 || isempty(T)
            limpiar_ext_termico('Campo termico vacio.');
            return;
        end
        ix = max(1, round(size(T, 1) / 2));
        iy = max(1, round(size(T, 2) / 2));
        iz = max(1, round(size(T, 3) / 2));
        t_act = double(r.t_full(idx_t));
        tramo = etiqueta_tramo_ext(r, idx_t);
        plot_ext_plano(c_ext.ax_xy, r.xg, r.yg, squeeze(T(:,:,iz))', ...
            sprintf('XY | z=%.2f | t=%.4f min | %s', r.zg(iz), t_act, tramo), 'X (mm)', 'Y (mm)');
        plot_ext_plano(c_ext.ax_xz, r.xg, r.zg, squeeze(T(:,iy,:))', ...
            sprintf('XZ | y=%.2f | %s', r.yg(iy), tramo), 'X (mm)', 'Z (mm)');
        plot_ext_plano(c_ext.ax_yz, r.yg, r.zg, squeeze(T(ix,:,:))', ...
            sprintf('YZ | x=%.2f | %s', r.xg(ix), tramo), 'Y (mm)', 'Z (mm)');
        plot_ext_3d(r, T, idx_t, tramo);
    end

    function plot_ext_plano(ax, x, y, C, titulo, xlab, ylab)
        colorbar(ax, 'off');
        cla(ax, 'reset');
        tesis_auxiliares('tema_ui', 'axes', ax);
        imagesc(ax, x, y, C);
        axis(ax, 'xy');
        colormap(ax, parula(256));
        cb = colorbar(ax);
        cb.Color = theme.colors.text;
        xlabel(ax, xlab); ylabel(ax, ylab);
        title(ax, titulo, 'Color', theme.colors.accent, 'Interpreter', 'none', 'FontSize', 8);
        grid_ui(ax);
    end

    function plot_ext_3d(r, T, idx_t, tramo)
        ax = c_ext.ax_3d;
        colorbar(ax, 'off');
        cla(ax, 'reset');
        tesis_auxiliares('tema_ui', 'axes', ax);
        T_abl = 60;
        if isfield(r, 'T_abl') && isscalar(r.T_abl) && isfinite(r.T_abl)
            T_abl = double(r.T_abl);
        end
        mask = isfinite(T) & T >= T_abl;
        if ~any(mask(:))
            limpiar_eje_ext(ax, sprintf('Sin voxeles sobre %.1f C.', T_abl));
            title(ax, 'Campo 3D', 'Color', theme.colors.accent);
            view(ax, 3);
            return;
        end
        max_pts = 40000;
        idx_hot = find(mask);
        if numel(idx_hot) > max_pts
            idx_hot = idx_hot(round(linspace(1, numel(idx_hot), max_pts)));
        end
        [ix, iy, iz] = ind2sub(size(T), idx_hot);
        x = double(r.xg(:)); y = double(r.yg(:)); z = double(r.zg(:));
        temp = T(idx_hot);
        scatter3(ax, x(ix), y(iy), z(iz), 10, temp, 'filled', ...
            'MarkerFaceAlpha', 0.62, 'MarkerEdgeAlpha', 0.12);
        colormap(ax, parula(256));
        cb = colorbar(ax); cb.Color = theme.colors.text;
        xlabel(ax, 'X (mm)'); ylabel(ax, 'Y (mm)'); zlabel(ax, 'Z (mm)');
        title(ax, sprintf('T >= %.1f C | t=%.4f min | %s', T_abl, r.t_full(idx_t), tramo), ...
            'Color', theme.colors.accent, 'Interpreter', 'none');
        grid_ui(ax); axis(ax, 'vis3d'); view(ax, 3);
    end

    function limpiar_ext_termico(msg)
        limpiar_eje_ext(c_ext.ax_xy, msg);
        limpiar_eje_ext(c_ext.ax_xz, msg);
        limpiar_eje_ext(c_ext.ax_yz, msg);
        limpiar_eje_ext(c_ext.ax_3d, msg);
    end

    function limpiar_eje_ext(ax, msg)
        colorbar(ax, 'off');
        cla(ax, 'reset');
        tesis_auxiliares('tema_ui', 'axes', ax);
        text(ax, 0.5, 0.5, msg, 'Units', 'normalized', ...
            'HorizontalAlignment', 'center', 'Color', theme.colors.textMuted);
        grid_ui(ax);
    end

    function [V_sel, sigma_sel, modelo_label] = curva_extrap_actual(r)
        V_sel = [];
        sigma_sel = [];
        if isfield(r, 'modelo_tipo') && ~isempty(r.modelo_tipo)
            modelo_label = r.modelo_tipo;
        else
            modelo_label = 'sin_extrapolacion';
        end
        if ~isfield(r, 'extrap') || ~isfield(r.extrap, 't_ext_only') || isempty(r.extrap.t_ext_only)
            if isfield(r, 'V_ext'), V_sel = r.V_ext; end
            if isfield(r, 'sigma_sel'), sigma_sel = r.sigma_sel; end
            return;
        end
        switch c_ext.estrategia.Value
            case 'Gradiente local'
                if isfield(r.extrap, 'V_grad'), V_sel = r.extrap.V_grad; end
                if isfield(r.extrap, 'sigma_grad'), sigma_sel = r.extrap.sigma_grad; end
                modelo_label = 'gradiente_local';
            case 'LOWESS'
                if isfield(r.extrap, 'V_lowess'), V_sel = r.extrap.V_lowess; end
                if isfield(r.extrap, 'sigma_low'), sigma_sel = r.extrap.sigma_low; end
                modelo_label = 'lowess_cuadratico';
            otherwise
                if isfield(r.extrap, 'V_pca'), V_sel = r.extrap.V_pca; end
                if isfield(r.extrap, 'sigma_pca'), sigma_sel = r.extrap.sigma_pca; end
                modelo_label = 'pca_temporal';
        end
    end

    function plot_extrap_methods(r)
        cla(c_ext.ax_methods, 'reset'); tesis_auxiliares('tema_ui', 'axes', c_ext.ax_methods); hold(c_ext.ax_methods, 'on');
        ley = {};
        if isfield(r, 't_fine') && isfield(r, 'V_base')
            plot(c_ext.ax_methods, r.t_fine, r.V_base, 'k-', 'LineWidth', 1.0); ley{end+1} = 'Base';
        end
        if isfield(r, 'extrap') && isfield(r.extrap, 't_ext_only') && ~isempty(r.extrap.t_ext_only)
            t = r.extrap.t_ext_only;
            if isfield(r.extrap, 'V_pca'), plot(c_ext.ax_methods, t, r.extrap.V_pca, 'LineWidth', 1.2); ley{end+1} = 'PCA temporal'; end
            if isfield(r.extrap, 'V_lowess'), plot(c_ext.ax_methods, t, r.extrap.V_lowess, '--', 'LineWidth', 1.2); ley{end+1} = 'LOWESS'; end
            if isfield(r.extrap, 'V_grad'), plot(c_ext.ax_methods, t, r.extrap.V_grad, ':', 'LineWidth', 1.4); ley{end+1} = 'Gradiente local'; end
        else
            text(c_ext.ax_methods, 0.05, 0.55, 'Sin tramo extrapolado.', 'Units', 'normalized');
        end
        if isfinite(c_ext.t_extra.Value) && c_ext.t_extra.Value > 0
            xline(c_ext.ax_methods, c_ext.t_extra.Value, ':', 'T extra', 'HandleVisibility', 'off');
        end
        hold(c_ext.ax_methods, 'off'); grid_ui(c_ext.ax_methods);
        xlabel(c_ext.ax_methods, 'Tiempo (min)'); ylabel(c_ext.ax_methods, 'Volumen'); title(c_ext.ax_methods, 'Comparacion de metodos');
        if ~isempty(ley), legend(c_ext.ax_methods, ley, 'Location', 'best'); end
    end

    function plot_extrap_sigma(r, sigma_sel, modelo_label)
        if nargin < 2 || isempty(sigma_sel)
            [~, sigma_sel, modelo_label] = curva_extrap_actual(r);
        end
        cla(c_ext.ax_sigma, 'reset'); tesis_auxiliares('tema_ui', 'axes', c_ext.ax_sigma);
        if ~isempty(sigma_sel) && isfield(r, 't_ext') && ~isempty(r.t_ext)
            sigma = mean(abs(sigma_sel), 1, 'omitnan');
            plot(c_ext.ax_sigma, r.t_ext, sigma, 'LineWidth', 1.2);
            grid_ui(c_ext.ax_sigma); xlabel(c_ext.ax_sigma, 'Tiempo extrapolado (min)'); ylabel(c_ext.ax_sigma, 'Sigma media (C)');
            title(c_ext.ax_sigma, sprintf('Incertidumbre: %s', modelo_label));
        else
            text(c_ext.ax_sigma, 0.05, 0.55, 'Sin sigma extrapolada.', 'Units', 'normalized');
            axis(c_ext.ax_sigma, 'off'); title(c_ext.ax_sigma, 'Incertidumbre / sigma');
        end
    end

    function plot_ext_factor()
        cla(c_ext.ax_factor, 'reset'); tesis_auxiliares('tema_ui', 'axes', c_ext.ax_factor);
        if ~c_ext.usar_corr.Value
            text(c_ext.ax_factor, 0.05, 0.55, 'Correccion termica desactivada para esta construccion.', 'Units', 'normalized');
            axis(c_ext.ax_factor, 'off'); title(c_ext.ax_factor, 'Factor de correccion');
            return;
        end
        if isempty(state.corr) || ~isfield(state.corr, 'correccion_termica')
            text(c_ext.ax_factor, 0.05, 0.55, 'Sin correccion termica cargada.', 'Units', 'normalized');
            axis(c_ext.ax_factor, 'off'); title(c_ext.ax_factor, 'Factor de correccion');
            return;
        end
        ct = state.corr.correccion_termica;
        hold(c_ext.ax_factor, 'on');
        hay = false;
        zonas = zonas_correccion_ui(ct);
        if ~isempty(zonas)
            for zi = 1:numel(zonas)
                hay = plot_factor_ct(zonas(zi), sprintf('Zona %d', zi)) || hay;
            end
        else
            hay = plot_factor_ct(ct, 'Factor') || hay;
        end
        t_fin_abs = horizonte_factor_ext();
        if isfinite(t_fin_abs)
            t_rel_h = t_fin_abs - origen_ct_plot(ct);
            if isfinite(t_rel_h)
                xline(c_ext.ax_factor, t_rel_h, ':', 'Fin aplicado', 'HandleVisibility', 'off');
            end
        end
        hold(c_ext.ax_factor, 'off');
        if ~hay
            text(c_ext.ax_factor, 0.05, 0.55, 'Correccion sin factor_enfriamiento.', 'Units', 'normalized');
            axis(c_ext.ax_factor, 'off'); title(c_ext.ax_factor, 'Factor de correccion');
        else
            grid_ui(c_ext.ax_factor); xlabel(c_ext.ax_factor, 'Tiempo relativo (min)'); ylabel(c_ext.ax_factor, 'Factor');
            title(c_ext.ax_factor, 'Factor de correccion'); legend(c_ext.ax_factor, 'show', 'Location', 'best');
        end
    end

    function ok = plot_factor_ct(ct, nombre)
        ok = false;
        if ~isfield(ct, 't_rel_min') || ~isfield(ct, 'factor_enfriamiento')
            return;
        end
        t = double(ct.t_rel_min(:));
        f = double(ct.factor_enfriamiento(:));
        valido = isfinite(t) & isfinite(f);
        t = t(valido); f = f(valido);
        if numel(t) < 2
            return;
        end
        plot(c_ext.ax_factor, t, f, 'LineWidth', 1.2, 'DisplayName', nombre);
        ok = true;
        if ~isfield(ct, 'extrapolacion_factor')
            return;
        end
        t_fin_abs = horizonte_factor_ext();
        if ~isfinite(t_fin_abs)
            return;
        end
        t_rel_h = t_fin_abs - origen_ct_plot(ct);
        if isfinite(t_rel_h) && t_rel_h > max(t) + 1e-9
            tt = linspace(max(t), t_rel_h, 120);
            yy = arrayfun(@(tx) max(0, min(1, extrapolar_factor_plot(tx, ct.extrapolacion_factor))), tt);
            plot(c_ext.ax_factor, tt, yy, '--', 'LineWidth', 1.0, 'DisplayName', [nombre ' extrap']);
        end
    end

    function t_fin = horizonte_factor_ext()
        t_fin = NaN;
        if ~isempty(state.volumen) && isfield(state.volumen, 't_full') && ~isempty(state.volumen.t_full)
            vals = double(state.volumen.t_full(:));
            vals = vals(isfinite(vals));
            if ~isempty(vals)
                t_fin = max(vals);
                return;
            end
        end
        if isfinite(c_ext.t_extra.Value) && c_ext.t_extra.Value > 0
            t_fin = c_ext.t_extra.Value;
        end
    end

    function t0 = origen_ct_plot(ct)
        t0 = 0;
        if isfield(ct, 't_origen_simulacion_min') && isscalar(ct.t_origen_simulacion_min) && isfinite(ct.t_origen_simulacion_min)
            t0 = double(ct.t_origen_simulacion_min);
        end
    end

    function factor = extrapolar_factor_plot(t_rel_min, modelo)
        factor = 1;
        if isempty(modelo) || ~isstruct(modelo)
            return;
        end
        if ~isfield(modelo, 'metodo')
            if isfield(modelo, 'factor_inicio') && isfinite(modelo.factor_inicio)
                factor = modelo.factor_inicio;
            end
            return;
        end
        if strcmp(modelo.metodo, 'pca_temporal_embebido_ssa')
            factor = extrapolar_factor_pca_plot(t_rel_min, modelo);
        elseif isfield(modelo, 'factor_inicio') && isfinite(modelo.factor_inicio)
            factor = modelo.factor_inicio;
        end
    end

    function factor = extrapolar_factor_pca_plot(t_rel_min, modelo)
        campos = {'t_inicio_min', 'factor_inicio', 'paso_min', 'historia_centrada', ...
            'coeficientes_recurrencia', 'media_factor', 'max_cambio_por_paso', 'limites_extrapolacion'};
        for ci = 1:numel(campos)
            if ~isfield(modelo, campos{ci})
                factor = getfield_default_plot(modelo, 'factor_inicio', 1);
                return;
            end
        end
        dt = max(0, double(t_rel_min) - double(modelo.t_inicio_min));
        if dt == 0
            factor = modelo.factor_inicio;
            return;
        end
        paso_min = max(eps, double(modelo.paso_min));
        n_pasos = max(1, ceil(dt / paso_min));
        historia = double(modelo.historia_centrada(:));
        coef = double(modelo.coeficientes_recurrencia(:));
        valores = zeros(n_pasos + 1, 1);
        valores(1) = double(modelo.factor_inicio);
        for paso = 1:n_pasos
            if numel(historia) ~= numel(coef)
                factor = valores(paso);
                return;
            end
            siguiente_centrado = coef' * historia;
            anterior_centrado = valores(paso) - double(modelo.media_factor);
            cambio = siguiente_centrado - anterior_centrado;
            max_cambio = abs(double(modelo.max_cambio_por_paso));
            cambio = max(-max_cambio, min(max_cambio, cambio));
            siguiente = double(modelo.media_factor) + anterior_centrado + cambio;
            limites = double(modelo.limites_extrapolacion(:));
            if numel(limites) >= 2
                siguiente = max(limites(1), min(limites(2), siguiente));
            end
            valores(paso + 1) = siguiente;
            historia = [historia(2:end); siguiente - double(modelo.media_factor)];
        end
        tiempos = (0:n_pasos)' * paso_min;
        factor = interp1(tiempos, valores, dt, 'linear');
    end

    function val = getfield_default_plot(s, field, def)
        if isstruct(s) && isfield(s, field)
            val = s.(field);
        else
            val = def;
        end
    end

    function fail(etq, ME)
        estado.Text = ['Error ' etq '.']; logmsg('ERROR %s: %s', etq, ME.message); uialert(fig, ME.message, ['Error ' etq]);
    end
    function abrir(r), if isfolder(r) && ispc, winopen(r); else, logmsg('Ruta: %s', r); end, end
    function sep(), logbox.Value = [repmat({''}, 5, 1); logbox.Value(:)]; drawnow limitrate; end
    function logmsg(fmt, varargin)
        try
            msg = sprintf(fmt, varargin{:});
        catch
            msg = char(fmt);
        end
        parts = regexp(char(msg), '\r\n|\n|\r', 'split'); stamp = char(datetime('now', 'Format', 'HH:mm:ss')); add = {};
        for k = 1:numel(parts), s = strtrim(parts{k}); if ~isempty(s), add{end+1,1} = sprintf('[%s] %s', stamp, s); end, end %#ok<AGROW>
        if isempty(add), return; end
        logbox.Value = [add; logbox.Value(:)]; if numel(logbox.Value) > 700, logbox.Value = logbox.Value(1:700); end
        drawnow limitrate;
    end
end
function tf = hay_mats_particionados(carpeta)
    tf = false;
    if ~isfolder(carpeta)
        return;
    end
    ruta_indice = fullfile(carpeta, 'Indice_Datasets_Metadata.mat');
    if isfile(ruta_indice)
        try
            raw = load(ruta_indice, 'particiones');
            tf = isfield(raw, 'particiones') && isstruct(raw.particiones) && ...
                ~isempty(raw.particiones);
            if tf
                return;
            end
        catch
            % Indice incompleto: se conserva el escaneo de compatibilidad.
        end
    end
    archivos = dir(fullfile(carpeta, '**', '*.mat'));
    archivos = archivos(~[archivos.isdir]);
    for k = 1:numel(archivos)
        nombre = lower(archivos(k).name);
        ruta_archivo = fullfile(archivos(k).folder, archivos(k).name);
        if ~ruta_esta_en_repetidos_global(ruta_archivo) && endsWith(nombre, '.mat') && ...
                ~startsWith(nombre, 'indice_') && ...
                ~startsWith(nombre, 'reporte_') && ...
                ~contains(nombre, 'historial')
            tf = true;
            return;
        end
    end
end

function bootstrap_modulo()
    carpeta_modulo = fileparts(mfilename('fullpath'));
    candidatos_aux = {fullfile(carpeta_modulo, '..', 'aux_codes')};
    for k_aux = 1:numel(candidatos_aux)
        if isfolder(candidatos_aux{k_aux}), addpath(candidatos_aux{k_aux}); end
    end
    if exist('tesis_auxiliares', 'file') == 2
        tesis_auxiliares('configurar_paths', carpeta_modulo);
    end
end

% =========================================================================
% LOGICA INTEGRADA LOCAL
% =========================================================================

function ejecutar_exportador_mat_integrado(varargin)
    if nargin >= 1 && ischar(varargin{1}) && ...
            strcmpi(varargin{1}, 'selftest_metadata_paths')
        ejecutar_selftest_rutas_stl_corregidas();
        return;
    end
    comsol_mat_exportador_masivo(varargin{:});

% ---- Inicio copia local: comsol_mat_exportador_masivo.m ----
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

    carpeta_exportacion = crear_carpeta_exportacion(ruta_mat_entrada, config_ui);

    imprimir_separador();
    log_exportador('INICIANDO EXPORTACIÓN MASIVA DE STL Y TXT\n');
    imprimir_separador();

    rutas_mat = resolver_mats_exportador(ruta_mat_entrada);
    log_exportador('MAT a exportar: %d\n', numel(rutas_mat));
    for idx_mat = 1:numel(rutas_mat)
        ruta_mat_actual = rutas_mat{idx_mat};
        log_exportador('[MAT %d/%d] Cargando: %s ...\n', ...
            idx_mat, numel(rutas_mat), ruta_mat_actual);
        [dataset, carga_correcta, partition_meta] = cargar_dataset_desde_mat(ruta_mat_actual);
        if ~carga_correcta
            log_exportador('[WARN] MAT omitido por error de carga: %s\n', ruta_mat_actual);
            continue;
        end

        exportar_modelos(dataset, carpeta_exportacion, radio_alpha, ...
            iteraciones_suavizado, temperatura_min_stl, ...
            temperatura_max_stl_caso0, temperatura_max_stl_termo, ...
            partition_meta);
        clear dataset;
    end

    imprimir_separador();
    log_exportador('PROCESO FINALIZADO CON ÉXITO.\n');
    log_exportador('Todos los archivos válidos fueron guardados en:\n %s\n', carpeta_exportacion);
    imprimir_separador();
end

function lanzar_ui_comsol_mat_exportador_masivo()
    data_paths = tesis_auxiliares('dataset_paths');
    dataset_default = tesis_auxiliares('dataset_masivo_reciente', data_paths);
    if hay_mats_particionados(data_paths.datasets_masivos_por_metadata)
        dataset_default = data_paths.datasets_masivos_por_metadata;
    end
    entradas = struct( ...
        'key', 'ruta_mat_entrada', ...
        'label', 'MAT del extractor', ...
        'kind', 'file', ...
        'filter', {{'*.mat', 'Dataset termico del extractor (*.mat)'}}, ...
        'title', 'Selecciona el .mat del Extractor Masivo', ...
        'default', dataset_default);

    tesis_auxiliares('crear_dashboard_modulo',  ...
        'COMSOL MAT Exportador', ...
        ['Exporta STL por instante y TXT de sondas desde el .mat ', ...
         'estructurado generado por el extractor masivo.'], ...
        entradas, ...
        @(valores, logfn) ejecutar_desde_ui_comsol_mat_exportador(valores, logfn));
end

function ejecutar_desde_ui_comsol_mat_exportador(valores, logfn)
    if isempty(valores.ruta_mat_entrada) || ...
            ~(isfile(valores.ruta_mat_entrada) || isfolder(valores.ruta_mat_entrada))
        error('Selecciona un archivo .mat o una carpeta de particiones valida antes de ejecutar.');
    end
    valores.logfn = logfn;
    data_paths = tesis_auxiliares('dataset_paths');
    valores.carpeta_exportacion = data_paths.distribuciones_stl;
    logfn('MAT de entrada: %s', valores.ruta_mat_entrada);
    logfn('Salida optimizador STL: %s', valores.carpeta_exportacion);
    comsol_mat_exportador_masivo('run', valores);
    logfn('Exportacion STL/TXT terminada.');
end

function rutas_mat = resolver_mats_exportador(ruta_mat_entrada)
    if ruta_esta_en_repetidos_global(ruta_mat_entrada)
        error('La entrada STL esta dentro de repetidos y fue bloqueada: %s', ruta_mat_entrada);
    end
    if isfolder(ruta_mat_entrada)
        rutas_indice = resolver_mats_indice_exportador(ruta_mat_entrada);
        if ~isempty(rutas_indice)
            rutas_mat = rutas_indice;
            return;
        end
        archivos = dir(fullfile(ruta_mat_entrada, '**', '*.mat'));
        archivos = archivos(~[archivos.isdir]);
        keep = true(numel(archivos), 1);
        for k = 1:numel(archivos)
            nombre = lower(archivos(k).name);
            ruta_archivo = fullfile(archivos(k).folder, archivos(k).name);
            keep(k) = ~ruta_esta_en_repetidos_global(ruta_archivo) && ...
                endsWith(nombre, '.mat') && ...
                ~startsWith(nombre, 'indice_') && ...
                ~startsWith(nombre, 'reporte_') && ...
                ~contains(nombre, 'historial');
        end
        archivos = archivos(keep);
        [~, orden] = sort({archivos.name});
        archivos = archivos(orden);
        rutas_scan = arrayfun(@(a) fullfile(a.folder, a.name), ...
            archivos, 'UniformOutput', false);
        rutas_mat = unique([rutas_indice(:); rutas_scan(:)], 'stable')';
    else
        rutas_mat = {ruta_mat_entrada};
    end
    if isempty(rutas_mat)
        error('No se encontraron archivos .mat exportables en: %s', ruta_mat_entrada);
    end
end

function rutas_mat = resolver_mats_indice_exportador(carpeta)
    rutas_mat = {};
    ruta_indice = fullfile(carpeta, 'Indice_Datasets_Metadata.mat');
    if ~isfile(ruta_indice)
        return;
    end
    try
        raw = load(ruta_indice, 'particiones');
        if ~isfield(raw, 'particiones') || ~isstruct(raw.particiones) || ...
                ~isfield(raw.particiones, 'ruta')
            return;
        end
        rutas_mat = {raw.particiones.ruta};
        rutas_mat = rutas_mat(cellfun(@isfile, rutas_mat) & ...
            ~cellfun(@ruta_esta_en_repetidos_global, rutas_mat));
    catch
        rutas_mat = {};
    end
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

    data_paths = tesis_auxiliares('dataset_paths');
    dataset_default = tesis_auxiliares('dataset_masivo_reciente', data_paths);
    if hay_mats_particionados(data_paths.datasets_masivos_por_metadata)
        dataset_default = data_paths.datasets_masivos_por_metadata;
    end
    [archivo, carpeta] = uigetfile( ...
        '*.mat', ...
        'Selecciona el conjunto de datos (.mat) del Extractor Masivo', ...
        dataset_default);

    if isequal(archivo, 0)
        ruta_mat_entrada = '';
        return;
    end

    ruta_mat_entrada = fullfile(carpeta, archivo);
end

function [dataset, carga_correcta, partition_meta] = cargar_dataset_desde_mat(ruta_mat_entrada)
% cargar_dataset_desde_mat
% Carga el primer struct encontrado dentro del .mat. Se conserva la lógica
% original, donde el archivo generado por el extractor contiene una variable
% principal con la estructura del dataset.

    dataset = struct();
    carga_correcta = false;
    partition_meta = struct();

    if ruta_esta_en_repetidos_global(ruta_mat_entrada)
        log_exportador('[ERROR] El archivo esta en repetidos y no puede exportarse: %s\n', ...
            ruta_mat_entrada);
        return;
    end

    try
        datos_crudos = load(ruta_mat_entrada);
        nombres_variables = fieldnames(datos_crudos);

        if isempty(nombres_variables)
            log_exportador('[ERROR] El archivo .mat no contiene variables.\n');
            return;
        end

        if isfield(datos_crudos, 'dataset')
            dataset = datos_crudos.dataset;
        else
            for idx_var = 1:numel(nombres_variables)
                nombre_var = nombres_variables{idx_var};
                if isstruct(datos_crudos.(nombre_var)) && ...
                        ~ismember(nombre_var, {'partition_meta', 'particiones', 'omitidos', 'resumen'})
                    dataset = datos_crudos.(nombre_var);
                    break;
                end
            end
            if isempty(fieldnames(dataset))
                log_exportador('[ERROR] El archivo .mat no contiene dataset estructurado.\n');
                return;
            end
        end
        if isfield(datos_crudos, 'partition_meta') && isstruct(datos_crudos.partition_meta)
            partition_meta = datos_crudos.partition_meta;
        end
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
        data_paths = tesis_auxiliares('dataset_paths');
        carpeta_exportacion = data_paths.distribuciones_stl;
    end
    crear_carpeta_si_no_existe(carpeta_exportacion);
end

%% =========================================================================
%% EXPORTACIÓN PRINCIPAL
%% =========================================================================
function exportar_modelos(dataset, carpeta_exportacion, radio_alpha, ...
        iteraciones_suavizado, temperatura_min_stl, ...
        temperatura_max_stl_caso0, temperatura_max_stl_termo, partition_meta)
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
            temperatura_max_stl_termo, ...
            partition_meta);
    end
end

function exportar_datasets_de_modelo(estructura_modelo, nombre_modelo, ...
        carpeta_exportacion, radio_alpha, iteraciones_suavizado, ...
        temperatura_min_stl, temperatura_max_stl_caso0, ...
        temperatura_max_stl_termo, partition_meta)
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

        [metadata_util, motivo_metadata] = dataset_exportable_por_metadata( ...
            nombre_modelo, tag_dataset, partition_meta);
        if ~metadata_util
            log_exportador('Omitido: %s -> %s (%s)\n', nombre_modelo, tag_dataset, motivo_metadata);
            continue;
        end

        log_exportador('  [Dataset %d/%d] %s -> %s\n', ...
            indice_dataset, numel(tags_dataset), nombre_modelo, tag_dataset);

        subcarpeta_optimizador = subcarpeta_optimizador_desde_metadata( ...
            nombre_modelo, tag_dataset, partition_meta);
        carpeta_salida = fullfile(carpeta_exportacion, subcarpeta_optimizador);
        crear_carpeta_si_no_existe(carpeta_salida);
        idx_caso = extraer_caso_dataset_stl( ...
            tag_dataset, datos_solucion, partition_meta);
        temperatura_max_stl = seleccionar_maximo_termico_stl( ...
            idx_caso, temperatura_max_stl_caso0, ...
            temperatura_max_stl_termo, datos_solucion, partition_meta);
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
        [region_unica, n_regiones] = nube_termica_region_unica_stl(puntos, radio_alpha);
        if ~region_unica
            n_sin_puntos = n_sin_puntos + 1;
            eliminar_salida_stl_obsoleta(ruta_stl, ruta_done);
            log_exportador(['    [%d/%d] t=%.4f min omitido: nube termica ' ...
                'separada en %g regiones. No se genera STL multicomponente.\n'], ...
                posicion_temporal, numero_snapshots, snapshot.t_min, n_regiones);
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

        n_regiones = numRegions(forma_alpha);
        if n_regiones ~= 1
            log_exportador(['     [WARN] STL omitido en t=%.4f: nube termica ' ...
                'multicomponente (%g regiones).\n'], tiempo_min, n_regiones);
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

function [region_unica, n_regiones] = nube_termica_region_unica_stl(puntos, radio_alpha)
    region_unica = false;
    n_regiones = NaN;
    if ~tiene_puntos_suficientes(puntos)
        return;
    end
    try
        radio_alpha_local = calcular_radio_alpha(puntos, radio_alpha);
        forma_alpha = alphaShape(puntos(:, 1), puntos(:, 2), puntos(:, 3), radio_alpha_local);
        n_regiones = numRegions(forma_alpha);
        region_unica = n_regiones == 1;
    catch
        n_regiones = NaN;
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

function temperatura_max = seleccionar_maximo_termico_stl( ...
        idx_caso, temperatura_max_caso0, temperatura_max_termo, ...
        datos_solucion, partition_meta)
    if nargin >= 4 && es_dataset_corregido_stl(datos_solucion, partition_meta)
        temperatura_max = temperatura_max_termo;
    elseif idx_caso == 0
        temperatura_max = temperatura_max_caso0;
    else
        temperatura_max = temperatura_max_termo;
    end
end

function tf = es_dataset_corregido_stl(datos_solucion, partition_meta)
    tf = campo_logico_exportador(partition_meta, 'dataset_corregido');
    if tf || nargin < 1 || ~isstruct(datos_solucion) || ...
            ~isfield(datos_solucion, 'metadata') || ~isstruct(datos_solucion.metadata)
        return;
    end
    md = datos_solucion.metadata;
    tf = campo_logico_exportador(md, 'dataset_corregido');
    if ~tf && isfield(md, 'partition_meta') && isstruct(md.partition_meta)
        tf = campo_logico_exportador(md.partition_meta, 'dataset_corregido');
    end
    if ~tf && isfield(md, 'correccion_termica')
        tf = true;
    end
end

function tf = campo_logico_exportador(s, campo)
    tf = false;
    if isstruct(s) && isfield(s, campo) && ~isempty(s.(campo))
        valor = s.(campo);
        if islogical(valor)
            tf = logical(valor(1));
        elseif isnumeric(valor)
            valor = double(valor(1));
            tf = isfinite(valor) && valor ~= 0;
        end
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
    fprintf(identificador, 'created_at=%s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
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
    fprintf(identificador_archivo, 'Fecha Export. : %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
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

function subcarpeta = subcarpeta_optimizador_desde_metadata( ...
        nombre_modelo, tag_dataset, partition_meta)
    tipo = campo_meta_char_exportador(partition_meta, 'tipo');
    if isempty(tipo)
        tipo = extraer_primer_match(nombre_modelo, {'Doble_slot', 'Monopolo', 'Un_slot'}, 'Tipo_desconocido');
    end
    antena = campo_meta_char_exportador(partition_meta, 'antena');
    if isempty(antena)
        num_antenas = campo_meta_num_exportador(partition_meta, 'num_antenas');
        if isfinite(num_antenas)
            antena = sprintf('%dant', round(num_antenas));
        end
    end
    if isempty(antena)
        antena = regexp(nombre_modelo, '\d+ant', 'match', 'once');
    end
    if isempty(antena)
        antena = 'antenas_desconocidas';
    end
    caso_meta = campo_meta_num_exportador(partition_meta, 'caso');
    if isfinite(caso_meta)
        caso_txt = sprintf('Caso_%d', round(caso_meta));
    else
        caso = regexp(tag_dataset, 'c(\d+)', 'tokens', 'once');
        if isempty(caso)
            caso_txt = 'Caso_desconocido';
        else
            caso_txt = sprintf('Caso_%s', caso{1});
        end
    end
    potencia_meta = campo_meta_num_exportador(partition_meta, 'potencia_W');
    if isfinite(potencia_meta)
        potencia_txt = texto_potencia_exportador(potencia_meta);
    else
        potencia = regexp(tag_dataset, 'p(\d+)', 'tokens', 'once');
        if isempty(potencia)
            potencia_txt = 'Potencia_desconocida';
        else
            potencia_txt = sprintf('Potencia_%sW', potencia{1});
        end
    end
    subcarpeta = fullfile(tipo, antena, caso_txt, potencia_txt);
    carpetas_correccion = carpetas_metadata_correccion_global(partition_meta);
    if ~isempty(carpetas_correccion)
        subcarpeta = fullfile(subcarpeta, carpetas_correccion{:});
    end
end

function texto = texto_potencia_exportador(potencia)
    texto = sprintf('Potencia_%gW', double(potencia));
    texto = strrep(texto, '.', 'p');
end

function valor = campo_meta_char_exportador(meta, campo)
    valor = '';
    if isstruct(meta) && isfield(meta, campo) && ~isempty(meta.(campo))
        valor = char(meta.(campo));
    end
end

function valor = campo_meta_num_exportador(meta, campo)
    valor = NaN;
    if isstruct(meta) && isfield(meta, campo) && isnumeric(meta.(campo)) && ...
            isscalar(meta.(campo)) && isfinite(double(meta.(campo)))
        valor = double(meta.(campo));
    end
end

function tf = metadata_particion_exportable(partition_meta)
    tf = false;
    if ~isstruct(partition_meta)
        return;
    end
    tipo = campo_meta_char_exportador(partition_meta, 'tipo');
    antena = campo_meta_char_exportador(partition_meta, 'antena');
    num_antenas = campo_meta_num_exportador(partition_meta, 'num_antenas');
    caso = campo_meta_num_exportador(partition_meta, 'caso');
    potencia = campo_meta_num_exportador(partition_meta, 'potencia_W');
    tf = ~isempty(tipo) && (~isempty(antena) || isfinite(num_antenas)) && ...
        isfinite(caso) && isfinite(potencia);
end

function [es_util, motivo] = dataset_exportable_por_metadata( ...
        nombre_modelo, tag_dataset, partition_meta)
    es_util = false;
    motivo = '';

    if nargin >= 3 && metadata_particion_exportable(partition_meta)
        es_util = true;
        return;
    end

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

function idx_caso = extraer_caso_dataset_stl(tag_dataset, datos_solucion, partition_meta)
    idx_caso = NaN;
    token = regexp(tag_dataset, '(?:^|_)c(\d+)(?:_|$)', ...
        'tokens', 'once', 'ignorecase');
    if ~isempty(token)
        idx_caso = str2double(token{1});
    end
    if ~isfinite(idx_caso) && nargin >= 3
        idx_caso = campo_meta_num_exportador(partition_meta, 'caso');
    end
    if ~isfinite(idx_caso) && isfield(datos_solucion, 'metadata') && ...
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
    if iscell(texto)
        if isempty(texto)
            texto = '';
        else
            texto = char(texto{1});
        end
    elseif isstring(texto)
        if isempty(texto)
            texto = '';
        else
            texto = char(texto(1));
        end
    else
        texto = char(texto);
    end
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

function ejecutar_selftest_rutas_stl_corregidas()
    meta = struct('tipo', 'Monopolo', 'antena', '1ant', ...
        'num_antenas', 1, 'caso', 1, 'potencia_W', 30, ...
        'dataset_corregido', true, ...
        'tag_correccion', 'correccion_junio_19_20min_prueba_1_zonas_4');
    ruta_19 = strrep(subcarpeta_optimizador_desde_metadata( ...
        'modelo_Monopolo_1ant', 'dset_c1_p30', meta), '\', '/');
    esperada = ['Monopolo/1ant/Caso_1/Potencia_30W/' ...
        'Fecha_junio_19/Tiempo_20min/Prueba_1/Zonas_4'];
    assert(strcmpi(ruta_19, esperada), ...
        'La ruta STL no conserva la metadata experimental completa.');
    meta.tag_correccion = 'correccion_junio_22_20min_prueba_1_zonas_4';
    ruta_22 = strrep(subcarpeta_optimizador_desde_metadata( ...
        'modelo_Monopolo_1ant', 'dset_c1_p30', meta), '\', '/');
    assert(~strcmpi(ruta_19, ruta_22), ...
        'Dos fechas de correccion resolvieron la misma carpeta STL.');
    fprintf('SELFTEST_STL_METADATA_PATHS_OK %s | %s\n', ruta_19, ruta_22);
end

% ---- Fin copia local: comsol_mat_exportador_masivo.m ----
end
function ejecutar_preprocesador_stl_integrado(varargin)
    if nargin >= 1 && ischar(varargin{1}) && ...
            strcmpi(varargin{1}, 'selftest_metadata_paths')
        ejecutar_selftest_metadata_voxel_corregido();
        return;
    end
    preprocesar_stl_a_mat(varargin{:});

% ---- Inicio copia local: preprocesar_stl_a_mat.m ----
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
        data_paths = tesis_auxiliares('dataset_paths');
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
    archivos_stl = archivos_stl(~arrayfun(@(a) ruta_esta_en_repetidos_global( ...
        fullfile(a.folder, a.name)), archivos_stl));
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
        metadata = crear_metadata_preprocesamiento_stl( ...
            ruta_relativa, ruta_stl, tipo_procesamiento, resolucion);

        [ruta_util, motivo_metadata] = ruta_stl_tiene_metadata_util(metadata);
        if ~ruta_util
            n_omitidos_metadata = n_omitidos_metadata + 1;
            log_preprocesador('Distribucion %d/%d: %s ... Omitida: %s.\n', ...
                indice_archivo, numel(archivos_stl), ruta_relativa, motivo_metadata);
            continue;
        end

        if ~ruta_stl_pasa_filtro_metadata_preprocesador(metadata, filtro_metadata)
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
            ruta_salida, tipo_procesamiento, forma, grid_x, grid_y, grid_z, centro, resolucion, metadata);
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

function [es_util, motivo] = ruta_stl_tiene_metadata_util(metadata_o_ruta)
    metadata = asegurar_metadata_stl_preprocesador(metadata_o_ruta);
    es_util = false;

    if isempty(metadata.tipo)
        motivo = 'sin tipo de antena reconocible';
        return;
    end

    if isempty(metadata.antena)
        motivo = 'sin numero de antenas reconocible';
        return;
    end

    if isempty(metadata.caso)
        motivo = 'sin carpeta Caso_X';
        return;
    end

    if isempty(metadata.potencia)
        motivo = 'sin carpeta Potencia_YW';
        return;
    end

    if ~metadata.es_geometria_ablacion
        motivo = 'archivo STL no corresponde a geometria de ablacion';
        return;
    end

    es_util = true;
    motivo = 'metadata util';
end

function pasa = ruta_stl_pasa_filtro_metadata_preprocesador(metadata_o_ruta, filtro_metadata)
    pasa = true;
    if ~isstruct(filtro_metadata) || isempty(fieldnames(filtro_metadata))
        return;
    end

    metadata = asegurar_metadata_stl_preprocesador(metadata_o_ruta);
    filtro_tipo = obtener_valor_filtro_preprocesador(filtro_metadata, {'tipo'});
    if ~isempty(filtro_tipo)
        pasa = pasa && strcmpi(metadata.tipo, char(filtro_tipo));
    end
    filtro_antena = obtener_valor_filtro_preprocesador(filtro_metadata, {'antena', 'antenas'});
    if ~isempty(filtro_antena)
        pasa = pasa && strcmpi(metadata.antena, char(filtro_antena));
    end
    filtro_caso = obtener_valor_filtro_preprocesador(filtro_metadata, {'caso'});
    if ~isempty(filtro_caso)
        caso_meta = normalizar_token_numerico_preprocesador(metadata.caso, 'caso');
        caso_filtro = normalizar_token_numerico_preprocesador(filtro_caso, 'caso');
        pasa = pasa && strcmpi(caso_meta, caso_filtro);
    end
    filtro_potencia = obtener_valor_filtro_preprocesador(filtro_metadata, {'potencia'});
    if ~isempty(filtro_potencia)
        potencia_meta = normalizar_token_numerico_preprocesador(metadata.potencia, 'potencia');
        potencia_filtro = normalizar_token_numerico_preprocesador(filtro_potencia, 'potencia');
        pasa = pasa && strcmpi(potencia_meta, potencia_filtro);
    end
    filtro_fecha = obtener_valor_filtro_preprocesador( ...
        filtro_metadata, {'fecha_adquisicion', 'fecha'});
    if ~isempty(filtro_fecha)
        pasa = pasa && strcmpi(metadata.fecha_adquisicion, char(filtro_fecha));
    end
    filtro_tiempo = obtener_valor_filtro_preprocesador( ...
        filtro_metadata, {'tiempo_ejecucion_min'});
    if filtro_numerico_definido_preprocesador(filtro_tiempo)
        pasa = pasa && numeros_metadata_iguales_preprocesador( ...
            metadata.tiempo_ejecucion_min, filtro_tiempo);
    end
    filtro_prueba = obtener_valor_filtro_preprocesador( ...
        filtro_metadata, {'numero_prueba'});
    if filtro_numerico_definido_preprocesador(filtro_prueba)
        pasa = pasa && numeros_metadata_iguales_preprocesador( ...
            metadata.numero_prueba, filtro_prueba);
    end
    filtro_zonas = obtener_valor_filtro_preprocesador( ...
        filtro_metadata, {'num_zonas'});
    if filtro_numerico_definido_preprocesador(filtro_zonas)
        pasa = pasa && numeros_metadata_iguales_preprocesador( ...
            metadata.num_zonas, filtro_zonas);
    end
end

function tf = filtro_numerico_definido_preprocesador(valor)
    tf = ~isempty(valor);
    if tf && isnumeric(valor)
        tf = isscalar(valor) && isfinite(double(valor));
    end
end

function tf = numeros_metadata_iguales_preprocesador(a, b)
    a = numero_metadata_preprocesador(a);
    b = numero_metadata_preprocesador(b);
    tf = isfinite(a) && isfinite(b) && abs(a - b) < 1e-9;
end

function valor = numero_metadata_preprocesador(valor)
    if isnumeric(valor) && isscalar(valor)
        valor = double(valor);
    else
        token = regexp(lower(char(valor)), '[-+]?\d+(?:[p.]\d+)?', ...
            'match', 'once');
        if isempty(token)
            valor = NaN;
        else
            valor = str2double(strrep(token, 'p', '.'));
        end
    end
end

function metadata = asegurar_metadata_stl_preprocesador(metadata_o_ruta)
    if isstruct(metadata_o_ruta)
        metadata = metadata_o_ruta;
        if ~isfield(metadata, 'es_geometria_ablacion')
            ruta = lower(strrep(campo_char_preprocesador(metadata, 'ruta_relativa'), '\', '/'));
            metadata.es_geometria_ablacion = contains(ruta, 'geometria_ablacion');
        end
        return;
    end
    metadata = crear_metadata_preprocesamiento_stl(char(metadata_o_ruta), '', '', NaN);
end

function valor = obtener_valor_filtro_preprocesador(filtro_metadata, campos)
    valor = '';
    for k = 1:numel(campos)
        campo = campos{k};
        if isfield(filtro_metadata, campo) && ~isempty(filtro_metadata.(campo))
            valor = filtro_metadata.(campo);
            return;
        end
    end
end

function token = normalizar_token_numerico_preprocesador(valor, tipo)
    if isnumeric(valor) && isscalar(valor) && isfinite(double(valor))
        token = sprintf('%g', double(valor));
        return;
    end
    token = lower(char(valor));
    token = strrep(token, ' ', '');
    switch tipo
        case 'caso'
            token = regexprep(token, '^(caso_|caso|c)', '');
            token = strrep(token, 'p', '.');
        case 'potencia'
            token = regexprep(token, '^(potencia_|potencia|p)', '');
            token = regexprep(token, 'w$', '');
            token = strrep(token, 'p', '.');
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

function guardar_representacion_volumetrica(ruta_salida, tipo_procesamiento, forma, grid_x, grid_y, grid_z, centro, resolucion, metadata)
    puntos_rejilla = [grid_x(:), grid_y(:), grid_z(:)];
    mascara = inpolyhedron(forma, puntos_rejilla);
    mascara = reshape(mascara, size(grid_x));

    % Alias de compatibilidad: el optimizador histórico espera gridX/gridY/gridZ.
    gridX = grid_x;
    gridY = grid_y;
    gridZ = grid_z;

    switch tipo_procesamiento
        case 'mascara'
            save(ruta_salida, 'mascara', 'grid_x', 'grid_y', 'grid_z', 'gridX', 'gridY', 'gridZ', 'centro', 'resolucion', 'metadata');
            log_preprocesador('  mascara guardada.\n');

        case 'sdf'
            sdf = (bwdist(mascara) - bwdist(~mascara)) * resolucion;
            save(ruta_salida, 'sdf', 'grid_x', 'grid_y', 'grid_z', 'gridX', 'gridY', 'gridZ', 'centro', 'resolucion', 'metadata');
            log_preprocesador('  SDF guardada.\n');

        case 'tsdf'
            sdf = (bwdist(mascara) - bwdist(~mascara)) * resolucion;
            distancia_truncamiento = 2 * resolucion;
            truncDist = distancia_truncamiento;
            tsdf = max(-distancia_truncamiento, min(distancia_truncamiento, sdf));
            save(ruta_salida, 'tsdf', 'grid_x', 'grid_y', 'grid_z', 'gridX', 'gridY', 'gridZ', ...
                'centro', 'resolucion', 'distancia_truncamiento', 'truncDist', 'metadata');
            log_preprocesador('  TSDF guardada.\n');
    end
end

function metadata = crear_metadata_preprocesamiento_stl(ruta_relativa, ruta_stl, tipo_procesamiento, resolucion)
    ruta_normalizada = normalizar_texto_metadata_preprocesador(ruta_relativa);
    ruta_normalizada = strrep(ruta_normalizada, '\', '/');
    metadata = struct();
    metadata.ruta_stl = ruta_stl;
    metadata.ruta_relativa = ruta_normalizada;
    metadata.tipo_procesamiento = char(tipo_procesamiento);
    metadata.resolucion = resolucion;
    metadata.tipo = extraer_primer_match_preprocesador( ...
        ruta_normalizada, {'Doble_slot', 'Monopolo', 'Un_slot'}, '');
    metadata.antena = regexp(ruta_normalizada, '\d+ant', 'match', 'once');
    metadata.caso = extraer_token_metadata_preprocesamiento(ruta_normalizada, 'Caso_([0-9]+)');
    metadata.potencia = extraer_token_metadata_preprocesamiento(ruta_normalizada, 'Potencia_([0-9]+(?:p[0-9]+)?)W');
    meta_corr = metadata_especifica_correccion_global(ruta_normalizada);
    metadata.fecha_adquisicion = meta_corr.fecha_adquisicion;
    metadata.tiempo_ejecucion_min = meta_corr.tiempo_ejecucion_min;
    metadata.numero_prueba = meta_corr.numero_prueba;
    metadata.num_zonas = meta_corr.num_zonas;
    metadata.zona_experimental = meta_corr.zona_experimental;
    metadata.tag_correccion = meta_corr.tag_correccion;
    metadata.dataset_corregido = ~isempty(meta_corr.fecha_adquisicion) || ...
        contains(lower(ruta_normalizada), 'correccion');
    metadata.es_geometria_ablacion = contains(lower(ruta_normalizada), 'geometria_ablacion');
    metadata.fuente_metadata = 'ruta_stl';
    metadata = completar_metadata_stl_desde_sidecar_preprocesador(metadata);
    metadata.fecha_preprocesamiento = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function valor = extraer_primer_match_preprocesador(texto, candidatos, valor_default)
    valor = valor_default;
    texto = normalizar_texto_metadata_preprocesador(texto);
    for k = 1:numel(candidatos)
        if contains(texto, candidatos{k}, 'IgnoreCase', true)
            valor = candidatos{k};
            return;
        end
    end
end

function texto = normalizar_texto_metadata_preprocesador(valor)
    if iscell(valor)
        if isempty(valor)
            texto = '';
        else
            texto = char(valor{1});
        end
    elseif isstring(valor)
        if isempty(valor)
            texto = '';
        else
            texto = char(valor(1));
        end
    else
        texto = char(valor);
    end
end

function valor = extraer_token_metadata_preprocesamiento(texto, patron)
    texto = normalizar_texto_metadata_preprocesador(texto);
    token = regexp(texto, patron, 'tokens', 'once');
    if isempty(token)
        valor = '';
    else
        valor = strrep(token{1}, 'p', '.');
    end
end

function metadata = completar_metadata_stl_desde_sidecar_preprocesador(metadata)
    ruta_stl = campo_char_preprocesador(metadata, 'ruta_stl');
    if isempty(ruta_stl)
        return;
    end
    [carpeta_stl, nombre_stl, ~] = fileparts(ruta_stl);
    candidatos = { ...
        fullfile(carpeta_stl, [nombre_stl '_metadata.mat']), ...
        fullfile(carpeta_stl, 'metadata.mat')};
    for k = 1:numel(candidatos)
        if ~isfile(candidatos{k})
            continue;
        end
        try
            raw = load(candidatos{k});
            md = extraer_struct_metadata_preprocesador(raw);
            if ~isempty(md)
                metadata = fusionar_metadata_stl_preprocesador(metadata, md, candidatos{k});
                return;
            end
        catch
        end
    end
end

function md = extraer_struct_metadata_preprocesador(raw)
    md = [];
    candidatos = {'metadata', 'partition_meta', 'metadata_dataset'};
    for k = 1:numel(candidatos)
        campo = candidatos{k};
        if isstruct(raw) && isfield(raw, campo) && isstruct(raw.(campo))
            md = raw.(campo);
            return;
        end
    end
    if isstruct(raw)
        campos = fieldnames(raw);
        for k = 1:numel(campos)
            if isstruct(raw.(campos{k}))
                md = raw.(campos{k});
                return;
            end
        end
    end
end

function metadata = fusionar_metadata_stl_preprocesador(metadata, md, ruta_sidecar)
    if isfield(md, 'tipo') && ~isempty(md.tipo)
        metadata.tipo = char(md.tipo);
    end
    if isfield(md, 'antena') && ~isempty(md.antena)
        if isnumeric(md.antena) && isscalar(md.antena)
            metadata.antena = sprintf('%dant', round(double(md.antena)));
        else
            metadata.antena = char(md.antena);
        end
    elseif isfield(md, 'num_antenas') && isnumeric(md.num_antenas) && isscalar(md.num_antenas)
        metadata.antena = sprintf('%dant', round(double(md.num_antenas)));
    end
    if isfield(md, 'caso') && ~isempty(md.caso)
        metadata.caso = texto_metadata_preprocesador(md.caso);
    elseif isfield(md, 'idx_caso') && ~isempty(md.idx_caso)
        metadata.caso = texto_metadata_preprocesador(md.idx_caso);
    end
    if isfield(md, 'potencia') && ~isempty(md.potencia)
        metadata.potencia = texto_metadata_preprocesador(md.potencia);
    elseif isfield(md, 'potencia_W') && ~isempty(md.potencia_W)
        metadata.potencia = texto_metadata_preprocesador(md.potencia_W);
    end
    metadata.fuente_metadata = ruta_sidecar;
end

function texto = texto_metadata_preprocesador(valor)
    if isnumeric(valor) && isscalar(valor) && isfinite(double(valor))
        texto = sprintf('%g', double(valor));
    else
        texto = char(valor);
    end
end

function valor = campo_char_preprocesador(s, campo)
    valor = '';
    if isstruct(s) && isfield(s, campo) && ~isempty(s.(campo))
        valor = char(s.(campo));
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
    fprintf(identificador, 'created_at=%s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    fprintf(identificador, 'signature=%s\n', firma_preprocesamiento);
    clear limpieza;
end

function carpeta_salida = obtener_carpeta_salida_mat(carpeta_stl, config)
    carpeta_salida = obtener_campo_config_local(config, 'carpeta_salida', '');
    if ~isempty(carpeta_salida)
        return;
    end
    data_paths = tesis_auxiliares('dataset_paths');
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

function ejecutar_selftest_metadata_voxel_corregido()
    ruta = fullfile('Monopolo', '1ant', 'Caso_1', 'Potencia_30W', ...
        'Fecha_junio_19', 'Tiempo_20min', 'Prueba_1', 'Zonas_4', ...
        'Geometria_Ablacion_t5.0000min.stl');
    metadata = crear_metadata_preprocesamiento_stl(ruta, '', 'sdf', 0.5);
    assert(strcmp(metadata.fecha_adquisicion, 'junio_19'));
    assert(metadata.tiempo_ejecucion_min == 20);
    assert(metadata.numero_prueba == 1 && metadata.num_zonas == 4);
    filtro = struct('tipo', 'Monopolo', 'antena', '1ant', ...
        'caso', 'c1', 'potencia', 'p30', ...
        'fecha_adquisicion', 'junio_19', ...
        'tiempo_ejecucion_min', 20, 'numero_prueba', 1, 'num_zonas', 4);
    assert(ruta_stl_pasa_filtro_metadata_preprocesador(metadata, filtro));
    filtro.fecha_adquisicion = 'junio_22';
    assert(~ruta_stl_pasa_filtro_metadata_preprocesador(metadata, filtro));
    fprintf(['SELFTEST_VOXEL_METADATA_PATHS_OK fecha=%s tiempo=%g ' ...
        'prueba=%g zonas=%g\n'], metadata.fecha_adquisicion, ...
        metadata.tiempo_ejecucion_min, metadata.numero_prueba, ...
        metadata.num_zonas);
end

% ---- Fin copia local: preprocesar_stl_a_mat.m ----
end
function varargout = ejecutar_correlador_volumen_integrado(varargin)
    if nargin >= 1 && ischar(varargin{1})
        accion = lower(varargin{1});
        switch accion
            case 'leer_experimental'
                if nargin >= 3, tiempo_seg = varargin{3}; else, tiempo_seg = true; end
                varargout{1} = leer_experimental(varargin{2}, tiempo_seg); return;
            case 'leer_txt_sondas'
                varargout{1} = leer_txt_sondas(varargin{2}); return;
            case 'calcular_correlacion'
                varargout{1} = calcular_correlacion(varargin{2}); return;
            case 'guardar_correccion'
                ruta_guardada = guardar_correccion_mat(varargin{2}, varargin{3});
                if nargout > 0, varargout{1} = ruta_guardada; end
                return;
            case 'nombre_correccion'
                varargout{1} = nombre_correccion_default(varargin{2}); return;
            case 'ruta_relativa_correccion'
                varargout{1} = ruta_relativa_correccion_default(varargin{2}); return;
            case 'cargar_dataset'
                varargout{1} = cargar_dataset_termico(varargin{2}); return;
            case 'construir_volumen'
                if nargin >= 4, logfn = varargin{4}; else, logfn = []; end
                varargout{1} = construir_funcion_volumen(varargin{2}, varargin{3}, logfn); return;
            case 'exportar_volumen'
                if nargin >= 4, logfn = varargin{4}; else, logfn = []; end
                varargout{1} = exportar_volumen_desde_resultado(varargin{2}, varargin{3}, logfn); return;
            case 'reaplicar_correccion_volumen'
                varargout{1} = reaplicar_correccion_volumen_resultado(varargin{2}, varargin{3}, varargin{4}); return;
            case 'selftest_limite_volumen'
                ejecutar_selftest_limite_volumen();
                if nargout > 0, varargout{1} = true; end
                return;
            case 'selftest_metadata_corr'
                ejecutar_selftest_metadata_correlacion();
                if nargout > 0, varargout{1} = true; end
                return;
        end
    end
    correlador_volumen_interpolado_ui(varargin{:});
    if nargout > 0, varargout{1} = []; end

% ---- Inicio copia local: correlador_volumen_interpolado_ui.m ----
function correlador_volumen_interpolado_ui(varargin)
%CORRELADOR_VOLUMEN_INTERPOLADO_UI Correlacion + funcion volumen en UI.
%
% Modulo fusionado que elimina la interaccion por consola de:
%   - correlador_polinomial_dual
%   - funcion_volumen_interpolada
%
% Los modulos originales se conservan intactos. Este archivo concentra el
% flujo en una interfaz por pasos y reutiliza la misma convencion de salida:
% correccion_termica, p_arreglo, T4D_*.mat y T_funcion_*.m.
    if nargin > 0 && ischar(varargin{1}) && strcmpi(varargin{1}, 'selftest')
        ejecutar_selftest(varargin{2:end});
        return;
    end

    theme = tesis_auxiliares('tema_ui');
    state = struct();
    state.ruta_exp = '';
    state.ruta_sim = '';
    state.ruta_dataset = '';
    data_paths = tesis_auxiliares('dataset_paths');
    state.carpeta_exportacion = data_paths.volumen_4d;
    state.exp = [];
    state.sim = [];
    state.dataset = [];
    state.modelos = {};
    state.datasets = {};
    state.correccion = [];
    state.resultado_volumen = [];
    state.actualizando = false;
    state.indice_tiempo_4d = 1;

    W = 1520;
    H = 920;
    xCtrl = 12;
    wCtrl = 450;
    xMain = 480;
    wMain = 1020;

    fig = uifigure('Name', 'Correlador + Funcion Volumen Interpolada', ...
        'Position', [25 25 W H], ...
        'Color', theme.colors.bg, ...
        'Resize', 'off');

    uilabel(fig, 'Position', [xCtrl 878 wCtrl 28], ...
        'Text', 'CORRELACION Y FUNCION VOLUMEN', ...
        'HorizontalAlignment', 'center', ...
        'FontSize', 14, ...
        'FontWeight', 'bold', ...
        'FontColor', theme.colors.accent);

    tabsAnalisis = uitabgroup(fig, 'Position', [xMain 185 wMain 710]);
    tabCorr = uitab(tabsAnalisis, 'Title', 'Analisis 2D');
    tab4D = uitab(tabsAnalisis, 'Title', 'Vista 3D');

    pnlCorr = uipanel(tabCorr, 'Title', 'Correlacion simulacion vs experimento', ...
        'Position', [10 355 995 320]);
    axCorr = uiaxes(pnlCorr, 'Position', [12 12 970 275]);

    pnlFuncion = uipanel(tabCorr, 'Title', 'Funcion de correccion', ...
        'Position', [10 10 490 330]);
    axFuncion = uiaxes(pnlFuncion, 'Position', [10 10 470 285]);

    pnlVol = uipanel(tabCorr, 'Title', 'Volumen y extrapolacion 2D', ...
        'Position', [515 10 490 330]);
    axVol = uiaxes(pnlVol, 'Position', [12 12 465 285]);

    pnlPlanos = uipanel(tab4D, 'Title', 'Planos ortogonales T(x,y,z,t)', ...
        'Position', [10 10 490 665]);
    axXY = uiaxes(pnlPlanos, 'Position', [10 370 225 230]);
    axXZ = uiaxes(pnlPlanos, 'Position', [252 370 225 230]);
    axYZ = uiaxes(pnlPlanos, 'Position', [132 82 225 230]);

    pnl3D = uipanel(tab4D, 'Title', 'Visualizacion 3D de correccion', ...
        'Position', [510 10 495 665]);
    ax3D = uiaxes(pnl3D, 'Position', [10 10 475 620]);

    pnlLog = uipanel(fig, 'Title', 'Registro de eventos', ...
        'Position', [xMain 20 wMain 150]);
    txtLog = uitextarea(pnlLog, ...
        'Position', [8 8 wMain-16 116], ...
        'Editable', 'off', ...
        'Value', {'Listo.'});

    crear_seccion('1. Archivos y recorte', 846);
    btnExp = uibutton(fig, 'Position', [xCtrl 818 162 28], ...
        'Text', 'Experimental CSV/XLS', ...
        'ButtonPushedFcn', @cargar_experimental);
    lblExp = uilabel(fig, 'Position', [xCtrl+172 822 276 20], ...
        'Text', '--', 'Interpreter', 'none');

    btnSim = uibutton(fig, 'Position', [xCtrl 784 162 28], ...
        'Text', 'Simulacion TXT', ...
        'ButtonPushedFcn', @cargar_simulacion_txt);
    lblSim = uilabel(fig, 'Position', [xCtrl+172 788 276 20], ...
        'Text', '--', 'Interpreter', 'none');

    uilabel(fig, 'Position', [xCtrl 752 94 20], 'Text', 'Sonda TXT:');
    ddSonda = uidropdown(fig, 'Position', [xCtrl+96 750 180 24], ...
        'Items', {'P1'}, 'Value', 'P1', ...
        'ValueChangedFcn', @actualizar_correlacion_tiempo_real);

    crear_mini_label('Exp inicio:', 722, 0);
    edExpIni = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl 700 118 24], 'Value', 1, 'Limits', [1 Inf], ...
        'ValueChangedFcn', @actualizar_correlacion_tiempo_real);
    crear_mini_label('Exp fin:', 722, 152);
    edExpFin = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl+152 700 118 24], 'Value', 0, 'Limits', [0 Inf], ...
        'ValueChangedFcn', @actualizar_correlacion_tiempo_real);
    crear_mini_label('Grado polinomio:', 722, 306);
    edGrado = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl+306 700 142 24], 'Value', 6, 'Limits', [1 12], ...
        'ValueChangedFcn', @actualizar_correlacion_tiempo_real);

    crear_mini_label('Sim inicio:', 672, 0);
    edSimIni = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl 650 118 24], 'Value', 1, 'Limits', [1 Inf], ...
        'ValueChangedFcn', @actualizar_correlacion_tiempo_real);
    crear_mini_label('Sim fin:', 672, 152);
    edSimFin = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl+152 650 118 24], 'Value', 0, 'Limits', [0 Inf], ...
        'ValueChangedFcn', @actualizar_correlacion_tiempo_real);
    crear_mini_label('N comun:', 672, 306);
    edNComun = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl+306 650 142 24], 'Value', 1000, 'Limits', [20 Inf], ...
        'ValueChangedFcn', @actualizar_correlacion_tiempo_real);

    btnRunCorr = uibutton(fig, 'Position', [xCtrl 612 216 28], ...
        'Text', 'Calcular correccion', ...
        'ButtonPushedFcn', @calcular_correlacion_ui);
    btnSaveCorr = uibutton(fig, 'Position', [xCtrl+232 612 216 28], ...
        'Text', 'Guardar .mat', ...
        'ButtonPushedFcn', @guardar_correccion_ui);

    crear_seccion('2. Dataset termico', 582);
    btnDataset = uibutton(fig, 'Position', [xCtrl 554 162 28], ...
        'Text', 'Dataset masivo .mat', ...
        'ButtonPushedFcn', @cargar_dataset);
    lblDataset = uilabel(fig, 'Position', [xCtrl+172 558 276 20], ...
        'Text', '--', 'Interpreter', 'none');
    uilabel(fig, 'Position', [xCtrl 524 64 20], 'Text', 'Modelo:');
    ddModelo = uidropdown(fig, 'Position', [xCtrl+70 522 378 24], ...
        'Items', {'(sin dataset)'}, 'Value', '(sin dataset)', ...
        'ValueChangedFcn', @actualizar_datasets);
    uilabel(fig, 'Position', [xCtrl 494 64 20], 'Text', 'Dataset:');
    ddDataset = uidropdown(fig, 'Position', [xCtrl+70 492 378 24], ...
        'Items', {'(sin dataset)'}, 'Value', '(sin dataset)');

    crear_seccion('3. Configuracion volumen 4D', 464);
    crear_mini_label('Nx:', 438, 0);
    edNx = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl 416 98 24], 'Value', 45, 'Limits', [5 120]);
    crear_mini_label('Ny:', 438, 116);
    edNy = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl+116 416 98 24], 'Value', 45, 'Limits', [5 120]);
    crear_mini_label('Nz:', 438, 232);
    edNz = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl+232 416 98 24], 'Value', 45, 'Limits', [5 120]);
    crear_mini_label('T abl:', 388, 0);
    edTAbl = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl 366 98 24], 'Value', 60);
    crear_mini_label('Fin ext (min):', 388, 116);
    edTExtra = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl+116 366 98 24], 'Value', 0, ...
        'Tooltip', 'Minuto final de extrapolacion. Si es 0, se usa automatico: 1.5x el tiempo simulado.');
    crear_mini_label('Estrategia:', 388, 350);
    ddEstrategia = uidropdown(fig, 'Position', [xCtrl+350 366 98 24], ...
        'Items', {'PCA temporal', 'LOWESS', 'Gradiente local'}, ...
        'Value', 'PCA temporal', ...
        'ValueChangedFcn', @actualizar_analisis_4d);
    uilabel(fig, 'Position', [xCtrl 338 118 20], 'Text', 'Tiempo vista 3D:');
    lblTiempoVista = uilabel(fig, 'Position', [xCtrl+124 338 324 20], ...
        'Text', 'sin volumen construido', ...
        'FontSize', 9, ...
        'FontColor', theme.colors.textMuted);
    sldTiempo4D = uislider(fig, 'Position', [xCtrl+8 320 432 3], ...
        'Limits', [1 2], ...
        'Value', 1, ...
        'MajorTicks', [1 2], ...
        'MajorTickLabels', {'', ''}, ...
        'Enable', 'off', ...
        'ValueChangingFcn', @actualizar_tiempo_4d_desde_slider, ...
        'ValueChangedFcn', @actualizar_tiempo_4d_desde_slider);

    crear_seccion('4. Correccion y exportacion', 298);
    chkUsarCorreccion = uicheckbox(fig, 'Position', [xCtrl 270 146 22], ...
        'Text', 'Usar correccion', 'Value', true, ...
        'ValueChangedFcn', @actualizar_correccion_4d_y_redibujar);
    chkOffset = uicheckbox(fig, 'Position', [xCtrl+154 270 190 22], ...
        'Text', 'Offset basal', 'Value', true, ...
        'ValueChangedFcn', @actualizar_correccion_4d_y_redibujar);
    uilabel(fig, 'Position', [xCtrl+350 270 58 20], 'Text', 'Intens:');
    edIntensidad = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl+400 268 48 24], 'Value', 1, 'Limits', [0 1], ...
        'ValueChangedFcn', @actualizar_correccion_4d_y_redibujar);

    btnExportDir = uibutton(fig, 'Position', [xCtrl 236 162 28], ...
        'Text', 'Carpeta exportacion', ...
        'ButtonPushedFcn', @seleccionar_exportacion);
    lblExportDir = uilabel(fig, 'Position', [xCtrl+172 240 276 20], ...
        'Text', state.carpeta_exportacion, 'Interpreter', 'none');

    chkExportMat = uicheckbox(fig, 'Position', [xCtrl 174 90 22], ...
        'Text', 'T4D .mat', 'Value', true);
    chkExportM = uicheckbox(fig, 'Position', [xCtrl+100 174 92 22], ...
        'Text', 'Funcion .m', 'Value', true);
    chkExportRBF = uicheckbox(fig, 'Position', [xCtrl+202 174 70 22], ...
        'Text', 'RBF', 'Value', false);
    uilabel(fig, 'Position', [xCtrl+286 174 78 20], 'Text', 'Centros:');
    edRbfCenters = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl+350 172 98 24], 'Value', 2000, 'Limits', [50 Inf]);

    btnRunVol = uibutton(fig, 'Position', [xCtrl 132 216 32], ...
        'Text', 'Construir extrapolacion 4D', ...
        'ButtonPushedFcn', @construir_volumen_ui);
    btnExportVol = uibutton(fig, 'Position', [xCtrl+230 132 218 32], ...
        'Text', 'Exportar resultados', ...
        'ButtonPushedFcn', @exportar_volumen_ui);

    lblStatus = uilabel(fig, 'Position', [xCtrl 94 wCtrl 24], ...
        'Text', 'Listo.', 'FontSize', 9, ...
        'FontColor', theme.colors.thermalBlue);

    tesis_auxiliares('tema_ui', 'apply', fig);
    tesis_auxiliares('tema_ui', 'axes', axCorr);
    tesis_auxiliares('tema_ui', 'axes', axXY);
    tesis_auxiliares('tema_ui', 'axes', axXZ);
    tesis_auxiliares('tema_ui', 'axes', axYZ);
    tesis_auxiliares('tema_ui', 'axes', ax3D);
    tesis_auxiliares('tema_ui', 'axes', axFuncion);
    tesis_auxiliares('tema_ui', 'axes', axVol);
    tesis_auxiliares('tema_ui', 'textarea', txtLog);
    tesis_auxiliares('tema_ui', 'button', btnExp, 'primary');
    tesis_auxiliares('tema_ui', 'button', btnSim, 'primary');
    tesis_auxiliares('tema_ui', 'button', btnDataset, 'primary');
    tesis_auxiliares('tema_ui', 'button', btnExportDir, 'secondary');
    tesis_auxiliares('tema_ui', 'button', btnRunCorr, 'success');
    tesis_auxiliares('tema_ui', 'button', btnSaveCorr, 'primary');
    tesis_auxiliares('tema_ui', 'button', btnRunVol, 'success');
    tesis_auxiliares('tema_ui', 'button', btnExportVol, 'primary');
    establecer_estado('Modulo fusionado iniciado.');

    function crear_seccion(txt, y)
        uilabel(fig, 'Position', [xCtrl y wCtrl 20], ...
            'Text', txt, ...
            'FontSize', 11, ...
            'FontWeight', 'bold', ...
            'FontColor', theme.colors.accent);
    end

    function crear_mini_label(txt, y, dx)
        uilabel(fig, 'Position', [xCtrl+dx y 108 20], ...
            'Text', txt, ...
            'FontSize', 9);
    end

    function cargar_experimental(~, ~)
        [file, path] = uigetfile( ...
            {'*.csv;*.xlsx;*.xls', 'Datos experimentales (*.csv, *.xlsx, *.xls)'}, ...
            'Selecciona archivo experimental', data_paths.experimentales);
        if isequal(file, 0)
            return;
        end
        state.ruta_exp = fullfile(path, file);
        try
            state.exp = leer_experimental(state.ruta_exp, true);
            lblExp.Text = file;
            edExpIni.Value = 1;
            edExpFin.Value = numel(state.exp.t_min);
            establecer_estado('Experimental cargado: %d muestras, %d sondas.', ...
                numel(state.exp.t_min), size(state.exp.T, 2));
            actualizar_correlacion_tiempo_real();
        catch ME
            uialert(fig, ME.message, 'Error experimental');
            establecer_estado('Error al cargar experimental.');
        end
    end

    function cargar_simulacion_txt(~, ~)
        [file, path] = uigetfile({'*.txt', 'Registro de simulacion (*.txt)'}, ...
            'Selecciona TXT de simulacion');
        if isequal(file, 0)
            return;
        end
        state.ruta_sim = fullfile(path, file);
        try
            state.sim = leer_txt_sondas(state.ruta_sim);
            lblSim.Text = file;
            ddSonda.Items = state.sim.labels;
            ddSonda.Value = state.sim.labels{1};
            edSimIni.Value = 1;
            edSimFin.Value = numel(state.sim.t_min);
            establecer_estado('Simulacion TXT cargada: %d tiempos, %d sondas.', ...
                numel(state.sim.t_min), numel(state.sim.labels));
            actualizar_correlacion_tiempo_real();
        catch ME
            uialert(fig, ME.message, 'Error simulacion');
            establecer_estado('Error al cargar TXT de simulacion.');
        end
    end

    function actualizar_correlacion_tiempo_real(~, ~)
        if isempty(state.exp) || isempty(state.sim)
            limpiar_eje(axCorr, 'Carga experimental y TXT de simulacion.');
            return;
        end
        try
            cfg = obtener_config_correlacion();
            state.correccion = calcular_correlacion(cfg);
            dibujar_curvas_correlacion(state.correccion, state.correccion);
            dibujar_funcion_correccion_4d();
            if ~isempty(state.resultado_volumen)
                actualizar_correccion_4d_y_redibujar();
            end
            establecer_estado('Correccion actualizada: RMSE factor %.4f C, %d zonas.', ...
                state.correccion.correccion_termica.rmse_factor_C, ...
                contar_zonas_correccion(state.correccion.correccion_termica));
        catch ME
            establecer_estado('Correccion en tiempo real no disponible: %s', ME.message);
        end
    end

    function calcular_correlacion_ui(~, ~)
        if isempty(state.exp) || isempty(state.sim)
            uialert(fig, 'Carga experimental y TXT de simulacion.', 'Datos faltantes');
            return;
        end
        try
            insertar_separacion_log();
            actualizar_correlacion_tiempo_real();
            if isempty(state.correccion)
                error('No se pudo generar una correccion valida con la configuracion actual.');
            end
            establecer_estado('Correccion calculada: RMSE factor %.4f C, %d zonas.', ...
                state.correccion.correccion_termica.rmse_factor_C, ...
                contar_zonas_correccion(state.correccion.correccion_termica));
        catch ME
            uialert(fig, ME.message, 'Error correlacion');
            establecer_estado('Error al calcular correlacion.');
        end
    end

    function guardar_correccion_ui(~, ~)
        if isempty(state.correccion)
            calcular_correlacion_ui();
            if isempty(state.correccion)
                return;
            end
        end
        insertar_separacion_log();
        ruta_default_corr = fullfile(data_paths.correlaciones, ...
            ruta_relativa_correccion_default(state.correccion));
        carpeta_default_corr = fileparts(ruta_default_corr);
        if ~isfolder(carpeta_default_corr), mkdir(carpeta_default_corr); end
        [file, path] = uiputfile('*.mat', ...
            'Guardar correccion termica', ruta_default_corr);
        if isequal(file, 0)
            return;
        end
        ruta_guardada = guardar_correccion_mat(fullfile(path, file), state.correccion);
        establecer_estado('Correccion guardada: %s', ruta_guardada);
    end

    function cfg = obtener_config_correlacion()
        cfg = struct();
        cfg.exp = state.exp;
        cfg.sim = state.sim;
        cfg.sonda = ddSonda.Value;
        cfg.exp_inicio = round(edExpIni.Value);
        cfg.exp_fin = round(edExpFin.Value);
        cfg.sim_inicio = round(edSimIni.Value);
        cfg.sim_fin = round(edSimFin.Value);
        cfg.grado = round(edGrado.Value);
        cfg.n_comun = round(edNComun.Value);
        cfg.nombre_exp = state.ruta_exp;
        cfg.nombre_sim = state.ruta_sim;
    end

    function cargar_dataset(~, ~)
        [file, path] = uigetfile('*.mat', 'Selecciona Dataset_Termico_Masivo.mat', ...
            tesis_auxiliares('dataset_masivo_reciente', data_paths));
        if isequal(file, 0)
            return;
        end
        state.ruta_dataset = fullfile(path, file);
        try
            state.dataset = cargar_dataset_termico(state.ruta_dataset);
            state.modelos = fieldnames(state.dataset);
            state.modelos = state.modelos(~strcmp(state.modelos, 'session_meta'));
            state.actualizando = true;
            ddModelo.Items = state.modelos;
            ddModelo.Value = state.modelos{1};
            state.actualizando = false;
            lblDataset.Text = file;
            actualizar_datasets();
            establecer_estado('Dataset cargado: %d modelos.', numel(state.modelos));
        catch ME
            state.actualizando = false;
            uialert(fig, ME.message, 'Error dataset');
            establecer_estado('Error al cargar dataset.');
        end
    end

    function actualizar_datasets(~, ~)
        if state.actualizando || isempty(state.dataset) || isempty(ddModelo.Value)
            return;
        end
        modelo = ddModelo.Value;
        if ~isfield(state.dataset, modelo)
            return;
        end
        dsNames = fieldnames(state.dataset.(modelo));
        dsNames = dsNames(~strcmp(dsNames, 'session_meta'));
        state.datasets = dsNames;
        state.actualizando = true;
        ddDataset.Items = dsNames;
        ddDataset.Value = dsNames{1};
        state.actualizando = false;
    end

    function seleccionar_exportacion(~, ~)
        folder = uigetdir(state.carpeta_exportacion, 'Selecciona carpeta de exportacion');
        if isequal(folder, 0)
            return;
        end
        state.carpeta_exportacion = folder;
        lblExportDir.Text = folder;
        establecer_estado('Carpeta de exportacion: %s', folder);
    end

    function construir_volumen_ui(~, ~)
        if isempty(state.dataset)
            uialert(fig, 'Carga primero el Dataset_Termico_Masivo.mat.', 'Datos faltantes');
            return;
        end
        try
            insertar_separacion_log();
            cfg = obtener_config_volumen();
            corr = [];
            if chkUsarCorreccion.Value
                corr = state.correccion;
            end
            state.resultado_volumen = construir_funcion_volumen(cfg, corr, @establecer_estado);
            actualizar_control_tiempo_4d(state.resultado_volumen);
            dibujar_analisis_4d(state.resultado_volumen);
            establecer_estado('Extrapolacion 4D construida. Simulado %.4f-%.4f min; %s.', ...
                min(state.resultado_volumen.t_fine), max(state.resultado_volumen.t_fine), ...
                describir_tramo_extrapolado(state.resultado_volumen));
        catch ME
            uialert(fig, ME.message, 'Error volumen');
            establecer_estado('Error al construir funcion volumen: %s', ME.message);
        end
    end

    function exportar_volumen_ui(~, ~)
        if isempty(state.resultado_volumen)
            uialert(fig, 'Construye primero la extrapolacion 4D.', 'Sin resultado');
            return;
        end
        try
            insertar_separacion_log();
            cfg = state.resultado_volumen.cfg;
            cfg.carpeta_exportacion = state.carpeta_exportacion;
            cfg.export_mat = chkExportMat.Value;
            cfg.export_m = chkExportM.Value;
            cfg.export_rbf = chkExportRBF.Value;
            cfg.n_rbf_max = round(edRbfCenters.Value);
            archivos = exportar_volumen_desde_resultado(cfg, state.resultado_volumen, @establecer_estado);
            state.resultado_volumen.archivos = archivos;
            establecer_estado('Resultados exportados en: %s', cfg.carpeta_exportacion);
        catch ME
            uialert(fig, ME.message, 'Error exportacion');
            establecer_estado('Error al exportar resultados: %s', ME.message);
        end
    end

    function cfg = obtener_config_volumen()
        cfg = struct();
        cfg.dataset = state.dataset;
        cfg.modelo = ddModelo.Value;
        cfg.dsName = ddDataset.Value;
        cfg.nx = round(edNx.Value);
        cfg.ny = round(edNy.Value);
        cfg.nz = round(edNz.Value);
        cfg.nt_fine = NaN;
        cfg.T_abl = edTAbl.Value;
        cfg.t_extra_max = edTExtra.Value;
        cfg.nt_ext = NaN;
        cfg.estrategia = ddEstrategia.Value;
        cfg.carpeta_exportacion = state.carpeta_exportacion;
        cfg.ruta_correccion = '';
        cfg.export_mat = chkExportMat.Value;
        cfg.export_m = chkExportM.Value;
        cfg.export_rbf = chkExportRBF.Value;
        cfg.n_rbf_max = round(edRbfCenters.Value);
        cfg.aplicar_offset_base = chkOffset.Value;
        cfg.intensidad_correccion = edIntensidad.Value;
    end

    function dibujar_curvas_correlacion(curvas, corr)
        cla(axCorr, 'reset');
        tesis_auxiliares('tema_ui', 'axes', axCorr);
        yyaxis(axCorr, 'left');
        hold(axCorr, 'on');
        plot(axCorr, curvas.t_exp_zero, curvas.y_exp, '-', ...
            'Color', [1.0 0.35 0.25], 'LineWidth', 1.4, ...
            'DisplayName', 'Experimental recortado');
        plot(axCorr, curvas.t_sim_zero, curvas.y_sim, '-', ...
            'Color', [0.35 0.65 1.0], 'LineWidth', 1.4, ...
            'DisplayName', 'Simulacion recortada');
        if ~isempty(corr)
            plot(axCorr, corr.t_comun, corr.y_exp_interp, '--', ...
                'Color', [1.0 0.55 0.45], 'LineWidth', 1.2, ...
                'DisplayName', 'Exp interp');
            plot(axCorr, corr.t_comun, corr.y_sim_interp, '--', ...
                'Color', [0.55 0.78 1.0], 'LineWidth', 1.2, ...
                'DisplayName', 'Sim interp');
            plot(axCorr, corr.t_comun, ...
                corr.correccion_termica.simulacion_corregida_factor_C, ...
                '-', 'Color', [0.45 0.90 0.35], 'LineWidth', 2.0, ...
                'DisplayName', 'Sim corregida');
            ajuste_aplicado = obtener_ajuste_aditivo_correlacion(corr);
            if ~isempty(ajuste_aplicado)
                yyaxis(axCorr, 'right');
                plot(axCorr, corr.t_comun, ajuste_aplicado, ':', ...
                    'Color', [1.00 0.82 0.20], 'LineWidth', 2.2, ...
                    'DisplayName', 'Funcion aplicada +/- (Tcorr-Tsim)');
                yline(axCorr, 0, ':', ...
                    'Color', theme.colors.textMuted, ...
                    'HandleVisibility', 'off');
                ylabel(axCorr, 'Correccion aplicada (C)');
                ajustar_limites_correccion(axCorr, ajuste_aplicado);
                yyaxis(axCorr, 'left');
            end
        end
        hold(axCorr, 'off');
        xlabel(axCorr, 'Tiempo relativo (min)');
        ylabel(axCorr, 'Temperatura (C)');
        title(axCorr, 'Correlacion simulacion vs experimento', ...
            'Color', theme.colors.accent);
        grid(axCorr, 'on');
        lg = legend(axCorr, 'show', 'Location', 'best');
        lg.TextColor = theme.colors.text;
        lg.Color = theme.colors.card;
        lg.EdgeColor = theme.colors.border;
    end

    function ajuste = obtener_ajuste_aditivo_correlacion(corr)
        ajuste = [];
        if isempty(corr) || ~isfield(corr, 't_comun') || ~isfield(corr, 'y_sim_interp')
            return;
        end
        if isfield(corr, 'correccion_termica') && ...
                isfield(corr.correccion_termica, 'simulacion_corregida_factor_C') && ...
                numel(corr.correccion_termica.simulacion_corregida_factor_C) == numel(corr.y_sim_interp)
            ajuste = corr.correccion_termica.simulacion_corregida_factor_C(:) - corr.y_sim_interp(:);
            return;
        end
        if isfield(corr, 'p_arreglo') && ~isempty(corr.p_arreglo)
            ajuste = -polyval(corr.p_arreglo, corr.t_comun(:));
        end
    end

    function ajustar_limites_correccion(ax, ajuste)
        ajuste = ajuste(isfinite(ajuste));
        if isempty(ajuste)
            return;
        end
        max_abs = max(abs(ajuste));
        max_abs = max(max_abs, 1);
        ylim(ax, [-1.1 1.1] * max_abs);
    end

    function actualizar_analisis_4d(~, ~)
        if isempty(state.resultado_volumen)
            return;
        end
        dibujar_volumen(state.resultado_volumen);
        dibujar_funcion_correccion_4d();
        dibujar_vistas_3d(state.resultado_volumen);
    end

    function dibujar_analisis_4d(res)
        dibujar_volumen(res);
        dibujar_funcion_correccion_4d();
        dibujar_vistas_3d(res);
        tabsAnalisis.SelectedTab = tab4D;
    end

    function dibujar_vistas_3d(res)
        dibujar_planos_ortogonales(res);
        dibujar_3d_correccion(res);
    end

    function actualizar_correccion_4d_y_redibujar(~, ~)
        if isempty(state.resultado_volumen)
            return;
        end
        try
            recalcular_campo_corregido_en_memoria();
            actualizar_analisis_4d();
        catch ME
            establecer_estado('No se pudo actualizar la correccion 4D: %s', ME.message);
        end
    end

    function recalcular_campo_corregido_en_memoria()
        res = state.resultado_volumen;
        if ~isfield(res, 'T_export_base_nd') || isempty(res.T_export_base_nd)
            return;
        end
        cfg = res.cfg;
        cfg.aplicar_offset_base = chkOffset.Value;
        cfg.intensidad_correccion = edIntensidad.Value;
        cfg.export_mat = chkExportMat.Value;
        cfg.export_m = chkExportM.Value;
        cfg.export_rbf = chkExportRBF.Value;
        cfg.n_rbf_max = round(edRbfCenters.Value);
        cfg.carpeta_exportacion = state.carpeta_exportacion;
        res.cfg = cfg;
        if chkUsarCorreccion.Value && ~isempty(state.correccion)
            [T_nd_corr, V_corr, meta] = aplicar_correccion_volumen( ...
                res.T_export_base_nd, res.T_base_vec, res.t_full, cfg, ...
                state.correccion, res.voxel_vol, res.zg);
            res.Fgrid_ext = griddedInterpolant({res.xg, res.yg, res.zg, res.t_full}, ...
                T_nd_corr, 'linear', 'linear');
            res.V_corr = V_corr;
            res.correccion_exportada = meta;
        else
            res.Fgrid_ext = res.Fgrid_base;
            res.V_corr = [];
            res.correccion_exportada = struct('activa', false);
        end
        state.resultado_volumen = res;
    end

    function dibujar_volumen(res)
        cla(axVol, 'reset');
        tesis_auxiliares('tema_ui', 'axes', axVol);
        hold(axVol, 'on');
        plot(axVol, res.t_fine, res.V_base, 'o-', ...
            'Color', [0.35 0.75 1.0], 'MarkerSize', 3, ...
            'LineWidth', 1.4, 'DisplayName', 'V base');
        if ~isempty(res.t_ext) && isfield(res, 'extrap')
            plot(axVol, res.t_ext, res.extrap.V_grad, '-', ...
                'Color', [0.42 0.72 1.0], ...
                'LineWidth', ancho_metodo(res, 'gradiente_local'), ...
                'DisplayName', 'Gradiente local');
            plot(axVol, res.t_ext, res.extrap.V_lowess, '-', ...
                'Color', [0.40 1.00 0.55], ...
                'LineWidth', ancho_metodo(res, 'lowess_cuadratico'), ...
                'DisplayName', 'LOWESS');
            plot(axVol, res.t_ext, res.extrap.V_pca, '-', ...
                'Color', [1.00 0.72 0.25], ...
                'LineWidth', ancho_metodo(res, 'pca_temporal'), ...
                'DisplayName', 'PCA temporal');
        end
        if chkUsarCorreccion.Value && isfield(res, 'V_corr') && ~isempty(res.V_corr)
            plot(axVol, res.t_full, res.V_corr, '--', ...
                'Color', [1.0 0.35 0.75], 'LineWidth', 2.0, ...
                'DisplayName', 'V corregido');
        end
        hold(axVol, 'off');
        xlabel(axVol, 'Tiempo (min)');
        ylabel(axVol, 'Volumen ablacionado (mm^3)');
        title(axVol, sprintf('%s / %s | T >= %.1f C | %s', ...
            res.modelo, res.dsName, res.T_abl, describir_tramo_extrapolado(res)), ...
            'Color', theme.colors.accent, 'Interpreter', 'none');
        grid(axVol, 'on');
        lg = legend(axVol, 'show', 'Location', 'northwest');
        lg.TextColor = theme.colors.text;
        lg.Color = theme.colors.card;
        lg.EdgeColor = theme.colors.border;
    end

    function ancho = ancho_metodo(res, tipo)
        tipo_ui = normalizar_estrategia(ddEstrategia.Value);
        if strcmp(tipo_ui, tipo) || (isempty(tipo_ui) && strcmp(res.modelo_tipo, tipo))
            ancho = 3.0;
        else
            ancho = 1.5;
        end
    end

    function dibujar_funcion_correccion_4d()
        cla(axFuncion, 'reset');
        tesis_auxiliares('tema_ui', 'axes', axFuncion);
        if isempty(state.correccion) || ~isfield(state.correccion, 'correccion_termica')
            text(axFuncion, 0.5, 0.5, 'Sin correccion termica cargada o calculada', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'Color', theme.colors.textMuted);
            grid(axFuncion, 'on');
            return;
        end
        ct = state.correccion.correccion_termica;
        t = ct.t_rel_min(:);
        factor = ct.factor_enfriamiento(:);
        yyaxis(axFuncion, 'left');
        hold(axFuncion, 'on');
        zonas = obtener_zonas_correccion(ct);
        if isempty(zonas)
            plot(axFuncion, t, factor, '-', ...
                'Color', [0.45 0.90 0.35], ...
                'LineWidth', 2.0, ...
                'DisplayName', 'Factor enfriamiento');
        else
            colores_zona = lines(numel(zonas));
            for zi = 1:numel(zonas)
                zona = zonas(zi);
                plot(axFuncion, zona.t_rel_min(:), zona.factor_enfriamiento(:), '-', ...
                    'Color', colores_zona(zi, :), ...
                    'LineWidth', 1.8, ...
                    'DisplayName', sprintf('%s z=%.1f mm', ...
                    zona.label, zona.profundidad_sim_mm));
            end
            plot(axFuncion, t, factor, ':', ...
                'Color', [0.85 0.85 0.85], ...
                'LineWidth', 1.1, ...
                'DisplayName', 'Factor seleccionado');
        end
        hold(axFuncion, 'off');
        ylabel(axFuncion, 'Factor');
        ylim(axFuncion, [0 1]);
        yyaxis(axFuncion, 'right');
        if isfield(ct, 'delta_T_C') && ~isempty(ct.delta_T_C)
            plot(axFuncion, t, ct.delta_T_C(:), '--', ...
                'Color', [0.95 0.62 0.12], ...
                'LineWidth', 1.4, ...
                'DisplayName', 'Delta T');
            ylabel(axFuncion, 'Delta T (C)');
        elseif isfield(state.correccion, 'y_delta') && ~isempty(state.correccion.y_delta)
            plot(axFuncion, state.correccion.t_comun, state.correccion.y_delta, '--', ...
                'Color', [0.95 0.62 0.12], ...
                'LineWidth', 1.4, ...
                'DisplayName', 'Delta T');
            ylabel(axFuncion, 'Delta T (C)');
        end
        xlabel(axFuncion, 'Tiempo relativo (min)');
        title(axFuncion, sprintf('Funcion de correccion | RMSE %.4f C | zonas %d', ...
            ct.rmse_factor_C, numel(zonas)), ...
            'Color', theme.colors.accent);
        grid(axFuncion, 'on');
        lg = legend(axFuncion, 'show', 'Location', 'best');
        lg.TextColor = theme.colors.text;
        lg.Color = theme.colors.card;
        lg.EdgeColor = theme.colors.border;
    end

    function dibujar_planos_ortogonales(res)
        if isempty(res) || ~isfield(res, 'Fgrid_ext') || isempty(res.Fgrid_ext)
            limpiar_eje(axXY, 'Sin campo 4D.');
            limpiar_eje(axXZ, 'Sin campo 4D.');
            limpiar_eje(axYZ, 'Sin campo 4D.');
            limpiar_eje(ax3D, 'Sin campo 4D.');
            return;
        end
        V = res.Fgrid_ext.Values;
        idx_t = obtener_indice_visual(res);
        T = squeeze(V(:,:,:,idx_t));
        ix = max(1, round(size(T, 1) / 2));
        iy = max(1, round(size(T, 2) / 2));
        iz = max(1, round(size(T, 3) / 2));
        t_act = res.t_full(idx_t);
        tramo = etiqueta_tramo_tiempo(res, idx_t);

        dibujar_plano(axXY, res.xg, res.yg, squeeze(T(:,:,iz))', ...
            sprintf('XY | z=%.2f | t=%.3f min | %s', res.zg(iz), t_act, tramo), ...
            'X (mm)', 'Y (mm)');
        dibujar_plano(axXZ, res.xg, res.zg, squeeze(T(:,iy,:))', ...
            sprintf('XZ | y=%.2f | %s', res.yg(iy), tramo), ...
            'X (mm)', 'Z (mm)');
        dibujar_plano(axYZ, res.yg, res.zg, squeeze(T(ix,:,:))', ...
            sprintf('YZ | x=%.2f | %s', res.xg(ix), tramo), ...
            'Y (mm)', 'Z (mm)');
    end

    function idx_t = obtener_indice_visual(res)
        idx_t = round(sldTiempo4D.Value);
        if isempty(idx_t) || ~isfinite(idx_t)
            idx_t = min(numel(res.t_fine), numel(res.t_full));
        end
        idx_t = max(1, min(numel(res.t_full), idx_t));
        state.indice_tiempo_4d = idx_t;
    end

    function actualizar_control_tiempo_4d(res)
        if isempty(res) || ~isfield(res, 't_full') || isempty(res.t_full)
            state.indice_tiempo_4d = 1;
            sldTiempo4D.Value = 1;
            sldTiempo4D.Limits = [1 2];
            sldTiempo4D.MajorTicks = [1 2];
            sldTiempo4D.MajorTickLabels = {'', ''};
            sldTiempo4D.Enable = 'off';
            lblTiempoVista.Text = 'sin volumen construido';
            lblTiempoVista.FontColor = theme.colors.textMuted;
            return;
        end
        n = numel(res.t_full);
        sldTiempo4D.Value = 1;
        sldTiempo4D.Limits = [1 max(2, n)];
        idx_fin_sim = min(numel(res.t_fine), n);
        idx = max(1, min(n, idx_fin_sim));
        state.indice_tiempo_4d = idx;
        sldTiempo4D.Value = idx;
        sldTiempo4D.Enable = 'on';
        ticks = unique([1 idx_fin_sim n]);
        if n == 1
            ticks = [1 2];
        end
        sldTiempo4D.MajorTicks = ticks;
        labels = cell(1, numel(ticks));
        for tk = 1:numel(ticks)
            if ticks(tk) == 1
                labels{tk} = 'Inicio';
            elseif ticks(tk) == idx_fin_sim
                labels{tk} = 'Fin sim';
            elseif ticks(tk) == n
                labels{tk} = 'Fin ext';
            else
                labels{tk} = sprintf('%d', ticks(tk));
            end
        end
        sldTiempo4D.MajorTickLabels = labels;
        actualizar_etiqueta_tiempo_4d(res, idx);
    end

    function actualizar_tiempo_4d_desde_slider(~, event)
        if isempty(state.resultado_volumen)
            return;
        end
        idx = round(sldTiempo4D.Value);
        if nargin >= 2 && ~isempty(event)
            try
                idx = round(event.Value);
            catch
                idx = round(sldTiempo4D.Value);
            end
        end
        idx = max(1, min(numel(state.resultado_volumen.t_full), idx));
        sldTiempo4D.Value = idx;
        state.indice_tiempo_4d = idx;
        actualizar_etiqueta_tiempo_4d(state.resultado_volumen, idx);
        dibujar_vistas_3d(state.resultado_volumen);
    end

    function actualizar_etiqueta_tiempo_4d(res, idx)
        if isempty(res) || ~isfield(res, 't_full') || isempty(res.t_full)
            lblTiempoVista.Text = 'sin volumen construido';
            lblTiempoVista.FontColor = theme.colors.textMuted;
            return;
        end
        idx = max(1, min(numel(res.t_full), idx));
        lblTiempoVista.Text = sprintf('%.4f min | %s | %d/%d', ...
            res.t_full(idx), etiqueta_tramo_tiempo(res, idx), idx, numel(res.t_full));
        lblTiempoVista.FontColor = theme.colors.text;
    end

    function txt = etiqueta_tramo_tiempo(res, idx)
        if idx <= numel(res.t_fine)
            txt = 'simulado';
        else
            txt = 'extrapolado';
        end
    end

    function txt = describir_tramo_extrapolado(res)
        if isempty(res.t_ext)
            txt = 'sin extrapolacion temporal';
        else
            txt = sprintf('extrap %.4f-%.4f min (%d puntos)', ...
                res.t_ext(1), res.t_ext(end), numel(res.t_ext));
        end
    end

    function dibujar_3d_correccion(res)
        colorbar(ax3D, 'off');
        cla(ax3D, 'reset');
        tesis_auxiliares('tema_ui', 'axes', ax3D);
        if isempty(res) || ~isfield(res, 'Fgrid_ext') || isempty(res.Fgrid_ext)
            limpiar_eje(ax3D, 'Sin campo 4D.');
            return;
        end
        idx_t = obtener_indice_visual(res);
        V = res.Fgrid_ext.Values;
        T = squeeze(V(:,:,:,idx_t));
        [X, Y, Z] = ndgrid(res.xg, res.yg, res.zg);
        mask = isfinite(T) & T >= res.T_abl;
        if ~any(mask(:))
            text(ax3D, 0.5, 0.5, ...
                sprintf('Sin voxeles sobre %.1f C en %.4f min (%s)', ...
                res.T_abl, res.t_full(idx_t), etiqueta_tramo_tiempo(res, idx_t)), ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'Color', theme.colors.textMuted);
            title(ax3D, 'Campo 3D corregido', 'Color', theme.colors.accent);
            grid(ax3D, 'on');
            view(ax3D, 3);
            return;
        end
        pts = [X(mask), Y(mask), Z(mask)];
        temp = T(mask);
        max_pts = 60000;
        if size(pts, 1) > max_pts
            idx = round(linspace(1, size(pts, 1), max_pts));
            pts = pts(idx, :);
            temp = temp(idx);
        end
        scatter3(ax3D, pts(:,1), pts(:,2), pts(:,3), 10, temp, 'filled', ...
            'MarkerFaceAlpha', 0.62, 'MarkerEdgeAlpha', 0.12);
        colormap(ax3D, parula(256));
        cb = colorbar(ax3D);
        cb.Color = theme.colors.text;
        xlabel(ax3D, 'X (mm)');
        ylabel(ax3D, 'Y (mm)');
        zlabel(ax3D, 'Z (mm)');
        title(ax3D, sprintf('T >= %.1f C | t=%.4f min | %s', ...
            res.T_abl, res.t_full(idx_t), etiqueta_tramo_tiempo(res, idx_t)), ...
            'Color', theme.colors.accent);
        grid(ax3D, 'on');
        axis(ax3D, 'vis3d');
        view(ax3D, 3);
    end

    function dibujar_plano(ax, x, y, C, titulo, xlab, ylab)
        colorbar(ax, 'off');
        cla(ax, 'reset');
        tesis_auxiliares('tema_ui', 'axes', ax);
        imagesc(ax, x, y, C);
        axis(ax, 'xy');
        colormap(ax, parula(256));
        cb = colorbar(ax);
        cb.Color = theme.colors.text;
        xlabel(ax, xlab);
        ylabel(ax, ylab);
        title(ax, titulo, 'Color', theme.colors.accent, ...
            'Interpreter', 'none', 'FontSize', 8);
        grid(ax, 'on');
    end

    function limpiar_eje(ax, msg)
        cla(ax, 'reset');
        tesis_auxiliares('tema_ui', 'axes', ax);
        text(ax, 0.5, 0.5, msg, ...
            'Units', 'normalized', ...
            'HorizontalAlignment', 'center', ...
            'Color', theme.colors.textMuted);
        grid(ax, 'on');
    end

    function establecer_estado(formato, varargin)
        msg = sprintf(formato, varargin{:});
        lblStatus.Text = msg;
        if isvalid(txtLog)
            marca = char(datetime('now', 'Format', 'HH:mm:ss'));
            txtLog.Value = [{sprintf('[%s] %s', marca, msg)}; txtLog.Value(:)];
        end
        drawnow limitrate;
    end

    function insertar_separacion_log()
        if isvalid(txtLog)
            txtLog.Value = [repmat({''}, 5, 1); txtLog.Value(:)];
        end
        drawnow limitrate;
    end
end

function expData = leer_experimental(ruta, tiempo_en_segundos)
    datos = readmatrix(ruta);
    datos = datos(any(isfinite(datos), 2), :);
    if isempty(datos)
        error('El archivo experimental no contiene datos numericos validos.');
    end
    if size(datos, 2) >= 2 && es_columna_tiempo(datos(:, 1))
        tiempo = datos(:, 1);
        temperatura = datos(:, 2:end);
    else
        temperatura = datos;
        tiempo = (0:size(temperatura, 1)-1)';
    end
    validos = isfinite(tiempo) & any(isfinite(temperatura), 2);
    tiempo = tiempo(validos);
    temperatura = temperatura(validos, :);
    if tiempo_en_segundos
        tiempo = tiempo / 60;
    end
    labels = arrayfun(@(k) sprintf('P%d', k), 1:size(temperatura, 2), ...
        'UniformOutput', false);
    expData = struct('t_min', tiempo(:), ...
        'T', temperatura, ...
        'labels', {labels});
end

function tf = es_columna_tiempo(col)
    col = col(:);
    col = col(isfinite(col));
    tf = numel(col) >= 2 && all(diff(col) >= 0);
end

function simData = leer_txt_sondas(ruta_txt)
    fid = fopen(ruta_txt, 'r');
    if fid < 0
        error('No se pudo abrir el TXT: %s', ruta_txt);
    end
    cleanup = onCleanup(@() fclose(fid));
    labels = {};
    values = [];
    tabla = false;
    line = fgetl(fid);
    while ischar(line)
        if contains(line, 'Tiempo(min)')
            tabla = true;
            labels = parsear_encabezado_sondas(line);
            line = fgetl(fid);
            if ischar(line) && contains(line, '---')
                line = fgetl(fid);
            end
            continue;
        end
        if tabla
            nums = sscanf(line, '%f');
            if numel(nums) >= 2
                values = [values; nums(:)']; %#ok<AGROW>
            end
        end
        line = fgetl(fid);
    end
    if isempty(values)
        error('No se encontro tabla numerica Tiempo(min)/sondas en el TXT.');
    end
    nCols = size(values, 2);
    if isempty(labels) || numel(labels) ~= nCols - 1
        labels = arrayfun(@(k) sprintf('Sonda_%d', k), 1:nCols-1, ...
            'UniformOutput', false);
    end
    simData = struct('t_min', values(:, 1), ...
        'T', values(:, 2:end), ...
        'labels', {labels(:)'});
end

function labels = parsear_encabezado_sondas(line)
    tokens = regexp(strtrim(line), '\s+', 'split');
    labels = {};
    for k = 2:numel(tokens)
        tok = regexprep(tokens{k}, '\(.*?\)', '');
        tok = regexprep(tok, '[^a-zA-Z0-9_]', '_');
        tok = regexprep(tok, '_+', '_');
        tok = regexprep(tok, '^_|_$', '');
        if isempty(tok)
            tok = sprintf('Sonda_%d', k-1);
        end
        labels{end+1} = tok; %#ok<AGROW>
    end
end

function curvas = preparar_curvas_correlacion(cfg, sim_idx, exp_idx)
    T_exp = obtener_matriz_T(cfg.exp.T);
    T_sim = obtener_matriz_T(cfg.sim.T);
    if nargin < 2 || isempty(sim_idx)
        sim_idx = find(strcmp(cfg.sim.labels, cfg.sonda), 1);
        if isempty(sim_idx)
            sim_idx = 1;
        end
    end
    sim_idx = max(1, min(sim_idx, size(T_sim, 2)));
    if nargin < 3 || isempty(exp_idx)
        exp_idx = min(sim_idx, size(T_exp, 2));
    end
    exp_idx = max(1, min(exp_idx, size(T_exp, 2)));

    y_exp = T_exp(:, exp_idx);
    t_exp = cfg.exp.t_min(:);
    y_sim = T_sim(:, sim_idx);
    t_sim = cfg.sim.t_min(:);

    exp_fin = cfg.exp_fin;
    if isempty(exp_fin) || exp_fin <= 0
        exp_fin = numel(y_exp);
    end
    sim_fin = cfg.sim_fin;
    if isempty(sim_fin) || sim_fin <= 0
        sim_fin = numel(y_sim);
    end

    validar_indices_recorte(cfg.exp_inicio, exp_fin, numel(y_exp), 'experimental');
    validar_indices_recorte(cfg.sim_inicio, sim_fin, numel(y_sim), 'simulacion');

    curvas = struct();
    curvas.t_exp_zero = t_exp(cfg.exp_inicio:exp_fin) - t_exp(cfg.exp_inicio);
    curvas.y_exp = y_exp(cfg.exp_inicio:exp_fin);
    curvas.t_sim_zero = t_sim(cfg.sim_inicio:sim_fin) - t_sim(cfg.sim_inicio);
    curvas.y_sim = y_sim(cfg.sim_inicio:sim_fin);
    curvas.t_inicio_exp_min = t_exp(cfg.exp_inicio);
    curvas.t_inicio_sim_min = t_sim(cfg.sim_inicio);
    curvas.nombre_exp = cfg.nombre_exp;
    curvas.nombre_sim = cfg.nombre_sim;
    curvas.indice_sonda_sim = sim_idx;
    curvas.indice_sonda_exp = exp_idx;
    curvas.sonda = cfg.sim.labels{sim_idx};
    if isfield(cfg.exp, 'labels') && numel(cfg.exp.labels) >= exp_idx
        curvas.sonda_experimental = cfg.exp.labels{exp_idx};
    else
        curvas.sonda_experimental = sprintf('P%d', exp_idx);
    end
end

function T = obtener_matriz_T(T)
    if isempty(T)
        T = zeros(0, 1);
    elseif isvector(T)
        T = T(:);
    end
end

function validar_indices_recorte(i0, i1, n, etiqueta)
    if i0 < 1 || i1 > n || i0 >= i1
        error('Indices de recorte invalidos para %s.', etiqueta);
    end
end

function resultado = calcular_correlacion(cfg)
    curvas = preparar_curvas_correlacion(cfg);
    [t_comun, y_exp_interp, y_sim_interp] = sincronizar_curvas_ui( ...
        curvas.t_exp_zero, curvas.y_exp, ...
        curvas.t_sim_zero, curvas.y_sim, cfg.n_comun);
    y_delta = y_sim_interp - y_exp_interp;
    grado = min([cfg.grado, 12, numel(t_comun)-1]);
    p_arreglo = polyfit(t_comun, y_delta, grado);
    correccion_termica = crear_modelo_correccion_ui( ...
        t_comun, y_exp_interp, y_sim_interp, y_delta, ...
        p_arreglo, grado, ...
        curvas.t_inicio_exp_min, curvas.t_inicio_sim_min);
    [zonas, meta_zonas] = crear_zonas_correccion(cfg);
    if ~isempty(zonas)
        correccion_termica.version = 6;
        correccion_termica.modo_espacial = 'zonas_profundidad_z';
        correccion_termica.zonas = zonas;
        correccion_termica.profundidades_sim_mm = meta_zonas.profundidades_sim_mm;
        correccion_termica.profundidades_exp_mm = meta_zonas.profundidades_exp_mm;
        correccion_termica.z_edges_mm = meta_zonas.z_edges_mm;
        correccion_termica.descripcion_zonas = ...
            ['Correccion por bandas de profundidad z. Cada zona usa ', ...
             'el factor de la sonda equivalente y la misma formula ', ...
             'factor_sobre_incremento_termico_local.'];
    else
        correccion_termica.modo_espacial = 'global';
    end

    resultado = curvas;
    resultado.t_comun = t_comun;
    resultado.y_exp_interp = y_exp_interp;
    resultado.y_sim_interp = y_sim_interp;
    resultado.y_delta = y_delta;
    resultado.p_arreglo = p_arreglo;
    resultado.correccion_termica = correccion_termica;
end

function [zonas, meta] = crear_zonas_correccion(cfg)
    prof_sim_default = [18.6, 25.2, 31.8, 38.4];
    prof_exp_default = [26.4, 19.8, 13.2, 6.6];
    T_exp = obtener_matriz_T(cfg.exp.T);
    T_sim = obtener_matriz_T(cfg.sim.T);
    n_zonas = min([numel(prof_sim_default), numel(prof_exp_default), ...
        size(T_exp, 2), size(T_sim, 2)]);
    meta = struct( ...
        'profundidades_sim_mm', prof_sim_default(1:max(1, n_zonas)), ...
        'profundidades_exp_mm', prof_exp_default(1:max(1, n_zonas)), ...
        'z_edges_mm', []);
    zonas = struct([]);
    if n_zonas < 2
        return;
    end

    prof_sim = prof_sim_default(1:n_zonas);
    prof_exp = prof_exp_default(1:n_zonas);
    z_edges = calcular_bordes_zonas_z(prof_sim);
    meta.profundidades_sim_mm = prof_sim;
    meta.profundidades_exp_mm = prof_exp;
    meta.z_edges_mm = z_edges;

    for zi = 1:n_zonas
        curvas_z = preparar_curvas_correlacion(cfg, zi, zi);
        [t_comun_z, y_exp_z, y_sim_z] = sincronizar_curvas_ui( ...
            curvas_z.t_exp_zero, curvas_z.y_exp, ...
            curvas_z.t_sim_zero, curvas_z.y_sim, cfg.n_comun);
        y_delta_z = y_sim_z - y_exp_z;
        grado_z = min([cfg.grado, 12, numel(t_comun_z)-1]);
        p_arreglo_z = polyfit(t_comun_z, y_delta_z, grado_z);
        zona = crear_modelo_correccion_ui( ...
            t_comun_z, y_exp_z, y_sim_z, y_delta_z, ...
            p_arreglo_z, grado_z, ...
            curvas_z.t_inicio_exp_min, curvas_z.t_inicio_sim_min);
        zona.label = sprintf('P%d', zi);
        zona.indice_zona = zi;
        zona.indice_sonda_sim = curvas_z.indice_sonda_sim;
        zona.indice_sonda_exp = curvas_z.indice_sonda_exp;
        zona.nombre_sonda_sim = curvas_z.sonda;
        zona.nombre_sonda_exp = curvas_z.sonda_experimental;
        zona.profundidad_sim_mm = prof_sim(zi);
        zona.profundidad_exp_mm = prof_exp(zi);
        zona.z_min_mm = z_edges(zi);
        zona.z_max_mm = z_edges(zi + 1);
        zona.t_comun = t_comun_z(:);
        zona.y_exp_interp = y_exp_z(:);
        zona.y_sim_interp = y_sim_z(:);
        zona.p_arreglo = p_arreglo_z(:)';
        zona.y_delta = y_delta_z(:);
        zonas = [zonas; zona]; %#ok<AGROW>
    end
end

function z_edges = calcular_bordes_zonas_z(profundidades_sim_mm)
    profundidades_sim_mm = profundidades_sim_mm(:)';
    if numel(profundidades_sim_mm) < 2
        z_edges = [-Inf, Inf];
        return;
    end
    medios = (profundidades_sim_mm(1:end-1) + ...
        profundidades_sim_mm(2:end)) / 2;
    z_edges = [-Inf, medios, Inf];
end

function [t_comun, y_exp_interp, y_sim_interp] = sincronizar_curvas_ui(t_exp, y_exp, t_sim, y_sim, n_comun)
    [t_exp, y_exp] = limpiar_curva_temporal(t_exp, y_exp, 'experimental');
    [t_sim, y_sim] = limpiar_curva_temporal(t_sim, y_sim, 'simulacion');
    tmax = min(max(t_exp), max(t_sim));
    if tmax <= 0
        error('No existe intervalo temporal comun entre curvas.');
    end
    n_comun = max(20, round(n_comun));
    t_comun = linspace(0, tmax, n_comun)';
    y_exp_interp = interp1(t_exp, y_exp, t_comun, 'pchip');
    y_sim_interp = interp1(t_sim, y_sim, t_comun, 'pchip');
end

function [t, y] = limpiar_curva_temporal(t, y, etiqueta)
    t = t(:);
    y = y(:);
    validos = isfinite(t) & isfinite(y);
    t = t(validos);
    y = y(validos);
    if numel(t) < 2
        error('La curva %s no tiene suficientes datos validos.', etiqueta);
    end
    [t, idx] = unique(t, 'stable');
    y = y(idx);
    [t, orden] = sort(t);
    y = y(orden);
    if numel(t) < 2 || t(end) <= t(1)
        error('La curva %s no tiene intervalo temporal valido.', etiqueta);
    end
end

function correccion_termica = crear_modelo_correccion_ui(t_comun, ...
        y_exp_interp, y_sim_interp, y_delta, p_arreglo, grado, ...
        tiempo_inicio_exp_min, tiempo_inicio_sim_min)
    ajuste_polinomial = polyval(p_arreglo, t_comun);
    rmse_polinomio = sqrt(mean((ajuste_polinomial - y_delta).^2, 'omitnan'));
    base_exp = y_exp_interp(1);
    base_sim = y_sim_interp(1);
    inc_exp = y_exp_interp - base_exp;
    inc_sim = y_sim_interp - base_sim;
    umbral = max(0.5, 0.01 * max(abs(inc_sim)));
    estables = isfinite(inc_exp) & isfinite(inc_sim) & inc_sim >= umbral;
    if ~any(estables)
        error('No existe calentamiento simulado suficiente para calcular el factor.');
    end
    muestras = inc_exp(estables) ./ inc_sim(estables);
    muestras = max(0, min(1, muestras));
    factor = interp1(t_comun(estables), muestras, t_comun, 'pchip', 'extrap');
    factor = max(0, min(1, factor));
    primer = find(estables, 1, 'first');
    factor(t_comun < t_comun(primer)) = factor(primer);
    offset = base_exp - base_sim;
    sim_corr = base_sim + offset + factor .* inc_sim;
    rmse_factor = sqrt(mean((sim_corr - y_exp_interp).^2, 'omitnan'));
    extrap = crear_extrapolacion_factor_ui(t_comun, factor);

    correccion_termica = struct( ...
        'version', 5, ...
        'convencion', 'factor_sobre_incremento_termico_local', ...
        'formula_aplicacion', ['T_corr(p,t)=T_base(p)+offset_base_C+', ...
            'factor_enfriamiento(t)*(T(p,t)-T_base(p))'], ...
        'metodo_recomendado', 'factor_incremento_pchip_pca_ssa', ...
        't_rel_min', t_comun(:), ...
        'factor_enfriamiento', factor(:), ...
        'extrapolacion_factor', extrap, ...
        'limites_factor', [0, 1], ...
        'umbral_incremento_simulado_C', umbral, ...
        'temperatura_base_exp_C', base_exp, ...
        'temperatura_base_sim_C', base_sim, ...
        'offset_base_C', offset, ...
        'y_exp_interp', y_exp_interp(:), ...
        'y_sim_interp', y_sim_interp(:), ...
        'incremento_exp_C', inc_exp(:), ...
        'incremento_sim_C', inc_sim(:), ...
        'simulacion_corregida_factor_C', sim_corr(:), ...
        'rmse_factor_C', rmse_factor, ...
        'delta_T_C', y_delta(:), ...
        'intervalo_valido_min', [min(t_comun), max(t_comun)], ...
        'tiempo_referencia', 'relativo_al_inicio_recortado', ...
        't_origen_experimento_min', tiempo_inicio_exp_min, ...
        't_origen_simulacion_min', tiempo_inicio_sim_min, ...
        'extrapolacion_permitida', true, ...
        'grado_polinomio_compatibilidad', grado, ...
        'rmse_polinomio_C', rmse_polinomio);
end

function ruta_guardada = guardar_correccion_mat(ruta, corr)
    t_comun = corr.t_comun;
    y_exp_interp = corr.y_exp_interp;
    y_sim_interp = corr.y_sim_interp;
    p_arreglo = corr.p_arreglo;
    y_delta = corr.y_delta;
    correccion_termica = corr.correccion_termica;
    nombre_exp = campo_corr_texto(corr, 'nombre_exp');
    nombre_sim = campo_corr_texto(corr, 'nombre_sim');
    metadata_correlacion = metadata_correlacion_archivos(corr);
    carpeta = fileparts(ruta);
    if ~isfolder(carpeta), mkdir(carpeta); end
    ruta_guardada = ruta_disponible_correccion(ruta, corr);
    carpeta_guardada = fileparts(ruta_guardada);
    if ~isfolder(carpeta_guardada), mkdir(carpeta_guardada); end
    marca = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
    ruta_temporal = sprintf('%s.partial_%s', ruta_guardada, marca);
    cleanup = onCleanup(@() borrar_temporal_correccion(ruta_temporal));
    save(ruta_temporal, 't_comun', 'y_exp_interp', 'y_sim_interp', ...
        'p_arreglo', 'y_delta', 'correccion_termica', ...
        'nombre_exp', 'nombre_sim', 'metadata_correlacion');
    [ok, msg] = movefile(ruta_temporal, ruta_guardada);
    if ~ok, error('No se pudo finalizar la correlacion: %s', msg); end
    clear cleanup;
end

function nombre = nombre_correccion_default(corr)
    if isfield(corr, 'correccion_termica') && ...
            isfield(corr.correccion_termica, 'zonas') && ...
            ~isempty(corr.correccion_termica.zonas)
        nombre = 'Correccion_termica_zonal.mat';
    else
        nombre = 'Correccion_termica_global.mat';
    end
end

function relativa = ruta_relativa_correccion_default(corr)
    meta = metadata_correlacion_archivos(corr);
    nombre = nombre_correccion_default(corr);
    if metadata_correlacion_completa(meta)
        potencia = sprintf('Potencia_%gW', meta.potencia_W);
        potencia = strrep(potencia, '.', 'p');
        partes = {meta.tipo_antena, sprintf('%dant', round(meta.num_antenas)), ...
            sprintf('Caso_%d', round(meta.caso)), potencia};
        if metadata_correlacion_especifica_completa(meta)
            partes = [partes, {['Fecha_' simplificar_tag_archivo(meta.fecha_adquisicion, 32)], ...
                sprintf('Tiempo_%gmin', meta.tiempo_ejecucion_min), ...
                sprintf('Prueba_%d', round(meta.numero_prueba)), ...
                sprintf('Zonas_%d', round(meta.num_zonas))}];
        end
        relativa = fullfile(partes{:}, nombre);
    else
        relativa = fullfile('metadata_incompleta', nombre);
    end
end

function metadata = metadata_correlacion_archivos(corr)
    ruta_exp = campo_corr_texto(corr, 'nombre_exp');
    ruta_sim = campo_corr_texto(corr, 'nombre_sim');
    meta_sim = extraer_metadata_ruta_correlacion(ruta_sim);
    meta_exp = extraer_metadata_experimental_correlacion(ruta_exp, corr);
    metadata = struct( ...
        'ruta_exp', ruta_exp, ...
        'ruta_sim', ruta_sim, ...
        'carpeta_exp', carpeta_contenedora_exp(ruta_exp), ...
        'tag_carpeta_exp', tag_carpeta_experimental(ruta_exp), ...
        'archivo_exp', nombre_archivo(ruta_exp), ...
        'archivo_sim', nombre_archivo(ruta_sim), ...
        'tipo_antena', meta_sim.tipo_antena, ...
        'num_antenas', meta_sim.num_antenas, ...
        'caso', meta_sim.caso, ...
        'potencia_W', meta_sim.potencia_W, ...
        'fecha_experimento', tag_carpeta_experimental(ruta_exp), ...
        'fecha_adquisicion', meta_exp.fecha_adquisicion, ...
        'tiempo_ejecucion_min', meta_exp.tiempo_ejecucion_min, ...
        'numero_prueba', meta_exp.numero_prueba, ...
        'num_zonas', meta_exp.num_zonas, ...
        'zona_experimental', meta_exp.zona_experimental, ...
        'duracion_min', duracion_correlacion(corr), ...
        'sonda_simulada', campo_corr_texto(corr, 'sonda'), ...
        'sonda_experimental', campo_corr_texto(corr, 'sonda_experimental'), ...
        'schema_version', 3);
end

function meta = extraer_metadata_experimental_correlacion(ruta_exp, corr)
    meta = struct('fecha_adquisicion', tag_carpeta_experimental(ruta_exp), ...
        'tiempo_ejecucion_min', NaN, 'numero_prueba', 1, ...
        'num_zonas', NaN, 'zona_experimental', '');
    if isempty(meta.fecha_adquisicion)
        normal = strrep(char(ruta_exp), '\', '/');
        token_fecha = regexp(normal, '/([^/]+)/[^/]+$', 'tokens', 'once');
        if ~isempty(token_fecha), meta.fecha_adquisicion = token_fecha{1}; end
    end
    [~, base_exp] = fileparts(char(ruta_exp));
    token = regexp(base_exp, '(\d+(?:[p.]\d+)?)\s*min', ...
        'tokens', 'once', 'ignorecase');
    if ~isempty(token)
        meta.tiempo_ejecucion_min = str2double(strrep(lower(token{1}), 'p', '.'));
    end
    token = regexp(base_exp, '\d+(?:[p.]\d+)?\s*min[_\s-]*(\d+)', ...
        'tokens', 'once', 'ignorecase');
    if ~isempty(token), meta.numero_prueba = str2double(token{1}); end
    if isstruct(corr) && isfield(corr, 'correccion_termica') && ...
            isstruct(corr.correccion_termica) && ...
            isfield(corr.correccion_termica, 'zonas')
        meta.num_zonas = numel(corr.correccion_termica.zonas);
    end
    if isfinite(meta.num_zonas)
        meta.zona_experimental = sprintf('Zonas_%d', round(meta.num_zonas));
    end
end

function meta = extraer_metadata_ruta_correlacion(ruta)
    normal = strrep(char(ruta), '\', '/');
    meta = struct('tipo_antena', '', 'num_antenas', NaN, ...
        'caso', NaN, 'potencia_W', NaN);
    tipos = {'Doble_slot', 'Monopolo', 'Un_slot'};
    for k = 1:numel(tipos)
        if contains(normal, ['/' tipos{k} '/'], 'IgnoreCase', true)
            meta.tipo_antena = tipos{k};
            break;
        end
    end
    token = regexp(normal, '(\d+)ant', 'tokens', 'once', 'ignorecase');
    if ~isempty(token), meta.num_antenas = str2double(token{1}); end
    token = regexp(normal, 'Caso_(\d+)', 'tokens', 'once', 'ignorecase');
    if ~isempty(token), meta.caso = str2double(token{1}); end
    token = regexp(normal, 'Potencia_([\d.p]+)W', 'tokens', 'once', 'ignorecase');
    if ~isempty(token)
        meta.potencia_W = str2double(strrep(lower(token{1}), 'p', '.'));
    end
end

function tf = metadata_correlacion_completa(meta)
    tf = isstruct(meta) && isfield(meta, 'tipo_antena') && ...
        ~isempty(meta.tipo_antena) && isfield(meta, 'num_antenas') && ...
        isfinite(meta.num_antenas) && isfield(meta, 'caso') && ...
        isfinite(meta.caso) && isfield(meta, 'potencia_W') && ...
        isfinite(meta.potencia_W);
end

function tf = metadata_correlacion_especifica_completa(meta)
    tf = metadata_correlacion_completa(meta) && ...
        isfield(meta, 'fecha_adquisicion') && ~isempty(meta.fecha_adquisicion) && ...
        isfield(meta, 'tiempo_ejecucion_min') && isfinite(meta.tiempo_ejecucion_min) && ...
        isfield(meta, 'numero_prueba') && isfinite(meta.numero_prueba) && ...
        isfield(meta, 'num_zonas') && isfinite(meta.num_zonas);
end

function duracion = duracion_correlacion(corr)
    duracion = NaN;
    if isstruct(corr) && isfield(corr, 't_comun') && ~isempty(corr.t_comun)
        t = double(corr.t_comun(:));
        t = t(isfinite(t));
        if ~isempty(t), duracion = max(t) - min(t); end
    end
end

function ruta = ruta_disponible_correccion(ruta, corr)
    if ~isfile(ruta), return; end
    [folder, base, ext] = fileparts(ruta);
    if correccion_guardada_equivalente(ruta, corr)
        categoria = 'equivalentes';
    else
        categoria = 'conflictos';
    end
    folder_repetido = fullfile(folder, 'repetidos', categoria);
    revision = 2;
    ruta = fullfile(folder_repetido, sprintf('Revision_%d', revision), [base ext]);
    while isfile(ruta)
        revision = revision + 1;
        ruta = fullfile(folder_repetido, sprintf('Revision_%d', revision), [base ext]);
    end
end

function tf = correccion_guardada_equivalente(ruta, corr)
    campos = {'t_comun', 'y_exp_interp', 'y_sim_interp', 'p_arreglo', ...
        'y_delta', 'correccion_termica', 'nombre_exp', 'nombre_sim', ...
        'metadata_correlacion'};
    try
        guardada = load(ruta, campos{:});
        esperada = struct( ...
            't_comun', corr.t_comun, ...
            'y_exp_interp', corr.y_exp_interp, ...
            'y_sim_interp', corr.y_sim_interp, ...
            'p_arreglo', corr.p_arreglo, ...
            'y_delta', corr.y_delta, ...
            'correccion_termica', corr.correccion_termica, ...
            'nombre_exp', campo_corr_texto(corr, 'nombre_exp'), ...
            'nombre_sim', campo_corr_texto(corr, 'nombre_sim'), ...
            'metadata_correlacion', metadata_correlacion_archivos(corr));
        tf = all(cellfun(@(campo) isfield(guardada, campo) && ...
            isequaln(guardada.(campo), esperada.(campo)), campos));
    catch
        tf = false;
    end
end

function borrar_temporal_correccion(ruta)
    if isfile(ruta), delete(ruta); end
end

function ejecutar_selftest_metadata_correlacion()
    corr = struct();
    corr.nombre_exp = fullfile('datasets', 'experimentales', '19_jun', ...
        '1 antenas_30 watt 20min.csv');
    corr.nombre_sim = fullfile('datasets', 'distribuciones_stl', 'Monopolo', ...
        '1ant', 'Caso_1', 'Potencia_30W', 'Registro_Sondas_Temperatura.txt');
    corr.t_comun = [0; 20];
    corr.y_exp_interp = [20; 35];
    corr.y_sim_interp = [20; 32];
    corr.p_arreglo = [1; 1.25];
    corr.y_delta = [0; 3];
    corr.sonda = 'P1';
    corr.correccion_termica = struct('zonas', repmat(struct('indice', 1), 4, 1));
    meta = metadata_correlacion_archivos(corr);
    assert(metadata_correlacion_completa(meta));
    assert(metadata_correlacion_especifica_completa(meta));
    assert(strcmp(meta.tipo_antena, 'Monopolo'));
    assert(meta.num_antenas == 1 && meta.caso == 1 && meta.potencia_W == 30);
    assert(strcmp(meta.fecha_adquisicion, '19_jun') && ...
        meta.tiempo_ejecucion_min == 20 && meta.numero_prueba == 1 && ...
        meta.num_zonas == 4 && strcmp(meta.zona_experimental, 'Zonas_4'));
    nombre = nombre_correccion_default(corr);
    assert(strcmp(nombre, 'Correccion_termica_zonal.mat'));
    relativa = strrep(ruta_relativa_correccion_default(corr), '\', '/');
    assert(contains(relativa, 'Monopolo/1ant/Caso_1/Potencia_30W/', ...
        'IgnoreCase', true));
    assert(contains(relativa, ...
        'Fecha_19_jun/Tiempo_20min/Prueba_1/Zonas_4/', 'IgnoreCase', true));
    ruta_temporal = [tempname '.mat'];
    cleanup = onCleanup(@() borrar_temporal_correccion(ruta_temporal));
    guardar_correccion_mat(ruta_temporal, corr);
    equivalente = strrep(ruta_disponible_correccion(ruta_temporal, corr), '\', '/');
    assert(contains(equivalente, '/repetidos/equivalentes/Revision_2/', ...
        'IgnoreCase', true));
    corr_conflicto = corr;
    corr_conflicto.y_delta(end) = corr_conflicto.y_delta(end) + 1;
    conflicto = strrep(ruta_disponible_correccion( ...
        ruta_temporal, corr_conflicto), '\', '/');
    assert(contains(conflicto, '/repetidos/conflictos/Revision_2/', ...
        'IgnoreCase', true));
    clear cleanup;
    fprintf('SELFTEST_CORR_METADATA_OK %s\n', relativa);
end

function txt = campo_corr_texto(corr, campo)
    txt = '';
    if isstruct(corr) && isfield(corr, campo) && ~isempty(corr.(campo))
        txt = char(corr.(campo));
    end
end

function tag = tag_carpeta_experimental(ruta_exp)
    tag = simplificar_tag_archivo(carpeta_contenedora_exp(ruta_exp), 24);
    if strcmp(tag, 'datos')
        tag = '';
    end
end

function carpeta = carpeta_contenedora_exp(ruta_exp)
    carpeta = '';
    if isempty(ruta_exp) || ~isfile(ruta_exp)
        return;
    end
    [folder, ~, ~] = fileparts(ruta_exp);
    try
        paths = tesis_auxiliares('dataset_paths');
        root_exp = char(paths.experimentales);
        if strcmp(folder, root_exp)
            return;
        end
        rel = erase(folder, [root_exp filesep]);
        if isempty(rel) || strcmp(rel, folder)
            return;
        end
        partes = regexp(rel, '[\\/]', 'split');
        carpeta = partes{end};
    catch
        [~, carpeta] = fileparts(folder);
    end
end

function tag = simplificar_tag_archivo(txt, nmax)
    tag = lower(regexprep(txt, '[^\w]+', '_'));
    tag = regexprep(tag, '_+', '_');
    tag = regexprep(tag, '^_|_$', '');
    if isempty(tag)
        tag = 'datos';
    end
    if numel(tag) > nmax
        tag = tag(1:nmax);
        tag = regexprep(tag, '_+$', '');
    end
end

function dataset = cargar_dataset_termico(ruta)
    dataset = cargar_dataset_termico_compuesto(ruta);
end

function h = horizonte_extrapolacion_cfg(cfg)
    h = NaN;
    if isfield(cfg, 't_extra_max') && ~isempty(cfg.t_extra_max) && ...
            isnumeric(cfg.t_extra_max) && isscalar(cfg.t_extra_max) && isfinite(cfg.t_extra_max)
        h = double(cfg.t_extra_max);
    end
end

function resultado = construir_funcion_volumen(cfg, corr, logfn)
    if nargin < 3 || isempty(logfn)
        logfn = @(varargin) fprintf([varargin{1} '\n'], varargin{2:end});
    end
    dsData = cfg.dataset.(cfg.modelo).(cfg.dsName);
    snapshots = dsData.snapshots;
    t_min_orig = dsData.t_min(:)';
    nTimes = numel(snapshots);
    logfn('Dataset %s/%s: %d instantes.', cfg.modelo, cfg.dsName, nTimes);

    usar_full = isfield(dsData, 'full_field') && ...
        isfield(dsData.full_field, 'points') && ...
        isfield(dsData.full_field, 'T_C') && ...
        size(dsData.full_field.T_C, 2) == nTimes;
    if usar_full
        puntos_fuente = double(dsData.full_field.points);
        temperaturas_fuente = double(dsData.full_field.T_C);
        validos_espaciales = any(isfinite(temperaturas_fuente), 2);
        puntos_dominio = puntos_fuente(validos_espaciales, :);
        logfn('Usando full_field: %d puntos fuente.', size(puntos_dominio, 1));
    else
        puntos_dominio = zeros(0, 3);
        for ti = 1:nTimes
            puntos_dominio = [puntos_dominio; snapshots(ti).points]; %#ok<AGROW>
        end
        logfn('Sin full_field: usando nubes filtradas de snapshots.');
    end
    if isempty(puntos_dominio)
        error('Sin puntos termicos en el dataset.');
    end

    [xg, yg, zg, gridPoints, bbox] = construir_malla(puntos_dominio, cfg);
    nGrid = size(gridPoints, 1);
    logfn('Malla %d x %d x %d = %d voxeles.', cfg.nx, cfg.ny, cfg.nz, nGrid);

    T_grid_time = NaN(nGrid, nTimes);
    for ti = 1:nTimes
        if usar_full
            pts = puntos_fuente;
            Tvals = temperaturas_fuente(:, ti);
        else
            pts = double(snapshots(ti).points);
            Tvals = double(snapshots(ti).T(:));
        end
        valid = all(isfinite(pts), 2) & isfinite(Tvals);
        if sum(valid) < 4
            continue;
        end
        F = scatteredInterpolant(pts(valid,1), pts(valid,2), pts(valid,3), ...
            Tvals(valid), 'linear', 'linear');
        T_grid_time(:, ti) = F(gridPoints(:,1), gridPoints(:,2), gridPoints(:,3));
        if mod(ti, max(1, floor(nTimes/5))) == 0
            logfn('Mallado espacial %d/%d.', ti, nTimes);
        end
    end

    validTimes = any(isfinite(T_grid_time), 1);
    if ~any(validTimes)
        error('No se pudo construir ningun instante termico.');
    end
    horizonte_cfg = horizonte_extrapolacion_cfg(cfg);
    if isfinite(horizonte_cfg) && horizonte_cfg > 0
        dentro_horizonte = t_min_orig <= horizonte_cfg + 1e-9;
        if any(validTimes & dentro_horizonte)
            validTimes = validTimes & dentro_horizonte;
            logfn('Campo 4D limitado al horizonte %.4g min: %d instantes fuente.', ...
                horizonte_cfg, nnz(validTimes));
        else
            logfn('Horizonte %.4g min anterior a los datos utiles; se conserva rango completo.', horizonte_cfg);
        end
    end
    T_grid_time = T_grid_time(:, validTimes);
    t_valid = t_min_orig(validTimes);
    [t_fine, orden_t] = sort(t_valid);
    t_fine = t_fine(:)';
    T_4D_vec = T_grid_time(:, orden_t);
    [t_fine, indices_unicos] = unique(t_fine, 'stable');
    T_4D_vec = T_4D_vec(:, indices_unicos);
    if numel(t_fine) < 2
        error('Se requieren al menos dos minutos fuente para extrapolar/corregir el volumen 4D.');
    end
    cfg.nt_fine = numel(t_fine);
    % Interpolacion temporal fina pausada: se conserva el muestreo real en minutos.
    logfn('Campo 4D construido con %d instantes fuente en minutos.', cfg.nt_fine);

    voxel_vol = (bbox.xmax-bbox.xmin)/(cfg.nx-1) * ...
        (bbox.ymax-bbox.ymin)/(cfg.ny-1) * ...
        (bbox.zmax-bbox.zmin)/(cfg.nz-1);
    V_base = calcular_volumen_por_tiempo(T_4D_vec, cfg.T_abl, voxel_vol);

    t_extra_obj = horizonte_extrapolacion_cfg(cfg);
    if ~isfinite(t_extra_obj) || t_extra_obj <= 0
        t_extra_obj = max(t_fine);
        cfg.nt_ext = 0;
        logfn('T extra max min=0: sin extrapolacion automatica; horizonte final %.4g min.', t_extra_obj);
    elseif t_extra_obj <= max(t_fine) + 1e-9
        cfg.nt_ext = 0;
        logfn('Horizonte %.4g min cubierto por datos fuente; sin tramo extrapolado.', t_extra_obj);
    else
        cfg.nt_ext = max(0, round(cfg.nt_ext));
    end
    cfg.t_extra_max = t_extra_obj;
    extrap = construir_extrapolacion_campo(T_4D_vec, t_fine, cfg.nt_ext, ...
        cfg.t_extra_max, cfg.T_abl, voxel_vol);
    [T_ext_sel, sigma_sel, modelo_sel] = seleccionar_extrapolacion(extrap, cfg.estrategia);
    t_full = [t_fine, extrap.t_ext_only];
    T_export_vec = [T_4D_vec, T_ext_sel];
    T_export_nd = permute(reshape(T_export_vec, ...
        [cfg.ny, cfg.nx, cfg.nz, numel(t_full)]), [2, 1, 3, 4]);
    Fgrid_ext = griddedInterpolant({xg, yg, zg, t_full}, ...
        T_export_nd, 'linear', 'linear');
    T_export_base_nd = T_export_nd;
    Fgrid_base = Fgrid_ext;
    T_base_vec = T_4D_vec(:, 1);
    V_ext = calcular_volumen_por_tiempo(T_ext_sel, cfg.T_abl, voxel_vol);

    V_corr = [];
    correccion_exportada = struct('activa', false);
    if ~isempty(corr)
        [T_export_nd, V_corr, correccion_exportada] = aplicar_correccion_volumen( ...
            T_export_nd, T_base_vec, t_full, cfg, corr, voxel_vol, zg);
        Fgrid_ext = griddedInterpolant({xg, yg, zg, t_full}, ...
            T_export_nd, 'linear', 'linear');
        logfn('Correccion termica aplicada al campo exportado.');
    end

    tag = tag_resultado_volumen(cfg, corr);
    archivos = struct('mat', '', 'm', '', 'rbf', '');

    resultado = struct( ...
        'modelo', cfg.modelo, ...
        'dsName', cfg.dsName, ...
        'T_abl', cfg.T_abl, ...
        't_fine', t_fine, ...
        't_ext', extrap.t_ext_only, ...
        't_full', t_full, ...
        'xg', xg, ...
        'yg', yg, ...
        'zg', zg, ...
        'V_base', V_base, ...
        'V_ext', V_ext, ...
        'V_corr', V_corr, ...
        'Fgrid_ext', Fgrid_ext, ...
        'Fgrid_base', Fgrid_base, ...
        'T_export_base_nd', T_export_base_nd, ...
        'T_4D_vec', T_4D_vec, ...
        'T_base_vec', T_base_vec, ...
        'extrap', extrap, ...
        'modelo_tipo', modelo_sel.tipo, ...
        'modelo_params', modelo_sel.params, ...
        'modelo_sel', modelo_sel, ...
        'sigma_sel', sigma_sel, ...
        'tag', tag, ...
        'cfg', cfg, ...
        'voxel_vol', voxel_vol, ...
        'correccion_exportada', correccion_exportada, ...
        'correccion_fuente', corr, ...
        'archivos', archivos);
end

function [xg, yg, zg, gridPoints, bbox] = construir_malla(puntos, cfg)
    xmin = min(puntos(:,1)); xmax = max(puntos(:,1));
    ymin = min(puntos(:,2)); ymax = max(puntos(:,2));
    zmin = min(puntos(:,3)); zmax = max(puntos(:,3));
    mg = 0.05;
    xmin = xmin - mg*(xmax-xmin); xmax = xmax + mg*(xmax-xmin);
    ymin = ymin - mg*(ymax-ymin); ymax = ymax + mg*(ymax-ymin);
    zmin = zmin - mg*(zmax-zmin); zmax = zmax + mg*(zmax-zmin);
    xg = linspace(xmin, xmax, cfg.nx);
    yg = linspace(ymin, ymax, cfg.ny);
    zg = linspace(zmin, zmax, cfg.nz);
    [X, Y, Z] = meshgrid(xg, yg, zg);
    gridPoints = [X(:), Y(:), Z(:)];
    bbox = struct('xmin', xmin, 'xmax', xmax, ...
        'ymin', ymin, 'ymax', ymax, 'zmin', zmin, 'zmax', zmax);
end

function V = calcular_volumen_por_tiempo(T_mat, T_abl, voxel_vol)
    V = zeros(1, size(T_mat, 2));
    for k = 1:size(T_mat, 2)
        T = T_mat(:, k);
        V(k) = sum(isfinite(T) & T >= T_abl) * voxel_vol;
    end
end

function extrap = construir_extrapolacion_campo(T_4D_vec, t_fine, ~, t_extra_max, T_abl, voxel_vol)
    nGrid = size(T_4D_vec, 1);
    if ~isfinite(t_extra_max) || t_extra_max <= max(t_fine) + 1e-9
        vacio = zeros(nGrid, 0);
        extrap = struct('t_ext_only', [], 'grad', vacio, 'lowess', vacio, 'pca', vacio, ...
            'sigma_grad', vacio, 'sigma_low', vacio, 'sigma_pca', vacio, ...
            'V_grad', [], 'V_lowess', [], 'V_pca', [], ...
            'meta_grad', struct(), 'meta_low', struct(), 'meta_pca', struct());
        return;
    end
    nt_fine = numel(t_fine);
    t_ext_only = tiempos_extrapolacion_minutos(t_fine(end), t_extra_max);
    nt_ext = numel(t_ext_only);
    if nt_ext == 0
        vacio = zeros(nGrid, 0);
        extrap = struct('t_ext_only', [], 'grad', vacio, 'lowess', vacio, 'pca', vacio, ...
            'sigma_grad', vacio, 'sigma_low', vacio, 'sigma_pca', vacio, ...
            'V_grad', [], 'V_lowess', [], 'V_pca', [], ...
            'meta_grad', struct(), 'meta_low', struct(), 'meta_pca', struct());
        return;
    end
    k_win = min(12, nt_fine);
    t_win = t_fine(end-k_win+1:end);
    T_win = T_4D_vec(:, end-k_win+1:end);
    dt_ext = t_ext_only - t_fine(end);

    t_win_c = t_win - t_fine(end);
    Sxx = sum(t_win_c.^2);
    a_grad = T_4D_vec(:, end);
    b_grad = ((T_win - a_grad) * t_win_c') / Sxx;
    resid_grad = T_win - (a_grad + b_grad * t_win_c);
    rmse_grad = sqrt(mean(resid_grad.^2, 2));
    T_ext_grad = NaN(nGrid, nt_ext);
    sigma_grad = NaN(nGrid, nt_ext);
    for ei = 1:nt_ext
        T_ext_grad(:, ei) = a_grad + b_grad * dt_ext(ei);
        sigma_grad(:, ei) = rmse_grad * sqrt(1 + dt_ext(ei)^2 / Sxx);
    end

    span_t = max(eps, t_fine(end) - t_win(1));
    u_win = (t_win - t_fine(end)) / span_t;
    w_low = max(1 - abs(u_win).^3, 0).^3;
    W = diag(w_low);
    Phi = [ones(k_win,1), t_win_c', t_win_c'.^2];
    PhiW = Phi' * W;
    AtA = PhiW * Phi + 1e-8 * eye(3);
    coef_low = AtA \ (PhiW * T_win');
    coef_low(1, :) = T_4D_vec(:, end)';
    fit_low = (Phi * coef_low)';
    rmse_low = sqrt(sum(w_low .* (T_win - fit_low).^2, 2) / sum(w_low));
    T_ext_low = NaN(nGrid, nt_ext);
    sigma_low = NaN(nGrid, nt_ext);
    for ei = 1:nt_ext
        phi = [1, dt_ext(ei), dt_ext(ei)^2];
        T_ext_low(:, ei) = (phi * coef_low)';
        sigma_low(:, ei) = rmse_low * (1 + abs(dt_ext(ei)) / span_t);
    end

    T_mean = mean(T_4D_vec, 2, 'omitnan');
    T_center = T_4D_vec - T_mean;
    T_center(~isfinite(T_center)) = 0;
    [U, S, V] = svd(T_center, 'econ');
    sv = diag(S);
    energia_total = sum(sv.^2);
    if energia_total <= eps
        energia = 1;
        r_pca = 1;
    else
        energia = cumsum(sv.^2) / energia_total;
        r_pca = find(energia >= 0.99, 1, 'first');
        r_pca = min(numel(sv), max(r_pca, min(3, numel(sv))));
    end
    U_r = U(:, 1:r_pca);
    S_r = S(1:r_pca, 1:r_pca);
    V_r = V(:, 1:r_pca);
    V_ext = zeros(nt_ext, r_pca);
    dv_dt = zeros(r_pca, 1);
    for ri = 1:r_pca
        modo = V_r(:, ri);
        dv_dt(ri) = (modo(end) - modo(end-1)) / (t_fine(end) - t_fine(end-1));
        V_ext(:, ri) = modo(end) + dv_dt(ri) * dt_ext';
    end
    T_ext_pca = (U_r * S_r * V_ext')' + T_mean';
    T_ext_pca = T_ext_pca';
    T_pca_inicio = T_mean + U_r * S_r * V_r(end, :)';
    T_ext_pca = T_ext_pca + (T_4D_vec(:, end) - T_pca_inicio);
    sigma_pca = (sigma_grad + sigma_low) / 2;

    extrap = struct( ...
        't_ext_only', t_ext_only, ...
        'grad', T_ext_grad, ...
        'lowess', T_ext_low, ...
        'pca', T_ext_pca, ...
        'sigma_grad', sigma_grad, ...
        'sigma_low', sigma_low, ...
        'sigma_pca', sigma_pca, ...
        'V_grad', calcular_volumen_por_tiempo(T_ext_grad, T_abl, voxel_vol), ...
        'V_lowess', calcular_volumen_por_tiempo(T_ext_low, T_abl, voxel_vol), ...
        'V_pca', calcular_volumen_por_tiempo(T_ext_pca, T_abl, voxel_vol), ...
        'meta_grad', struct('tipo', 'gradiente_local', 'a_grad', a_grad, 'b_grad', b_grad, 'rmse', rmse_grad), ...
        'meta_low', struct('tipo', 'lowess_cuadratico', 'coeficientes', coef_low, 'rmse', rmse_low), ...
        'meta_pca', struct('tipo', 'pca_temporal', 'rango', r_pca, ...
            'energia_retenida', energia(r_pca), 'derivada_modos', dv_dt));
end

function t_ext = tiempos_extrapolacion_minutos(t_inicio, t_fin)
    primer_minuto = floor(double(t_inicio) + 1e-9) + 1;
    ultimo_minuto = floor(double(t_fin) + 1e-9);
    if ultimo_minuto < primer_minuto
        t_ext = [];
    else
        t_ext = primer_minuto:ultimo_minuto;
    end
end

function [T_ext, sigma, modelo] = seleccionar_extrapolacion(extrap, estrategia)
    if isempty(extrap.t_ext_only)
        T_ext = zeros(size(extrap.grad, 1), 0);
        sigma = [];
        modelo = struct('tipo', 'sin_extrapolacion', 'params', struct());
        return;
    end
    switch estrategia
        case 'Gradiente local'
            T_ext = extrap.grad;
            sigma = extrap.sigma_grad;
            modelo = struct('tipo', 'gradiente_local', 'params', extrap.meta_grad);
        case 'LOWESS'
            T_ext = extrap.lowess;
            sigma = extrap.sigma_low;
            modelo = struct('tipo', 'lowess_cuadratico', 'params', extrap.meta_low);
        otherwise
            T_ext = extrap.pca;
            sigma = extrap.sigma_pca;
            modelo = struct('tipo', 'pca_temporal', 'params', extrap.meta_pca);
    end
end

function tipo = normalizar_estrategia(estrategia)
    switch estrategia
        case 'Gradiente local'
            tipo = 'gradiente_local';
        case 'LOWESS'
            tipo = 'lowess_cuadratico';
        case 'PCA temporal'
            tipo = 'pca_temporal';
        otherwise
            tipo = '';
    end
end

function [T_nd_corr, V_corr, meta] = aplicar_correccion_volumen(T_nd, T_base_vec, t_full, cfg, corr, voxel_vol, zg)
    T_nd_corr = T_nd;
    ct = corr.correccion_termica;
    t_rel_vec = ct.t_rel_min(:);
    factor_vec = ct.factor_enfriamiento(:);
    extrap = ct.extrapolacion_factor;
    if isfield(ct, 't_origen_simulacion_min') && isfinite(ct.t_origen_simulacion_min)
        t0 = ct.t_origen_simulacion_min;
    else
        t0 = min(t_full);
    end
    offset_base = 0;
    if cfg.aplicar_offset_base && isfield(ct, 'offset_base_C')
        offset_base = cfg.intensidad_correccion * ct.offset_base_C;
    end
    base_nd = permute(reshape(T_base_vec, ...
        [size(T_nd,2), size(T_nd,1), size(T_nd,3)]), [2,1,3]);
    V_corr = zeros(1, numel(t_full));
    zonas = obtener_zonas_correccion(ct);
    if ~isempty(zonas) && nargin >= 7 && ~isempty(zg)
        Z_nd = repmat(reshape(zg(:)', 1, 1, []), ...
            size(T_nd, 1), size(T_nd, 2), 1);
        factores_zona = NaN(numel(t_full), numel(zonas));
        for ti = 1:numel(t_full)
            Ttmp = T_nd(:,:,:,ti);
            for zi = 1:numel(zonas)
                zona = zonas(zi);
                t0_z = obtener_origen_zona(zona, t0);
                t_rel_z = t_full(ti) - t0_z;
                [factor_modelo, activo] = evaluar_factor_zona(t_rel_z, zona);
                if ~activo
                    continue;
                end
                factor_z = 1 + cfg.intensidad_correccion * (factor_modelo - 1);
                offset_z = 0;
                if cfg.aplicar_offset_base && isfield(zona, 'offset_base_C')
                    offset_z = cfg.intensidad_correccion * zona.offset_base_C;
                elseif cfg.aplicar_offset_base && isfield(ct, 'offset_base_C')
                    offset_z = cfg.intensidad_correccion * ct.offset_base_C;
                end
                mask_z = mascara_zona_z(Z_nd, zona, zi, numel(zonas));
                Ttmp(mask_z) = base_nd(mask_z) + offset_z + ...
                    factor_z .* (Ttmp(mask_z) - base_nd(mask_z));
                factores_zona(ti, zi) = factor_z;
            end
            Ttmp = limitar_temperatura_corregida_volumen(Ttmp, corr, cfg);
            T_nd_corr(:,:,:,ti) = Ttmp;
            Tvol = T_nd_corr(:,:,:,ti);
            V_corr(ti) = sum(isfinite(Tvol(:)) & Tvol(:) >= cfg.T_abl) * voxel_vol;
        end
        meta = struct( ...
            'activa', true, ...
            'convencion', 'factor_sobre_incremento_termico_local', ...
            'metodo', 'factor_incremento_pchip_pca_ssa_zonal', ...
            'modo_espacial', 'zonas_profundidad_z', ...
            't_origen_dataset_min', t0, ...
            'zonas', zonas, ...
            'z_edges_mm', obtener_z_edges_desde_zonas(zonas), ...
            'factores_zona_aplicados', factores_zona, ...
            'temperatura_max_corregida_C', limite_temperatura_corregida_volumen(corr, cfg), ...
            'intensidad_correccion', cfg.intensidad_correccion, ...
            'aplicar_offset_base', cfg.aplicar_offset_base);
        return;
    end
    for ti = 1:numel(t_full)
        t_rel = t_full(ti) - t0;
        [factor_modelo, activo] = evaluar_factor_termico(t_rel, t_rel_vec, factor_vec, extrap);
        if activo
            factor = 1 + cfg.intensidad_correccion * (factor_modelo - 1);
            T_nd_corr(:,:,:,ti) = base_nd + offset_base + ...
                factor .* (T_nd(:,:,:,ti) - base_nd);
        end
        T_nd_corr(:,:,:,ti) = limitar_temperatura_corregida_volumen( ...
            T_nd_corr(:,:,:,ti), corr, cfg);
        Ttmp = T_nd_corr(:,:,:,ti);
        V_corr(ti) = sum(isfinite(Ttmp(:)) & Ttmp(:) >= cfg.T_abl) * voxel_vol;
    end
    meta = struct( ...
        'activa', true, ...
        'convencion', 'factor_sobre_incremento_termico_local', ...
        'metodo', 'factor_incremento_pchip_pca_ssa', ...
        't_origen_dataset_min', t0, ...
        'intervalo_relativo_valido_min', [min(t_rel_vec), max(t_rel_vec)], ...
        't_rel_min', t_rel_vec, ...
        'factor_enfriamiento', factor_vec, ...
        'extrapolacion_factor', extrap, ...
        'offset_base_C', offset_base, ...
        'temperatura_max_corregida_C', limite_temperatura_corregida_volumen(corr, cfg), ...
        'intensidad_correccion', cfg.intensidad_correccion, ...
        'aplicar_offset_base', cfg.aplicar_offset_base);
end

function res = reaplicar_correccion_volumen_resultado(res, cfg, corr)
    if ~isfield(res, 'T_export_base_nd') || isempty(res.T_export_base_nd)
        error('El resultado 4D no contiene T_export_base_nd para reaplicar correccion.');
    end
    if ~isfield(res, 'Fgrid_base') || isempty(res.Fgrid_base)
        error('El resultado 4D no contiene Fgrid_base para restaurar el campo base.');
    end
    res.cfg = cfg;
    if isempty(corr)
        res.Fgrid_ext = res.Fgrid_base;
        res.V_corr = [];
        res.correccion_exportada = struct('activa', false);
        res.correccion_fuente = [];
        res.tag = tag_resultado_volumen(cfg, []);
        return;
    end
    [T_nd_corr, V_corr, meta] = aplicar_correccion_volumen( ...
        res.T_export_base_nd, res.T_base_vec, res.t_full, cfg, corr, ...
        res.voxel_vol, res.zg);
    res.Fgrid_ext = griddedInterpolant({res.xg, res.yg, res.zg, res.t_full}, ...
        T_nd_corr, 'linear', 'linear');
    res.V_corr = V_corr;
    res.correccion_exportada = meta;
    res.correccion_fuente = corr;
    res.tag = tag_resultado_volumen(cfg, corr);
end

function T_corr = limitar_temperatura_corregida_volumen(T_corr, corr, cfg)
    limite = limite_temperatura_corregida_volumen(corr, cfg);
    if isfinite(limite)
        T_corr(T_corr > limite) = limite;
    end
end

function limite = limite_temperatura_corregida_volumen(corr, cfg)
    limite = 120;
    if isstruct(cfg) && isfield(cfg, 'temperatura_max_corregida_C')
        limite = cfg.temperatura_max_corregida_C;
    end
    if isempty(limite) || ~isnumeric(limite) || ~isscalar(limite) || ~isfinite(limite)
        limite = 120;
    end
    limite = min(double(limite), 120);
    exp_max = max_experimental_correccion_volumen(corr);
    if isfinite(exp_max)
        limite = min(limite, exp_max);
    end
end

function exp_max = max_experimental_correccion_volumen(corr)
    exp_max = max_vector_finito_volumen(corr, 'y_exp_interp');
    if isstruct(corr) && isfield(corr, 'correccion_termica')
        ct = corr.correccion_termica;
        exp_max = max([exp_max, max_vector_finito_volumen(ct, 'y_exp_interp')], [], 'omitnan');
        if isfield(ct, 'zonas') && ~isempty(ct.zonas)
            for zi = 1:numel(ct.zonas)
                exp_max = max([exp_max, max_vector_finito_volumen(ct.zonas(zi), 'y_exp_interp')], [], 'omitnan');
            end
        end
    end
    if isempty(exp_max) || ~isfinite(exp_max)
        exp_max = NaN;
    end
end

function vmax = max_vector_finito_volumen(s, campo)
    vmax = NaN;
    if isstruct(s) && isfield(s, campo) && isnumeric(s.(campo)) && ~isempty(s.(campo))
        vals = double(s.(campo)(:));
        vals = vals(isfinite(vals));
        if ~isempty(vals)
            vmax = max(vals);
        end
    end
end

function n = contar_zonas_correccion(ct)
    n = numel(obtener_zonas_correccion(ct));
end

function zonas = obtener_zonas_correccion(ct)
    zonas = struct([]);
    if isstruct(ct) && isfield(ct, 'zonas') && ~isempty(ct.zonas)
        zonas = ct.zonas(:);
    end
end

function t0 = obtener_origen_zona(zona, t0_global)
    t0 = t0_global;
    if isfield(zona, 't_origen_simulacion_min') && ...
            isscalar(zona.t_origen_simulacion_min) && ...
            isfinite(zona.t_origen_simulacion_min)
        t0 = zona.t_origen_simulacion_min;
    end
end

function [factor, activo] = evaluar_factor_zona(t_rel, zona)
    factor = 1;
    activo = false;
    if ~isfield(zona, 't_rel_min') || ~isfield(zona, 'factor_enfriamiento')
        return;
    end
    t_rel_vec = zona.t_rel_min(:);
    factor_vec = zona.factor_enfriamiento(:);
    if isfield(zona, 'extrapolacion_factor')
        extrap = zona.extrapolacion_factor;
    else
        extrap = struct();
    end
    [factor, activo] = evaluar_factor_termico(t_rel, t_rel_vec, factor_vec, extrap);
end

function mask_z = mascara_zona_z(Z_nd, zona, idx_zona, n_zonas)
    z_min = -Inf;
    z_max = Inf;
    if isfield(zona, 'z_min_mm')
        z_min = zona.z_min_mm;
    end
    if isfield(zona, 'z_max_mm')
        z_max = zona.z_max_mm;
    end
    if idx_zona == n_zonas
        mask_z = Z_nd >= z_min & Z_nd <= z_max;
    else
        mask_z = Z_nd >= z_min & Z_nd < z_max;
    end
end

function z_edges = obtener_z_edges_desde_zonas(zonas)
    if isempty(zonas)
        z_edges = [];
        return;
    end
    z_edges = [zonas(1).z_min_mm, arrayfun(@(z) z.z_max_mm, zonas(:)')];
end

function [factor, activo] = evaluar_factor_termico(t_rel, t_rel_vec, factor_vec, extrap)
    factor = 1;
    activo = false;
    if isempty(t_rel_vec) || numel(t_rel_vec) < 2 || numel(t_rel_vec) ~= numel(factor_vec)
        return;
    end
    if t_rel < min(t_rel_vec) - 1e-9
        return;
    end
    if t_rel <= max(t_rel_vec) + 1e-9
        factor = interp1(t_rel_vec, factor_vec, t_rel, 'pchip');
    else
        factor = extrapolar_factor_ui(t_rel, extrap);
    end
    factor = max(0, min(1, factor));
    activo = isfinite(factor);
end

function archivos = exportar_volumen_desde_resultado(cfg, res, logfn)
    if nargin < 3 || isempty(logfn)
        logfn = @(varargin) fprintf([varargin{1} '\n'], varargin{2:end});
    end
    modelo_sel = struct('tipo', res.modelo_tipo, 'params', res.modelo_params);
    if isfield(res, 'modelo_sel') && ~isempty(res.modelo_sel)
        modelo_sel = res.modelo_sel;
    end
    correccion_exportada = struct('activa', false);
    if isfield(res, 'correccion_exportada')
        correccion_exportada = res.correccion_exportada;
    end
    voxel_vol = res.voxel_vol;
    metodos_extrapolacion = construir_metodos_extrapolacion_exportables(res, cfg, logfn);
    Fgrid_sin_correccion = [];
    if isfield(res, 'Fgrid_base') && ~isempty(res.Fgrid_base)
        Fgrid_sin_correccion = res.Fgrid_base;
    end
    archivos = exportar_resultados_volumen(cfg, res.tag, res.Fgrid_ext, ...
        Fgrid_sin_correccion, res.xg, res.yg, res.zg, res.t_full, res.t_fine, res.V_base, ...
        res.V_corr, modelo_sel, voxel_vol, correccion_exportada, ...
        metodos_extrapolacion, logfn);
end

function metodos = construir_metodos_extrapolacion_exportables(res, cfg, logfn)
    metodos = struct();
    if nargin < 3 || isempty(logfn)
        logfn = @(varargin) fprintf([varargin{1} '\n'], varargin{2:end});
    end
    if ~isfield(res, 'T_4D_vec') || ~isfield(res, 'extrap') || ...
            ~isfield(res.extrap, 't_ext_only') || isempty(res.extrap.t_ext_only)
        return;
    end
    defs = struct( ...
        'campo', {'pca', 'lowess', 'grad'}, ...
        'volumen', {'V_pca', 'V_lowess', 'V_grad'}, ...
        'meta', {'meta_pca', 'meta_low', 'meta_grad'}, ...
        'nombre', {'pca_temporal', 'lowess_cuadratico', 'gradiente_local'});
    nx = numel(res.xg); ny = numel(res.yg); nz = numel(res.zg);
    t_full_m = [res.t_fine, res.extrap.t_ext_only];
    for mi = 1:numel(defs)
        d = defs(mi);
        if ~isfield(res.extrap, d.campo) || isempty(res.extrap.(d.campo))
            continue;
        end
        T_vec = [res.T_4D_vec, res.extrap.(d.campo)];
        if size(T_vec, 1) ~= nx * ny * nz
            logfn('Metodo %s omitido en exportacion: dimensiones incompatibles.', d.nombre);
            continue;
        end
        T_nd = permute(reshape(T_vec, [ny, nx, nz, numel(t_full_m)]), [2, 1, 3, 4]);
        T_nd_sin_corr = T_nd;
        V_sin_corr = res.V_base;
        if isfield(res.extrap, d.volumen)
            V_sin_corr = [res.V_base, res.extrap.(d.volumen)];
        end
        Fgrid_sin_corr_m = griddedInterpolant({res.xg, res.yg, res.zg, t_full_m}, ...
            T_nd_sin_corr, 'linear', 'linear');
        V_corr_m = [];
        Fgrid_corr_m = [];
        correccion_metodo = struct('activa', false);
        if isfield(res, 'correccion_fuente') && ~isempty(res.correccion_fuente)
            [T_nd, V_corr_m, correccion_metodo] = aplicar_correccion_volumen( ...
                T_nd, res.T_base_vec, t_full_m, cfg, res.correccion_fuente, ...
                res.voxel_vol, res.zg);
            Fgrid_corr_m = griddedInterpolant({res.xg, res.yg, res.zg, t_full_m}, ...
                T_nd, 'linear', 'linear');
        end
        Fgrid_m = Fgrid_sin_corr_m;
        V_export = V_sin_corr;
        if ~isempty(Fgrid_corr_m)
            Fgrid_m = Fgrid_corr_m;
        end
        if ~isempty(V_corr_m)
            V_export = V_corr_m;
        end
        params = struct();
        if isfield(res.extrap, d.meta)
            params = res.extrap.(d.meta);
        end
        metodos.(d.nombre) = struct( ...
            'Fgrid_ext', Fgrid_m, ...
            'Fgrid_sin_correccion', Fgrid_sin_corr_m, ...
            'Fgrid_corregido', Fgrid_corr_m, ...
            't_exp', t_full_m, ...
            't_fine_exp', res.t_fine, ...
            'V_base_exp', V_export, ...
            'V_sin_correccion', V_sin_corr, ...
            'V_corr', V_corr_m, ...
            'modelo_tipo', d.nombre, ...
            'modelo_params', params, ...
            'correccion_exportada', correccion_metodo);
    end
    nombres = fieldnames(metodos);
    if ~isempty(nombres)
        logfn('Metodos de extrapolacion incluidos en MAT: %s.', strjoin(nombres', ', '));
    end
end

function archivos = exportar_resultados_volumen(cfg, tag, Fgrid_ext, Fgrid_sin_correccion, xg, yg, zg, ...
        t_full, t_fine, V_base, V_corr, modelo_sel, voxel_vol, correccion_exportada, metodos_extrapolacion, logfn)
    archivos = struct('mat', '', 'm', '', 'rbf', '');
    if ~isfolder(cfg.carpeta_exportacion)
        mkdir(cfg.carpeta_exportacion);
    end
    if cfg.export_mat
        out_mat = fullfile(cfg.carpeta_exportacion, sprintf('T4D_%s.mat', tag));
        xg_exp = xg; yg_exp = yg; zg_exp = zg; t_exp = t_full;
        T_abl_exp = cfg.T_abl;
        V_sin_correccion = V_base;
        V_corr_exp = V_corr;
        V_base_exp = V_base;
        Fgrid_corregido = [];
        if ~isempty(V_corr)
            V_base_exp = V_corr;
            Fgrid_corregido = Fgrid_ext;
        end
        t_fine_exp = t_fine;
        modelo_nombre = modelo_sel.tipo;
        modelo_params = modelo_sel.params;
        modelo_tipo = modelo_sel.tipo;
        nx = cfg.nx; ny = cfg.ny; nz = cfg.nz;
        p_corr_save = [];
        save(out_mat, 'Fgrid_ext', 'Fgrid_sin_correccion', 'Fgrid_corregido', ...
            'xg_exp', 'yg_exp', 'zg_exp', 't_exp', ...
            'T_abl_exp', 'V_base_exp', 'V_sin_correccion', 'V_corr_exp', 't_fine_exp', ...
            'modelo_nombre', 'modelo_params', 'modelo_tipo', ...
            'nx', 'ny', 'nz', 'voxel_vol', 'p_corr_save', ...
            'correccion_exportada', 'metodos_extrapolacion', '-v7.3');
        archivos.mat = out_mat;
        logfn('T4D .mat exportado: %s', out_mat);
    end
    if cfg.export_m
        out_m = fullfile(cfg.carpeta_exportacion, sprintf('T_funcion_%s.m', tag));
        escribir_funcion_exportada(out_m, tag, cfg, t_full, modelo_sel);
        archivos.m = out_m;
        logfn('Funcion .m exportada: %s', out_m);
    end
    if cfg.export_rbf
        out_rbf = fullfile(cfg.carpeta_exportacion, sprintf('RBF_%s.mat', tag));
        exportar_rbf(out_rbf, Fgrid_ext, xg, yg, zg, t_fine, cfg);
        archivos.rbf = out_rbf;
        logfn('RBF exportado: %s', out_rbf);
    end
end

function escribir_funcion_exportada(out_m, tag, cfg, t_full, modelo_sel)
    fid = fopen(out_m, 'w');
    if fid < 0
        error('No se pudo crear %s', out_m);
    end
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'function T_out = T_funcion_%s(x, y, z, t)\n', tag);
    fprintf(fid, '%% T_funcion_%s - Campo termico 4D exportado\n', tag);
    fprintf(fid, '%% Generado por correlador_volumen_interpolado_ui\n');
    fprintf(fid, '%% Dataset: %s / %s\n', cfg.modelo, cfg.dsName);
    fprintf(fid, '%% Dominio temporal: [%.4f, %.4f] min\n', min(t_full), max(t_full));
    fprintf(fid, '%% Umbral ablacion: %.1f C\n', cfg.T_abl);
    fprintf(fid, '%% Modelo V(t): %s\n\n', modelo_sel.tipo);
    fprintf(fid, 'persistent Fgrid_loaded\n');
    fprintf(fid, 'if isempty(Fgrid_loaded)\n');
    fprintf(fid, '    data_path = fullfile(fileparts(mfilename(''fullpath'')), ''T4D_%s.mat'');\n', tag);
    fprintf(fid, '    if ~isfile(data_path)\n');
    fprintf(fid, '        error(''Archivo T4D_%s.mat no encontrado.'');\n', tag);
    fprintf(fid, '    end\n');
    fprintf(fid, '    S = load(data_path, ''Fgrid_ext'');\n');
    fprintf(fid, '    Fgrid_loaded = S.Fgrid_ext;\n');
    fprintf(fid, 'end\n');
    fprintf(fid, 'T_out = Fgrid_loaded(x, y, z, t);\n');
    fprintf(fid, 'end\n');
end

function exportar_rbf(out_rbf, Fgrid_ext, xg, yg, zg, t_fine, cfg)
    rng(42);
    [Xr, Yr, Zr, Tr] = ndgrid(xg, yg, zg, t_fine);
    pts4D = [Xr(:), Yr(:), Zr(:), Tr(:)];
    vals = Fgrid_ext.Values(:,:,:,1:numel(t_fine));
    Tvals = vals(:);
    valid = isfinite(Tvals);
    pts4D = pts4D(valid, :);
    Tvals = Tvals(valid);
    n_total = numel(Tvals);
    n_centers = min(round(cfg.n_rbf_max), n_total);
    idx = randperm(n_total, n_centers);
    pts4D_rbf = pts4D(idx, :);
    Tvals_rbf = Tvals(idx);
    kernel = @(r2) r2 .* log(sqrt(r2) + 1e-10);
    A = zeros(n_centers, n_centers);
    for ci = 1:n_centers
        d = pts4D_rbf - pts4D_rbf(ci, :);
        A(:, ci) = kernel(sum(d.^2, 2));
    end
    A = A + 1e-6 * eye(n_centers);
    w_rbf = A \ Tvals_rbf;
    xg_exp = xg; yg_exp = yg; zg_exp = zg; t_exp = Fgrid_ext.GridVectors{4};
    T_abl_exp = cfg.T_abl;
    save(out_rbf, 'pts4D_rbf', 'w_rbf', 'n_centers', ...
        'xg_exp', 'yg_exp', 'zg_exp', 't_exp', 'T_abl_exp', '-v7.3');
end

function modelo = crear_extrapolacion_factor_ui(t_min, factor)
    t_min = t_min(:);
    factor = factor(:);
    validos = isfinite(t_min) & isfinite(factor);
    t_min = t_min(validos);
    factor = factor(validos);
    [t_min, idx] = unique(t_min, 'stable');
    factor = factor(idx);
    if numel(t_min) < 12 || t_min(end) <= t_min(1)
        modelo = crear_modelo_factor_constante_ui(t_min, factor);
        return;
    end
    frac = 0.50;
    t_inicio = t_min(end) - frac * (t_min(end) - t_min(1));
    idx_train = t_min >= t_inicio;
    n_uniforme = min(301, max(40, sum(idx_train)));
    t_uniforme = linspace(t_min(find(idx_train, 1, 'first')), t_min(end), n_uniforme)';
    factor_uniforme = interp1(t_min, factor, t_uniforme, 'pchip');
    n = numel(factor_uniforme);
    L = min(80, max(12, floor(n / 4)));
    L = min(L, n - 2);
    K = n - L + 1;
    media = mean(factor_uniforme);
    centrado = factor_uniforme - media;
    X = zeros(L, K);
    for c = 1:K
        X(:, c) = centrado(c:c+L-1);
    end
    [U, S, ~] = svd(X, 'econ');
    energia = diag(S).^2;
    if ~any(energia > 0)
        modelo = crear_modelo_factor_constante_ui(t_min, factor);
        return;
    end
    energia_ac = cumsum(energia) / sum(energia);
    r = find(energia_ac >= 0.99, 1, 'first');
    r = max(1, min([r, 8, L - 2]));
    modos = U(:, 1:r);
    ultima = modos(end, :);
    den = 1 - sum(ultima.^2);
    if den <= 1e-8
        modelo = crear_modelo_factor_constante_ui(t_min, factor);
        return;
    end
    coef = (modos(1:end-1, :) * ultima') / den;
    n_cambios = min(40, n - 1);
    cambios = diff(factor_uniforme(end-n_cambios:end));
    max_cambio = max(1e-6, 5 * median(abs(cambios)));
    margen = max(0.01, 0.20 * range(factor_uniforme));
    modelo = struct( ...
        'metodo', 'pca_temporal_embebido_ssa', ...
        't_inicio_min', t_min(end), ...
        'factor_inicio', factor(end), ...
        'paso_min', median(diff(t_uniforme)), ...
        'media_factor', media, ...
        'longitud_ventana', L, ...
        'rango_pca', r, ...
        'energia_retenida', energia_ac(r), ...
        'coeficientes_recurrencia', coef(:), ...
        'historia_centrada', centrado(end-L+2:end), ...
        'max_cambio_por_paso', max_cambio, ...
        'limites_factor', [0, 1], ...
        'limites_extrapolacion', [max(0, min(factor_uniforme)-margen), ...
                                  min(1, max(factor_uniforme)+margen)], ...
        'fraccion_entrenamiento', frac, ...
        'continua_en_valor', true);
end

function modelo = crear_modelo_factor_constante_ui(t_min, factor)
    if isempty(t_min) || isempty(factor)
        modelo = struct('metodo', 'factor_constante_respaldo', ...
            't_inicio_min', 0, 'factor_inicio', 1, ...
            'limites_factor', [0, 1], 'continua_en_valor', true);
    else
        modelo = struct('metodo', 'factor_constante_respaldo', ...
            't_inicio_min', t_min(end), ...
            'factor_inicio', max(0, min(1, factor(end))), ...
            'limites_factor', [0, 1], 'continua_en_valor', true);
    end
end

function factor = extrapolar_factor_ui(t_rel_min, modelo)
    if isempty(modelo) || ~isstruct(modelo) || ~isfield(modelo, 'metodo')
        factor = 1;
        return;
    end
    if strcmp(modelo.metodo, 'pca_temporal_embebido_ssa')
        factor = extrapolar_factor_pca_ui(t_rel_min, modelo);
    else
        factor = modelo.factor_inicio;
    end
end

function factor = extrapolar_factor_pca_ui(t_rel_min, modelo)
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
        siguiente_centrado = modelo.coeficientes_recurrencia(:)' * historia;
        anterior_centrado = valores(paso) - modelo.media_factor;
        cambio = siguiente_centrado - anterior_centrado;
        cambio = max(-modelo.max_cambio_por_paso, ...
            min(modelo.max_cambio_por_paso, cambio));
        siguiente = modelo.media_factor + anterior_centrado + cambio;
        siguiente = max(modelo.limites_extrapolacion(1), ...
            min(modelo.limites_extrapolacion(2), siguiente));
        valores(paso + 1) = siguiente;
        historia = [historia(2:end); siguiente - modelo.media_factor];
    end
    tiempos = (0:n_pasos)' * modelo.paso_min;
    factor = interp1(tiempos, valores, dt, 'linear');
end

function tag = sanitizar_tag(tag)
    tag = regexprep(tag, '[^a-zA-Z0-9_]', '_');
    tag = regexprep(tag, '_+', '_');
    if isempty(tag) || ~isletter(tag(1))
        tag = ['T_' tag];
    end
end

function tag = tag_resultado_volumen(cfg, corr)
    tag_base = sprintf('%s_%s', cfg.modelo, cfg.dsName);
    tag_corr = tag_correccion_volumen(cfg, corr);
    if ~isempty(tag_corr)
        tag_base = sprintf('%s_%s', tag_base, tag_corr);
    end
    tag = sanitizar_tag(tag_base);
end

function tag = tag_correccion_volumen(cfg, corr)
    tag = '';
    if isempty(corr)
        return;
    end
    meta = metadata_correlacion_archivos(corr);
    if metadata_correlacion_especifica_completa(meta)
        tiempo = strrep(sprintf('%g', meta.tiempo_ejecucion_min), '.', 'p');
        tag = sanitizar_tag(sprintf( ...
            'correccion_%s_%smin_prueba_%d_zonas_%d', ...
            meta.fecha_adquisicion, tiempo, round(meta.numero_prueba), ...
            round(meta.num_zonas)));
        return;
    end
    txt = texto_tag_correccion_volumen(cfg, true);
    if isempty(txt)
        txt = texto_tag_correccion_volumen(corr, false);
    end
    if isempty(txt) && isstruct(corr) && isfield(corr, 'correccion_termica')
        txt = texto_tag_correccion_volumen(corr.correccion_termica, false);
    end
    if isempty(txt)
        tag = 'correccion_termica';
        return;
    end
    [~, base, ~] = fileparts(char(txt));
    tag = sanitizar_tag(base);
    if startsWith(lower(tag), 'corr_')
        tag = tag(6:end);
    end
    if numel(tag) > 48
        tag = tag(1:48);
        tag = regexprep(tag, '_+$', '');
    end
    if isempty(tag)
        tag = 'correccion_termica';
    end
end

function txt = texto_tag_correccion_volumen(s, solo_archivo)
    txt = '';
    if ~isstruct(s)
        return;
    end
    if solo_archivo
        campos = {'ruta_correccion', 'ruta_correccion_mat'};
    else
        campos = {'ruta_correccion_mat', 'nombre_corr', 'nombre_exp', 'nombre_sim', 'tag'};
    end
    for k = 1:numel(campos)
        campo = campos{k};
        if isfield(s, campo) && ~isempty(s.(campo))
            candidato = char(s.(campo));
            if solo_archivo && ~isfile(candidato)
                continue;
            end
            txt = candidato;
            return;
        end
    end
end

function name = nombre_archivo(ruta)
    [~, base, ext] = fileparts(ruta);
    name = [base ext];
end

function ejecutar_selftest_limite_volumen()
    T_nd = zeros(2, 2, 2, 2);
    T_nd(:,:,:,1) = reshape([37 50 70 110 130 90 60 45], [2 2 2]);
    T_nd(:,:,:,2) = reshape([45 75 95 125 150 88 66 55], [2 2 2]);
    T_base_vec = reshape(permute(T_nd(:,:,:,1), [2 1 3]), [], 1);
    t_full = [0 1];
    corr = struct();
    corr.y_exp_interp = [37; 80; 78];
    corr.correccion_termica = struct( ...
        't_rel_min', [0; 1], ...
        'factor_enfriamiento', [1; 0.9], ...
        'extrapolacion_factor', struct(), ...
        't_origen_simulacion_min', 0, ...
        'offset_base_C', 0, ...
        'y_exp_interp', [37; 80; 78]);
    cfg = struct( ...
        'aplicar_offset_base', true, ...
        'intensidad_correccion', 1, ...
        'temperatura_max_corregida_C', 120, ...
        'T_abl', 60);

    [T_corr, V_corr, meta] = aplicar_correccion_volumen(T_nd, T_base_vec, ...
        t_full, cfg, corr, 1, []);
    valores = T_corr(isfinite(T_corr));
    max_corr = max(valores);
    assert(max_corr <= 80 + 1e-9, 'El limite experimental no se aplico al volumen corregido.');
    assert(abs(meta.temperatura_max_corregida_C - 80) <= 1e-9, ...
        'La metadata no conserva el limite experimental aplicado.');
    assert(numel(V_corr) == numel(t_full) && all(isfinite(V_corr)), ...
        'El volumen corregido debe producir una serie temporal finita.');

    cfg.temperatura_max_corregida_C = 70;
    [T_corr_cfg, ~, meta_cfg] = aplicar_correccion_volumen(T_nd, T_base_vec, ...
        t_full, cfg, corr, 1, []);
    valores_cfg = T_corr_cfg(isfinite(T_corr_cfg));
    max_corr_cfg = max(valores_cfg);
    assert(max_corr_cfg <= 70 + 1e-9, 'El limite manual de configuracion no se aplico.');
    assert(abs(meta_cfg.temperatura_max_corregida_C - 70) <= 1e-9, ...
        'La metadata no conserva el limite manual aplicado.');

    selftest_muestreo_minutos_volumen();

    fprintf('SELFTEST_LIMITE_VOLUMEN_OK max_exp=%.3f max_cfg=%.3f\n', ...
        max_corr, max_corr_cfg);
end

function selftest_muestreo_minutos_volumen()
    [X, Y, Z] = ndgrid([0 1], [0 1], [0 1]);
    puntos = [X(:), Y(:), Z(:)];
    base = [37; 42; 45; 50; 55; 60; 65; 70];
    T_C = [base, base + 5, base + 12];
    snapshots = repmat(struct('points', puntos, 'T', T_C(:, 1)), 1, 3);
    for ti = 1:3
        snapshots(ti).T = T_C(:, ti);
    end
    ds = struct( ...
        'snapshots', snapshots, ...
        't_min', [0 1 2], ...
        'full_field', struct('points', puntos, 'T_C', T_C));
    dataset = struct();
    dataset.modelo_sintetico = struct('dset_minutos', ds);
    cfg = struct( ...
        'dataset', dataset, ...
        'modelo', 'modelo_sintetico', ...
        'dsName', 'dset_minutos', ...
        'nx', 3, 'ny', 3, 'nz', 3, ...
        'nt_fine', 99, ...
        'T_abl', 60, ...
        't_extra_max', 4, ...
        'nt_ext', 99, ...
        'estrategia', 'Gradiente local', ...
        'carpeta_exportacion', tempdir, ...
        'export_mat', false, ...
        'export_m', false, ...
        'export_rbf', false, ...
        'n_rbf_max', 100, ...
        'aplicar_offset_base', true, ...
        'intensidad_correccion', 1);

    res = construir_funcion_volumen(cfg, [], @(varargin) []);
    assert(isequal(res.t_fine, [0 1 2]), ...
        'El volumen debe conservar los minutos fuente y no remuestrear con nt_fine.');
    assert(size(res.T_4D_vec, 2) == 3, ...
        'El campo base debe tener un instante por minuto fuente.');
    assert(numel(res.t_ext) == 2 && max(abs(res.t_ext - [3 4])) < 1e-9, ...
        'La extrapolacion debe iniciar despues del ultimo minuto fuente y cerrar en el horizonte.');

    corr = struct();
    corr.ruta_correccion_mat = fullfile(tempdir, 'corr_fecha_a_4ant_30w_15min.mat');
    corr.correccion_termica = struct( ...
        't_rel_min', [0; 1; 2], ...
        'factor_enfriamiento', [1; 0.95; 0.9], ...
        'extrapolacion_factor', struct(), ...
        't_origen_simulacion_min', 0, ...
        'offset_base_C', 0, ...
        'y_exp_interp', [37; 80; 90]);
    res_corr = construir_funcion_volumen(cfg, corr, @(varargin) []);
    assert(contains(lower(res_corr.tag), 'fecha_a_4ant_30w_15min'), ...
        'El tag 4D debe incluir el nombre del MAT de correccion.');
    res_reaplicado = reaplicar_correccion_volumen_resultado(res, cfg, corr);
    assert(isfield(res_reaplicado, 'V_corr') && ~isempty(res_reaplicado.V_corr), ...
        'La correccion debe reaplicarse sobre el volumen mallado sin reconstruirlo.');
    res_base = reaplicar_correccion_volumen_resultado(res_reaplicado, cfg, []);
    assert(isempty(res_base.V_corr) && isempty(res_base.correccion_fuente), ...
        'Desactivar correccion debe restaurar el volumen base en memoria.');
end

function ejecutar_selftest(varargin)
    sim_csv = '4 antenas_30 watt_antena 15min.csv';
    sim_txt = 'Registro_Sondas_Temperatura.txt';
    dataset_mat = 'Dataset_Termico_Masivo.mat';
    out_dir = fullfile(tempdir, 'tesis_correlador_volumen_selftest');
    if numel(varargin) >= 1 && ~isempty(varargin{1}), sim_csv = varargin{1}; end
    if numel(varargin) >= 2 && ~isempty(varargin{2}), sim_txt = varargin{2}; end
    if numel(varargin) >= 3 && ~isempty(varargin{3}), dataset_mat = varargin{3}; end
    if ~isfolder(out_dir), mkdir(out_dir); end

    expData = leer_experimental(sim_csv, true);
    txtData = leer_txt_sondas(sim_txt);
    cfgCorr = struct( ...
        'exp', expData, ...
        'sim', txtData, ...
        'sonda', txtData.labels{1}, ...
        'exp_inicio', 1, ...
        'exp_fin', numel(expData.t_min), ...
        'sim_inicio', 1, ...
        'sim_fin', numel(txtData.t_min), ...
        'grado', 6, ...
        'n_comun', 200, ...
        'nombre_exp', sim_csv, ...
        'nombre_sim', sim_txt);
    corr = calcular_correlacion(cfgCorr);
    assert(isfield(corr, 'correccion_termica'), 'No se genero correccion.');

    dataset = cargar_dataset_termico(dataset_mat);
    cfgVol = struct( ...
        'dataset', dataset, ...
        'modelo', 'modelo_Monopolo_4ant', ...
        'dsName', 'dset_c0_p30', ...
        'nx', 9, 'ny', 9, 'nz', 9, ...
        'nt_fine', 18, ...
        'T_abl', 60, ...
        't_extra_max', 25, ...
        'nt_ext', 6, ...
        'estrategia', 'PCA temporal', ...
        'carpeta_exportacion', out_dir, ...
        'export_mat', true, ...
        'export_m', true, ...
        'export_rbf', false, ...
        'n_rbf_max', 100, ...
        'aplicar_offset_base', true, ...
        'intensidad_correccion', 1);
    res = construir_funcion_volumen(cfgVol, corr, @(varargin) fprintf([varargin{1} '\n'], varargin{2:end}));
    res.archivos = exportar_volumen_desde_resultado(cfgVol, res, @(varargin) fprintf([varargin{1} '\n'], varargin{2:end}));
    assert(isfile(res.archivos.mat), 'No se exporto T4D .mat.');
    assert(isfile(res.archivos.m), 'No se exporto funcion .m.');
    assert(any(isfinite(res.V_base)), 'V_base no contiene valores finitos.');
    assert(any(isfinite(res.V_corr)), 'V_corr no contiene valores finitos.');
    fprintf('SELFTEST_CORR_VOL_OK rmse=%.4f Vmax=%.4f VcorrMax=%.4f out=%s\n', ...
        corr.correccion_termica.rmse_factor_C, max(res.V_base), max(res.V_corr), out_dir);
end

% ---- Fin copia local: correlador_volumen_interpolado_ui.m ----
end
function varargout = ejecutar_exportador_correcciones_integrado(varargin)
    if nargin >= 1 && ischar(varargin{1}) && strcmpi(varargin{1}, 'selftest_metadata')
        ejecutar_selftest_filtros_metadata();
        if nargout > 0, varargout{1} = true; end
        return;
    end
    if nargout > 0
        [varargout{1:nargout}] = exportador_masivo_correcciones(varargin{:});
    else
        exportador_masivo_correcciones(varargin{:});
    end

% ---- Inicio copia local: exportador_masivo_correcciones.m ----
function varargout = exportador_masivo_correcciones(varargin)
%EXPORTADOR_MASIVO_CORRECCIONES Aplica correlaciones a datasets completos.
%
% Flujo:
%   1. Carga un Dataset_Termico_Masivo.mat.
%   2. Recorre uno o varios .mat de correccion termica.
%   3. Exporta datasets corregidos completos.
%   4. Opcionalmente exporta STL/TXT corregidos y MAT voxelizados.
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

    if nargin >= 1 && ischar(varargin{1}) && strcmpi(varargin{1}, 'selected')
        if nargin >= 2
            config = varargin{2};
        else
            config = struct();
        end
        resumen = exportar_dataset_seleccionado_corregido(config);
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
    paths = tesis_auxiliares('dataset_paths');
    dataset_default = tesis_auxiliares('dataset_masivo_reciente', paths);
    if hay_mats_particionados(paths.datasets_masivos_por_metadata)
        dataset_default = paths.datasets_masivos_por_metadata;
    end

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
    lbl_dataset = uilabel(gl, 'Text', dataset_default, ...
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
    btn_open = uibutton(gl, 'Text', 'Abrir carpeta datasets');
    btn_open.Layout.Column = [1 2];

    pnl_log = uipanel(fig, 'Title', 'Registro de eventos', ...
        'Position', [398 12 570 596]);
    txt_log = uitextarea(pnl_log, ...
        'Position', [8 8 554 560], ...
        'Editable', 'off', ...
        'Value', {'Listo.'});

    ruta_dataset = dataset_default;
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
            tesis_auxiliares('dataset_masivo_reciente', paths));
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

function resumen = exportar_dataset_seleccionado_corregido(config)
    logfn = obtener_campo_config_exportador(config, 'logfn', []);
    if isempty(logfn)
        logfn = @(varargin) fprintf([varargin{1} '\n'], varargin{2:end});
    end
    if ~isfield(config, 'dataset') || isempty(config.dataset)
        error('No hay dataset cargado para exportar.');
    end
    modelo = obtener_campo_config_exportador(config, 'modelo', '');
    dsName = obtener_campo_config_exportador(config, 'dsName', '');
    if isempty(modelo) || isempty(dsName) || ...
            ~isfield(config.dataset, modelo) || ~isfield(config.dataset.(modelo), dsName)
        error('Selecciona un modelo/dataset valido antes de exportar.');
    end
    corr_raw = obtener_campo_config_exportador(config, 'correccion', []);
    if isempty(corr_raw)
        error('No hay una correccion resuelta por metadata para exportar.');
    end
    if isstruct(corr_raw) && isfield(corr_raw, 'correccion_termica')
        corr = corr_raw.correccion_termica;
    else
        corr = corr_raw;
    end
    if ~isstruct(corr) || ~isfield(corr, 'factor_enfriamiento')
        error('La correccion no contiene factor_enfriamiento.');
    end

    paths = tesis_auxiliares('dataset_paths');
    root_salida = obtener_campo_config_exportador(config, ...
        'carpeta_salida_dataset', paths.datasets_corregidos_por_metadata);
    if ~isfolder(root_salida)
        mkdir(root_salida);
    end

    ds = config.dataset.(modelo).(dsName);
    ds_corr = corregir_dataset_individual_exportador(ds, corr, config);
    tag_corr = tag_correccion_seleccionada(corr_raw, corr, config);
    partition_meta = crear_partition_meta_corregido( ...
        config, ds_corr, corr, tag_corr, root_salida);
    ds_corr.metadata.partition_meta = partition_meta;

    dataset = struct();
    if isfield(config.dataset, 'session_meta')
        dataset.session_meta = config.dataset.session_meta;
    end
    if isfield(config.dataset.(modelo), 'session_meta')
        dataset.(modelo).session_meta = config.dataset.(modelo).session_meta;
    end
    dataset.(modelo).(dsName) = ds_corr;

    [carpeta_destino, archivo_destino] = destino_particion_corregida(root_salida, partition_meta);
    if ~isfolder(carpeta_destino)
        mkdir(carpeta_destino);
    end
    ruta = fullfile(carpeta_destino, archivo_destino);
    save(ruta, 'dataset', 'partition_meta', '-v7.3');

    item = item_indice_corregido(ruta, partition_meta);
    actualizar_indice_corregido(root_salida, item, logfn);
    resumen = item;
    resumen.ruta = ruta;
    logfn('Dataset corregido seleccionado guardado: %s', ruta);
end

function tag = tag_correccion_seleccionada(corr_raw, corr, config)
    tag = tag_experimental_correccion_exportador(corr_raw);
    if isempty(tag), tag = tag_experimental_correccion_exportador(corr); end
    if ~isempty(tag), return; end
    rutas = {'ruta_correccion', 'ruta_correccion_mat'};
    for k = 1:numel(rutas)
        campo = rutas{k};
        if isstruct(config) && isfield(config, campo) && ~isempty(config.(campo)) && ...
                isfile(char(config.(campo)))
            [~, nombre_corr] = fileparts(char(config.(campo)));
            tag = sanitizar_nombre_correccion_exportador(nombre_corr);
            break;
        end
        if isstruct(corr_raw) && isfield(corr_raw, campo) && ~isempty(corr_raw.(campo)) && ...
                isfile(char(corr_raw.(campo)))
            [~, nombre_corr] = fileparts(char(corr_raw.(campo)));
            tag = sanitizar_nombre_correccion_exportador(nombre_corr);
            break;
        end
    end
    if ~isempty(tag)
        return;
    end
    candidatos = {'nombre_corr', 'nombre_sim', 'nombre_exp', 'tag'};
    for k = 1:numel(candidatos)
        campo = candidatos{k};
        if isstruct(corr_raw) && isfield(corr_raw, campo) && ~isempty(corr_raw.(campo))
            tag = sanitizar_nombre_correccion_exportador(corr_raw.(campo));
            break;
        end
        if isstruct(corr) && isfield(corr, campo) && ~isempty(corr.(campo))
            tag = sanitizar_nombre_correccion_exportador(corr.(campo));
            break;
        end
    end
    if isempty(tag)
        tag = 'correccion_termica';
    end
end

function partition_meta = crear_partition_meta_corregido(config, ds_corr, corr, tag_corr, root_salida)
    modelo = char(config.modelo);
    dsName = char(config.dsName);
    fuente_meta = struct();
    if isfield(ds_corr, 'metadata') && isstruct(ds_corr.metadata)
        fuente_meta = ds_corr.metadata;
    end
    meta_compartida = tesis_auxiliares('metadata_ruta', ...
        [modelo '/' dsName], fuente_meta);
    if isfield(fuente_meta, 'metadata_dataset') && ...
            isstruct(fuente_meta.metadata_dataset)
        meta_compartida = tesis_auxiliares('metadata_ruta', ...
            [modelo '/' dsName], fuente_meta.metadata_dataset);
    end
    meta = struct('tipo', meta_compartida.tipo, ...
        'antena', meta_compartida.antena, ...
        'num_antenas', meta_compartida.num_antenas, ...
        'caso', meta_compartida.caso, ...
        'potencia_W', meta_compartida.potencia_W);
    if isempty(meta.tipo), meta.tipo = 'Tipo_desconocido'; end
    if isempty(meta.antena), meta.antena = 'antenas_desconocidas'; end
    ruta_fuente = obtener_campo_config_exportador(config, 'ruta_dataset', '');
    partition_meta = meta;
    partition_meta.ruta_entrada = char(ruta_fuente);
    partition_meta.modelo = modelo;
    partition_meta.tag_dataset = dsName;
    partition_meta.partition_key = strjoin({modelo, dsName, tag_corr}, '__');
    partition_meta.fuentes_equivalentes = {char(ruta_fuente)};
    partition_meta.agrupar_por = 'tipo_antenas_caso_potencia';
    partition_meta.dataset_corregido = true;
    partition_meta.tag_correccion = tag_corr;
    meta_especifica = metadata_especifica_correccion_global(tag_corr);
    partition_meta.fecha_adquisicion = meta_especifica.fecha_adquisicion;
    partition_meta.tiempo_ejecucion_min = meta_especifica.tiempo_ejecucion_min;
    partition_meta.numero_prueba = meta_especifica.numero_prueba;
    partition_meta.num_zonas = meta_especifica.num_zonas;
    partition_meta.zona_experimental = meta_especifica.zona_experimental;
    partition_meta.root_salida = root_salida;
    partition_meta.fecha_generacion = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    partition_meta.correccion_termica = crear_metadata_correccion_exportador(corr, config);
end

function tf = isfinite_num_exportador(valor)
    tf = isnumeric(valor) && isscalar(valor) && isfinite(double(valor));
end

function [carpeta, archivo] = destino_particion_corregida(root_salida, partition_meta)
    carpeta = fullfile(root_salida, ...
        texto_meta_o_default(partition_meta.tipo, 'Tipo_desconocido'), ...
        texto_meta_o_default(partition_meta.antena, 'antenas_desconocidas'), ...
        texto_caso_corregido(partition_meta.caso), ...
        texto_potencia_corregida(partition_meta.potencia_W), ...
        sanitizar_nombre_correccion_exportador(partition_meta.tag_correccion));
    archivo = 'Dataset_corregido.mat';
end

function texto = texto_caso_corregido(caso)
    if isfinite_num_exportador(caso)
        texto = sprintf('Caso_%d', round(double(caso)));
    else
        texto = 'Caso_desconocido';
    end
end

function texto = texto_potencia_corregida(potencia)
    if isfinite_num_exportador(potencia)
        texto = sprintf('Potencia_%gW', double(potencia));
        texto = strrep(texto, '.', 'p');
    else
        texto = 'Potencia_desconocida';
    end
end

function texto = texto_meta_o_default(valor, predeterminado)
    if isempty(valor)
        texto = predeterminado;
    else
        texto = char(valor);
    end
end

function item = item_indice_corregido(ruta, partition_meta)
    item = struct( ...
        'ruta', ruta, ...
        'fuente', partition_meta.ruta_entrada, ...
        'modelo', partition_meta.modelo, ...
        'dataset', partition_meta.tag_dataset, ...
        'partition_key', partition_meta.partition_key, ...
        'fuentes_equivalentes', strjoin(partition_meta.fuentes_equivalentes, '|'), ...
        'tipo', partition_meta.tipo, ...
        'antena', partition_meta.antena, ...
        'num_antenas', partition_meta.num_antenas, ...
        'caso', partition_meta.caso, ...
        'potencia_W', partition_meta.potencia_W, ...
        'dataset_corregido', true, ...
        'tag_correccion', partition_meta.tag_correccion);
end

function actualizar_indice_corregido(root_salida, item, logfn)
    ruta_mat = fullfile(root_salida, 'Indice_Datasets_Metadata.mat');
    particiones = item([]);
    omitidos = {};
    if isfile(ruta_mat)
        try
            raw = load(ruta_mat, 'particiones', 'omitidos');
            if isfield(raw, 'particiones') && isstruct(raw.particiones)
                particiones = raw.particiones;
            end
            if isfield(raw, 'omitidos') && iscell(raw.omitidos)
                omitidos = raw.omitidos;
            end
        catch
            particiones = item([]);
            omitidos = {};
        end
    end
    if ~isempty(particiones) && isfield(particiones, 'partition_key')
        particiones = particiones(~strcmpi({particiones.partition_key}, item.partition_key));
    end
    particiones(end + 1) = item;
    resumen = struct( ...
        'fecha', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
        'carpeta_salida', root_salida, ...
        'particiones', particiones, ...
        'omitidos', {omitidos});
    save(ruta_mat, 'particiones', 'omitidos', 'resumen', '-v7.3');
    escribir_indice_corregido_csv(fullfile(root_salida, 'Indice_Datasets_Metadata.csv'), particiones);
    logfn('Indice corregido actualizado: %s', ruta_mat);
end

function escribir_indice_corregido_csv(ruta_csv, particiones)
    fid = fopen(ruta_csv, 'w');
    if fid < 0
        return;
    end
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, ['ruta,fuente,modelo,dataset,partition_key,fuentes_equivalentes,' ...
        'tipo,antena,num_antenas,caso,potencia_W,dataset_corregido,tag_correccion\n']);
    for k = 1:numel(particiones)
        p = particiones(k);
        fprintf(fid, '%s,%s,%s,%s,%s,%s,%s,%s,%g,%g,%g,%d,%s\n', ...
            csv_exportador(p.ruta), csv_exportador(p.fuente), ...
            csv_exportador(p.modelo), csv_exportador(p.dataset), ...
            csv_exportador(p.partition_key), csv_exportador(p.fuentes_equivalentes), ...
            csv_exportador(p.tipo), csv_exportador(p.antena), ...
            p.num_antenas, p.caso, p.potencia_W, logical(p.dataset_corregido), ...
            csv_exportador(p.tag_correccion));
    end
end

function texto = csv_exportador(valor)
    texto = char(valor);
    texto = strrep(texto, '"', '""');
    texto = ['"' texto '"'];
end

function resumen = ejecutar_exportador_masivo_correcciones(config)
    paths = tesis_auxiliares('dataset_paths');
    logfn = obtener_campo_config_exportador(config, 'logfn', []);
    if isempty(logfn)
        logfn = @(varargin) fprintf([varargin{1} '\n'], varargin{2:end});
    end

    dataset_default = tesis_auxiliares('dataset_masivo_reciente', paths);
    if hay_mats_particionados(paths.datasets_masivos_por_metadata)
        dataset_default = paths.datasets_masivos_por_metadata;
    end
    ruta_dataset = obtener_campo_config_exportador(config, ...
        'ruta_dataset', dataset_default);
    carpeta_correlaciones = obtener_campo_config_exportador(config, ...
        'carpeta_correlaciones', paths.correlaciones);
    rutas_correcciones = obtener_campo_config_exportador(config, ...
        'rutas_correcciones', {});
    if isempty(rutas_correcciones)
        archivos = dir(fullfile(carpeta_correlaciones, '**', '*.mat'));
        archivos = archivos(~arrayfun(@(a) ruta_esta_en_repetidos( ...
            fullfile(a.folder, a.name)), archivos));
        rutas_correcciones = arrayfun(@(a) fullfile(a.folder, a.name), ...
            archivos, 'UniformOutput', false);
    end
    if ischar(rutas_correcciones) || isstring(rutas_correcciones)
        rutas_correcciones = cellstr(rutas_correcciones);
    end
    rutas_correcciones = rutas_correcciones(~cellfun( ...
        @ruta_esta_en_repetidos_global, rutas_correcciones));

    if ~(isfile(ruta_dataset) || isfolder(ruta_dataset))
        error('No existe el dataset masivo o catalogo de particiones: %s', ruta_dataset);
    end
    if isempty(rutas_correcciones)
        error('No se encontraron correlaciones .mat en: %s', carpeta_correlaciones);
    end

    exportar_stl = obtener_campo_config_exportador(config, 'exportar_stl', true);
    exportar_mat = obtener_campo_config_exportador(config, 'exportar_mat', true);
    carpeta_salida_datasets = obtener_campo_config_exportador(config, ...
        'carpeta_salida_datasets', paths.datasets_corregidos_por_metadata);
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
        corr_raw = load(ruta_corr);
        if ~isfield(corr_raw, 'correccion_termica')
            logfn('[WARN] Omitida: no contiene correccion_termica.');
            continue;
        end
        filtro_corr = crear_filtro_correlacion_exportador( ...
            nombre_corr, tag_corr, corr_raw);
        tag_corr = filtro_corr.tag;
        partition_meta_corr = crear_partition_meta_masivo_correccion( ...
            filtro_corr, ruta_dataset, ruta_corr);
        logfn('---');
        logfn('[%d/%d] Correccion: %s', ci, numel(rutas_correcciones), nombre_corr);
        logfn('Filtro de correlacion: tipo=%s | antenas=%s | potencia=%s | caso=%s', ...
            valor_filtro_log_exportador(filtro_corr.tipo), ...
            valor_filtro_log_exportador(filtro_corr.antena), ...
            valor_filtro_log_exportador(filtro_corr.potencia), ...
            valor_filtro_log_exportador(filtro_corr.caso));

        carpeta_dataset_corr = fullfile(carpeta_salida_datasets, tag_corr);
        asegurar_carpeta_exportador(carpeta_dataset_corr);
        ruta_out_dataset = fullfile(carpeta_dataset_corr, 'Dataset_corregido.mat');
        ruta_done_dataset = [ruta_out_dataset '.done'];
        dataset_vigente = dataset_corregido_vigente_exportador( ...
            ruta_out_dataset, ruta_done_dataset, filtro_corr);
        dataset_regenerado = false;
        if dataset_vigente && ~sobrescribir
            logfn('Fase 1/3 dataset corregido vigente. Omitido: %s', ruta_out_dataset);
        else
            corr = corr_raw.correccion_termica;
            config_corr = config;
            config_corr.correccion = corr_raw;
            config_corr.temperatura_max_corregida_C = obtener_campo_config_exportador( ...
                config, 'temperatura_max_corregida_C', 120);
            logfn('Cargando solo particiones compatibles con esta correccion...');
            dataset_base = cargar_dataset_base_exportador( ...
                ruta_dataset, filtro_corr, logfn);
            logfn('Fase 1/3 corrigiendo dataset completo...');
            dataset_corr = corregir_dataset_completo_exportador( ...
                dataset_base, corr, config_corr, logfn, filtro_corr);
            clear dataset_base corr;
            dataset = dataset_corr;
            clear dataset_corr;
            partition_meta = partition_meta_corr;
            save(ruta_out_dataset, 'dataset', 'partition_meta', '-v7.3');
            clear dataset corr_raw;
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
            ejecutar_exportador_mat_integrado('run', cfg_stl);
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
            ejecutar_preprocesador_stl_integrado('run', cfg_pre);
            resumen.mat{end+1} = carpeta_mat;
        end
    end
end

function partition_meta = crear_partition_meta_masivo_correccion( ...
        filtro_corr, ruta_dataset, ruta_corr)
    ant = regexp(char(filtro_corr.antena), '(\d+)', 'tokens', 'once');
    caso = regexp(char(filtro_corr.caso), '(\d+)', 'tokens', 'once');
    potencia = regexp(char(filtro_corr.potencia), '([\d.p]+)', 'tokens', 'once');
    partition_meta = struct( ...
        'tipo', char(filtro_corr.tipo), ...
        'antena', char(filtro_corr.antena), ...
        'num_antenas', token_numero_exportador(ant), ...
        'caso', token_numero_exportador(caso), ...
        'potencia_W', token_numero_exportador(potencia), ...
        'dataset_corregido', true, ...
        'tag_correccion', char(filtro_corr.tag), ...
        'fecha_adquisicion', char(filtro_corr.fecha_adquisicion), ...
        'tiempo_ejecucion_min', double(filtro_corr.tiempo_ejecucion_min), ...
        'numero_prueba', double(filtro_corr.numero_prueba), ...
        'num_zonas', double(filtro_corr.num_zonas), ...
        'zona_experimental', char(filtro_corr.zona_experimental), ...
        'ruta_entrada', char(ruta_dataset), ...
        'ruta_correccion', char(ruta_corr), ...
        'agrupar_por', ...
        'tipo_antenas_caso_potencia_fecha_tiempo_prueba_zonas');
end

function valor = token_numero_exportador(token)
    valor = NaN;
    if ~isempty(token)
        valor = str2double(strrep(lower(token{1}), 'p', '.'));
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

function dataset_base = cargar_dataset_base_exportador(ruta_dataset, filtro_corr, logfn)
    if ~isfolder(ruta_dataset)
        dataset_base = cargar_dataset_termico_archivo(ruta_dataset);
        return;
    end

    rutas_todas = resolver_particiones_dataset(ruta_dataset);
    rutas = filtrar_particiones_exportador(rutas_todas, filtro_corr);
    if isempty(rutas)
        error(['No hay particiones compatibles con la correlacion %s. ', ...
            'Revisa antenas, potencia y caso en el nombre de la correlacion.'], ...
            filtro_corr.tag);
    end

    bytes = 0;
    for k = 1:numel(rutas)
        info = dir(rutas{k});
        if ~isempty(info)
            bytes = bytes + double(info(1).bytes);
        end
    end
    logfn('Particiones seleccionadas: %d/%d (%.2f GB en disco).', ...
        numel(rutas), numel(rutas_todas), bytes / 1024^3);

    dataset_base = struct();
    for k = 1:numel(rutas)
        nuevo = cargar_dataset_termico_archivo(rutas{k});
        dataset_base = fusionar_dataset_termico(dataset_base, nuevo);
        clear nuevo;
        if k == 1 || mod(k, 25) == 0 || k == numel(rutas)
            logfn('  Particiones cargadas: %d/%d.', k, numel(rutas));
            drawnow limitrate;
        end
    end
end

function rutas = filtrar_particiones_exportador(rutas_todas, filtro_corr)
    rutas = {};
    % El nombre canonico contiene modelo, caso y potencia, por lo que este
    % filtro funciona tanto con indices portables como con indices obsoletos.
    for k = 1:numel(rutas_todas)
        ruta = rutas_todas{k};
        if ~ruta_esta_en_repetidos(ruta) && ...
                modelo_pasa_filtro_correlacion(ruta, filtro_corr) && ...
                dataset_pasa_filtro_correlacion(ruta, filtro_corr)
            rutas{end + 1} = rutas_todas{k}; %#ok<AGROW>
        end
    end
    rutas = unique(rutas, 'stable');
end

function filtro = crear_filtro_correlacion_exportador(nombre_corr, tag_corr, corr_raw)
    tag_experimental = tag_experimental_correccion_exportador(corr_raw);
    if ~isempty(tag_experimental), tag_corr = tag_experimental; end
    raw = lower(regexprep(char(nombre_corr), '[^\w]+', '_'));
    ant = regexp(raw, '(\d+)_?ant(?:enas)?', 'tokens', 'once');
    potencia = regexp(raw, '(\d+)_?w(?:att)?', 'tokens', 'once');
    caso = regexp(raw, '(?:^|_)c(?:aso)?_?(\d+)(?=_|$)', 'tokens', 'once');
    filtro = struct( ...
        'tag', tag_corr, ...
        'tipo', '', ...
        'antena', '', ...
        'potencia', '', ...
        'caso', '', ...
        'fecha_adquisicion', '', ...
        'tiempo_ejecucion_min', NaN, ...
        'numero_prueba', NaN, ...
        'num_zonas', NaN, ...
        'zona_experimental', '');
    if ~isempty(ant)
        filtro.antena = sprintf('%sant', ant{1});
    end
    if ~isempty(potencia)
        filtro.potencia = sprintf('p%s', potencia{1});
    end
    if ~isempty(caso)
        filtro.caso = sprintf('c%s', caso{1});
    end
    if nargin >= 3 && isstruct(corr_raw)
        meta = metadata_filtro_desde_correccion(corr_raw);
        if ~isempty(meta.tipo_antena), filtro.tipo = meta.tipo_antena; end
        if isfinite(meta.num_antenas), filtro.antena = sprintf('%dant', round(meta.num_antenas)); end
        if isfinite(meta.potencia_W), filtro.potencia = sprintf('p%g', meta.potencia_W); end
        if isfinite(meta.caso), filtro.caso = sprintf('c%d', round(meta.caso)); end
        meta_especifica = metadata_especifica_correccion_global(corr_raw);
        filtro.fecha_adquisicion = meta_especifica.fecha_adquisicion;
        filtro.tiempo_ejecucion_min = meta_especifica.tiempo_ejecucion_min;
        filtro.numero_prueba = meta_especifica.numero_prueba;
        filtro.num_zonas = meta_especifica.num_zonas;
        filtro.zona_experimental = meta_especifica.zona_experimental;
    end
    if ~isempty(filtro.tipo) && ~isempty(filtro.antena) && ...
            ~isempty(filtro.caso) && ~isempty(filtro.potencia)
        filtro.tag = sanitizar_nombre_correccion_exportador(sprintf('%s_%s_%s_%s_%s', ...
            filtro.tipo, filtro.antena, filtro.caso, filtro.potencia, tag_corr));
    end
end

function tag = tag_experimental_correccion_exportador(corr_raw)
    tag = '';
    if ~isstruct(corr_raw), return; end
    fecha = '';
    tiempo = NaN;
    prueba = NaN;
    zonas = NaN;
    ruta_exp = '';
    if isfield(corr_raw, 'metadata_correlacion') && ...
            isstruct(corr_raw.metadata_correlacion)
        md = corr_raw.metadata_correlacion;
        fecha = texto_meta_filtro(md, 'fecha_adquisicion');
        if isempty(fecha), fecha = texto_meta_filtro(md, 'fecha_experimento'); end
        if isempty(fecha), fecha = texto_meta_filtro(md, 'tag_carpeta_exp'); end
        tiempo = numero_meta_filtro(md, 'tiempo_ejecucion_min');
        prueba = numero_meta_filtro(md, 'numero_prueba');
        zonas = numero_meta_filtro(md, 'num_zonas');
        ruta_exp = texto_meta_filtro(md, 'ruta_exp');
    end
    if isempty(ruta_exp) && isfield(corr_raw, 'nombre_exp') && ...
            ~isempty(corr_raw.nombre_exp)
        ruta_exp = char(corr_raw.nombre_exp);
    end
    normal = strrep(ruta_exp, '\', '/');
    [~, base_exp] = fileparts(normal);
    if isempty(fecha)
        token = regexp(normal, '/([^/]+)/[^/]+$', 'tokens', 'once');
        if ~isempty(token), fecha = token{1}; end
    end
    if ~isfinite(tiempo)
        token = regexp(base_exp, '(\d+(?:[p.]\d+)?)\s*min', ...
            'tokens', 'once', 'ignorecase');
        if ~isempty(token)
            tiempo = str2double(strrep(lower(token{1}), 'p', '.'));
        end
    end
    if ~isfinite(prueba)
        token = regexp(base_exp, '\d+(?:[p.]\d+)?\s*min[_\s-]*(\d+)', ...
            'tokens', 'once', 'ignorecase');
        if isempty(token), prueba = 1; else, prueba = str2double(token{1}); end
    end
    if ~isfinite(zonas) && isfield(corr_raw, 'correccion_termica') && ...
            isstruct(corr_raw.correccion_termica) && ...
            isfield(corr_raw.correccion_termica, 'zonas')
        zonas = numel(corr_raw.correccion_termica.zonas);
    end
    if isempty(fecha) || ~isfinite(tiempo) || ~isfinite(prueba) || ~isfinite(zonas)
        return;
    end
    tiempo_txt = strrep(sprintf('%g', tiempo), '.', 'p');
    tag = sanitizar_nombre_correccion_exportador(sprintf( ...
        'correccion_%s_%smin_prueba_%d_zonas_%d', fecha, tiempo_txt, ...
        round(prueba), round(zonas)));
end

function meta = metadata_filtro_desde_correccion(corr_raw)
    meta = struct('tipo_antena', '', 'num_antenas', NaN, ...
        'caso', NaN, 'potencia_W', NaN);
    if isfield(corr_raw, 'metadata_correlacion') && ...
            isstruct(corr_raw.metadata_correlacion)
        md = corr_raw.metadata_correlacion;
        meta.tipo_antena = texto_meta_filtro(md, 'tipo_antena');
        meta.num_antenas = numero_meta_filtro(md, 'num_antenas');
        meta.caso = numero_meta_filtro(md, 'caso');
        meta.potencia_W = numero_meta_filtro(md, 'potencia_W');
        ruta_sim = texto_meta_filtro(md, 'ruta_sim');
    else
        ruta_sim = '';
    end
    if isempty(ruta_sim) && isfield(corr_raw, 'nombre_sim')
        ruta_sim = char(corr_raw.nombre_sim);
    end
    inferida = extraer_metadata_ruta_filtro(ruta_sim);
    if isempty(meta.tipo_antena), meta.tipo_antena = inferida.tipo_antena; end
    if ~isfinite(meta.num_antenas), meta.num_antenas = inferida.num_antenas; end
    if ~isfinite(meta.caso), meta.caso = inferida.caso; end
    if ~isfinite(meta.potencia_W), meta.potencia_W = inferida.potencia_W; end
end

function meta = extraer_metadata_ruta_filtro(ruta)
    normal = strrep(char(ruta), '\', '/');
    meta = struct('tipo_antena', '', 'num_antenas', NaN, ...
        'caso', NaN, 'potencia_W', NaN);
    tipos = {'Doble_slot', 'Monopolo', 'Un_slot'};
    for k = 1:numel(tipos)
        if contains(normal, ['/' tipos{k} '/'], 'IgnoreCase', true)
            meta.tipo_antena = tipos{k};
            break;
        end
    end
    token = regexp(normal, '(\d+)ant', 'tokens', 'once', 'ignorecase');
    if ~isempty(token), meta.num_antenas = str2double(token{1}); end
    token = regexp(normal, 'Caso_(\d+)', 'tokens', 'once', 'ignorecase');
    if ~isempty(token), meta.caso = str2double(token{1}); end
    token = regexp(normal, 'Potencia_([\d.p]+)W', 'tokens', 'once', 'ignorecase');
    if ~isempty(token)
        meta.potencia_W = str2double(strrep(lower(token{1}), 'p', '.'));
    end
end

function texto = texto_meta_filtro(s, campo)
    texto = '';
    if isstruct(s) && isfield(s, campo) && ~isempty(s.(campo))
        valor = s.(campo);
        if isstring(valor), valor = char(valor); end
        if ischar(valor), texto = valor; end
    end
end

function valor = numero_meta_filtro(s, campo)
    valor = NaN;
    if isstruct(s) && isfield(s, campo) && isnumeric(s.(campo)) && ...
            isscalar(s.(campo)) && isfinite(double(s.(campo)))
        valor = double(s.(campo));
    end
end

function tf = ruta_esta_en_repetidos(ruta)
    partes = regexp(strrep(lower(char(ruta)), '\', '/'), '/', 'split');
    tf = any(strcmp(partes, 'repetidos'));
end

function tf = modelo_pasa_filtro_correlacion(nombre_modelo, filtro)
    tf = true;
    if isfield(filtro, 'tipo') && ~isempty(filtro.tipo)
        tf = tf && contains(char(nombre_modelo), filtro.tipo, 'IgnoreCase', true);
    end
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
            T_corr = limitar_temperatura_corregida_exportador(T_corr, corr, config);
            return;
        end
    end

    [factor_modelo, activo] = evaluar_factor_correccion_exportador(t_min, corr);
    if ~activo
        T_corr = limitar_temperatura_corregida_exportador(T_corr, corr, config);
        return;
    end
    factor = 1 + intensidad * (factor_modelo - 1);
    offset = 0;
    if aplicar_offset && isfield(corr, 'offset_base_C')
        offset = intensidad * corr.offset_base_C;
    end
    T_corr = T_base + offset + factor .* (T_orig - T_base);
    T_corr = limitar_temperatura_corregida_exportador(T_corr, corr, config);
end

function T_corr = limitar_temperatura_corregida_exportador(T_corr, corr, config)
    limite = limite_temperatura_corregida_exportador(corr, config);
    if isfinite(limite)
        T_corr(T_corr > limite) = limite;
    end
end

function limite = limite_temperatura_corregida_exportador(corr, config)
    limite = obtener_campo_config_exportador(config, 'temperatura_max_corregida_C', 120);
    if isempty(limite) || ~isnumeric(limite) || ~isscalar(limite) || ~isfinite(limite)
        limite = 120;
    end
    limite = min(double(limite), 120);
    exp_max = max_experimental_correccion_exportador(corr, config);
    if isfinite(exp_max)
        limite = min(limite, exp_max);
    end
end

function exp_max = max_experimental_correccion_exportador(corr, config)
    exp_max = NaN;
    cr = obtener_campo_config_exportador(config, 'correccion', []);
    exp_max = max([exp_max, max_vector_finito_exportador(cr, 'y_exp_interp')], [], 'omitnan');
    if isstruct(cr) && isfield(cr, 'correccion_termica')
        exp_max = max([exp_max, max_vector_finito_exportador(cr.correccion_termica, 'y_exp_interp')], [], 'omitnan');
    end
    exp_max = max([exp_max, max_vector_finito_exportador(corr, 'y_exp_interp')], [], 'omitnan');
    if isstruct(corr) && isfield(corr, 'zonas') && ~isempty(corr.zonas)
        for zi = 1:numel(corr.zonas)
            exp_max = max([exp_max, max_vector_finito_exportador(corr.zonas(zi), 'y_exp_interp')], [], 'omitnan');
        end
    end
    if isempty(exp_max) || ~isfinite(exp_max)
        exp_max = NaN;
    end
end

function vmax = max_vector_finito_exportador(s, campo)
    vmax = NaN;
    if isstruct(s) && isfield(s, campo) && isnumeric(s.(campo)) && ~isempty(s.(campo))
        vals = double(s.(campo)(:));
        vals = vals(isfinite(vals));
        if ~isempty(vals)
            vmax = max(vals);
        end
    end
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
        'temperatura_max_corregida_C', limite_temperatura_corregida_exportador(corr, config), ...
        'temperatura_max_experimental_C', max_experimental_correccion_exportador(corr, config), ...
        'ruta_correccion', obtener_campo_config_exportador(config, 'ruta_correccion', ''), ...
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

function tag = sanitizar_nombre_correccion_exportador(txt)
    [~, base, ~] = fileparts(char(txt));
    if isempty(base)
        base = char(txt);
    end
    tag = lower(regexprep(base, '[^\w]+', '_'));
    tag = regexprep(tag, '_+', '_');
    tag = regexprep(tag, '^_|_$', '');
    if startsWith(tag, 'corr_')
        tag = tag(6:end);
    end
    if numel(tag) > 72
        tag = tag(1:72);
        tag = regexprep(tag, '_+$', '');
    end
    if isempty(tag)
        tag = 'correccion';
    end
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
            contains(contenido, ['tipo=' filtro_corr.tipo]) && ...
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
    fprintf(fid, 'tipo=%s\n', filtro_corr.tipo);
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
    carpetas_correccion = carpetas_metadata_correccion_global(filtro_corr);
    if isempty(carpetas_correccion)
        logfn(['[WARN] Limpieza omitida: faltan fecha/tiempo/prueba/zonas; ' ...
            'no se eliminara una carpeta compartida.']);
        return;
    end

    tipos = obtener_subdirs_exportador(root_salida);
    if isfield(filtro_corr, 'tipo') && ~isempty(filtro_corr.tipo)
        tipos = filtrar_valores_exportador(tipos, filtro_corr.tipo);
    end
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
                    dir_adquisicion = fullfile(dir_potencia, carpetas_correccion{:});
                    if isfolder(dir_adquisicion)
                        limpiar_carpeta_generada_exportador( ...
                            dir_adquisicion, root_salida, logfn);
                        n_limpias = n_limpias + 1;
                    end
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

function ejecutar_selftest_filtros_metadata()
    paths = tesis_auxiliares('dataset_paths');
    catalogo_corr = catalogar_correcciones_metadata_ext(paths.correlaciones);
    candidatas = catalogo_corr(strcmpi({catalogo_corr.tipo}, 'Monopolo') & ...
        strcmpi({catalogo_corr.antena}, '1ant') & ...
        abs([catalogo_corr.caso] - 1) < 1e-9 & ...
        abs([catalogo_corr.potencia_W] - 30) < 1e-9);
    assert(~isempty(candidatas), ...
        'No existe una correlacion Monopolo/1ant/Caso_1/Potencia_30W para la prueba.');
    ruta_corr = candidatas(1).ruta;
    corr_raw = load(ruta_corr);
    [~, nombre_corr] = fileparts(ruta_corr);
    tag = sanitizar_tag_exportador(nombre_corr);
    filtro = crear_filtro_correlacion_exportador(nombre_corr, tag, corr_raw);
    assert(strcmp(filtro.tipo, 'Monopolo'), 'El tipo inferido no es Monopolo.');
    assert(strcmp(filtro.antena, '1ant'), 'El numero de antenas inferido no es 1ant.');
    assert(strcmp(filtro.caso, 'c1'), 'El caso inferido no es Caso_1.');
    assert(strcmp(filtro.potencia, 'p30'), 'La potencia inferida no es 30 W.');
    assert(contains(filtro.tag, lower(filtro.fecha_adquisicion)) && ...
        contains(filtro.tag, sprintf('prueba_%d', round(filtro.numero_prueba))) && ...
        contains(filtro.tag, sprintf('zonas_%d', round(filtro.num_zonas))), ...
        'El tag perdio metadata experimental necesaria para evitar colisiones.');
    assert(isfinite(filtro.tiempo_ejecucion_min) && ...
        isfinite(filtro.numero_prueba) && isfinite(filtro.num_zonas), ...
        'El filtro no conserva tiempo/prueba/zonas de la correccion.');
    partition_meta = struct('tipo', filtro.tipo, 'antena', filtro.antena, ...
        'caso', 1, 'potencia_W', 30, 'tag_correccion', filtro.tag);
    [carpeta_prueba, archivo_prueba] = destino_particion_corregida( ...
        fullfile('datasets', 'datasets_corregidos'), partition_meta);
    assert(strcmp(archivo_prueba, 'Dataset_corregido.mat'));
    assert(contains(carpeta_prueba, filtro.tag, 'IgnoreCase', true), ...
        'La carpeta del dataset corregido no conserva la identidad de correccion.');
    assert(modelo_pasa_filtro_correlacion('modelo_Monopolo_1ant', filtro));
    assert(~modelo_pasa_filtro_correlacion('modelo_Doble_slot_1ant', filtro));
    assert(dataset_pasa_filtro_correlacion('dset_c1_p30', filtro));
    assert(~dataset_pasa_filtro_correlacion('dset_c0_p30', filtro));
    rutas = resolver_particiones_dataset(paths.datasets_masivos_por_metadata);
    filtradas = filtrar_particiones_exportador(rutas, filtro);
    assert(~isempty(filtradas), 'El filtro completo no encontro particiones.');
    for k = 1:numel(filtradas)
        ruta = strrep(filtradas{k}, '\', '/');
        assert(contains(ruta, '/Monopolo/1ant/Caso_1/Potencia_30W/', ...
            'IgnoreCase', true), 'Particion fuera de metadata: %s', filtradas{k});
        assert(~ruta_esta_en_repetidos(filtradas{k}), ...
            'El filtro incluyo una particion en repetidos: %s', filtradas{k});
    end
    fprintf(['SELFTEST_METADATA_OK tipo=%s antena=%s caso=%s potencia=%s ', ...
        'particiones=%d\n'], filtro.tipo, filtro.antena, filtro.caso, ...
        filtro.potencia, numel(filtradas));
end

% ---- Fin copia local: exportador_masivo_correcciones.m ----
end

function tf = ruta_esta_en_repetidos_global(ruta)
    partes = regexp(strrep(lower(char(ruta)), '\', '/'), '/', 'split');
    tf = any(strcmp(partes, 'repetidos'));
end

function meta = metadata_especifica_correccion_global(fuente)
    meta = struct('fecha_adquisicion', '', ...
        'tiempo_ejecucion_min', NaN, 'numero_prueba', NaN, ...
        'num_zonas', NaN, 'zona_experimental', '', ...
        'tag_correccion', '');
    if isstruct(fuente)
        meta = copiar_metadata_especifica_correccion_global(meta, fuente);
        if isfield(fuente, 'metadata_correlacion') && ...
                isstruct(fuente.metadata_correlacion)
            meta = copiar_metadata_especifica_correccion_global( ...
                meta, fuente.metadata_correlacion);
        end
        if isfield(fuente, 'correccion_termica') && ...
                isstruct(fuente.correccion_termica)
            meta = copiar_metadata_especifica_correccion_global( ...
                meta, fuente.correccion_termica);
        end
        texto = meta.tag_correccion;
        if isempty(texto) && isfield(fuente, 'tag') && ~isempty(fuente.tag)
            texto = char(fuente.tag);
        end
        if isempty(texto) && isfield(fuente, 'ruta_correccion_mat') && ...
                ~isempty(fuente.ruta_correccion_mat)
            texto = char(fuente.ruta_correccion_mat);
        end
    else
        texto = char(fuente);
    end
    meta = completar_metadata_especifica_desde_texto_global(meta, texto);
    if isempty(meta.zona_experimental) && isfinite(meta.num_zonas)
        meta.zona_experimental = sprintf('Zonas_%d', round(meta.num_zonas));
    end
    if isempty(meta.tag_correccion) && ~isempty(meta.fecha_adquisicion) && ...
            isfinite(meta.tiempo_ejecucion_min) && ...
            isfinite(meta.numero_prueba) && isfinite(meta.num_zonas)
        tiempo = strrep(sprintf('%g', meta.tiempo_ejecucion_min), '.', 'p');
        meta.tag_correccion = sprintf( ...
            'correccion_%s_%smin_prueba_%d_zonas_%d', ...
            meta.fecha_adquisicion, tiempo, round(meta.numero_prueba), ...
            round(meta.num_zonas));
    end
end

function meta = copiar_metadata_especifica_correccion_global(meta, fuente)
    campos_texto = {'fecha_adquisicion', 'zona_experimental', 'tag_correccion'};
    for k = 1:numel(campos_texto)
        campo = campos_texto{k};
        if isempty(meta.(campo)) && isfield(fuente, campo) && ...
                ~isempty(fuente.(campo))
            meta.(campo) = char(fuente.(campo));
        end
    end
    campos_num = {'tiempo_ejecucion_min', 'numero_prueba', 'num_zonas'};
    for k = 1:numel(campos_num)
        campo = campos_num{k};
        if ~isfinite(meta.(campo)) && isfield(fuente, campo) && ...
                isnumeric(fuente.(campo)) && isscalar(fuente.(campo)) && ...
                isfinite(double(fuente.(campo)))
            meta.(campo) = double(fuente.(campo));
        end
    end
    if ~isfinite(meta.num_zonas) && isfield(fuente, 'zonas') && ...
            isstruct(fuente.zonas) && ~isempty(fuente.zonas)
        meta.num_zonas = numel(fuente.zonas);
    end
end

function meta = completar_metadata_especifica_desde_texto_global(meta, texto)
    normal = strrep(char(texto), '\', '/');
    token = regexp(normal, '(?:^|/)Fecha_([^/]+)(?:/|$)', ...
        'tokens', 'once', 'ignorecase');
    if isempty(meta.fecha_adquisicion) && ~isempty(token)
        meta.fecha_adquisicion = token{1};
    end
    token = regexp(normal, '(?:^|/)Tiempo_([\d.p]+)min(?:/|$)', ...
        'tokens', 'once', 'ignorecase');
    if ~isfinite(meta.tiempo_ejecucion_min) && ~isempty(token)
        meta.tiempo_ejecucion_min = str2double(strrep(lower(token{1}), 'p', '.'));
    end
    token = regexp(normal, '(?:^|/)Prueba_(\d+)(?:/|$)', ...
        'tokens', 'once', 'ignorecase');
    if ~isfinite(meta.numero_prueba) && ~isempty(token)
        meta.numero_prueba = str2double(token{1});
    end
    token = regexp(normal, '(?:^|/)Zonas_(\d+)(?:/|$)', ...
        'tokens', 'once', 'ignorecase');
    if ~isfinite(meta.num_zonas) && ~isempty(token)
        meta.num_zonas = str2double(token{1});
    end

    token = regexp(normal, ...
        'correccion_(.+?)_([\d]+(?:p[\d]+)?)min_prueba_(\d+)_zonas_(\d+)', ...
        'tokens', 'once', 'ignorecase');
    if ~isempty(token)
        if isempty(meta.fecha_adquisicion), meta.fecha_adquisicion = token{1}; end
        if ~isfinite(meta.tiempo_ejecucion_min)
            meta.tiempo_ejecucion_min = str2double(strrep(lower(token{2}), 'p', '.'));
        end
        if ~isfinite(meta.numero_prueba), meta.numero_prueba = str2double(token{3}); end
        if ~isfinite(meta.num_zonas), meta.num_zonas = str2double(token{4}); end
        if isempty(meta.tag_correccion)
            meta.tag_correccion = sprintf( ...
                'correccion_%s_%smin_prueba_%d_zonas_%d', ...
                meta.fecha_adquisicion, token{2}, round(meta.numero_prueba), ...
                round(meta.num_zonas));
        end
    end
end

function carpetas = carpetas_metadata_correccion_global(fuente)
    carpetas = {};
    meta = metadata_especifica_correccion_global(fuente);
    completa = ~isempty(meta.fecha_adquisicion) && ...
        isfinite(meta.tiempo_ejecucion_min) && ...
        isfinite(meta.numero_prueba) && isfinite(meta.num_zonas);
    if completa
        fecha = sanitizar_segmento_ruta_global(meta.fecha_adquisicion);
        tiempo = strrep(sprintf('%g', meta.tiempo_ejecucion_min), '.', 'p');
        carpetas = {['Fecha_' fecha], ['Tiempo_' tiempo 'min'], ...
            sprintf('Prueba_%d', round(meta.numero_prueba)), ...
            sprintf('Zonas_%d', round(meta.num_zonas))};
    elseif ~isempty(meta.tag_correccion)
        carpetas = {['Correccion_' ...
            sanitizar_segmento_ruta_global(meta.tag_correccion)]};
    end
end

function segmento = sanitizar_segmento_ruta_global(valor)
    segmento = regexprep(char(valor), '[^a-zA-Z0-9_-]+', '_');
    segmento = regexprep(segmento, '_+', '_');
    segmento = regexprep(segmento, '^_|_$', '');
    if isempty(segmento), segmento = 'desconocido'; end
end

function catalogo = catalogar_correcciones_metadata_ext(carpeta)
    plantilla = struct('ruta', '', 'tipo', '', 'antena', '', ...
        'num_antenas', NaN, 'caso', NaN, 'potencia_W', NaN, ...
        'fecha', '', 'tiempo', '', 'prueba', '', 'zona', '', ...
        'fecha_adquisicion', '', 'tiempo_ejecucion_min', NaN, ...
        'numero_prueba', NaN, 'num_zonas', NaN, ...
        'datenum', NaN, 'nombre', '');
    catalogo = plantilla([]);
    if ~isfolder(carpeta), return; end
    archivos = dir(fullfile(carpeta, '**', '*.mat'));
    archivos = archivos(~[archivos.isdir]);
    for k = 1:numel(archivos)
        ruta = fullfile(archivos(k).folder, archivos(k).name);
        if ruta_esta_en_repetidos_global(ruta), continue; end
        try
            raw = load(ruta, 'metadata_correlacion', 'nombre_sim', ...
                'nombre_exp', 'correccion_termica');
            if ~isfield(raw, 'correccion_termica'), continue; end
            raw.ruta_correccion_mat = ruta;
            meta = metadata_correccion_ext_unificada(raw);
            if ~metadata_corr_ext_completa(meta), continue; end
            entrada = plantilla;
            entrada.ruta = ruta;
            entrada.tipo = meta.tipo_antena;
            entrada.num_antenas = meta.num_antenas;
            entrada.antena = sprintf('%dant', round(meta.num_antenas));
            entrada.caso = meta.caso;
            entrada.potencia_W = meta.potencia_W;
            entrada.fecha_adquisicion = meta.fecha_adquisicion;
            entrada.tiempo_ejecucion_min = meta.tiempo_ejecucion_min;
            entrada.numero_prueba = meta.numero_prueba;
            entrada.num_zonas = meta.num_zonas;
            entrada.fecha = meta.fecha_adquisicion;
            entrada.tiempo = sprintf('%gmin', meta.tiempo_ejecucion_min);
            entrada.prueba = sprintf('Prueba_%d', round(meta.numero_prueba));
            entrada.zona = meta.zona_experimental;
            entrada.datenum = archivos(k).datenum;
            entrada.nombre = archivos(k).name;
            catalogo(end + 1) = entrada; %#ok<AGROW>
        catch ME
            warning('CatalogoCorrecciones:ArchivoOmitido', ...
                'Correccion omitida %s: %s', ruta, ME.message);
        end
    end
end

function filtradas = filtrar_catalogo_correcciones_ext( ...
        catalogo, tipo, antena, caso, potencia, fecha, tiempo, prueba, zona)
    if isempty(catalogo)
        filtradas = catalogo;
        return;
    end
    mask = strcmpi({catalogo.tipo}, char(tipo)) & ...
        strcmpi({catalogo.antena}, char(antena)) & ...
        abs([catalogo.caso] - double(caso)) < 1e-9 & ...
        abs([catalogo.potencia_W] - double(potencia)) < 1e-9 & ...
        strcmpi({catalogo.fecha}, char(fecha)) & ...
        strcmpi({catalogo.tiempo}, char(tiempo)) & ...
        strcmpi({catalogo.prueba}, char(prueba)) & ...
        strcmpi({catalogo.zona}, char(zona));
    filtradas = catalogo(mask);
end

function meta = metadata_correccion_ext_unificada(corr)
    meta = struct('tipo_antena', '', 'num_antenas', NaN, ...
        'caso', NaN, 'potencia_W', NaN, 'fecha_adquisicion', '', ...
        'tiempo_ejecucion_min', NaN, 'numero_prueba', NaN, ...
        'num_zonas', NaN, 'zona_experimental', '');
    ruta_sim = '';
    ruta_exp = '';
    if isfield(corr, 'metadata_correlacion') && isstruct(corr.metadata_correlacion)
        md = corr.metadata_correlacion;
        texto = campo_metadata_corr_ext(md, 'tipo_antena');
        if ~isempty(texto), meta.tipo_antena = texto; end
        valor = numero_metadata_corr_ext(md, 'num_antenas');
        if isfinite(valor), meta.num_antenas = valor; end
        valor = numero_metadata_corr_ext(md, 'caso');
        if isfinite(valor), meta.caso = valor; end
        valor = numero_metadata_corr_ext(md, 'potencia_W');
        if isfinite(valor), meta.potencia_W = valor; end
        ruta_sim = campo_metadata_corr_ext(md, 'ruta_sim');
        ruta_exp = campo_metadata_corr_ext(md, 'ruta_exp');
        meta.fecha_adquisicion = campo_metadata_corr_ext(md, 'fecha_adquisicion');
        if isempty(meta.fecha_adquisicion)
            meta.fecha_adquisicion = campo_metadata_corr_ext(md, 'fecha_experimento');
        end
        valor = numero_metadata_corr_ext(md, 'tiempo_ejecucion_min');
        if isfinite(valor), meta.tiempo_ejecucion_min = valor; end
        valor = numero_metadata_corr_ext(md, 'numero_prueba');
        if isfinite(valor), meta.numero_prueba = valor; end
        valor = numero_metadata_corr_ext(md, 'num_zonas');
        if isfinite(valor), meta.num_zonas = valor; end
        meta.zona_experimental = campo_metadata_corr_ext(md, 'zona_experimental');
    end
    if isempty(ruta_sim) && isfield(corr, 'nombre_sim') && ~isempty(corr.nombre_sim)
        ruta_sim = char(corr.nombre_sim);
    end
    if isempty(ruta_exp) && isfield(corr, 'nombre_exp') && ~isempty(corr.nombre_exp)
        ruta_exp = char(corr.nombre_exp);
    end
    meta = completar_metadata_corr_ext_desde_ruta(meta, ruta_sim);
    meta = completar_metadata_experimental_corr_ext(meta, ruta_exp);
    if ~isfinite(meta.num_zonas) && isfield(corr, 'correccion_termica') && ...
            isstruct(corr.correccion_termica) && ...
            isfield(corr.correccion_termica, 'zonas')
        meta.num_zonas = numel(corr.correccion_termica.zonas);
    end
    if isfield(corr, 'ruta_correccion_mat')
        meta = completar_metadata_corr_ext_desde_ruta( ...
            meta, char(corr.ruta_correccion_mat));
        if ~isfinite(meta.num_zonas)
            token = regexp(char(corr.ruta_correccion_mat), ...
                '(?:^|_)z(\d+)(?:_|\.|$)', 'tokens', 'once', 'ignorecase');
            if ~isempty(token), meta.num_zonas = str2double(token{1}); end
        end
    end
    if isempty(meta.zona_experimental) && isfinite(meta.num_zonas)
        meta.zona_experimental = sprintf('Zonas_%d', round(meta.num_zonas));
    end
end

function meta = completar_metadata_experimental_corr_ext(meta, ruta_exp)
    normal = strrep(char(ruta_exp), '\', '/');
    [~, base] = fileparts(normal);
    if isempty(meta.fecha_adquisicion)
        token = regexp(normal, '/([^/]+)/[^/]+$', 'tokens', 'once');
        if ~isempty(token), meta.fecha_adquisicion = token{1}; end
    end
    token_tiempo = regexp(base, '(\d+(?:[p.]\d+)?)\s*min', ...
        'tokens', 'once', 'ignorecase');
    if ~isfinite(meta.tiempo_ejecucion_min) && ~isempty(token_tiempo)
        meta.tiempo_ejecucion_min = str2double(strrep(lower(token_tiempo{1}), 'p', '.'));
    end
    if ~isfinite(meta.numero_prueba)
        token_prueba = regexp(base, '\d+(?:[p.]\d+)?\s*min[_\s-]*(\d+)', ...
            'tokens', 'once', 'ignorecase');
        if isempty(token_prueba)
            meta.numero_prueba = 1;
        else
            meta.numero_prueba = str2double(token_prueba{1});
        end
    end
end

function meta = completar_metadata_corr_ext_desde_ruta(meta, ruta)
    normal = strrep(char(ruta), '\', '/');
    if isempty(meta.tipo_antena)
        tipos = {'Doble_slot', 'Monopolo', 'Un_slot'};
        for k = 1:numel(tipos)
            if contains(normal, ['/' tipos{k} '/'], 'IgnoreCase', true)
                meta.tipo_antena = tipos{k};
                break;
            end
        end
    end
    if ~isfinite(meta.num_antenas)
        token = regexp(normal, '(\d+)ant', 'tokens', 'once', 'ignorecase');
        if ~isempty(token), meta.num_antenas = str2double(token{1}); end
    end
    if ~isfinite(meta.caso)
        token = regexp(normal, 'Caso_(\d+)', 'tokens', 'once', 'ignorecase');
        if ~isempty(token), meta.caso = str2double(token{1}); end
    end
    if ~isfinite(meta.potencia_W)
        token = regexp(normal, 'Potencia_([\d.p]+)W', 'tokens', 'once', 'ignorecase');
        if ~isempty(token)
            meta.potencia_W = str2double(strrep(lower(token{1}), 'p', '.'));
        end
    end
end

function tf = metadata_corr_ext_completa(meta)
    tf = isstruct(meta) && ~isempty(meta.tipo_antena) && ...
        isfinite(meta.num_antenas) && isfinite(meta.caso) && ...
        isfinite(meta.potencia_W) && ~isempty(meta.fecha_adquisicion) && ...
        isfinite(meta.tiempo_ejecucion_min) && isfinite(meta.numero_prueba) && ...
        isfinite(meta.num_zonas) && ~isempty(meta.zona_experimental);
end

function texto = campo_metadata_corr_ext(s, campo)
    texto = '';
    if isstruct(s) && isfield(s, campo) && ~isempty(s.(campo))
        valor = s.(campo);
        if isstring(valor), valor = char(valor); end
        if ischar(valor), texto = valor; end
    end
end

function valor = numero_metadata_corr_ext(s, campo)
    valor = NaN;
    if isstruct(s) && isfield(s, campo) && isnumeric(s.(campo)) && ...
            isscalar(s.(campo)) && isfinite(double(s.(campo)))
        valor = double(s.(campo));
    end
end

function ejecutar_selftest_carga_correcciones_filtrada()
    paths = tesis_auxiliares('dataset_paths');
    catalogo = catalogar_correcciones_metadata_ext(paths.correlaciones);
    assert(~isempty(catalogo), ...
        'No hay correcciones con metadata completa para probar el filtro.');
    for k = 1:numel(catalogo)
        muestra = catalogo(k);
        filtradas = filtrar_catalogo_correcciones_ext(catalogo, muestra.tipo, ...
            muestra.antena, muestra.caso, muestra.potencia_W, muestra.fecha, ...
            muestra.tiempo, muestra.prueba, muestra.zona);
        assert(isscalar(filtradas), ...
            'La metadata especifica no resolvio una correlacion unica.');
        assert(all(strcmpi({filtradas.tipo}, muestra.tipo)) && ...
            all(strcmpi({filtradas.antena}, muestra.antena)) && ...
            all(abs([filtradas.caso] - muestra.caso) < 1e-9) && ...
            all(abs([filtradas.potencia_W] - muestra.potencia_W) < 1e-9) && ...
            all(strcmpi({filtradas.fecha}, muestra.fecha)) && ...
            all(strcmpi({filtradas.tiempo}, muestra.tiempo)) && ...
            all(strcmpi({filtradas.prueba}, muestra.prueba)) && ...
            all(strcmpi({filtradas.zona}, muestra.zona)));
        assert(~any(arrayfun(@(e) ruta_esta_en_repetidos_global(e.ruta), filtradas)));
    end
    pruebas = unique({catalogo.prueba});
    meta_prueba_2 = metadata_especifica_correccion_global( ...
        'correccion_junio_19_20min_prueba_2_zonas_4');
    assert(meta_prueba_2.numero_prueba == 2, ...
        'No se detecto Prueba_2 en el tag de metadata.');
    fprintf(['SELFTEST_CORR_FILTERED_LOAD_OK catalogo=%d fechas=%d tiempos=%d ', ...
        'pruebas=%d zonas=%d\n'], numel(catalogo), ...
        numel(unique({catalogo.fecha})), numel(unique({catalogo.tiempo})), ...
        numel(pruebas), numel(unique({catalogo.zona})));
end

function dataset = cargar_dataset_termico_compuesto(ruta)
    if ruta_esta_en_repetidos_global(ruta)
        error('El dataset esta dentro de repetidos y fue bloqueado: %s', ruta);
    end
    if isfolder(ruta)
        rutas = resolver_particiones_dataset(ruta);
        if isempty(rutas)
            error('No se encontraron particiones MAT en: %s', ruta);
        end
        dataset = struct();
        for k = 1:numel(rutas)
            dataset = fusionar_dataset_termico( ...
                dataset, cargar_dataset_termico_archivo(rutas{k}));
        end
        return;
    end

    dataset = cargar_dataset_termico_archivo(ruta);
end

function rutas = resolver_particiones_dataset(carpeta)
    ruta_indice = fullfile(carpeta, 'Indice_Datasets_Metadata.mat');
    if isfile(ruta_indice)
        try
            raw = load(ruta_indice, 'particiones');
            if isfield(raw, 'particiones') && isstruct(raw.particiones) && ...
                    isfield(raw.particiones, 'ruta')
                rutas = {raw.particiones.ruta};
                rutas = rutas(cellfun(@isfile, rutas) & ...
                    ~cellfun(@ruta_esta_en_repetidos, rutas));
                if ~isempty(rutas)
                    rutas = unique(rutas(:)', 'stable');
                    return;
                end
            end
        catch
        end
    end

    archivos = dir(fullfile(carpeta, '**', '*.mat'));
    archivos = archivos(~[archivos.isdir]);
    keep = false(numel(archivos), 1);
    for k = 1:numel(archivos)
        nombre = lower(archivos(k).name);
        ruta_archivo = fullfile(archivos(k).folder, archivos(k).name);
        keep(k) = ~ruta_esta_en_repetidos_global(ruta_archivo) && ...
            endsWith(nombre, '.mat') && ...
            ~startsWith(nombre, 'indice_') && ...
            ~startsWith(nombre, 'reporte_') && ...
            ~contains(nombre, 'historial');
    end
    archivos = archivos(keep);
    rutas = arrayfun(@(a) fullfile(a.folder, a.name), archivos, 'UniformOutput', false);
    rutas = unique(rutas(:)', 'stable');
end

function dataset = cargar_dataset_termico_archivo(ruta)
    if ruta_esta_en_repetidos_global(ruta)
        error('El dataset esta dentro de repetidos y fue bloqueado: %s', ruta);
    end
    raw = load(ruta);
    if isfield(raw, 'dataset')
        dataset = raw.dataset;
        return;
    end
    vars = fieldnames(raw);
    ignorar = {'partition_meta', 'particiones', 'omitidos', 'resumen'};
    for k = 1:numel(vars)
        if isstruct(raw.(vars{k})) && ~ismember(vars{k}, ignorar)
            dataset = raw.(vars{k});
            return;
        end
    end
    error('No se encontro una estructura dataset en el archivo: %s', ruta);
end

function dataset = fusionar_dataset_termico(dataset, nuevo)
    if isempty(fieldnames(dataset)) && isfield(nuevo, 'session_meta')
        dataset.session_meta = nuevo.session_meta;
    end
    modelos = fieldnames(nuevo);
    modelos = modelos(~strcmp(modelos, 'session_meta'));
    for mi = 1:numel(modelos)
        modelo = modelos{mi};
        if ~isstruct(nuevo.(modelo))
            continue;
        end
        if ~isfield(dataset, modelo)
            dataset.(modelo) = struct();
        end
        if isfield(nuevo.(modelo), 'session_meta') && ...
                ~isfield(dataset.(modelo), 'session_meta')
            dataset.(modelo).session_meta = nuevo.(modelo).session_meta;
        end
        tags = fieldnames(nuevo.(modelo));
        tags = tags(~ismember(tags, {'session_meta', 'source_signature', 'datasets_omitidos'}));
        for ti = 1:numel(tags)
            tag = tags{ti};
            if isfield(dataset.(modelo), tag)
                continue;
            end
            dataset.(modelo).(tag) = nuevo.(modelo).(tag);
        end
    end
end
