function modulo_manejador_visual_datos(varargin)
%MODULO_MANEJADOR_VISUAL_DATOS App unica para inspeccion visual de datos.

    bootstrap_modulo();
    theme = tesis_auxiliares('tema_ui');
    paths = tesis_auxiliares('dataset_paths');
    dataset_default = tesis_auxiliares('dataset_masivo_reciente', paths);
    dataset_dist_default = paths.datasets_masivos_por_metadata;
    if ~isfolder(dataset_dist_default)
        dataset_dist_default = dataset_default;
    end
    if nargin >= 1 && (ischar(varargin{1}) || ...
            (isstring(varargin{1}) && isscalar(varargin{1}))) && ...
            strcmpi(char(varargin{1}), 'selftest_fecha_dataset')
        ejecutar_selftest_fecha_catalogo_visual();
        return;
    end
    state = struct('dataset_math', [], 'dataset_math_path', '', ...
        'dataset_meta_math', [], 'catalogo_math', [], 'catalogo_filtrado_math', [], ...
        'catalogo_dataset_indices_math', [], 'catalogo_base_math', [], ...
        'actualizando_filtros_math', false, 'corr', [], 'vol', [], ...
        'vol_pares', struct());

    fig = uifigure('Name', 'Manejador visual de datos', ...
        'Position', [50 35 1420 850], 'Color', theme.colors.bg);
    gl = uigridlayout(fig, [2, 1]);
    gl.RowHeight = {'1x', 165};
    gl.ColumnWidth = {'1x'};
    gl.Padding = [10 10 10 10]; gl.RowSpacing = 10; gl.ColumnSpacing = 10;
    activar_scroll(gl);

    c_math = ui_math(gl);
    plog = uipanel(gl, 'Title', 'Registro de eventos'); plog.Layout.Row = 2; plog.Layout.Column = 1;
    tesis_auxiliares('tema_ui', 'panel', plog); activar_scroll(plog);
    glog = uigridlayout(plog, [1, 1]); glog.Padding = [6 6 6 6]; activar_scroll(glog);
    logbox = uitextarea(glog, 'Editable', 'off', 'Value', {'Listo.'}); tesis_auxiliares('tema_ui', 'textarea', logbox);
    tesis_auxiliares('tema_ui', 'apply', fig); logmsg('Manejador visual iniciado como app unica.');
    load_dataset_math(false);
    actualizar_controles_modo_math();

    function c = ui_math(parent)
        gp = uigridlayout(parent, [1, 2]);
        gp.Layout.Row = 1; gp.Layout.Column = 1;
        gp.ColumnWidth = {360, '1x'};
        gp.Padding = [0 0 0 0];
        gp.ColumnSpacing = 10;
        activar_scroll(gp);

        ctrl = uipanel(gp, 'Title', 'Filtros y visualización', ...
            'TitlePosition', 'centertop');
        ctrl.Layout.Column = 1;
        tesis_auxiliares('tema_ui', 'panel', ctrl);
        activar_scroll(ctrl);
        g = crear_grid_control(ctrl, 18);
        c.fuente = drop(g, 1, 'Fuente', {'Corregidos', 'Simulados'});
        c.fuente.ValueChangedFcn = @(~,~) aplicar_fuente_math();
        c.modo = drop(g, 2, 'Vista', {'Correcciones 2D', 'Campo termico / artefacto 4D'});
        c.modo.ItemsData = {'correccion', 'termico'};
        c.modo.Value = 'correccion';
        c.modo.ValueChangedFcn = @(~,~) actualizar_vista_math();
        c.zona = drop(g, 3, 'Zona', {'Global'});
        c.zona.ValueChangedFcn = @(~,~) plot_corr_math();
        c.campo = drop(g, 4, 'Campo', {'Corregido', 'Simulado/base'});
        c.campo.ItemsData = {'corregido', 'sin_correccion'};
        c.campo.Value = 'corregido';
        c.campo.ValueChangedFcn = @(~,~) cambiar_campo_guardado_math();
        c.vista3d = drop(g, 5, 'Vista 3D', {'AlphaShape/STL', 'Puntos termicos', 'Ambos'});
        c.vista3d.ItemsData = {'alpha', 'puntos', 'ambos'};
        c.vista3d.Value = 'ambos';
        c.vista3d.ValueChangedFcn = @(~,~) actualizar_vista_math();
        c.tipo = drop(g, 6, 'Tipo', {'Todos'}); c.tipo.ValueChangedFcn = @(~,~) aplicar_filtros_catalogo_math();
        c.antena = drop(g, 7, 'Antenas', {'Todos'}); c.antena.ValueChangedFcn = @(~,~) aplicar_filtros_catalogo_math();
        c.caso = drop(g, 8, 'Caso', {'Todos'}); c.caso.ValueChangedFcn = @(~,~) aplicar_filtros_catalogo_math();
        c.potencia = drop(g, 9, 'Potencia', {'Todos'}); c.potencia.ValueChangedFcn = @(~,~) aplicar_filtros_catalogo_math();
        c.fecha = drop(g, 10, 'Fecha', {'Todos'}); c.fecha.ValueChangedFcn = @(~,~) aplicar_filtros_catalogo_math();
        c.tiempo_corr = drop(g, 11, 'Duración', {'Todos'}); c.tiempo_corr.ValueChangedFcn = @(~,~) aplicar_filtros_catalogo_math();
        c.prueba = drop(g, 12, 'Prueba', {'Todos'}); c.prueba.ValueChangedFcn = @(~,~) aplicar_filtros_catalogo_math();
        c.zonas = drop(g, 13, 'Zonas', {'Todos'}); c.zonas.ValueChangedFcn = @(~,~) aplicar_filtros_catalogo_math();
        c.modelo = drop(g, 14, 'Modelo', {'(sin dataset)'}); c.modelo.ValueChangedFcn = @(~,~) datasets_math();
        c.ds = drop(g, 15, 'Dataset', {'(sin dataset)'}); c.ds.ValueChangedFcn = @(~,~) cargar_dataset_seleccionado_math();
        c.tiempo = drop(g, 16, 'Tiempo', {'(sin volumen)'});
        c.tiempo.ValueChangedFcn = @(~,~) actualizar_tiempo_vol_math();
        c.tlabel = uilabel(g, 'Text', 'Tiempo guardado: sin dataset cargado');
        c.tlabel.Layout.Row = 17; c.tlabel.Layout.Column = [1 3];
        tesis_auxiliares('tema_ui', 'label', c.tlabel, 'status');
        set_tag(c.fuente, 'math_fuente_catalogo');
        set_tag(c.modo, 'math_modo_grafico');
        set_tag(c.zona, 'math_zona_selector');
        set_tag(c.campo, 'math_campo_termico');
        set_tag(c.vista3d, 'math_vista3d_selector');
        set_tag(c.tipo, 'math_filtro_tipo');
        set_tag(c.antena, 'math_filtro_antenas');
        set_tag(c.caso, 'math_filtro_caso');
        set_tag(c.potencia, 'math_filtro_potencia');
        set_tag(c.fecha, 'math_filtro_fecha');
        set_tag(c.tiempo_corr, 'math_filtro_tiempo_ejecucion');
        set_tag(c.prueba, 'math_filtro_prueba');
        set_tag(c.zonas, 'math_filtro_zonas');
        set_tag(c.modelo, 'math_modelo_selector');
        set_tag(c.ds, 'math_dataset_selector');
        set_tag(c.tiempo, 'math_tiempo_selector');
        set_tag(c.tlabel, 'math_tiempo_label');

        plots = uipanel(gp, 'Title', 'Paneles matematicos y visuales', ...
            'TitlePosition', 'centertop');
        plots.Layout.Column = 2;
        tesis_auxiliares('tema_ui', 'panel', plots);
        activar_scroll(plots);
        g2 = uigridlayout(plots, [1, 1]);
        g2.Padding = [8 8 8 8];
        activar_scroll(g2);

        c.panel_2d = uipanel(g2, 'Title', 'Graficas 2D de analisis', ...
            'TitlePosition', 'centertop');
        c.panel_2d.Layout.Row = 1; c.panel_2d.Layout.Column = 1;
        tesis_auxiliares('tema_ui', 'panel', c.panel_2d);
        g2d = uigridlayout(c.panel_2d, [4, 1]);
        g2d.RowHeight = {'1x', '1x', '1x', '1x'};
        g2d.Padding = [6 6 6 6];
        g2d.RowSpacing = 6;
        c.ax_factor = axes_panel(g2d, 1, 1, 'Correlacion simulacion vs experimento');
        c.ax_func = axes_panel(g2d, 2, 1, 'Funcion de correccion');
        c.ax_zonas = axes_panel(g2d, 3, 1, 'Zonas de correccion');
        c.ax_vol = axes_panel(g2d, 4, 1, 'Volumen 4D');

        c.panel_thermal = uipanel(g2, 'Title', 'Graficas termicas y 3D', ...
            'TitlePosition', 'centertop');
        c.panel_thermal.Layout.Row = 1; c.panel_thermal.Layout.Column = 1;
        tesis_auxiliares('tema_ui', 'panel', c.panel_thermal);
        gt = uigridlayout(c.panel_thermal, [1, 2]);
        gt.ColumnWidth = {'1.15x', '1x'};
        gt.Padding = [6 6 6 6];
        gt.ColumnSpacing = 8;
        [c.ax_xy, c.ax_xz, c.ax_yz] = planes_panel(gt, 1, 1);
        c.ax_3d = axes_panel(gt, 1, 2, 'Volumen 3D');
        c.ax_view = c.ax_3d;
        set_tag(c.ax_factor, 'math_ax_correccion_curvas');
        set_tag(c.ax_func, 'math_ax_funcion_correccion');
        set_tag(c.ax_view, 'math_ax_vista_seleccionada');
    end

    function ax = axes_panel(parent, row, col, titulo)
        pnl = uipanel(parent, 'Title', titulo, 'TitlePosition', 'centertop');
        pnl.Layout.Row = row;
        pnl.Layout.Column = col;
        tesis_auxiliares('tema_ui', 'panel', pnl);
        gax = uigridlayout(pnl, [1, 1]);
        gax.Padding = [4 4 4 4];
        ax = uiaxes(gax);
        tesis_auxiliares('tema_ui', 'axes', ax);
        title(ax, titulo);
    end
    function [ax_xy, ax_xz, ax_yz] = planes_panel(parent, row, col)
        pnl = uipanel(parent, 'Title', 'Planos ortogonales', ...
            'TitlePosition', 'centertop');
        pnl.Layout.Row = row;
        pnl.Layout.Column = col;
        tesis_auxiliares('tema_ui', 'panel', pnl);
        gp = uigridlayout(pnl, [2, 2]);
        gp.RowHeight = {'1x', '1x'};
        gp.ColumnWidth = {'1x', '1x'};
        gp.Padding = [4 4 4 4];
        gp.ColumnSpacing = 4;
        ax_xy = axes_panel(gp, 1, 1, 'Plano XY');
        ax_xz = axes_panel(gp, 1, 2, 'Plano XZ');
        ax_yz = axes_panel(gp, 2, [1 2], 'Plano YZ');
    end
    function set_axis_panel_title(ax, titulo)
        try
            ax.Parent.Parent.Title = titulo;
        catch
        end
    end

    function g = crear_grid_control(p, n)
        g = uigridlayout(p, [n, 3]); g.RowHeight = repmat({30}, 1, n); g.RowHeight{end} = '1x';
        g.ColumnWidth = {120, '1x', 85}; g.Padding = [10 10 10 10]; g.RowSpacing = 7;
        activar_scroll(g);
    end
    function d = drop(g, r, label, items)
        lab = uilabel(g, 'Text', label); lab.Layout.Row = r; lab.Layout.Column = 1;
        d = uidropdown(g, 'Items', items, 'Value', items{1}); d.Layout.Row = r; d.Layout.Column = [2 3];
        ayuda = descripcion_control_visual(label);
        lab.Tooltip = ayuda; d.Tooltip = ayuda;
        tesis_auxiliares('tema_ui', 'dropdown', d);
    end
    function ayuda = descripcion_control_visual(label)
        clave = lower(char(label));
        if contains(clave, 'fuente')
            ayuda = 'Alterna entre datasets simulados y sus pares corregidos sin recalcular temperaturas.';
        elseif contains(clave, 'vista')
            ayuda = 'Selecciona el conjunto de gráficas o la representación tridimensional visible.';
        elseif contains(clave, 'campo')
            ayuda = 'Muestra el campo corregido o el campo simulado/base emparejado por metadata.';
        elseif contains(clave, 'zona')
            ayuda = 'Zona espacial de la corrección térmica que se desea inspeccionar.';
        elseif contains(clave, 'caso')
            ayuda = 'Caso termodependiente almacenado en la metadata de la solución.';
        elseif contains(clave, 'potencia')
            ayuda = 'Potencia por antena asociada al campo térmico.';
        elseif contains(clave, 'antena')
            ayuda = 'Tipo o cantidad de antenas de la simulación seleccionada.';
        elseif contains(clave, 'fecha')
            ayuda = 'Fecha del experimento usado para generar la corrección.';
        elseif contains(clave, 'duración')
            ayuda = 'Duración del registro experimental asociado a la corrección.';
        elseif contains(clave, 'prueba')
            ayuda = 'Número de repetición experimental registrado en la metadata.';
        elseif contains(clave, 'modelo')
            ayuda = 'Modelo COMSOL disponible después de aplicar todos los filtros.';
        elseif contains(clave, 'dataset')
            ayuda = 'Solución térmica concreta dentro del modelo seleccionado.';
        elseif contains(clave, 'tiempo')
            ayuda = 'Instante térmico guardado que se mostrará en los planos y el volumen 3D.';
        else
            ayuda = 'Filtro de metadata usado para localizar el dataset sin modificarlo.';
        end
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
    function set_tag(obj, tag)
        if isprop(obj, 'Tag')
            obj.Tag = tag;
        end
    end
    function set_enable(obj, valor)
        if isprop(obj, 'Enable')
            if valor, obj.Enable = 'on'; else, obj.Enable = 'off'; end
        end
    end
    function actualizar_vista_math()
        actualizar_controles_modo_math();
        if modo_math_es_correccion()
            plot_corr_math();
        elseif asegurar_volumen_math()
            plot_vol_math();
        else
            limpiar_math_vol('No hay dataset corregido con full_field para graficar.');
        end
    end

    function tf = modo_math_es_correccion()
        tf = ~isfield(c_math, 'modo') || strcmp(c_math.modo.Value, 'correccion');
    end

    function actualizar_controles_modo_math()
        es_corr = modo_math_es_correccion();
        c_math.panel_2d.Visible = vis(es_corr);
        c_math.panel_thermal.Visible = vis(~es_corr);
        set_enable(c_math.zona, es_corr);
        set_enable(c_math.campo, ~es_corr);
        set_enable(c_math.vista3d, ~es_corr);
        set_enable(c_math.tiempo, ~es_corr);
    end

    function ok = asegurar_volumen_math()
        ok = ~isempty(state.vol);
        if ok, return; end
        if isempty(state.catalogo_math)
            load_dataset_math(false);
        end
        if isempty(state.catalogo_math)
            ok = false;
            return;
        end
        cargar_dataset_seleccionado_math(false);
        ok = ~isempty(state.vol);
    end

    function invalidar_volumen_math()
        state.vol = [];
        state.vol_pares = struct();
        state.dataset_math = [];
        state.dataset_math_path = '';
        state.dataset_meta_math = [];
        state.corr = [];
    end

    function aplicar_fuente_math()
        if ~isfield(c_math, 'fuente') || strcmp(c_math.fuente.Value, 'Corregidos')
            if isfield(c_math, 'campo'), c_math.campo.Value = 'corregido'; end
        else
            if isfield(c_math, 'campo'), c_math.campo.Value = 'sin_correccion'; end
        end
        invalidar_volumen_math();
        load_dataset_math(true);
    end

    function load_dataset_math(varargin)
        graficar = false;
        if nargin >= 1 && (islogical(varargin{1}) || isnumeric(varargin{1}))
            graficar = logical(varargin{1});
        end
        try
            ruta = ruta_catalogo_math();
            state.dataset_math = [];
            state.dataset_math_path = '';
            state.dataset_meta_math = [];
            state.catalogo_math = [];
            state.catalogo_filtrado_math = [];
            state.catalogo_dataset_indices_math = [];
            if isfolder(ruta) || isfile(ruta)
                state.catalogo_math = catalogar_datasets_visual(ruta);
            end
            if isempty(state.catalogo_math)
                modelos_math(false);
                logmsg('Catalogo matematico sin particiones: %s', ruta);
                return;
            end
            state.actualizando_filtros_math = true;
            limpieza = onCleanup(@() set_actualizando_filtros_math(false));
            controles = controles_filtros_catalogo_math();
            for k = 1:numel(controles)
                poblar_filtro_catalogo(controles(k).control, ...
                    valores_catalogo(state.catalogo_math, controles(k).campo));
            end
            clear limpieza;
            aplicar_filtros_catalogo_math(graficar);
            logmsg('Catalogo matematico cargado: %d particiones.', numel(state.catalogo_math));
        catch ME
            fail('catalogo matematico', ME);
        end
    end

    function aplicar_filtros_catalogo_math(graficar)
        if nargin < 1, graficar = true; end
        if isempty(state.catalogo_math), return; end
        if state.actualizando_filtros_math, return; end
        state.actualizando_filtros_math = true;
        limpieza = onCleanup(@() set_actualizando_filtros_math(false));
        controles = controles_filtros_catalogo_math();
        for k = 1:numel(controles)
            base = filtrar_catalogo_por_controles_math( ...
                state.catalogo_math, controles(k).campo);
            poblar_filtro_catalogo(controles(k).control, ...
                valores_catalogo(base, controles(k).campo));
        end
        state.catalogo_filtrado_math = filtrar_catalogo_por_controles_math(state.catalogo_math, '');
        state.catalogo_dataset_indices_math = [];
        modelos_math(graficar);
        logmsg('Catalogo matematico filtrado: %d particiones.', numel(state.catalogo_filtrado_math));
        clear limpieza;
    end

    function controles = controles_filtros_catalogo_math()
        controles = struct( ...
            'campo', {'tipo', 'antena', 'caso', 'potencia', 'fecha', ...
                'tiempo_corr', 'prueba', 'zonas'}, ...
            'control', {c_math.tipo, c_math.antena, c_math.caso, ...
                c_math.potencia, c_math.fecha, c_math.tiempo_corr, ...
                c_math.prueba, c_math.zonas});
    end

    function catalogo = filtrar_catalogo_por_controles_math(catalogo, campo_excluido)
        controles = controles_filtros_catalogo_math();
        mask = true(size(catalogo));
        for k = 1:numel(controles)
            if strcmp(controles(k).campo, campo_excluido)
                continue;
            end
            mask = mask & pasa_filtro_catalogo( ...
                valores_catalogo(catalogo, controles(k).campo), controles(k).control.Value);
        end
        catalogo = catalogo(mask);
    end

    function set_actualizando_filtros_math(valor)
        state.actualizando_filtros_math = valor;
    end

    function catalogo = catalogo_math_actual()
        if isstruct(state.catalogo_filtrado_math)
            catalogo = state.catalogo_filtrado_math;
        else
            catalogo = state.catalogo_math;
        end
    end

    function modelos_math(graficar)
        if nargin < 1, graficar = true; end
        catalogo = catalogo_math_actual();
        if isempty(catalogo)
            c_math.modelo.Items = {'(sin dataset)'};
            c_math.modelo.Value = '(sin dataset)';
            c_math.ds.Items = {'(sin dataset)'};
            c_math.ds.Value = '(sin dataset)';
            return;
        end
        m = unique({catalogo.modelo}, 'stable');
        if isempty(m), m = {'(sin dataset)'}; end
        c_math.modelo.Items = m;
        c_math.modelo.Value = m{1};
        datasets_math(graficar);
    end

    function datasets_math(graficar)
        if nargin < 1, graficar = true; end
        catalogo = catalogo_math_actual();
        idx = find(strcmp({catalogo.modelo}, c_math.modelo.Value));
        state.catalogo_dataset_indices_math = idx;
        if isempty(idx)
            c_math.ds.Items = {'(sin dataset)'};
            c_math.ds.Value = '(sin dataset)';
            return;
        end
        items = cell(1, numel(idx));
        for ii = 1:numel(idx)
            items{ii} = etiqueta_catalogo_visual(catalogo(idx(ii)));
        end
        c_math.ds.Items = items;
        c_math.ds.Value = items{1};
        if graficar
            cargar_dataset_seleccionado_math();
        end
    end

    function cargar_dataset_seleccionado_math(graficar)
        if nargin < 1, graficar = true; end
        try
            [ds, entrada] = current_ds_math();
            if isempty(ds)
                limpiar_math_vol('No se pudo cargar el dataset seleccionado.');
                return;
            end
            cargar_correccion_particion_math();
            state.vol = volumen_desde_dataset_math(ds, entrada);
            state.vol_pares = struct();
            state.vol_pares.(state.vol.tipo_campo_puntos) = state.vol;
            if entrada.dataset_corregido
                cargar_par_sin_correccion_math(entrada);
            end
            actualizar_controles_volumen_math();
            actualizar_campo_termico_math();
            if graficar
                actualizar_vista_math();
            end
        catch ME
            fail('dataset matematico', ME);
        end
    end

    function actualizar_campo_termico_math()
        if ~isfield(c_math, 'campo') || isempty(state.vol), return; end
        previo = c_math.campo.Value;
        items = {};
        data = {};
        if volumen_tiene_campo_math(state.vol, 'corregido')
            items{end+1} = 'Corregido'; data{end+1} = 'corregido';
        end
        if volumen_tiene_campo_math(state.vol, 'sin_correccion')
            items{end+1} = 'Simulado/base'; data{end+1} = 'sin_correccion';
        end
        if isempty(items), return; end
        c_math.campo.Items = items;
        c_math.campo.ItemsData = data;
        if any(strcmp(data, previo))
            c_math.campo.Value = previo;
        else
            c_math.campo.Value = data{1};
        end
        actualizar_opciones_vista3d_math();
    end

    function cambiar_campo_guardado_math()
        actualizar_opciones_vista3d_math();
        actualizar_tiempos_vol_math();
        actualizar_vista_math();
    end

    function actualizar_opciones_vista3d_math()
        if ~isfield(c_math, 'vista3d'), return; end
        v = volumen_campo_activo_math();
        if isfield(v, 'puntos_termicos')
            c_math.vista3d.Items = {'Puntos termicos guardados'};
            c_math.vista3d.ItemsData = {'puntos'};
            c_math.vista3d.Value = 'puntos';
        else
            c_math.vista3d.Items = {'AlphaShape/STL', 'Puntos termicos', 'Ambos'};
            c_math.vista3d.ItemsData = {'alpha', 'puntos', 'ambos'};
            c_math.vista3d.Value = 'ambos';
        end
    end

    function ruta = ruta_catalogo_math()
        if ~isfield(c_math, 'fuente') || strcmp(c_math.fuente.Value, 'Corregidos')
            ruta = paths.datasets_corregidos_por_metadata;
        else
            ruta = dataset_dist_default;
        end
    end

    function tf = volumen_tiene_campo_math(v, campo)
        if isfield(state.vol_pares, campo) && ~isempty(state.vol_pares.(campo))
            tf = true;
            return;
        end
        if isfield(v, 'puntos_termicos') && isfield(v, 'tipo_campo_puntos')
            tf = strcmp(campo, v.tipo_campo_puntos);
            return;
        end
        if strcmp(campo, 'sin_correccion')
            tf = (isfield(v, 'Fgrid_sin_correccion') && ~isempty(v.Fgrid_sin_correccion)) || ...
                (isfield(v, 'Fgrid_base') && ~isempty(v.Fgrid_base)) || ...
                (isfield(v, 'V_sin_correccion') && ~isempty(v.V_sin_correccion)) || ...
                (isfield(v, 'V_base') && ~isempty(v.V_base));
        else
            tf = (isfield(v, 'Fgrid_corregido') && ~isempty(v.Fgrid_corregido)) || ...
                (isfield(v, 'V_corr') && ~isempty(v.V_corr));
        end
    end

    function [ds, entrada] = current_ds_math()
        ds = [];
        entrada = crear_catalogo_visual(0);
        if isempty(state.catalogo_dataset_indices_math) || isempty(c_math.ds.Value)
            return;
        end
        pos = find(strcmp(c_math.ds.Items, c_math.ds.Value), 1, 'first');
        if isempty(pos) || pos > numel(state.catalogo_dataset_indices_math)
            return;
        end
        idx_catalogo = state.catalogo_dataset_indices_math(pos);
        catalogo = catalogo_math_actual();
        if idx_catalogo > numel(catalogo), return; end
        entrada = catalogo(idx_catalogo);
        if isempty(state.dataset_math) || ~strcmp(state.dataset_math_path, entrada.ruta)
            [state.dataset_math, state.dataset_meta_math] = load_dataset_con_meta(entrada.ruta);
            state.dataset_math_path = entrada.ruta;
            logmsg('Particion matematica cargada: %s', entrada.ruta);
        end
        ds = resolver_dataset_particion_visual(state.dataset_math, entrada);
    end

    function cargar_correccion_particion_math()
        state.corr = [];
        if ~isfield(state.dataset_meta_math, 'correccion_termica') || ...
                ~isstruct(state.dataset_meta_math.correccion_termica)
            poblar_zonas_math();
            return;
        end
        meta_corr = state.dataset_meta_math.correccion_termica;
        ruta_corr = resolver_ruta_correccion_math( ...
            campo_meta_visual(meta_corr, 'ruta_correccion', ''));
        if isfile(ruta_corr)
            state.corr = load_correction(ruta_corr);
            logmsg('Correccion resuelta por metadata: %s', ruta_corr);
        else
            state.corr = normalizar_correccion_vis( ...
                struct('correccion_termica', meta_corr));
            logmsg('Correccion completa no localizada; se usa la metadata embebida.');
        end
        poblar_zonas_math();
    end

    function ruta = resolver_ruta_correccion_math(ruta_guardada)
        ruta = char(ruta_guardada);
        if isfile(ruta) || isempty(ruta), return; end
        normal = strrep(ruta, '\', '/');
        marcador = '/correlaciones/';
        idx = strfind(lower(normal), marcador);
        if isempty(idx), ruta = ''; return; end
        relativa = normal(idx(end) + numel(marcador):end);
        candidata = fullfile(paths.correlaciones, strrep(relativa, '/', filesep));
        if isfile(candidata), ruta = candidata; else, ruta = ''; end
    end

    function cargar_par_sin_correccion_math(entrada_corr)
        entrada_base = entrada_corr;
        entrada_base.dataset_corregido = false;
        entrada_base.tag_correccion = '';
        ruta_base = campo_meta_visual(state.dataset_meta_math, 'ruta_entrada', '');
        if ~(ischar(ruta_base) && isfile(ruta_base))
            ruta_base = '';
            if isempty(state.catalogo_base_math)
                state.catalogo_base_math = catalogar_datasets_visual(dataset_dist_default);
            end
            idx = buscar_par_metadata_math(state.catalogo_base_math, entrada_corr);
            if ~isempty(idx)
                entrada_base = state.catalogo_base_math(idx);
                ruta_base = entrada_base.ruta;
            end
        else
            entrada_base.ruta = ruta_base;
            [ok_catalogo, entrada_catalogada] = leer_catalogo_particion_visual(ruta_base);
            if ok_catalogo
                entrada_base = entrada_catalogada;
            end
        end
        if isempty(ruta_base)
            logmsg('Sin par no corregido para %s/%s bajo la misma metadata.', ...
                entrada_corr.modelo, entrada_corr.dataset);
            return;
        end
        try
            [dataset_base, ~] = load_dataset_con_meta(ruta_base);
            ds_base = resolver_dataset_particion_visual(dataset_base, entrada_base);
            if isempty(ds_base)
                error('El archivo par no contiene el modelo/dataset esperado.');
            end
            state.vol_pares.sin_correccion = volumen_desde_dataset_math(ds_base, entrada_base);
            logmsg('Par sin correccion resuelto por metadata: %s', ruta_base);
        catch ME
            logmsg('Par sin correccion descartado: %s', ME.message);
        end
    end

    function idx = buscar_par_metadata_math(catalogo, referencia)
        idx = [];
        if isempty(catalogo), return; end
        campos = {'modelo', 'dataset', 'tipo', 'antena', 'caso', 'potencia'};
        mascara = ~[catalogo.dataset_corregido];
        for ci = 1:numel(campos)
            esperado = referencia.(campos{ci});
            if isempty(esperado), continue; end
            mascara = mascara & strcmpi(valores_catalogo(catalogo, campos{ci}), esperado);
        end
        idx = find(mascara, 1, 'first');
    end

    function poblar_filtro_catalogo(control, valores)
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
    function valores = valores_catalogo(catalogo, campo)
        if isempty(catalogo)
            valores = {};
        else
            valores = {catalogo.(campo)};
        end
    end
    function mask = pasa_filtro_catalogo(valores, filtro)
        if isempty(filtro) || strcmp(filtro, 'Todos')
            mask = true(size(valores));
            return;
        end
        mask = strcmp(valores, filtro);
    end
    function ds = resolver_dataset_particion_visual(dataset_particion, entrada)
        ds = [];
        if isfield(dataset_particion, entrada.modelo)
            md = dataset_particion.(entrada.modelo);
            if isfield(md, entrada.dataset)
                ds = md.(entrada.dataset);
                return;
            end
        end
        modelos = fieldnames(dataset_particion);
        modelos = modelos(~strcmp(modelos, 'session_meta'));
        for mi = 1:numel(modelos)
            md = dataset_particion.(modelos{mi});
            if isstruct(md) && isfield(md, entrada.dataset)
                ds = md.(entrada.dataset);
                return;
            end
        end
        if isscalar(modelos) && isstruct(dataset_particion.(modelos{1}))
            tags = fieldnames(dataset_particion.(modelos{1}));
            tags = tags(~ismember(tags, {'session_meta', 'source_signature', 'datasets_omitidos'}));
            if isscalar(tags)
                ds = dataset_particion.(modelos{1}).(tags{1});
            end
        end
    end
    function plot_corr_math()
        try
            if isempty(state.corr)
                limpiar_math_corr('Selecciona un dataset corregido mediante los filtros.');
                return;
            end
            poblar_zonas_math();
            corr_base = state.corr;
            ct_base = obtener_ct(corr_base);
            if isempty(ct_base), error('El MAT no contiene correccion_termica reconocible.'); end
            [ct, corr, etiqueta, idx_zona] = correccion_math_seleccionada();

            set_tag(c_math.ax_factor, 'math_ax_correccion_curvas');
            set_axis_panel_title(c_math.ax_factor, 'Correlacion simulacion vs experimento');
            cla(c_math.ax_factor, 'reset'); tesis_auxiliares('tema_ui', 'axes', c_math.ax_factor); hold(c_math.ax_factor, 'on');
            ley = {};
            if isfield(corr, 't_comun') && isfield(corr, 'y_exp_interp') && isfield(corr, 'y_sim_interp')
                plot(c_math.ax_factor, corr.t_comun(:), corr.y_exp_interp(:), '-', 'LineWidth', 1.0); ley{end+1} = 'Experimental';
                plot(c_math.ax_factor, corr.t_comun(:), corr.y_sim_interp(:), '-', 'LineWidth', 1.0); ley{end+1} = 'Simulada';
            end
            if isfield(ct, 'simulacion_corregida_factor_C') && isfield(corr, 't_comun') && ...
                    numel(ct.simulacion_corregida_factor_C) == numel(corr.t_comun)
                plot(c_math.ax_factor, corr.t_comun(:), ct.simulacion_corregida_factor_C(:), 'LineWidth', 1.4); ley{end+1} = 'Sim corregida';
            end
            if isempty(ley)
                text(c_math.ax_factor, 0.05, 0.55, 'Sin curvas exp/sim reconocidas.', 'Units', 'normalized');
            else
                legend(c_math.ax_factor, ley, 'Location', 'best');
            end
            grid(c_math.ax_factor, 'on'); xlabel(c_math.ax_factor, 'Tiempo (min)'); ylabel(c_math.ax_factor, 'Temperatura (C)');
            title(c_math.ax_factor, sprintf('Correlacion simulacion vs experimento | %s', etiqueta));
            hold(c_math.ax_factor, 'off');

            plot_funcion_correccion_math(ct, corr);
            if modo_math_es_correccion()
                plot_zonas_math(ct_base, idx_zona);
                plot_volumen_2d_math();
            end
            logmsg('Correccion graficada: %s.', etiqueta);
        catch ME
            fail('correccion matematica', ME);
        end
    end

    function poblar_zonas_math()
        if ~isfield(c_math, 'zona'), return; end
        previo = c_math.zona.Value;
        items = {'Global'};
        ct = obtener_ct(state.corr);
        if ~isempty(ct) && isfield(ct, 'zonas') && ~isempty(ct.zonas)
            zonas = ct.zonas(:);
            items = cell(1, numel(zonas) + 1);
            items{1} = 'Global';
            for zi = 1:numel(zonas)
                items{zi + 1} = etiqueta_zona_math(zonas(zi), zi);
            end
        end
        c_math.zona.Items = items;
        if any(strcmp(items, previo))
            c_math.zona.Value = previo;
        else
            c_math.zona.Value = items{1};
        end
    end

    function [ct, corr, etiqueta, idx_zona] = correccion_math_seleccionada()
        corr_base = state.corr;
        ct_base = obtener_ct(corr_base);
        idx_zona = zona_math_idx(ct_base);
        if idx_zona > 0
            zona = ct_base.zonas(idx_zona);
            ct = zona;
            corr = curva_zona_corr_math(corr_base, zona);
            etiqueta = etiqueta_zona_math(zona, idx_zona);
        else
            ct = ct_base;
            corr = corr_base;
            etiqueta = 'Global';
        end
    end

    function idx = zona_math_idx(ct)
        idx = 0;
        if isempty(ct) || ~isfield(ct, 'zonas') || isempty(ct.zonas) || ~isfield(c_math, 'zona')
            return;
        end
        if strcmp(c_math.zona.Value, 'Global')
            return;
        end
        pos = find(strcmp(c_math.zona.Items, c_math.zona.Value), 1, 'first');
        if ~isempty(pos)
            idx = min(max(0, pos - 1), numel(ct.zonas));
        end
    end

    function corr = curva_zona_corr_math(corr_base, zona)
        corr = corr_base;
        if isfield(zona, 't_comun')
            corr.t_comun = zona.t_comun(:);
        elseif isfield(zona, 't_rel_min')
            corr.t_comun = zona.t_rel_min(:);
        end
        campos = {'y_exp_interp', 'y_sim_interp', 'y_delta', 'p_arreglo'};
        for ci = 1:numel(campos)
            if isfield(zona, campos{ci})
                corr.(campos{ci}) = zona.(campos{ci});
            end
        end
    end

    function etiqueta = etiqueta_zona_math(zona, idx)
        if isfield(zona, 'label') && ~isempty(zona.label)
            etiqueta = sprintf('Zona %d | %s', idx, char(zona.label));
        else
            etiqueta = sprintf('Zona %d', idx);
        end
        if isfield(zona, 'z_min_mm') && isfield(zona, 'z_max_mm')
            etiqueta = sprintf('%s | z %.3g..%.3g mm', etiqueta, zona.z_min_mm, zona.z_max_mm);
        end
    end

    function plot_zonas_math(ct, idx_zona)
        set_tag(c_math.ax_zonas, 'math_ax_zonas_correccion');
        set_axis_panel_title(c_math.ax_zonas, 'Zonas de correccion');
        cla(c_math.ax_zonas, 'reset'); tesis_auxiliares('tema_ui', 'axes', c_math.ax_zonas); hold(c_math.ax_zonas, 'on');
        if isempty(ct) || ~isfield(ct, 'zonas') || isempty(ct.zonas)
            text(c_math.ax_zonas, 0.05, 0.55, 'Correccion sin zonas definidas.', 'Units', 'normalized');
            axis(c_math.ax_zonas, 'off'); title(c_math.ax_zonas, 'Zonas disponibles');
            hold(c_math.ax_zonas, 'off');
            return;
        end
        zonas = ct.zonas(:);
        hay = false;
        for zi = 1:numel(zonas)
            if ~isfield(zonas(zi), 't_rel_min') || ~isfield(zonas(zi), 'factor_enfriamiento')
                continue;
            end
            lw = 0.9;
            if zi == idx_zona, lw = 2.4; end
            plot(c_math.ax_zonas, zonas(zi).t_rel_min(:), zonas(zi).factor_enfriamiento(:), ...
                'LineWidth', lw, 'DisplayName', sprintf('Zona %d', zi));
            hay = true;
        end
        if hay
            legend(c_math.ax_zonas, 'show', 'Location', 'best');
        else
            text(c_math.ax_zonas, 0.05, 0.55, 'Zonas sin factor reconocible.', 'Units', 'normalized');
        end
        grid(c_math.ax_zonas, 'on'); xlabel(c_math.ax_zonas, 'Tiempo relativo (min)'); ylabel(c_math.ax_zonas, 'Factor');
        if idx_zona > 0
            titulo_zonas = sprintf('Factores por zona | seleccion %d', idx_zona);
        else
            titulo_zonas = 'Factores por zona | seleccion global';
        end
        title(c_math.ax_zonas, titulo_zonas);
        hold(c_math.ax_zonas, 'off');
    end

    function limpiar_axis_vacio_math(ax)
        cla(ax, 'reset');
        tesis_auxiliares('tema_ui', 'axes', ax);
        axis(ax, 'off');
        title(ax, '');
    end

    function plot_funcion_correccion_math(ct, corr)
        set_tag(c_math.ax_func, 'math_ax_funcion_correccion');
        set_axis_panel_title(c_math.ax_func, 'Funcion de correccion');
        cla(c_math.ax_func, 'reset'); tesis_auxiliares('tema_ui', 'axes', c_math.ax_func);
        hay = false;
        yyaxis(c_math.ax_func, 'left'); hold(c_math.ax_func, 'on');
        if isfield(ct, 'delta_T_C') && isfield(ct, 't_rel_min')
            plot(c_math.ax_func, ct.t_rel_min(:), ct.delta_T_C(:), '--', 'LineWidth', 1.1);
            hay = true;
        elseif isfield(corr, 'y_delta') && isfield(corr, 't_comun')
            plot(c_math.ax_func, corr.t_comun(:), corr.y_delta(:), '--', 'LineWidth', 1.1);
            hay = true;
        end
        ylabel(c_math.ax_func, 'Delta T (C)');
        yyaxis(c_math.ax_func, 'right');
        if isfield(ct, 'factor_enfriamiento') && isfield(ct, 't_rel_min')
            plot(c_math.ax_func, ct.t_rel_min(:), ct.factor_enfriamiento(:), ':', 'LineWidth', 1.5);
            hay = true;
        end
        ylabel(c_math.ax_func, 'Factor');
        yyaxis(c_math.ax_func, 'left');
        if ~hay
            text(c_math.ax_func, 0.05, 0.55, 'Sin funcion de correccion reconocida.', 'Units', 'normalized');
        else
            legend(c_math.ax_func, {'Delta T', 'Factor'}, 'Location', 'best');
        end
        grid(c_math.ax_func, 'on'); xlabel(c_math.ax_func, 'Tiempo relativo (min)'); title(c_math.ax_func, 'Funcion de correccion');
        hold(c_math.ax_func, 'off');
    end

    function limpiar_math_corr(msg)
        cla(c_math.ax_factor); title(c_math.ax_factor, msg);
        if isfield(c_math, 'ax_func'), cla(c_math.ax_func); title(c_math.ax_func, msg); end
        if isfield(c_math, 'ax_zonas'), cla(c_math.ax_zonas); title(c_math.ax_zonas, msg); end
        if isfield(c_math, 'ax_xz'), limpiar_axis_vacio_math(c_math.ax_xz); end
        if isfield(c_math, 'ax_yz'), limpiar_axis_vacio_math(c_math.ax_yz); end
        logmsg('%s', msg);
    end

    function actualizar_controles_volumen_math()
        if isempty(state.vol), return; end
        valor_previo = 'seleccionado';
        if isfield(c_math, 'metodo')
            try
                valor_previo = c_math.metodo.Value;
            catch
            end
        end
        items = {'Seleccionado'};
        data = {'seleccionado'};
        if isfield(state.vol, 'metodos_extrapolacion') && isstruct(state.vol.metodos_extrapolacion)
            nombres = fieldnames(state.vol.metodos_extrapolacion);
            for mi = 1:numel(nombres)
                data{end+1} = nombres{mi}; %#ok<AGROW>
                items{end+1} = etiqueta_metodo_vol_math(nombres{mi}); %#ok<AGROW>
            end
        end
        if isfield(c_math, 'metodo')
            c_math.metodo.Items = items;
            c_math.metodo.ItemsData = data;
            if any(strcmp(data, valor_previo))
                c_math.metodo.Value = valor_previo;
            else
                c_math.metodo.Value = data{1};
            end
        end
        actualizar_tiempos_vol_math();
    end

    function actualizar_tiempos_vol_math()
        sel = seleccionar_volumen_math();
        t = sel.t(:);
        if isempty(t)
            c_math.tiempo.Items = {'(sin volumen)'};
            c_math.tiempo.Value = '(sin volumen)';
            c_math.tlabel.Text = 'Tiempo guardado: sin campo cargado';
            return;
        end
        idx_previo = indice_tiempo_math();
        items = arrayfun(@(k) sprintf('%03d | %.4g min', k, t(k)), 1:numel(t), 'UniformOutput', false);
        c_math.tiempo.Items = items;
        idx = min(max(1, idx_previo), numel(items));
        c_math.tiempo.Value = items{idx};
        c_math.tlabel.Text = sprintf('Tiempo guardado: %.4g min | %s | %s', ...
            t(idx), etiqueta_metodo_vol_math(sel.metodo), etiqueta_campo_vol_math(sel.campo));
    end

    function actualizar_tiempo_vol_math()
        sel = seleccionar_volumen_math();
        idx = indice_tiempo_math();
        if ~isempty(sel.t)
            idx = min(max(1, idx), numel(sel.t));
            c_math.tlabel.Text = sprintf('Tiempo guardado: %.4g min | %s | %s', ...
                sel.t(idx), etiqueta_metodo_vol_math(sel.metodo), etiqueta_campo_vol_math(sel.campo));
        end
        plot_vol_math();
    end

    function idx = indice_tiempo_math()
        idx = 1;
        if isempty(c_math.tiempo.Items) || strcmp(c_math.tiempo.Items{1}, '(sin volumen)')
            return;
        end
        idx = find(strcmp(c_math.tiempo.Items, c_math.tiempo.Value), 1, 'first');
        if isempty(idx), idx = 1; end
    end

    function plot_vol_math()
        try
            if modo_math_es_correccion()
                plot_volumen_2d_math();
                return;
            end
            if isempty(state.vol)
                if ~asegurar_volumen_math()
                    limpiar_math_vol('Carga un dataset corregido con full_field valido.');
                    return;
                end
            end
            sel = seleccionar_volumen_math();
            idx_t = indice_tiempo_math();
            if ~isempty(sel.t), idx_t = min(max(1, idx_t), numel(sel.t)); end
            vol_activo = volumen_campo_activo_math();
            if isfield(vol_activo, 'puntos_termicos')
                plot_resumen_temperatura_archivo_math();
            else
                plot_volumen_curva_math(sel, idx_t);
            end
            draw_planes_math(sel, idx_t, 'todos');
            draw_volumen_3d_math(sel, idx_t);
            logmsg('Visualizando %s / %s.', ...
                etiqueta_metodo_vol_math(sel.metodo), etiqueta_campo_vol_math(sel.campo));
        catch ME
            fail('volumen', ME);
        end
    end

    function plot_volumen_2d_math()
        if ~asegurar_volumen_math()
            limpiar_axis_mensaje_math(c_math.ax_vol, 'Sin volumen 4D disponible para el dataset seleccionado.');
            return;
        end
        vol_activo = volumen_campo_activo_math();
        if isfield(vol_activo, 'puntos_termicos')
            plot_resumen_temperatura_archivo_math();
            return;
        end
        sel = seleccionar_volumen_math();
        idx_t = indice_tiempo_math();
        if ~isempty(sel.t), idx_t = min(max(1, idx_t), numel(sel.t)); end
        plot_volumen_curva_math(sel, idx_t);
    end

    function plot_volumen_curva_math(sel, idx_t)
        set_tag(c_math.ax_vol, 'math_ax_volumen_4d');
        set_axis_panel_title(c_math.ax_vol, 'Volumen 4D');
        cla(c_math.ax_vol, 'reset'); tesis_auxiliares('tema_ui', 'axes', c_math.ax_vol); hold(c_math.ax_vol, 'on');
        ley = plot_curvas_volumen_math(sel);
        if ~isempty(sel.t)
            xline(c_math.ax_vol, sel.t(idx_t), ':', 'Tiempo activo', 'HandleVisibility', 'off');
        end
        if isempty(ley)
            text(c_math.ax_vol, 0.05, 0.55, 'El dataset no contiene curvas de volumen reconocidas.', 'Units', 'normalized');
        else
            legend(c_math.ax_vol, 'show', 'Location', 'best');
        end
        grid(c_math.ax_vol, 'on'); xlabel(c_math.ax_vol, 'Tiempo (min)'); ylabel(c_math.ax_vol, 'Volumen');
        title(c_math.ax_vol, sprintf('Volumen 4D | %s | %s', etiqueta_metodo_vol_math(sel.metodo), etiqueta_campo_vol_math(sel.campo)));
        hold(c_math.ax_vol, 'off');
    end

    function limpiar_axis_mensaje_math(ax, msg)
        cla(ax, 'reset');
        tesis_auxiliares('tema_ui', 'axes', ax);
        text(ax, 0.05, 0.55, msg, 'Units', 'normalized');
        axis(ax, 'off');
        title(ax, msg);
    end

    function ley = plot_curvas_volumen_math(sel)
        ley = {};
        v = state.vol;
        campo = sel.campo;
        if isfield(v, 'metodos_extrapolacion') && isstruct(v.metodos_extrapolacion)
            nombres = fieldnames(v.metodos_extrapolacion);
            for mi = 1:numel(nombres)
                msel = seleccionar_volumen_math(nombres{mi}, campo);
                if ~isempty(msel.V) && ~isempty(msel.t)
                    estilo = '-'; ancho = 0.9;
                    if strcmp(nombres{mi}, sel.metodo), estilo = '-'; ancho = 1.8; end
                    plot(c_math.ax_vol, tiempo_compatible_vis(msel.t, msel.V), msel.V(:), estilo, ...
                        'LineWidth', ancho, 'DisplayName', etiqueta_metodo_vol_math(nombres{mi}));
                    ley{end+1} = nombres{mi}; %#ok<AGROW>
                end
            end
        end
        if isempty(ley) && ~isempty(sel.V) && ~isempty(sel.t)
            plot(c_math.ax_vol, tiempo_compatible_vis(sel.t, sel.V), sel.V(:), ...
                'LineWidth', 1.4, 'DisplayName', etiqueta_campo_vol_math(sel.campo));
            ley{end+1} = sel.campo;
        elseif ~isempty(sel.V) && ~isempty(sel.t)
            plot(c_math.ax_vol, tiempo_compatible_vis(sel.t, sel.V), sel.V(:), 'k--', ...
                'LineWidth', 1.2, 'DisplayName', sprintf('Activo: %s', etiqueta_metodo_vol_math(sel.metodo)));
        end
    end

    function draw_planes_math(sel, idx_t, plano)
        if nargin < 3, plano = 'todos'; end
        vol_activo = volumen_campo_activo_math();
        if isfield(vol_activo, 'puntos_termicos')
            try
                [P, T, tval] = puntos_archivo_math(idx_t, inf);
                cortes = tesis_auxiliares('planos_termicos_centrales', P, T);
                plot_plane_math(c_math.ax_xy, cortes.x, cortes.y, cortes.xy, ...
                    'X (mm)', 'Y (mm)', sprintf('XY | z=%.2f mm | t=%.2f min', ...
                    cortes.centro(3), tval));
                if ~isempty(cortes.limites_C), clim(c_math.ax_xy, cortes.limites_C); end
                if strcmp(plano, 'todos')
                    plot_plane_math(c_math.ax_xz, cortes.x, cortes.z, cortes.xz, ...
                        'X (mm)', 'Z (mm)', sprintf('XZ | y=%.2f mm | t=%.2f min', ...
                        cortes.centro(2), tval));
                    plot_plane_math(c_math.ax_yz, cortes.y, cortes.z, cortes.yz, ...
                        'Y (mm)', 'Z (mm)', sprintf('YZ | x=%.2f mm | t=%.2f min', ...
                        cortes.centro(1), tval));
                    if ~isempty(cortes.limites_C)
                        clim(c_math.ax_xz, cortes.limites_C);
                        clim(c_math.ax_yz, cortes.limites_C);
                    end
                end
            catch ME
                limpiar_plane_math(c_math.ax_xy, 'No se pudo calcular el corte central');
                if strcmp(plano, 'todos')
                    limpiar_plane_math(c_math.ax_xz, 'No se pudo calcular el corte central');
                    limpiar_plane_math(c_math.ax_yz, 'No se pudo calcular el corte central');
                end
                logmsg('AVISO cortes centrales nativos: %s', ME.message);
            end
            return;
        end
        if isempty(sel.F)
            limpiar_plane_math(c_math.ax_xy, 'Sin campo 4D');
            if strcmp(plano, 'todos')
                limpiar_plane_math(c_math.ax_xz, 'Sin campo 4D');
                limpiar_plane_math(c_math.ax_yz, 'Sin campo 4D');
            end
            return;
        end
        try
            [F, x, y, z, t] = volumen_grid_vectors_math(sel);
            if isempty(x) || isempty(y) || isempty(z) || isempty(t)
                error('Vectores de grilla incompletos en volumen 4D.');
            end
            idx_t = min(max(1, idx_t), numel(t));
            tval = t(idx_t);
            x = sample_vector_math(x, 95); y = sample_vector_math(y, 95); z = sample_vector_math(z, 95);
            xc = x(max(1, round(numel(x)/2)));
            yc = y(max(1, round(numel(y)/2)));
            zc = z(max(1, round(numel(z)/2)));

            [Xxy, Yxy] = ndgrid(x, y);
            Txy = F(Xxy, Yxy, zc .* ones(size(Xxy)), tval .* ones(size(Xxy)));
            if any(strcmp(plano, {'xy', 'todos'}))
                set_tag(c_math.ax_xy, 'math_ax_plano_xy');
                set_axis_panel_title(c_math.ax_xy, 'Plano termico XY');
                plot_plane_math(c_math.ax_xy, x, y, Txy', 'X (mm)', 'Y (mm)', sprintf('Plano XY | z=%.2f mm | t=%.2f min', zc, tval));
                if ~strcmp(plano, 'todos'), return; end
            end

            [Xxz, Zxz] = ndgrid(x, z);
            Txz = F(Xxz, yc .* ones(size(Xxz)), Zxz, tval .* ones(size(Xxz)));
            if any(strcmp(plano, {'xz', 'todos'}))
                set_tag(c_math.ax_xz, 'math_ax_plano_xz');
                set_axis_panel_title(c_math.ax_xz, 'Plano termico XZ');
                plot_plane_math(c_math.ax_xz, x, z, Txz', 'X (mm)', 'Z (mm)', sprintf('Plano XZ | y=%.2f mm | t=%.2f min', yc, tval));
                if ~strcmp(plano, 'todos'), return; end
            end

            [Yyz, Zyz] = ndgrid(y, z);
            Tyz = F(xc .* ones(size(Yyz)), Yyz, Zyz, tval .* ones(size(Yyz)));
            set_tag(c_math.ax_yz, 'math_ax_plano_yz');
            set_axis_panel_title(c_math.ax_yz, 'Plano termico YZ');
            plot_plane_math(c_math.ax_yz, y, z, Tyz', 'Y (mm)', 'Z (mm)', sprintf('Plano YZ | x=%.2f mm | t=%.2f min', xc, tval));
        catch ME
            limpiar_plane_math(c_math.ax_xy, 'No se pudieron graficar planos');
            if strcmp(plano, 'todos')
                limpiar_plane_math(c_math.ax_xz, 'No se pudieron graficar planos');
                limpiar_plane_math(c_math.ax_yz, 'No se pudieron graficar planos');
            end
            logmsg('AVISO planos 4D: %s', ME.message);
        end
    end

    function draw_volumen_3d_math(sel, idx_t)
        set_tag(c_math.ax_3d, 'math_ax_volumen_3d');
        set_axis_panel_title(c_math.ax_3d, 'Volumen 3D');
        cla(c_math.ax_3d, 'reset'); tesis_auxiliares('tema_ui', 'axes', c_math.ax_3d);
        vol_activo = volumen_campo_activo_math();
        if isfield(vol_activo, 'puntos_termicos')
            [P, T, tval] = puntos_archivo_math(idx_t, 50000);
            umbral = vol_activo.T_abl_exp;
            mask = T >= umbral;
            if any(mask)
                scatter3(c_math.ax_3d, P(mask,1), P(mask,2), P(mask,3), ...
                    7, T(mask), 'filled');
                axis(c_math.ax_3d, 'equal'); grid(c_math.ax_3d, 'on'); ...
                    view(c_math.ax_3d, 3); colorbar(c_math.ax_3d);
                xlabel(c_math.ax_3d, 'X (mm)'); ylabel(c_math.ax_3d, 'Y (mm)'); ...
                    zlabel(c_math.ax_3d, 'Z (mm)');
            else
                text(c_math.ax_3d, 0.05, 0.55, sprintf('Sin puntos >= %.1f C.', umbral), ...
                    'Units', 'normalized');
            end
            title(c_math.ax_3d, sprintf('Puntos guardados | t=%.2f min | umbral visual %.1f C', ...
                tval, umbral));
            return;
        end
        if isempty(sel.F)
            text(c_math.ax_3d, 0.05, 0.55, 'Sin campo 4D', 'Units', 'normalized');
            axis(c_math.ax_3d, 'off'); title(c_math.ax_3d, 'Volumen 3D / Isosuperficie');
            return;
        end
        try
            [F, x, y, z, t] = volumen_grid_vectors_math(sel);
            idx_t = min(max(1, idx_t), numel(t));
            tval = t(idx_t);
            x = sample_vector_math(x, 45); y = sample_vector_math(y, 45); z = sample_vector_math(z, 45);
            [X, Y, Z] = ndgrid(x, y, z);
            T = F(X, Y, Z, tval .* ones(size(X)));
            umbral = sel.T_abl;
            if ~isfinite(umbral), umbral = 55; end
            mask = isfinite(T) & T >= umbral;
            if nnz(mask) < 8
                text(c_math.ax_3d, 0.05, 0.55, sprintf('Sin volumen >= %.1f C en este instante.', umbral), 'Units', 'normalized');
                axis(c_math.ax_3d, 'off'); title(c_math.ax_3d, 'Volumen 3D');
                return;
            end
            modo3d = 'ambos';
            if isfield(c_math, 'vista3d'), modo3d = c_math.vista3d.Value; end
            dibujar_superficie = any(strcmp(modo3d, {'alpha', 'ambos'}));
            dibujar_puntos = any(strcmp(modo3d, {'puntos', 'ambos'}));
            hay = false;
            if dibujar_superficie
                fv = isosurface(X, Y, Z, T, umbral);
                if ~isempty(fv.vertices)
                    patch(c_math.ax_3d, fv, 'FaceColor', [0.9 0.25 0.12], ...
                        'EdgeColor', 'none', 'FaceAlpha', 0.42, 'DisplayName', 'AlphaShape/STL');
                    hay = true;
                end
            end
            hold(c_math.ax_3d, 'on');
            if dibujar_puntos
                P = [X(mask), Y(mask), Z(mask)];
                C = T(mask);
                nshow = min(2500, size(P, 1));
                idxp = unique(round(linspace(1, size(P, 1), nshow)));
                scatter3(c_math.ax_3d, P(idxp,1), P(idxp,2), P(idxp,3), 7, C(idxp), ...
                    'filled', 'DisplayName', 'Puntos termicos');
                hay = true;
            end
            if ~hay
                text(c_math.ax_3d, 0.05, 0.55, 'Vista 3D vacia.', 'Units', 'normalized');
                axis(c_math.ax_3d, 'off'); title(c_math.ax_3d, 'Volumen 3D');
                return;
            end
            hold(c_math.ax_3d, 'off');
            axis(c_math.ax_3d, 'equal'); grid(c_math.ax_3d, 'on'); view(c_math.ax_3d, 3);
            camlight(c_math.ax_3d, 'headlight'); lighting(c_math.ax_3d, 'gouraud');
            xlabel(c_math.ax_3d, 'X (mm)'); ylabel(c_math.ax_3d, 'Y (mm)'); zlabel(c_math.ax_3d, 'Z (mm)');
            colorbar(c_math.ax_3d);
            title(c_math.ax_3d, sprintf('3D %s | %.1f C | t=%.2f min', etiqueta_vista3d_math(modo3d), umbral, tval));
        catch ME
            text(c_math.ax_3d, 0.05, 0.55, 'No se pudo graficar 3D.', 'Units', 'normalized');
            axis(c_math.ax_3d, 'off'); title(c_math.ax_3d, 'Volumen 3D / Isosuperficie');
            logmsg('AVISO volumen 3D: %s', ME.message);
        end
    end

    function txt = etiqueta_vista3d_math(modo3d)
        switch char(modo3d)
            case 'alpha'
                txt = 'AlphaShape/STL';
            case 'puntos'
                txt = 'puntos termicos';
            otherwise
                txt = 'AlphaShape/STL + puntos';
        end
    end

    function [F, x, y, z, t] = volumen_grid_vectors_math(sel)
        F = sel.F;
        x = sel.x; y = sel.y; z = sel.z; t = sel.t;
        if (isempty(x) || isempty(y) || isempty(z) || isempty(t)) && ~isempty(F) && isprop(F, 'GridVectors')
            gv = F.GridVectors;
            if isempty(x) && numel(gv) >= 1, x = double(gv{1}(:)); end
            if isempty(y) && numel(gv) >= 2, y = double(gv{2}(:)); end
            if isempty(z) && numel(gv) >= 3, z = double(gv{3}(:)); end
            if isempty(t) && numel(gv) >= 4, t = double(gv{4}(:)); end
        end
    end

    function sel = seleccionar_volumen_math(metodo, campo)
        if nargin < 1 || isempty(metodo)
            if isfield(c_math, 'metodo')
                metodo = c_math.metodo.Value;
            else
                metodo = 'seleccionado';
            end
        end
        if nargin < 2 || isempty(campo)
            if isfield(c_math, 'campo')
                campo = c_math.campo.Value;
            else
                campo = 'corregido';
            end
        end
        base = volumen_campo_activo_math(campo);
        if isempty(base)
            sel = volumen_sel_vacio(metodo, campo);
            return;
        end
        metodo = char(metodo);
        campo = char(campo);
        if ~strcmp(metodo, 'seleccionado') && isfield(base, 'metodos_extrapolacion') && ...
                isfield(base.metodos_extrapolacion, metodo)
            base = base.metodos_extrapolacion.(metodo);
        end
        sel = volumen_sel_desde_struct(base, metodo, campo);
        if isempty(sel.x) && isfield(state.vol, 'xg_exp'), sel.x = double(state.vol.xg_exp(:)); end
        if isempty(sel.y) && isfield(state.vol, 'yg_exp'), sel.y = double(state.vol.yg_exp(:)); end
        if isempty(sel.z) && isfield(state.vol, 'zg_exp'), sel.z = double(state.vol.zg_exp(:)); end
        if isempty(sel.t) && isfield(state.vol, 't_exp'), sel.t = double(state.vol.t_exp(:)); end
        if isempty(sel.T_abl) || ~isfinite(sel.T_abl)
            if isfield(state.vol, 'T_abl_exp'), sel.T_abl = state.vol.T_abl_exp; else, sel.T_abl = 55; end
        end
    end

    function v = volumen_campo_activo_math(varargin)
        campo = '';
        if nargin >= 1, campo = char(varargin{1}); end
        if isempty(campo) && isfield(c_math, 'campo')
            campo = char(c_math.campo.Value);
        end
        v = state.vol;
        if ~isempty(campo) && isfield(state.vol_pares, campo) && ...
                ~isempty(state.vol_pares.(campo))
            v = state.vol_pares.(campo);
        end
    end

    function sel = volumen_sel_vacio(metodo, campo)
        sel = struct('F', [], 'V', [], 't', [], 'x', [], 'y', [], 'z', [], ...
            'metodo', char(metodo), 'campo', char(campo), 'T_abl', NaN);
    end

    function sel = volumen_sel_desde_struct(v, metodo, campo)
        sel = volumen_sel_vacio(metodo, campo);
        if ~isstruct(v), return; end
        if strcmp(campo, 'sin_correccion')
            if isfield(v, 'Fgrid_sin_correccion') && ~isempty(v.Fgrid_sin_correccion)
                sel.F = v.Fgrid_sin_correccion;
            elseif isfield(v, 'Fgrid_base') && ~isempty(v.Fgrid_base)
                sel.F = v.Fgrid_base;
            elseif isfield(v, 'Fgrid_ext') && ~volumen_tiene_correccion(v)
                sel.F = v.Fgrid_ext;
            end
            if isfield(v, 'V_sin_correccion') && ~isempty(v.V_sin_correccion)
                sel.V = double(v.V_sin_correccion(:));
            elseif isfield(v, 'V_base') && ~isempty(v.V_base)
                sel.V = double(v.V_base(:));
            elseif isfield(v, 'V_base_exp') && ~volumen_tiene_correccion(v)
                sel.V = double(v.V_base_exp(:));
            end
        else
            if isfield(v, 'Fgrid_corregido') && ~isempty(v.Fgrid_corregido)
                sel.F = v.Fgrid_corregido;
            elseif isfield(v, 'Fgrid_ext') && ~isempty(v.Fgrid_ext)
                sel.F = v.Fgrid_ext;
            end
            if isfield(v, 'V_corr') && ~isempty(v.V_corr)
                sel.V = double(v.V_corr(:));
            elseif isfield(v, 'V_base_exp') && ~isempty(v.V_base_exp)
                sel.V = double(v.V_base_exp(:));
            elseif isfield(v, 'V_base') && ~isempty(v.V_base)
                sel.V = double(v.V_base(:));
            end
        end
        if isempty(sel.F) && isfield(v, 'Fgrid_ext') && ~isempty(v.Fgrid_ext) && ...
                (~strcmp(campo, 'sin_correccion') || ~volumen_tiene_correccion(v))
            sel.F = v.Fgrid_ext;
        end
        if isempty(sel.V) && isfield(v, 'V_base_exp') && ...
                (~strcmp(campo, 'sin_correccion') || ~volumen_tiene_correccion(v))
            sel.V = double(v.V_base_exp(:));
        end
        if isfield(v, 't_exp'), sel.t = double(v.t_exp(:)); end
        if isempty(sel.t) && isfield(v, 't_full'), sel.t = double(v.t_full(:)); end
        if isempty(sel.t) && isfield(v, 't_fine'), sel.t = double(v.t_fine(:)); end
        if ~isempty(sel.V)
            sel.t = tiempo_compatible_vis(sel.t, sel.V);
        end
        if isfield(v, 'xg_exp'), sel.x = double(v.xg_exp(:)); end
        if isfield(v, 'yg_exp'), sel.y = double(v.yg_exp(:)); end
        if isfield(v, 'zg_exp'), sel.z = double(v.zg_exp(:)); end
        if isfield(v, 'T_abl_exp'), sel.T_abl = double(v.T_abl_exp); end
    end

    function tf = volumen_tiene_correccion(v)
        tf = false;
        if isfield(v, 'correccion_exportada') && isstruct(v.correccion_exportada) && ...
                isfield(v.correccion_exportada, 'activa')
            tf = logical(v.correccion_exportada.activa);
        elseif isfield(v, 'V_corr') && ~isempty(v.V_corr)
            tf = true;
        end
    end

    function txt = etiqueta_metodo_vol_math(metodo)
        metodo = char(metodo);
        switch metodo
            case 'seleccionado'
                txt = 'Seleccionado/exportado';
            case 'pca_temporal'
                txt = 'PCA temporal (metadato heredado)';
            case 'lowess_cuadratico'
                txt = 'LOWESS';
            case 'gradiente_local'
                txt = 'Gradiente local';
            otherwise
                txt = strrep(metodo, '_', ' ');
        end
    end

    function txt = etiqueta_campo_vol_math(campo)
        campo = char(campo);
        switch campo
            case 'sin_correccion'
                txt = 'Sin correccion';
            otherwise
                txt = 'Exportado/corregido';
        end
    end
    function v = sample_vector_math(v, nmax)
        v = double(v(:));
        if numel(v) > nmax
            idx = unique(round(linspace(1, numel(v), nmax)));
            v = v(idx);
        end
    end

    function plot_plane_math(ax, a, b, C, xlab, ylab, ttl)
        cla(ax, 'reset'); tesis_auxiliares('tema_ui', 'axes', ax);
        ax.Visible = 'on';
        imagesc(ax, a, b, C);
        set(ax, 'YDir', 'normal');
        axis(ax, 'image'); colorbar(ax); grid(ax, 'on');
        xlabel(ax, xlab); ylabel(ax, ylab); title(ax, ttl);
    end

    function limpiar_plane_math(ax, msg)
        cla(ax, 'reset'); tesis_auxiliares('tema_ui', 'axes', ax);
        text(ax, 0.05, 0.55, msg, 'Units', 'normalized');
        axis(ax, 'off'); title(ax, msg);
    end

    function limpiar_math_vol(msg)
        cla(c_math.ax_vol); title(c_math.ax_vol, msg);
        if isfield(c_math, 'ax_xy'), limpiar_plane_math(c_math.ax_xy, msg); end
        if isfield(c_math, 'ax_xz'), limpiar_plane_math(c_math.ax_xz, msg); end
        if isfield(c_math, 'ax_yz'), limpiar_plane_math(c_math.ax_yz, msg); end
        if isfield(c_math, 'ax_3d'), limpiar_plane_math(c_math.ax_3d, msg); end
        logmsg('%s', msg);
    end

    function catalogo = catalogar_datasets_visual(ruta)
        catalogo = crear_catalogo_visual(0);
        if isfolder(ruta)
            catalogo = catalogar_indice_visual(ruta);
            if ~isempty(catalogo)
                return;
            end
            archivos = dir(fullfile(ruta, '**', '*.mat'));
            archivos = archivos(~[archivos.isdir]);
            archivos = archivos(~arrayfun(@(a) ruta_repetida_visual( ...
                fullfile(a.folder, a.name)), archivos));
            rutas = arrayfun(@(a) fullfile(a.folder, a.name), archivos, 'UniformOutput', false);
        elseif isfile(ruta)
            if ruta_repetida_visual(ruta)
                rutas = {};
            else
                rutas = {ruta};
            end
        else
            rutas = {};
        end
        for ri = 1:numel(rutas)
            [ok, entrada] = leer_catalogo_particion_visual(rutas{ri});
            if ok
                catalogo(end + 1) = entrada; %#ok<AGROW>
            end
        end
        catalogo = deduplicar_catalogo_visual(catalogo);
    end

    function catalogo = catalogar_indice_visual(carpeta)
        catalogo = crear_catalogo_visual(0);
        ruta_indice = fullfile(carpeta, 'Indice_Datasets_Metadata.mat');
        if ~isfile(ruta_indice)
            return;
        end
        try
            raw = load(ruta_indice, 'particiones');
            if ~isfield(raw, 'particiones') || ~isstruct(raw.particiones)
                return;
            end
            for pi = 1:numel(raw.particiones)
                p = raw.particiones(pi);
                if ~isfield(p, 'ruta') || ~isfile(p.ruta) || ruta_repetida_visual(p.ruta)
                    continue;
                end
                entrada = crear_catalogo_visual(1);
                entrada.ruta = p.ruta;
                entrada.modelo = campo_meta_visual(p, 'modelo', '');
                entrada.dataset = campo_meta_visual(p, 'dataset', '');
                entrada.tipo = campo_meta_visual(p, 'tipo', '');
                entrada.antena = campo_meta_visual(p, 'antena', '');
                entrada.caso = texto_num_meta_visual(campo_meta_visual(p, 'caso', NaN), 'Caso_%g');
                entrada.potencia = texto_num_meta_visual(campo_meta_visual(p, 'potencia_W', NaN), 'Potencia_%gW');
                entrada.fuente = campo_meta_visual(p, 'fuente', '');
                entrada.dataset_corregido = bool_meta_visual(campo_meta_visual(p, 'dataset_corregido', false));
                entrada.tag_correccion = campo_meta_visual(p, 'tag_correccion', '');
                [entrada.fecha, entrada.tiempo_corr, entrada.prueba, entrada.zonas] = ...
                    metadata_adquisicion_visual(p, entrada.ruta);
                entrada.clave = clave_catalogo_visual(entrada);
                if ~isempty(entrada.modelo) && ~isempty(entrada.dataset)
                    catalogo(end + 1) = entrada; %#ok<AGROW>
                end
            end
            catalogo = deduplicar_catalogo_visual(catalogo);
        catch
            catalogo = crear_catalogo_visual(0);
        end
    end

    function [ok, entrada] = leer_catalogo_particion_visual(ruta)
        ok = false;
        entrada = crear_catalogo_visual(1);
        [~, nombre, ~] = fileparts(ruta);
        nombre_lower = lower(nombre);
        if startsWith(nombre_lower, 'indice_') || startsWith(nombre_lower, 'reporte_') || ...
                contains(nombre_lower, 'historial')
            return;
        end
        try
            raw = load(ruta, 'partition_meta');
            if ~isfield(raw, 'partition_meta') || ~isstruct(raw.partition_meta)
                return;
            end
            pm = raw.partition_meta;
            entrada.ruta = ruta;
            entrada.modelo = campo_meta_visual(pm, 'modelo', '');
            entrada.dataset = campo_meta_visual(pm, 'tag_dataset', '');
            entrada.tipo = campo_meta_visual(pm, 'tipo', '');
            entrada.antena = campo_meta_visual(pm, 'antena', '');
            entrada.caso = texto_num_meta_visual(campo_meta_visual(pm, 'caso', NaN), 'Caso_%g');
            entrada.potencia = texto_num_meta_visual(campo_meta_visual(pm, 'potencia_W', NaN), 'Potencia_%gW');
            entrada.fuente = campo_meta_visual(pm, 'fuente', '');
            entrada.dataset_corregido = bool_meta_visual(campo_meta_visual(pm, 'dataset_corregido', false));
            entrada.tag_correccion = campo_meta_visual(pm, 'tag_correccion', '');
            [entrada.fecha, entrada.tiempo_corr, entrada.prueba, entrada.zonas] = ...
                metadata_adquisicion_visual(pm, ruta);
            entrada.clave = clave_catalogo_visual(entrada);
            if isempty(entrada.modelo) || isempty(entrada.dataset)
                return;
            end
            ok = true;
        catch
            ok = false;
        end
    end

    function catalogo = crear_catalogo_visual(n)
        plantilla = struct('ruta', '', 'modelo', '', 'dataset', '', ...
            'tipo', '', 'antena', '', 'caso', '', 'potencia', '', ...
            'fecha', '', 'tiempo_corr', '', 'prueba', '', 'zonas', '', ...
            'tag_correccion', '', 'fuente', '', ...
            'dataset_corregido', false, 'clave', '');
        if n == 0
            catalogo = plantilla([]);
        else
            catalogo = repmat(plantilla, n, 1);
        end
    end

    function catalogo = deduplicar_catalogo_visual(catalogo)
        if isempty(catalogo), return; end
        claves = cell(1, numel(catalogo));
        keep = true(1, numel(catalogo));
        for ci = 1:numel(catalogo)
            claves{ci} = clave_catalogo_visual(catalogo(ci));
            catalogo(ci).clave = claves{ci};
            if any(strcmpi(claves(1:ci-1), claves{ci}))
                keep(ci) = false;
            end
        end
        catalogo = catalogo(keep);
    end

    function clave = clave_catalogo_visual(entrada)
        identidad_correccion = entrada.tag_correccion;
        if isempty(identidad_correccion)
            identidad_correccion = strjoin({entrada.fecha, entrada.tiempo_corr, ...
                entrada.prueba, entrada.zonas}, '__');
        end
        partes = {entrada.modelo, entrada.dataset, identidad_correccion};
        partes = partes(~cellfun(@isempty, partes));
        clave = lower(strjoin(partes, '__'));
    end

    function valor = campo_meta_visual(s, campo, predeterminado)
        if isstruct(s) && isfield(s, campo) && ~isempty(s.(campo))
            valor = s.(campo);
        else
            valor = predeterminado;
        end
        if isstring(valor)
            valor = char(valor);
        end
    end

    function texto = texto_num_meta_visual(valor, formato)
        if isnumeric(valor) && isscalar(valor) && isfinite(double(valor))
            texto = sprintf(formato, double(valor));
            texto = strrep(texto, '.000000', '');
        elseif ischar(valor) || isstring(valor)
            texto = char(valor);
        else
            texto = '';
        end
    end

    function tf = bool_meta_visual(valor)
        if islogical(valor) || isnumeric(valor)
            tf = isscalar(valor) && logical(valor);
        elseif ischar(valor) || isstring(valor)
            tf = any(strcmpi(char(valor), {'1', 'true', 'si', 'yes'}));
        else
            tf = false;
        end
    end

    function plot_resumen_temperatura_archivo_math()
        v = volumen_campo_activo_math();
        T = double(v.temperaturas_termicas);
        t = double(v.t_full(:));
        set_axis_panel_title(c_math.ax_vol, 'Temperaturas almacenadas');
        cla(c_math.ax_vol, 'reset'); tesis_auxiliares('tema_ui', 'axes', c_math.ax_vol);
        plot(c_math.ax_vol, t, min(T, [], 1, 'omitnan'), '--', ...
            t, mean(T, 1, 'omitnan'), '-', t, max(T, [], 1, 'omitnan'), '-.', ...
            'LineWidth', 1.2);
        grid(c_math.ax_vol, 'on'); xlabel(c_math.ax_vol, 'Tiempo (min)'); ...
            ylabel(c_math.ax_vol, 'Temperatura (C)');
        legend(c_math.ax_vol, {'min', 'media', 'max'}, 'Location', 'best');
        title(c_math.ax_vol, 'Lectura directa del campo guardado; sin reconstruccion 4D');
    end

    function [P, T, tval] = puntos_archivo_math(idx_t, nmax)
        v = volumen_campo_activo_math();
        P = double(v.puntos_termicos);
        M = double(v.temperaturas_termicas);
        idx_t = max(1, min(size(M,2), idx_t));
        T = M(:,idx_t); tval = v.t_full(idx_t);
        validos = all(isfinite(P),2) & isfinite(T); P = P(validos,:); T = T(validos);
        if size(P,1) > nmax
            idx = round(linspace(1,size(P,1),nmax)); P=P(idx,:); T=T(idx);
        end
    end

    function [fecha, tiempo, prueba, zonas] = metadata_adquisicion_visual(meta, ruta)
        md = tesis_auxiliares('metadata_ruta', ruta, meta);
        fecha = char(md.fecha_adquisicion);
        if isempty(fecha)
            fecha = campo_meta_visual(meta, 'fecha_experimento', '');
        end
        tiempo = '';
        prueba = '';
        zonas = '';
        if isfinite(md.tiempo_ejecucion_min)
            tiempo = sprintf('Tiempo_%gmin', md.tiempo_ejecucion_min);
        end
        if isfinite(md.numero_prueba)
            prueba = sprintf('Prueba_%d', round(md.numero_prueba));
        end
        if isfinite(md.num_zonas)
            zonas = sprintf('Zonas_%d', round(md.num_zonas));
        end
    end

    function etiqueta = etiqueta_catalogo_visual(entrada)
        partes = {entrada.modelo, entrada.dataset, entrada.tipo, entrada.antena, ...
            entrada.caso, entrada.potencia};
        if ~isempty(entrada.fecha)
            partes{end + 1} = ['Fecha_' entrada.fecha];
        end
        partes = [partes, {entrada.tiempo_corr, entrada.prueba, entrada.zonas}];
        partes = partes(~cellfun(@isempty, partes));
        etiqueta = strjoin(partes, ' | ');
    end

    function [data, meta] = load_dataset_con_meta(ruta)
        S = load(ruta);
        meta = struct();
        if isfield(S, 'partition_meta') && isstruct(S.partition_meta)
            meta = S.partition_meta;
        end
        if isfield(S, 'dataset')
            data = S.dataset;
            return;
        end
        f = fieldnames(S);
        ignorar = {'partition_meta', 'particiones', 'omitidos', 'resumen'};
        for ii = 1:numel(f)
            if isstruct(S.(f{ii})) && ~ismember(f{ii}, ignorar)
                data = S.(f{ii});
                return;
            end
        end
        error('El MAT no contiene dataset struct.');
    end
    function c = load_correction(ruta)
        S = load(ruta);
        if isfield(S, 'correccion_termica')
            c = S;
        elseif isfield(S, 't_rel_min') && isfield(S, 'factor_enfriamiento')
            c = struct('correccion_termica', S);
        else
            c = S;
        end
        c = normalizar_correccion_vis(c);
    end

    function c = normalizar_correccion_vis(c)
        ct = obtener_ct(c);
        if isempty(ct)
            error('El MAT no contiene correccion_termica ni factor_enfriamiento/t_rel_min.');
        end
        if ~isfield(c, 't_comun') && isfield(ct, 't_rel_min'), c.t_comun = ct.t_rel_min(:); end
        if ~isfield(c, 'y_delta') && isfield(ct, 'delta_T_C'), c.y_delta = ct.delta_T_C(:); end
        if ~isfield(c, 'y_sim_interp') && isfield(ct, 'incremento_sim_C') && isfield(ct, 'temperatura_base_sim_C')
            c.y_sim_interp = ct.temperatura_base_sim_C + ct.incremento_sim_C(:);
        end
        if ~isfield(c, 'y_exp_interp') && isfield(ct, 'incremento_exp_C') && isfield(ct, 'temperatura_base_exp_C')
            c.y_exp_interp = ct.temperatura_base_exp_C + ct.incremento_exp_C(:);
        end
    end

    function ct = obtener_ct(corr)
        ct = [];
        if isempty(corr), return; end
        if isfield(corr, 'correccion_termica')
            ct = corr.correccion_termica;
        elseif isfield(corr, 't_rel_min') && isfield(corr, 'factor_enfriamiento')
            ct = corr;
        end
    end

    function v = volumen_desde_dataset_math(ds, entrada)
        if ~isfield(ds, 'full_field') || ~isfield(ds.full_field, 'points') || ...
                ~isfield(ds.full_field, 'T_C')
            error('El dataset seleccionado no contiene full_field legible.');
        end
        puntos = double(ds.full_field.points);
        temperaturas = double(ds.full_field.T_C);
        if size(temperaturas, 1) ~= size(puntos, 1)
            error('full_field.points y full_field.T_C no tienen tamanos compatibles.');
        end
        tiempos = tiempo_dataset_math(ds, ds.full_field, size(temperaturas, 2));
        corregido = entrada.dataset_corregido;
        tipo_campo = 'sin_correccion';
        if corregido, tipo_campo = 'corregido'; end
        v = struct('t_exp', tiempos(:), 't_full', tiempos(:), 't_fine', tiempos(:), ...
            'puntos_termicos', puntos, 'temperaturas_termicas', temperaturas, ...
            'tipo_campo_puntos', tipo_campo, 'T_abl_exp', 55, ...
            'fuente_dataset', entrada.ruta, 'solo_lectura', true, ...
            'correccion_exportada', struct('activa', corregido));
    end

    function t = tiempo_dataset_math(ds, ff, n)
        t = [];
        if isfield(ff, 't_min'), t = double(ff.t_min(:)); end
        if isempty(t) && isfield(ds, 't_min'), t = double(ds.t_min(:)); end
        if isempty(t) && isfield(ds, 'snapshots') && ~isempty(ds.snapshots)
            t = arrayfun(@(s) getfield_default(s, 't_min', NaN), ds.snapshots(:));
            t = double(t(:));
        end
        t = t(isfinite(t));
        if numel(t) ~= n
            if isempty(t)
                t = (0:n-1)';
            else
                t = linspace(t(1), t(end), n)';
            end
        end
    end

    function t = tiempo_compatible_vis(t_ref, valores)
        n = numel(valores);
        t_ref = double(t_ref(:));
        if numel(t_ref) == n
            t = t_ref;
        elseif numel(t_ref) > n
            t = t_ref(1:n);
        elseif isempty(t_ref)
            t = (0:n-1)';
        else
            t = linspace(t_ref(1), t_ref(end), n)';
        end
    end

    function val = getfield_default(s, field, def)
        if isfield(s, field), val = s.(field); else, val = def; end
    end

    function ejecutar_selftest_fecha_catalogo_visual()
        catalogo = catalogar_datasets_visual(paths.datasets_corregidos_por_metadata);
        assert(~isempty(catalogo), ...
            'No hay datasets corregidos para probar el filtro de fecha.');
        fechas = unique({catalogo.fecha});
        fechas = fechas(~cellfun(@isempty, fechas));
        assert(numel(fechas) >= 2, ...
            'El catalogo visual no conserva al menos dos fechas distintas.');
        claves = {catalogo.clave};
        assert(numel(unique(lower(string(claves)))) == numel(catalogo), ...
            'El catalogo visual aun contiene claves duplicadas.');
        assert(all(~cellfun(@isempty, {catalogo.tiempo_corr})) && ...
            all(~cellfun(@isempty, {catalogo.prueba})) && ...
            all(~cellfun(@isempty, {catalogo.zonas})), ...
            'El catalogo visual perdio tiempo, prueba o zonas.');
        muestra_1 = crear_catalogo_visual(1);
        muestra_1.modelo = 'modelo_Monopolo_1ant';
        muestra_1.dataset = 'dset_c1_p30';
        muestra_1.fecha = 'junio_19';
        muestra_1.tiempo_corr = 'Tiempo_20min';
        muestra_1.prueba = 'Prueba_1';
        muestra_1.zonas = 'Zonas_4';
        muestra_2 = muestra_1;
        muestra_2.prueba = 'Prueba_2';
        assert(~strcmp(clave_catalogo_visual(muestra_1), ...
            clave_catalogo_visual(muestra_2)) && ...
            ~strcmp(etiqueta_catalogo_visual(muestra_1), ...
            etiqueta_catalogo_visual(muestra_2)), ...
            'Dos pruebas de la misma fecha siguen siendo ambiguas.');
        pareja_fechas = false;
        for i = 1:numel(catalogo)
            for j = i + 1:numel(catalogo)
                if strcmp(catalogo(i).modelo, catalogo(j).modelo) && ...
                        strcmp(catalogo(i).dataset, catalogo(j).dataset) && ...
                        ~strcmpi(catalogo(i).fecha, catalogo(j).fecha)
                    pareja_fechas = true;
                    break;
                end
            end
            if pareja_fechas, break; end
        end
        assert(pareja_fechas, ...
            'No se conservaron dos fechas para un mismo modelo/dataset.');
        fprintf('SELFTEST_VISUAL_METADATA_OK catalogo=%d fechas=%s\n', ...
            numel(catalogo), strjoin(fechas, ','));
    end

    function fail(etq, ME)
        if ~isempty(ME.stack)
            logmsg('ERROR %s en %s:%d: %s', etq, ME.stack(1).name, ME.stack(1).line, ME.message);
        else
            logmsg('ERROR %s: %s', etq, ME.message);
        end
        uialert(fig, ME.message, ['Error ' etq]);
    end
    function logmsg(fmt, varargin)
        try
            msg = sprintf(fmt, varargin{:});
        catch
            msg = char(fmt);
        end
        parts = regexp(char(msg), '\r\n|\n|\r', 'split'); stamp = char(datetime('now', 'Format', 'HH:mm:ss')); add = {};
        for k = 1:numel(parts), s = strtrim(parts{k}); if ~isempty(s), add{end+1,1} = sprintf('[%s] %s', stamp, s); end, end %#ok<AGROW>
        if isempty(add), return; end
        logbox.Value = [add; logbox.Value(:)]; if numel(logbox.Value) > 600, logbox.Value = logbox.Value(1:600); end
        drawnow limitrate;
    end
end

function tf = ruta_repetida_visual(ruta)
    partes = regexp(strrep(lower(char(ruta)), '\', '/'), '/', 'split');
    tf = any(strcmp(partes, 'repetidos'));
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
