function modulo_interaccion_comsol(varargin)
%MODULO_INTERACCION_COMSOL App unica para generacion y extraccion COMSOL.

    bootstrap_modulo();
    theme = tesis_auxiliares('tema_ui');
    paths = tesis_auxiliares('dataset_paths');
    defaults = detectar_rutas_comsol_default(paths);

    fig = uifigure('Name', 'Interaccion con COMSOL', ...
        'Position', [55 45 1380 820], ...
        'Color', theme.colors.bg);

    gl = uigridlayout(fig, [3, 1]);
    gl.RowHeight = {68, '1x', 170};
    gl.ColumnWidth = {'1x'};
    gl.Padding = [10 10 10 10];
    gl.RowSpacing = 10;
    gl.ColumnSpacing = 10;
    activar_scroll(gl);

    pnl_ribbon = uipanel(gl, 'BorderType', 'none');
    pnl_ribbon.Layout.Row = 1;
    pnl_ribbon.Layout.Column = 1;
    tesis_auxiliares('tema_ui', 'card', pnl_ribbon);
    gr = uigridlayout(pnl_ribbon, [1, 4]);
    gr.RowHeight = {32};
    gr.ColumnWidth = {290, 150, 220, '1x'};
    gr.Padding = [14 8 14 8];
    gr.ColumnSpacing = 8;

    dd_modo = uidropdown(gr, ...
        'Items', {'Generador COMSOL', 'Extractor COMSOL'}, ...
        'ItemsData', {'Generador COMSOL', 'Extractor COMSOL'}, ...
        'Value', 'Generador COMSOL', ...
        'ValueChangedFcn', @(~,~) cambiar_panel());
    dd_modo.Layout.Row = 1;
    dd_modo.Layout.Column = 1;
    tesis_auxiliares('tema_ui', 'dropdown', dd_modo);

    btn_datasets = uibutton(gr, 'Text', 'Abrir datasets', ...
        'ButtonPushedFcn', @(~,~) abrir_carpeta(paths.root));
    btn_datasets.Layout.Row = 1;
    btn_datasets.Layout.Column = 2;
    tesis_auxiliares('tema_ui', 'button', btn_datasets, 'secondary');

    btn_root = uibutton(gr, 'Text', 'Abrir carpeta del proyecto', ...
        'ButtonPushedFcn', @(~,~) abrir_carpeta(tesis_auxiliares('project_root')));
    btn_root.Layout.Row = 1;
    btn_root.Layout.Column = 3;
    tesis_auxiliares('tema_ui', 'button', btn_root, 'secondary');

    lbl_estado = uilabel(gr, 'Text', 'Listo.');
    lbl_estado.Layout.Row = 1;
    lbl_estado.Layout.Column = 4;
    tesis_auxiliares('tema_ui', 'label', lbl_estado, 'status');

    pnl_workspace = uipanel(gl, 'Title', 'Panel de trabajo');
    pnl_workspace.Layout.Row = 2;
    pnl_workspace.Layout.Column = 1;
    tesis_auxiliares('tema_ui', 'panel', pnl_workspace);
    activar_scroll(pnl_workspace);

    gw = uigridlayout(pnl_workspace, [1, 1]);
    gw.Padding = [8 8 8 8];
    activar_scroll(gw);

    pnl_generador = crear_panel_contenido(gw, 'Generador multisolucion COMSOL');
    pnl_extractor = crear_panel_contenido(gw, 'Extractor COMSOL masivo');
    controles_generador = construir_panel_generador(pnl_generador);
    controles_extractor = construir_panel_extractor(pnl_extractor);
    actualizar_estado_filtros_extractor();
    pnl_log = uipanel(gl, 'Title', 'Registro de eventos');
    pnl_log.Layout.Row = 3;
    pnl_log.Layout.Column = 1;
    tesis_auxiliares('tema_ui', 'panel', pnl_log);
    activar_scroll(pnl_log);

    glog = uigridlayout(pnl_log, [1, 1]);
    glog.Padding = [6 6 6 6];
    activar_scroll(glog);
    txt_log = uitextarea(glog, 'Editable', 'off', 'Value', {'Listo.'});
    tesis_auxiliares('tema_ui', 'textarea', txt_log);

    tesis_auxiliares('tema_ui', 'apply', fig);
    tesis_auxiliares('tema_ui', 'textarea', txt_log);
    actualizar_antenas_generador(false);
    cambiar_panel();
    log_evento('Modulo COMSOL iniciado en modo de app unica.');

    function pnl = crear_panel_contenido(parent, titulo)
        pnl = uipanel(parent, 'Title', titulo);
        pnl.Layout.Row = 1;
        pnl.Layout.Column = 1;
        tesis_auxiliares('tema_ui', 'panel', pnl);
    end

    function c = construir_panel_generador(parent)
        g = uigridlayout(parent, [13, 4]);
        g.RowHeight = {22, 28, 28, 28, 22, 28, 28, 28, 28, 22, 96, 30, 32};
        g.ColumnWidth = {145, '1x', 145, '1x'};
        g.Padding = [12 12 12 12];
        g.RowSpacing = 7;
        g.ColumnSpacing = 8;
        activar_scroll(g);

        titulo = uilabel(g, 'Text', 'Entradas del generador');
        titulo.Layout.Row = 1; titulo.Layout.Column = [1 4];
        tesis_auxiliares('tema_ui', 'label', titulo, 'section');

        [c.ed_raiz, btn_raiz] = crear_selector_texto(g, 2, 'Root simulaciones', defaults.root_simulaciones, 'carpeta');
        btn_raiz.ButtonPushedFcn = @(~,~) seleccionar_root_generador();
        [c.ed_antenas, btn_antenas] = crear_selector_texto(g, 3, 'Antenas3D', defaults.antenas3d, 'carpeta');
        btn_antenas.ButtonPushedFcn = @(~,~) seleccionar_antenas3d_generador();
        [c.ed_tejidos, btn_tejidos] = crear_selector_texto(g, 4, 'DatosTejidos.mat', defaults.datos_tejidos, 'archivo');
        btn_tejidos.ButtonPushedFcn = @(~,~) seleccionar_archivo(c.ed_tejidos, '*.mat', 'Selecciona DatosTejidos.mat');

        lbl_rangos = uilabel(g, 'Text', 'Rangos de simulacion');
        lbl_rangos.Layout.Row = 5; lbl_rangos.Layout.Column = [1 4];
        tesis_auxiliares('tema_ui', 'label', lbl_rangos, 'section');

        c.ed_caso_ini = campo_num(g, 6, 1, 'Caso inicio', 0);
        c.ed_caso_fin = campo_num(g, 6, 3, 'Caso fin', 8);
        c.ed_pot_ini = campo_num(g, 7, 1, 'Potencia inicio W', 5);
        c.ed_pot_fin = campo_num(g, 7, 3, 'Potencia fin W', 100);
        c.ed_pot_paso = campo_num(g, 8, 1, 'Paso potencia W', 5);
        c.ed_tiempo = campo_num(g, 8, 3, 'Tiempo total min', 20);

        c.ed_nant_ini = campo_num(g, 9, 1, 'Antenas ini', 1);
        c.ed_nant_fin = campo_num(g, 9, 3, 'Antenas fin', 4);

        lbl_ant = uilabel(g, 'Text', 'Antenas detectadas en Antenas3D');
        lbl_ant.Layout.Row = 10; lbl_ant.Layout.Column = [1 4];
        tesis_auxiliares('tema_ui', 'label', lbl_ant, 'section');

        c.lb_antenas_disp = uilistbox(g, 'Items', {'(selecciona Antenas3D)'}, ...
            'Value', '(selecciona Antenas3D)', 'Multiselect', 'on');
        c.lb_antenas_disp.Layout.Row = 11; c.lb_antenas_disp.Layout.Column = [1 2];
        tesis_auxiliares('tema_ui', 'dropdown', c.lb_antenas_disp);

        c.lb_antenas_sel = uilistbox(g, 'Items', {}, 'Multiselect', 'on');
        c.lb_antenas_sel.Layout.Row = 11; c.lb_antenas_sel.Layout.Column = [3 4];
        tesis_auxiliares('tema_ui', 'dropdown', c.lb_antenas_sel);

        c.btn_add_ant = uibutton(g, 'Text', 'Agregar antena seleccionada ->', ...
            'ButtonPushedFcn', @(~,~) agregar_antenas_generador());
        c.btn_add_ant.Layout.Row = 12; c.btn_add_ant.Layout.Column = [1 2];
        tesis_auxiliares('tema_ui', 'button', c.btn_add_ant, 'secondary');
        c.btn_rm_ant = uibutton(g, 'Text', '<- Remover de seleccionadas', ...
            'ButtonPushedFcn', @(~,~) remover_antenas_generador());
        c.btn_rm_ant.Layout.Row = 12; c.btn_rm_ant.Layout.Column = [3 4];
        tesis_auxiliares('tema_ui', 'button', c.btn_rm_ant, 'secondary');


        c.btn_inspeccionar = uibutton(g, 'Text', 'Inspeccionar simulaciones existentes', ...
            'ButtonPushedFcn', @(~,~) inspeccionar_generador());
        c.btn_inspeccionar.Layout.Row = 13; c.btn_inspeccionar.Layout.Column = [1 2];
        tesis_auxiliares('tema_ui', 'button', c.btn_inspeccionar, 'secondary');

        c.btn_run = uibutton(g, 'Text', 'Ejecutar generador', ...
            'ButtonPushedFcn', @(~,~) ejecutar_generador());
        c.btn_run.Layout.Row = 13; c.btn_run.Layout.Column = [3 4];
        tesis_auxiliares('tema_ui', 'button', c.btn_run, 'success');
    end

    function c = construir_panel_extractor(parent)
        g = uigridlayout(parent, [16, 4]);
        g.RowHeight = {22, 28, 28, 22, 28, 28, 28, 28, 28, 22, 28, 122, 30, 22, 32, '1x'};
        g.ColumnWidth = {145, '1x', 145, '1x'};
        g.Padding = [12 12 12 12];
        g.RowSpacing = 6;
        g.ColumnSpacing = 8;
        activar_scroll(g);

        titulo = uilabel(g, 'Text', 'Entradas del extractor COMSOL');
        titulo.Layout.Row = 1; titulo.Layout.Column = [1 4];
        tesis_auxiliares('tema_ui', 'label', titulo, 'section');

        [c.ed_raiz, btn_raiz] = crear_selector_texto(g, 2, 'Root con .mph', defaults.root_mph, 'carpeta');
        btn_raiz.ButtonPushedFcn = @(~,~) seleccionar_carpeta(c.ed_raiz, 'Selecciona root con modelos .mph');
        [c.ed_salida, btn_salida] = crear_selector_texto(g, 3, 'Salida dataset .mat', paths.dataset_termico_masivo, 'archivo');
        btn_salida.ButtonPushedFcn = @(~,~) seleccionar_salida_mat(c.ed_salida, 'Dataset_Termico_Masivo.mat');

        lbl_filtros = uilabel(g, 'Text', 'Filtros de modelo');
        lbl_filtros.Layout.Row = 4; lbl_filtros.Layout.Column = [1 4];
        tesis_auxiliares('tema_ui', 'label', lbl_filtros, 'section');

        c.chk_ignorar = uicheckbox(g, 'Text', 'Ignorar filtros de modelo', 'Value', false, ...
            'ValueChangedFcn', @(~,~) actualizar_estado_filtros_extractor());
        c.chk_ignorar.Layout.Row = 5; c.chk_ignorar.Layout.Column = [1 2];
        c.dd_tipo = uidropdown(g, 'Items', {'Todos', 'Doble_slot', 'Monopolo', 'Un_slot'}, 'Value', 'Todos');
        c.dd_tipo.Layout.Row = 5; c.dd_tipo.Layout.Column = [3 4];
        tesis_auxiliares('tema_ui', 'dropdown', c.dd_tipo);

        c.ed_nant_ini = campo_num(g, 6, 1, 'N ant ini', 1);
        c.ed_nant_fin = campo_num(g, 6, 3, 'N ant fin', 4);
        c.ed_pot_ini = campo_num(g, 7, 1, 'Pot ini W', 5);
        c.ed_pot_fin = campo_num(g, 7, 3, 'Pot fin W', 100);
        c.ed_caso_ini = campo_num(g, 8, 1, 'Caso ini', 0);
        c.ed_caso_fin = campo_num(g, 8, 3, 'Caso fin', 8);

        c.chk_hueso = uicheckbox(g, 'Text', 'Extraer solo bloque de hueso 0-45 mm', 'Value', true);
        c.chk_hueso.Layout.Row = 9; c.chk_hueso.Layout.Column = [1 2];
        c.ed_grilla = campo_num(g, 9, 3, 'Grilla', 60);

        lbl_sondas = uilabel(g, 'Text', 'Desfase 1 antena y sondas');
        lbl_sondas.Layout.Row = 10; lbl_sondas.Layout.Column = [1 4];
        tesis_auxiliares('tema_ui', 'label', lbl_sondas, 'section');
        c.ed_desfase_x = campo_num(g, 11, 1, 'Desfase X', 1);
        c.ed_desfase_y = campo_num(g, 11, 3, 'Desfase Y', 1);

        c.tbl_sondas = uitable(g, 'Data', [0 0 18.6; 0 0 25.2; 0 0 31.8; 0 0 38.4], ...
            'ColumnName', {'X_mm', 'Y_mm', 'Z_mm'}, ...
            'ColumnEditable', [true true true]);
        c.tbl_sondas.Layout.Row = 12; c.tbl_sondas.Layout.Column = [1 4];

        c.btn_add_sonda = uibutton(g, 'Text', 'Agregar sonda', 'ButtonPushedFcn', @(~,~) agregar_sonda_extractor());
        c.btn_add_sonda.Layout.Row = 13; c.btn_add_sonda.Layout.Column = [1 2];
        tesis_auxiliares('tema_ui', 'button', c.btn_add_sonda, 'secondary');
        c.btn_rm_sonda = uibutton(g, 'Text', 'Remover sonda seleccionada/ultima', 'ButtonPushedFcn', @(~,~) remover_sonda_extractor());
        c.btn_rm_sonda.Layout.Row = 13; c.btn_rm_sonda.Layout.Column = [3 4];
        tesis_auxiliares('tema_ui', 'button', c.btn_rm_sonda, 'secondary');

        lbl_acc = uilabel(g, 'Text', 'Ejecucion COMSOL');
        lbl_acc.Layout.Row = 14; lbl_acc.Layout.Column = [1 4];
        tesis_auxiliares('tema_ui', 'label', lbl_acc, 'section');

        c.btn_inspeccionar = uibutton(g, 'Text', 'Inspeccionar .mph detectados', ...
            'ButtonPushedFcn', @(~,~) inspeccionar_extractor());
        c.btn_inspeccionar.Layout.Row = 15; c.btn_inspeccionar.Layout.Column = [1 2];
        tesis_auxiliares('tema_ui', 'button', c.btn_inspeccionar, 'secondary');

        c.btn_run = uibutton(g, 'Text', 'Extraer dataset masivo', ...
            'ButtonPushedFcn', @(~,~) ejecutar_extractor('dataset'));
        c.btn_run.Layout.Row = 15; c.btn_run.Layout.Column = [3 4];
        tesis_auxiliares('tema_ui', 'button', c.btn_run, 'success');
    end

    function [ed, btn] = crear_selector_texto(g, fila, etiqueta, valor, tipo)
        lbl = uilabel(g, 'Text', etiqueta);
        lbl.Layout.Row = fila; lbl.Layout.Column = 1;
        tesis_auxiliares('tema_ui', 'label', lbl);
        ed = uieditfield(g, 'text', 'Value', char(valor));
        ed.Layout.Row = fila; ed.Layout.Column = [2 3];
        tesis_auxiliares('tema_ui', 'edit', ed);
        if strcmp(tipo, 'carpeta')
            texto = 'Seleccionar...';
        else
            texto = 'Buscar...';
        end
        btn = uibutton(g, 'Text', texto);
        btn.Layout.Row = fila; btn.Layout.Column = 4;
        tesis_auxiliares('tema_ui', 'button', btn, 'secondary');
    end

    function ed = campo_num(g, fila, columna, etiqueta, valor)
        lbl = uilabel(g, 'Text', etiqueta);
        lbl.Layout.Row = fila; lbl.Layout.Column = columna;
        tesis_auxiliares('tema_ui', 'label', lbl);
        ed = uieditfield(g, 'numeric', 'Value', valor);
        ed.Layout.Row = fila; ed.Layout.Column = columna + 1;
        tesis_auxiliares('tema_ui', 'edit', ed);
    end

    function cambiar_panel()
        modo = dd_modo.Value;
        pnl_generador.Visible = visible_si(strcmp(modo, 'Generador COMSOL'));
        pnl_extractor.Visible = visible_si(strcmp(modo, 'Extractor COMSOL'));
        switch modo
            case 'Generador COMSOL'
                lbl_estado.Text = 'Vista generador activa.';
            case 'Extractor COMSOL'
                lbl_estado.Text = 'Vista extractor activa.';
        end
        log_evento('Vista activa: %s', modo);
    end

    function cfg = obtener_config_generador()
        cfg = struct( ...
            'ruta_raiz', controles_generador.ed_raiz.Value, ...
            'ruta_antenas', controles_generador.ed_antenas.Value, ...
            'ruta_datos_tejidos', controles_generador.ed_tejidos.Value, ...
            'caso_inicio', controles_generador.ed_caso_ini.Value, ...
            'caso_fin', controles_generador.ed_caso_fin.Value, ...
            'num_antenas_inicio', controles_generador.ed_nant_ini.Value, ...
            'num_antenas_fin', controles_generador.ed_nant_fin.Value, ...
            'potencia_inicio', controles_generador.ed_pot_ini.Value, ...
            'potencia_fin', controles_generador.ed_pot_fin.Value, ...
            'potencia_paso', controles_generador.ed_pot_paso.Value, ...
            'tiempo_simulacion_min', controles_generador.ed_tiempo.Value, ...
            'paso_tiempo_min', 1, ...
            'tipos_antena', {antenas_seleccionadas_generador()});
    end

    function cfg = obtener_config_extractor()
        puntos = controles_extractor.tbl_sondas.Data;
        if istable(puntos), puntos = table2array(puntos); end
        n_sondas = size(puntos, 1);
        cfg = struct( ...
            'ruta_raiz', controles_extractor.ed_raiz.Value, ...
            'ruta_salida_mat', controles_extractor.ed_salida.Value, ...
            'numero_grilla', controles_extractor.ed_grilla.Value, ...
            'extraer_solo_hueso', controles_extractor.chk_hueso.Value, ...
            'hueso_z_min_mm', 0, ...
            'hueso_z_max_mm', 45, ...
            'hueso_radio_mm', 50, ...
            'puntos_sonda', puntos, ...
            'etiquetas_sonda', {arrayfun(@(k) sprintf('P%d', k), 1:n_sondas, 'UniformOutput', false)}, ...
            'ignorar_filtros_modelo', controles_extractor.chk_ignorar.Value, ...
            'desfase_1antena_habilitado', true, ...
            'desfase_1antena_x_mm', controles_extractor.ed_desfase_x.Value, ...
            'desfase_1antena_y_mm', controles_extractor.ed_desfase_y.Value, ...
            'desfase_1antena_aplicar_a_todo_eje', true, ...
            'logfn', @log_evento);
        if ~controles_extractor.chk_ignorar.Value
            if ~strcmp(controles_extractor.dd_tipo.Value, 'Todos')
                cfg.tipos_antena = {controles_extractor.dd_tipo.Value};
            end
            cfg.num_antenas_inicio = controles_extractor.ed_nant_ini.Value;
            cfg.num_antenas_fin = controles_extractor.ed_nant_fin.Value;
            cfg.potencia_inicio = controles_extractor.ed_pot_ini.Value;
            cfg.potencia_fin = controles_extractor.ed_pot_fin.Value;
            cfg.potencia_paso = 5;
            cfg.caso_inicio = controles_extractor.ed_caso_ini.Value;
            cfg.caso_fin = controles_extractor.ed_caso_fin.Value;
        end
    end

    function activar_scroll(obj)
        if isprop(obj, 'Scrollable')
            try
                obj.Scrollable = 'on';
            catch
                obj.Scrollable = true;
            end
        end
    end

    function actualizar_estado_filtros_extractor()
        if ~isfield(controles_extractor, 'chk_ignorar')
            return;
        end
        if controles_extractor.chk_ignorar.Value
            habilitado = 'off';
        else
            habilitado = 'on';
        end
        controles_extractor.dd_tipo.Enable = habilitado;
        controles_extractor.ed_nant_ini.Enable = habilitado;
        controles_extractor.ed_nant_fin.Enable = habilitado;
        controles_extractor.ed_pot_ini.Enable = habilitado;
        controles_extractor.ed_pot_fin.Enable = habilitado;
        controles_extractor.ed_caso_ini.Enable = habilitado;
        controles_extractor.ed_caso_fin.Enable = habilitado;
        if controles_extractor.chk_ignorar.Value
            log_evento('Filtros de modelo inhabilitados: se procesaran todos los .mph validos detectados.');
        end
    end

    function seleccionar_root_generador()
        seleccionar_carpeta(controles_generador.ed_raiz, 'Selecciona root de simulaciones');
        ruta = controles_generador.ed_raiz.Value;
        ruta_antenas = buscar_carpeta_en_proyecto(ruta, 'Antenas3D');
        if ~isempty(ruta_antenas)
            controles_generador.ed_antenas.Value = ruta_antenas;
            log_evento('Antenas3D detectada dentro del root: %s', ruta_antenas);
        end
        ruta_tejidos = buscar_archivo_en_proyecto(ruta, 'DatosTejidos.mat');
        if ~isempty(ruta_tejidos)
            controles_generador.ed_tejidos.Value = ruta_tejidos;
            log_evento('DatosTejidos.mat detectado dentro del root: %s', ruta_tejidos);
        end
        actualizar_antenas_generador(true);
    end
    function seleccionar_antenas3d_generador()
        seleccionar_carpeta(controles_generador.ed_antenas, 'Selecciona carpeta Antenas3D');
        actualizar_antenas_generador(true);
    end

    function actualizar_antenas_generador(mostrar_log)
        if nargin < 1, mostrar_log = true; end
        try
            disponibles = ejecutar_generador_comsol_integrado('detectar_antenas', controles_generador.ed_antenas.Value);
            seleccion_actual = antenas_seleccionadas_generador(false);
            if isempty(disponibles)
                controles_generador.lb_antenas_disp.Items = {'(sin antenas detectadas)'};
                controles_generador.lb_antenas_disp.Value = '(sin antenas detectadas)';
                controles_generador.lb_antenas_sel.Items = {'(ninguna seleccionada)'};
                controles_generador.lb_antenas_sel.Value = '(ninguna seleccionada)';
                if mostrar_log
                    log_evento('No se detectaron antenas soportadas en: %s', controles_generador.ed_antenas.Value);
                end
                return;
            end
            if isempty(seleccion_actual)
                if any(strcmp(disponibles, 'Monopolo'))
                    seleccion_actual = {'Monopolo'};
                else
                    seleccion_actual = disponibles(1);
                end
            end
            seleccion_actual = seleccion_actual(ismember(seleccion_actual, disponibles));
            aplicar_listas_antenas(disponibles, seleccion_actual);
            if mostrar_log
                log_evento('Antenas detectadas: %s', strjoin(disponibles, ', '));
                log_evento('Antenas seleccionadas: %s', strjoin(antenas_seleccionadas_generador(false), ', '));
            end
        catch ME
            if mostrar_log
                log_evento('ERROR al detectar antenas: %s', ME.message);
            end
        end
    end

    function agregar_antenas_generador()
        disponibles = antenas_desde_listbox(controles_generador.lb_antenas_disp.Value);
        if isempty(disponibles), return; end
        todas = ejecutar_generador_comsol_integrado('detectar_antenas', controles_generador.ed_antenas.Value);
        seleccion = unique([antenas_seleccionadas_generador(false), disponibles], 'stable');
        aplicar_listas_antenas(todas, seleccion);
        log_evento('Antenas seleccionadas: %s', strjoin(antenas_seleccionadas_generador(false), ', '));
    end

    function remover_antenas_generador()
        quitar = antenas_desde_listbox(controles_generador.lb_antenas_sel.Value);
        if isempty(quitar), return; end
        todas = ejecutar_generador_comsol_integrado('detectar_antenas', controles_generador.ed_antenas.Value);
        seleccion = antenas_seleccionadas_generador(false);
        seleccion = seleccion(~ismember(seleccion, quitar));
        aplicar_listas_antenas(todas, seleccion);
        seleccion = antenas_seleccionadas_generador(false);
        if isempty(seleccion)
            log_evento('No hay antenas seleccionadas. Agrega al menos una antes de ejecutar.');
        else
            log_evento('Antenas seleccionadas: %s', strjoin(seleccion, ', '));
        end
    end

    function aplicar_listas_antenas(todas, seleccion)
        seleccion = seleccion(ismember(seleccion, todas));
        disponibles = todas(~ismember(todas, seleccion));
        if isempty(disponibles)
            controles_generador.lb_antenas_disp.Items = {'(todas seleccionadas)'};
            controles_generador.lb_antenas_disp.Value = '(todas seleccionadas)';
        else
            controles_generador.lb_antenas_disp.Items = disponibles;
            controles_generador.lb_antenas_disp.Value = disponibles{1};
        end
        if isempty(seleccion)
            controles_generador.lb_antenas_sel.Items = {'(ninguna seleccionada)'};
            controles_generador.lb_antenas_sel.Value = '(ninguna seleccionada)';
        else
            controles_generador.lb_antenas_sel.Items = seleccion;
            controles_generador.lb_antenas_sel.Value = seleccion{1};
        end
    end

    function antenas = antenas_seleccionadas_generador(lanzar_error)
        if nargin < 1, lanzar_error = true; end
        antenas = antenas_desde_listbox(controles_generador.lb_antenas_sel.Items);
        if isempty(antenas) && lanzar_error
            error('Selecciona al menos una antena detectada en Antenas3D.');
        end
    end

    function antenas = antenas_desde_listbox(valor)
        antenas = normalizar_lista_ui(valor);
        if isempty(antenas), return; end
        es_placeholder = cellfun(@(s) startsWith(char(s), '('), antenas);
        antenas = antenas(~es_placeholder);
    end

    function agregar_sonda_extractor()
        datos = controles_extractor.tbl_sondas.Data;
        if istable(datos), datos = table2array(datos); end
        datos = double(datos);
        if isempty(datos)
            nueva = [0 0 18.6];
        else
            nueva = [0 0 datos(end, 3) + 6.6];
        end
        controles_extractor.tbl_sondas.Data = [datos; nueva];
        log_evento('Sonda agregada: [%.4g %.4g %.4g] mm', nueva(1), nueva(2), nueva(3));
    end

    function remover_sonda_extractor()
        datos = controles_extractor.tbl_sondas.Data;
        if istable(datos), datos = table2array(datos); end
        datos = double(datos);
        if isempty(datos), return; end
        filas = [];
        try
            if isprop(controles_extractor.tbl_sondas, 'Selection') && ~isempty(controles_extractor.tbl_sondas.Selection)
                filas = unique(controles_extractor.tbl_sondas.Selection(:, 1));
            end
        catch
            filas = [];
        end
        if isempty(filas)
            filas = size(datos, 1);
        end
        filas = filas(filas >= 1 & filas <= size(datos, 1));
        datos(filas, :) = [];
        controles_extractor.tbl_sondas.Data = datos;
        log_evento('Sondas removidas: %s', mat2str(filas(:)'));
    end
    function ejecutar_generador()
        try
            cfg = obtener_config_generador();
            validar_ruta_generador(cfg);
            insertar_separacion_log();
            log_evento('Ejecutando generador con tipos: %s', strjoin(cfg.tipos_antena, ', '));
            lbl_estado.Text = 'Generador en ejecucion...';
            drawnow limitrate;
            ejecutar_generador_comsol_integrado('run', cfg);
            lbl_estado.Text = 'Generador finalizado.';
            log_evento('Generador finalizado.');
        catch ME
            lbl_estado.Text = 'Error en generador.';
            log_evento('ERROR generador: %s', ME.message);
            uialert(fig, ME.message, 'Error generador');
        end
    end

    function ejecutar_extractor(modo)
        try
            if nargin < 1 || ~strcmp(modo, 'dataset')
                modo = 'dataset';
            end
            cfg = obtener_config_extractor();
            insertar_separacion_log();
            log_evento('Ejecutando extractor COMSOL. Modo: %s', modo);
            lbl_estado.Text = 'Extractor en ejecucion...';
            drawnow limitrate;
            extractor_comsol_masivo('run', cfg);
            lbl_estado.Text = 'Extractor finalizado.';
            log_evento('Dataset masivo COMSOL actualizado: %s', obtener_ruta_dataset_salida(cfg));
        catch ME
            lbl_estado.Text = 'Error en extractor.';
            log_evento('ERROR extractor: %s', ME.message);
            uialert(fig, ME.message, 'Error extractor');
        end
    end

    function ruta_dataset = obtener_ruta_dataset_salida(cfg)
        ruta_dataset = cfg.ruta_salida_mat;
        if isempty(ruta_dataset)
            ruta_dataset = paths.dataset_termico_masivo;
        end
    end

    function inspeccionar_generador()
        try
            insertar_separacion_log();
            lineas = ejecutar_generador_comsol_integrado('inspeccionar', controles_generador.ed_raiz.Value);
            for i = 1:numel(lineas), log_evento('%s', lineas{i}); end
        catch ME
            log_evento('ERROR inspeccion generador: %s', ME.message);
        end
    end

    function inspeccionar_extractor()
        try
            ruta = controles_extractor.ed_raiz.Value;
            insertar_separacion_log();
            if ~isfolder(ruta)
                log_evento('Root del extractor no existe: %s', ruta);
                return;
            end
            mph = dir(fullfile(ruta, '**', '*.mph'));
            log_evento('Modelos .mph detectados: %d', numel(mph));
            for i = 1:min(12, numel(mph))
                log_evento('  %s', fullfile(mph(i).folder, mph(i).name));
            end
            if numel(mph) > 12
                log_evento('  ... %d modelos adicionales.', numel(mph) - 12);
            end
        catch ME
            log_evento('ERROR inspeccion extractor: %s', ME.message);
        end
    end

    function validar_ruta_generador(cfg)
        if isempty(cfg.ruta_raiz) || ~isfolder(cfg.ruta_raiz)
            error('Selecciona una carpeta root valida para el generador.');
        end
        if isempty(cfg.ruta_datos_tejidos) || ~isfile(cfg.ruta_datos_tejidos)
            error('Selecciona DatosTejidos.mat valido.');
        end
    end

    function seleccionar_carpeta(ed, titulo)
        ruta = uigetdir(ed.Value, titulo);
        if isequal(ruta, 0), return; end
        ed.Value = ruta;
        log_evento('Carpeta seleccionada: %s', ruta);
    end

    function seleccionar_archivo(ed, filtro, titulo)
        [archivo, carpeta] = uigetfile(filtro, titulo, fileparts(ed.Value));
        if isequal(archivo, 0), return; end
        ed.Value = fullfile(carpeta, archivo);
        log_evento('Archivo seleccionado: %s', ed.Value);
    end

    function seleccionar_salida_mat(ed, nombre_default)
        [archivo, carpeta] = uiputfile('*.mat', 'Selecciona salida MAT', fullfile(paths.datasets_masivos, nombre_default));
        if isequal(archivo, 0), return; end
        ed.Value = fullfile(carpeta, archivo);
        log_evento('Salida MAT seleccionada: %s', ed.Value);
    end

    function abrir_carpeta(ruta)
        if isfolder(ruta) && ispc
            winopen(ruta);
        else
            log_evento('Ruta: %s', ruta);
        end
    end

    function lista = normalizar_lista_ui(valor)
        if isempty(valor)
            lista = {};
        elseif ischar(valor)
            lista = {valor};
        elseif isstring(valor)
            lista = cellstr(valor(:));
        else
            lista = valor(:)';
        end
    end

    function valor = visible_si(condicion)
        if condicion
            valor = 'on';
        else
            valor = 'off';
        end
    end

    function insertar_separacion_log()
        txt_log.Value = [repmat({''}, 5, 1); txt_log.Value(:)];
        drawnow limitrate;
    end

    function log_evento(formato, varargin)
        try
            msg = sprintf(formato, varargin{:});
        catch
            msg = char(formato);
        end
        partes = regexp(char(msg), '\r\n|\n|\r', 'split');
        nuevas = cell(0, 1);
        marca = char(datetime('now', 'Format', 'HH:mm:ss'));
        for k = 1:numel(partes)
            linea = strtrim(partes{k});
            if isempty(linea), continue; end
            nuevas{end+1, 1} = sprintf('[%s] %s', marca, linea); %#ok<AGROW>
        end
        if isempty(nuevas), return; end
        txt_log.Value = [nuevas; txt_log.Value(:)];
        if numel(txt_log.Value) > 600
            txt_log.Value = txt_log.Value(1:600);
        end
        drawnow limitrate;
    end
end
function defaults = detectar_rutas_comsol_default(paths)
    root = tesis_auxiliares('project_root');
    defaults = struct();
    defaults.root_simulaciones = root;
    defaults.root_mph = root;
    defaults.antenas3d = fullfile(root, 'Antenas3D');
    defaults.datos_tejidos = fullfile(root, 'DatosTejidos.mat');

    ruta_antenas = buscar_carpeta_en_proyecto(root, 'Antenas3D');
    if ~isempty(ruta_antenas)
        defaults.antenas3d = ruta_antenas;
        defaults.root_simulaciones = fileparts(ruta_antenas);
        defaults.root_mph = fileparts(ruta_antenas);
    end

    ruta_tejidos = buscar_archivo_en_proyecto(root, 'DatosTejidos.mat');
    if ~isempty(ruta_tejidos)
        defaults.datos_tejidos = ruta_tejidos;
        defaults.root_simulaciones = fileparts(ruta_tejidos);
        if isempty(ruta_antenas)
            defaults.root_mph = fileparts(ruta_tejidos);
        end
    end

    if isfield(paths, 'datasets_masivos') && isfolder(paths.datasets_masivos)
        defaults.datasets_masivos = paths.datasets_masivos;
    end
end

function ruta = buscar_carpeta_en_proyecto(root, nombre)
    ruta = '';
    directa = fullfile(root, nombre);
    if isfolder(directa)
        ruta = directa;
        return;
    end
    try
        d = dir(fullfile(root, '**', nombre));
        d = d([d.isdir]);
        d = d(~startsWith({d.folder}, fullfile(root, '.git')));
        if ~isempty(d)
            ruta = fullfile(d(1).folder, d(1).name);
        end
    catch
        ruta = '';
    end
end

function ruta = buscar_archivo_en_proyecto(root, nombre)
    ruta = '';
    directa = fullfile(root, nombre);
    if isfile(directa)
        ruta = directa;
        return;
    end
    try
        d = dir(fullfile(root, '**', nombre));
        d = d(~[d.isdir]);
        d = d(~startsWith({d.folder}, fullfile(root, '.git')));
        if ~isempty(d)
            ruta = fullfile(d(1).folder, d(1).name);
        end
    catch
        ruta = '';
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

function varargout = ejecutar_generador_comsol_integrado(varargin)
    if nargin >= 1 && ischar(varargin{1}) && strcmpi(varargin{1}, 'inspeccionar')
        if nargin >= 2, ruta = varargin{2}; else, ruta = pwd; end
        varargout{1} = inspeccionar_simulaciones_generador(ruta);
        return;
    end
    if nargin >= 1 && ischar(varargin{1}) && strcmpi(varargin{1}, 'detectar_antenas')
        if nargin >= 2, ruta = varargin{2}; else, ruta = ''; end
        varargout{1} = detectar_antenas_disponibles(ruta);
        return;
    end
    generador_sin_metales_multi_solucion_sin_tumor(varargin{:});
    if nargout > 0, varargout{1} = []; end

% ---- Inicio copia local: generador_sin_metales_multi_solucion_sin_tumor.m ----
function generador_sin_metales_multi_solucion_sin_tumor(varargin)
% =========================================================================
%  GENERADOR SIN METALES MULTISOLUCIÓN SIN TUMOR
% =========================================================================
%
%  FUNCIONALIDAD
%  Genera modelos COMSOL por tipo de antena, número de antenas, caso
%  termodependiente y potencia. Mantiene un índice de soluciones para evitar
%  recomputar combinaciones ya finalizadas y registra fallos o carbonización.
%
%  ESTÁNDAR DE LIMPIEZA
%  - Archivo convertido de script a función ejecutable.
%  - Funciones auxiliares en snake_case/español cuando no afectan COMSOL.
%  - Se conserva la lógica original de construcción, simulación e índice.
% =========================================================================

% =========================================================
%  Generador_SinMetales_MultiSolucion_SinTumor.m
%  Genera los 12 modelos (3 tipos x 4 arreglos) SIN TUMOR
%  con multiples soluciones (9 casos x N potencias) en un
%  unico .mph por combinacion.
%
%  Salida por modelo:
%    <ruta_raiz>\Dataset_SinMetales_SinTumor\<Tipo>\<nombre_modelo>\
%      <nombre_modelo>.mph
%      Indice_Soluciones.mat
%      Coordenadas_Antenas.txt
% =========================================================

if nargin == 0
    error('Use modulo_interaccion_comsol para abrir la UI integrada o pase ''run'', config.');
end

clc
config_ui = struct();
if nargin >= 2 && strcmpi(varargin{1}, 'run')
    config_ui = varargin{2};
end
import com.comsol.model.*
import com.comsol.model.util.*

%% ── RUTAS BASE ────────────────────────────────────────────────────────────
ruta_raiz    = 'D:\UPIITA\TT\TT2\Simulaciones';
ruta_antenas = fullfile(ruta_raiz, 'Antenas3D');
ruta_raiz = obtener_campo_config(config_ui, 'ruta_raiz', ruta_raiz);
ruta_antenas = obtener_campo_config(config_ui, 'ruta_antenas', ruta_antenas);
%%

ruta_salida = fullfile(ruta_raiz, 'Dataset_SinMetales_SinTumor2');
if ~exist(ruta_salida, 'dir'), mkdir(ruta_salida); end

tipos_validos = {'a',          'b',        'c'      };
nombres_tipos = {'Doble_slot', 'Monopolo', 'Un_slot'};

mat_path = obtener_campo_config(config_ui, 'ruta_datos_tejidos', fullfile(ruta_raiz, 'DatosTejidos.mat'));
config_gen = normalizar_config_generador(config_ui, nombres_tipos);
idx_tipos_a_simular = config_gen.idx_tipos;
casos_a_simular = config_gen.casos;
numeros_antenas = config_gen.numeros_antenas;
potencias_configuradas = config_gen.potencias;
tiempo_simulacion_min = config_gen.tiempo_simulacion_min;
paso_tiempo_min = config_gen.paso_tiempo_min;
potencia_total_max_1a3 = 100;
potencia_total_max_4ant = 120;
umbrales_carbonizacion_por_caso = [500, repmat(120, 1, 8)];

load(mat_path, 'DatasetTejidos');
dataset_tejidos = DatasetTejidos;
clear DatasetTejidos;
uni = containers.Map( ...
    {'Conductividad electrica','Conductividad termica','Metabolismo','Perfusion'}, ...
    {'S/m','W/(m*K)','W/m^3','1/s'});

fprintf('\n======================================================\n');
fprintf('  GENERADOR SIN METALES SIN TUMOR — ORDEN POR CASO\n');
fprintf('======================================================\n\n');

%% ── BUCLE PRINCIPAL ───────────────────────────────────────────────────────
for idx_caso = casos_a_simular

    fprintf('\n######################################################\n');
    fprintf('  CASO %d / 8\n', idx_caso);
    fprintf('######################################################\n');
    temperatura_carbonizacion = umbral_carbonizacion_generador( ...
        umbrales_carbonizacion_por_caso, idx_caso);

    for idx_tipo = idx_tipos_a_simular
        tipo_antena = tipos_validos{idx_tipo};
        nombre_tipo = nombres_tipos{idx_tipo};

        carpeta_tipo = fullfile(ruta_salida, nombre_tipo);
        if ~exist(carpeta_tipo, 'dir'), mkdir(carpeta_tipo); end

        for num_antenas = numeros_antenas

            nombre_modelo  = sprintf('modelo_%s_%dant', nombre_tipo, num_antenas);
            carpeta_modelo = fullfile(carpeta_tipo, nombre_modelo);
            if ~exist(carpeta_modelo, 'dir'), mkdir(carpeta_modelo); end

            ruta_mph    = fullfile(carpeta_modelo, [nombre_modelo, '.mph']);
            ruta_indice = fullfile(carpeta_modelo, 'Indice_Soluciones.mat');

            potencia_total_max = potencia_total_maxima_generador( ...
                num_antenas, potencia_total_max_1a3, ...
                potencia_total_max_4ant);
            mascara_potencia = potencias_configuradas * num_antenas <= ...
                potencia_total_max;
            potencias = potencias_configuradas(mascara_potencia);
            potencias_omitidas = potencias_configuradas(~mascara_potencia);

            fprintf('\n>> Caso:%d | Tipo:%s | Antenas:%d\n', ...
                idx_caso, nombre_tipo, num_antenas);
            if ~isempty(potencias_omitidas)
                fprintf(['   [FILTRO POTENCIA] Omitidas para %d antenas ' ...
                    '(limite %.1f W total): %s W/antena\n'], ...
                    num_antenas, potencia_total_max, ...
                    strjoin(string(potencias_omitidas), ', '));
            end
            if isempty(potencias)
                fprintf('   [SKIP] No hay potencias validas para este arreglo.\n');
                continue;
            end
 
            % ── Pre-verificacion rapida por .mat ──────────────────
            [ya_completo, pend] = verificar_modelo_mat( ...
                ruta_indice, potencias, idx_caso);
            if ya_completo
                fprintf('   [SKIP] Modelo completo segun indice. No se abre .mph\n');
                continue
            end
            fprintf('   Pendientes: %d simulaciones\n', length(pend));
            % ── Fin pre-verificacion ──────────────────────────────
 
            if exist(ruta_mph, 'file') && exist(ruta_indice, 'file')
                fprintf('   Cargando modelo existente...\n');
                try
                    model = mphload(ruta_mph);
                    indice = load(ruta_indice);
                    tabla_indice = indice.tags_completos;
                    fprintf('   Cargado. Soluciones previas: %d\n', length(tabla_indice));
                catch ME_load
                    fprintf('   Error al cargar (%s). Reconstruyendo.\n', ME_load.message);
                    model        = [];
                    tabla_indice = init_tabla();
                end
            elseif exist(ruta_mph, 'file') && ~exist(ruta_indice, 'file')
                fprintf('   .mph sin indice. Cargando modelo y creando indice vacio.\n');
                try
                    model = mphload(ruta_mph);
                    tabla_indice = init_tabla();
                catch
                    model        = [];
                    tabla_indice = init_tabla();
                end
            else
                model        = [];
                tabla_indice = init_tabla();
            end
            %% ── VERIFICAR CARBONIZACION PREVIA ───────────────────────────
            tag_sol_p1 = sprintf('sol_c%d_p%d', idx_caso, potencias(1));
            info_p1    = buscar(tabla_indice, tag_sol_p1);
            if ~isempty(info_p1) && strcmp(info_p1.estado, 'CARBON_SOSTENIDA_MIN1')
                fprintf('   [SKIP CASO] Carbonizacion sostenida ya detectada en pasada anterior.\n');
                ModelUtil.remove(model.tag());
                continue
            end

            %% ── CONSTRUCCION DEL MODELO BASE ──────────────────────────────
            if isempty(model)
                fprintf('   Construyendo modelo base (sin tumor)...\n');
                guardar_coordenadas(carpeta_modelo, num_antenas, ...
                    calcular_posiciones(num_antenas));
                try
                    model = construir_modelo_base(tipo_antena, num_antenas, ...
                        carpeta_modelo, dataset_tejidos, uni, ruta_antenas);
                catch ME_build
                    fprintf('   [ERROR CRITICO] Construccion fallida: %s\n', ME_build.message);
                    fprintf('   Abriendo COMSOL para depuracion manual...\n');
                    try
                        mphlaunch(model);
                        fprintf('\n*** Realiza las correcciones en COMSOL. ***\n');
                        fprintf('*** Cierra COMSOL y presiona ENTER para continuar. ***\n');
                        input('>>> ENTER para continuar... ', 's');
                    catch
                        fprintf('   [WARN] No se pudo abrir COMSOL (modelo invalido).\n');
                    end
                    continue
                end
            end

            %% ── VERIFICAR CARBONIZACION PREVIA ───────────────────────────
            tag_sol_p1 = sprintf('sol_c%d_p%d', idx_caso, potencias(1));
            info_p1    = buscar(tabla_indice, tag_sol_p1);
            if ~isempty(info_p1) && strcmp(info_p1.estado, 'CARBON_SOSTENIDA_MIN1')
                fprintf('   [SKIP CASO] Carbonizacion sostenida ya detectada en pasada anterior.\n');
                ModelUtil.remove(model.tag());
                continue
            end

            %% ── BUCLE DE POTENCIAS ────────────────────────────────────────
            carbonizacion_temprana = false;

            for p = 1:length(potencias)
            % for p = 1:1

                potencia_actual = potencias(p);
                potencia_total  = potencia_actual * num_antenas;

                tag_std  = sprintf('std_c%d_p%d',  idx_caso, potencia_actual);
                tag_sol  = sprintf('sol_c%d_p%d',  idx_caso, potencia_actual);
                tag_dset = sprintf('dset_c%d_p%d', idx_caso, potencia_actual);

                if carbonizacion_temprana
                    fprintf('    [SKIP] %s — carbonizacion previa.\n', tag_sol);
                    tabla_indice = registrar(tabla_indice, tag_std, tag_sol, tag_dset, ...
                        idx_caso, potencia_actual, potencia_total, 'SALTADO_CARBON', 0);
                    tags_completos = tabla_indice;       
                    save(ruta_indice, 'tags_completos'); 
                    continue
                end

                if solucion_existe(model, tabla_indice, tag_sol)
                    fprintf('    [OK]   %s — ya computada.\n', tag_sol);
                    info_cp = buscar(tabla_indice, tag_sol);
                    if ~isempty(info_cp) && strcmp(info_cp.estado, 'CARBON_SOSTENIDA_MIN1')
                        carbonizacion_temprana = true;
                    end
                    continue
                end

                limpiar(model, tag_std, tag_sol, tag_dset);

                fprintf('    [RUN]  %s | caso%d | P=%dW ... ', ...
                    tag_sol, idx_caso, potencia_actual);
                t0 = tic;

                model.param.set('idx_caso', num2str(idx_caso));
                model.param.set('P_in',     sprintf('%d[W]', potencia_actual));
                model.param.set('t',        sprintf('%.12g[min]', tiempo_simulacion_min));

                crear_study(model, tag_std, tag_sol, tiempo_simulacion_min, paso_tiempo_min);

                try
                    model.sol(tag_sol).runAll();
                    t_sim = toc(t0);
                    fprintf('OK (%.1f min)\n', t_sim / 60);
                catch ME_run
                    t_sim = toc(t0);
                    fprintf('FALLO (%.1f min): %s\n', t_sim/60, ME_run.message);
                    limpiar(model, tag_std, tag_sol, tag_dset);
                    tabla_indice = registrar(tabla_indice, tag_std, tag_sol, tag_dset, ...
                        idx_caso, potencia_actual, potencia_total, 'FALLO', t_sim/60);
                    tags_completos = tabla_indice;
                    save(ruta_indice, 'tags_completos');
                    mphsave(model, ruta_mph);
                    continue
                end

                model.result.dataset.create(tag_dset, 'Solution');
                model.result.dataset(tag_dset).set('solution', tag_sol);
                model.result.dataset(tag_dset).label( ...
                    sprintf('caso%d | P=%dW | Ptot=%dW', idx_caso, potencia_actual, potencia_total));

                if detectar_carbonizacion(model, tag_dset, temperatura_carbonizacion)
                    fprintf(['    [!] Carbonizacion sostenida desde t=1min. ' ...
                        'Saltando resto del caso.\n']);
                    carbonizacion_temprana = true;
                    tabla_indice = registrar(tabla_indice, tag_std, tag_sol, tag_dset, ...
                        idx_caso, potencia_actual, potencia_total, ...
                        'CARBON_SOSTENIDA_MIN1', t_sim/60);
                    tags_completos = tabla_indice;
                    save(ruta_indice, 'tags_completos');
                    mphsave(model, ruta_mph);
                    limpiar(model, tag_std, tag_sol, tag_dset);
                    continue
                end

                tabla_indice = registrar(tabla_indice, tag_std, tag_sol, tag_dset, ...
                    idx_caso, potencia_actual, potencia_total, 'OK', t_sim/60);

                tags_completos = tabla_indice;
                save(ruta_indice, 'tags_completos');
                mphsave(model, ruta_mph);

            end % fin potencias

            fprintf('   Guardado final y cierre: %s\n', ruta_mph);
            tags_completos = tabla_indice;
            save(ruta_indice, 'tags_completos');
            mphsave(model, ruta_mph);
            ModelUtil.remove(model.tag());
            fprintf('   Modelo cerrado.\n');

        end % fin num_antenas
    end % fin tipo
end % fin caso

fprintf('\n======================================================\n');
fprintf('  GENERACION COMPLETADA.\n');
fprintf('======================================================\n');


%% ============================================================
%  construir_modelo_base  —  SIN TUMOR
%% ============================================================

end

function model = construir_modelo_base(tipo_antena, num_antenas, carpeta_modelo, ...
        dataset_tejidos, uni, ruta_antenas)

import com.comsol.model.*
import com.comsol.model.util.*

%% ── CONFIGURACION POR ANTENA ──────────────────────────────────────────────
switch tipo_antena
    case 'a'
        cfg.nombre  = 'Doble_slot';
        cfg.archivo = fullfile(ruta_antenas, 'Antena_doble_slot_12cm_3D.mphbin');
        cfg.rot_deg = 90;
        cfg.displ_z = 19;
        cfg.cat_r   = 2.79 / 2;
        switch num_antenas
            case 1
                cfg.dom_diel  = {7};
                cfg.dom_cat   = {4};
                cfg.dom_cat_b = [21 22 23 24 69 70 109 114];
                cfg.dom_aire  = {[5 6]};
                cfg.port_bnd  = {[57 58 87 94]};
            case 2
                cfg.dom_diel  = {[7 11]};
                cfg.dom_cat   = {[4 8]};
                cfg.dom_cat_b = [21 22 23 24 66 67 106 111 131 132 133 134 176 177 216 221];
                cfg.dom_aire  = {[5 6 9 10]};
                cfg.port_bnd  = {[57 58 84 91], [167 168 194 201]};
            case 3
                cfg.dom_diel  = {[7 11 15]};
                cfg.dom_cat   = {[4 8 12]};
                cfg.dom_cat_b = [21 22 23 24 66 67 106 111 125 126 127 128 173 174 213 218 235 236 237 238 280 281 320 325];
                cfg.dom_aire  = {[5 6 9 10 13 14]};
                cfg.port_bnd  = {[57 58 84 91], [161 162 191 198], [271 272 298 305]};
            case 4
                cfg.dom_diel  = {[10 11 18 19]};
                cfg.dom_cat   = {[4 5 12 13]};
                cfg.dom_cat_b = [21 22 23 24 35 36 37 38 116 117 156 161 167 168 207 212 235 236 237 238 249 250 251 252 330 331 370 375 381 382 421 426];
                cfg.dom_aire  = {[6 7 8 9 14 15 16 17]};
                cfg.port_bnd  = {[105 106 185 192], [91 92 134 141], ...
                                 [305 306 348 355], [319 320 399 406]};
        end

    case 'b'
        cfg.nombre  = 'Monopolo';
        cfg.archivo = fullfile(ruta_antenas, 'Antena_monopolo_1.4219cm_3D.mphbin');
        cfg.rot_deg = 90;
        cfg.displ_z = 19.2;
        cfg.cat_r   = 2.8 / 2;
        switch num_antenas
            case 1
                cfg.dom_diel  = {5};
                cfg.dom_cat   = {4};
                cfg.dom_cat_b = [22 23 24 25 52 53 74 79];
                cfg.port_bnd  = {[40 41 61 68]};
            case 2
                cfg.dom_diel  = {[5 7]};
                cfg.dom_cat   = {[4 6]};
                cfg.dom_cat_b = [22 23 24 25 49 50 71 76 95 96 97 98 122 123 144 149];
                cfg.port_bnd  = {[40 41 58 65], [113 114 131 138]};
            case 3
                cfg.dom_diel  = {[5 7 9]};
                cfg.dom_cat   = {[4 6 8]};
                cfg.dom_cat_b = [22 23 24 25 49 50 71 76 89 90 91 92 119 120 141 146 162 163 164 165 189 190 211 216];
                cfg.port_bnd  = {[40 41 58 65], [180 181 198 205], [107 108 128 135]};
            case 4
                cfg.dom_diel  = {[6 7 10 11]};
                cfg.dom_cat   = {[4 5 8 9]};
                cfg.dom_cat_b = [22 23 24 25 37 38 39 40 82 83 104 109 115 116 137 142 162 163 164 165 177 178 179 180 222 223 244 249 255 256 277 282];
                cfg.port_bnd  = {[207 208 231 238], [67 68 91 98], ...
                                 [71 72 124 131], [211 212 264 271]};
        end

    case 'c'
        cfg.nombre  = 'Un_slot';
        cfg.archivo = fullfile(ruta_antenas, 'Antena_un_slot_12cm_3D.mphbin');
        cfg.rot_deg = 90;
        cfg.displ_z = 19.2;
        cfg.cat_r   = 2.79 / 2;
        switch num_antenas
            case 1
                cfg.dom_diel  = {6};
                cfg.dom_cat   = {4};
                cfg.dom_cat_b = [24 25 26 27 61 62 89 95];
                cfg.dom_aire  = {5};
                cfg.port_bnd  = {[48 49 73 80]};
            case 2
                cfg.dom_diel  = {[6 9]};
                cfg.dom_cat   = {[4 7]};
                cfg.dom_cat_b = [24 25 26 27 58 59 86 92 114 115 116 117 148 149 176 182];
                cfg.dom_aire  = {[5 8]};
                cfg.port_bnd  = {[48 49 70 77], [138 139 160 167]};
            case 3
                cfg.dom_diel  = {[6 9 12]};
                cfg.dom_cat   = {[4 7 10]};
                cfg.dom_cat_b = [24 25 26 27 58 59 86 92 108 109 110 111 145 146 173 179 198 199 200 201 232 233 260 266];
                cfg.dom_aire  = {[5 8 11]};
                cfg.port_bnd  = {[132 133 157 164], [48 49 70 77], [222 223 244 251]};
            case 4
                cfg.dom_diel  = {[8 9 14 15]};
                cfg.dom_cat   = {[4 5 10 11]};
                cfg.dom_cat_b = [24 25 26 27 41 42 43 44 99 100 127 133 140 141 168 174 198 199 200 201 215 216 217 218 273 274 301 307 314 315 342 348];
                cfg.dom_aire  = {[6 7 12 13]};
                cfg.port_bnd  = {[87 88 152 159], [77 78 111 118], ...
                                 [261 262 326 333], [251 252 285 292]};
        end
end

%% ── VECTORES GLOBALES ─────────────────────────────────────────────────────
dom_diel_total = [cfg.dom_diel{:}];
dom_cat_total  = [cfg.dom_cat{:}];
if tipo_antena ~= 'b'
    dom_aire_total = [cfg.dom_aire{:}];
    dom_ant_total  = unique([dom_diel_total, dom_cat_total, dom_aire_total]);
else
    dom_ant_total  = unique([dom_diel_total, dom_cat_total]);
end

label_ant = cfg.nombre;
model_tag = sprintf('M_%s_%d', tipo_antena, num_antenas);

posiciones = calcular_posiciones(num_antenas);

%% ── INICIALIZAR MODELO ────────────────────────────────────────────────────
model = ModelUtil.create(model_tag);
model.modelPath(carpeta_modelo);
model.component.create('comp1', true);
model.component('comp1').geom.create('geom1', 3);
model.component('comp1').mesh.create('mesh1');
model.component('comp1').physics.create('emw', 'ElectromagneticWaves', 'geom1');
model.component('comp1').physics.create('ht',  'BioHeat',              'geom1');

%% ── PARAMETROS ────────────────────────────────────────────────────────────
model.param.set('t',             '20[min]');
model.param.set('T',             '37[degC]');
model.param.set('P_in',          '10[W]');
model.param.set('f',             '2.45[GHz]');
model.param.set('rho_sangre',    '1050[kg/m^3]');
model.param.set('Cp_sangre',     '3639[J/(kg*K)]');
model.param.set('T_sangre',      '37[degC]');
model.param.set('omega_hueso',   '0.000526[1/s]');
model.param.set('sigma_hueso',   '0.805[S/m]');
model.param.set('k_hueso',       '0.31[W/(m*K)]');
model.param.set('m_hueso',       '368.3[W/m^3]');
model.param.set('eps_hueso',     '18.5');
model.param.set('omega_musculo', '6.47E-4[1/s]');
model.param.set('sigma_musculo', '1.74[S/m]');
model.param.set('k_musculo',     '0.49[W/(m*K)]');
model.param.set('m_musculo',     '716[W/m^3]');
model.param.set('eps_musculo',   '52.7');
model.param.set('omega_grasa',   '5.77E-4[1/s]');
model.param.set('sigma_grasa',   '0.268[S/m]');
model.param.set('k_grasa',       '0.21[W/(m*K)]');
model.param.set('m_grasa_1',     '3.9[W/m^3]');
model.param.set('eps_grasa',     '10.8');
model.param.set('omega_piel',    '0.00185[1/s]');
model.param.set('sigma_piel',    '1.46[S/m]');
model.param.set('k_piel',        '0.37[W/(m*K)]');
model.param.set('m_piel',        '0[W/m^3]');
model.param.set('eps_piel',      '38');
model.param.set('eps_cat',       '2.6');
model.param.set('eps_diel',      '2.03');
model.param.set('idx_caso',      '0', 'Indice de Escenario (0=Cte, 1-8=Dinamicos)');

%% ── FUNCIONES DE INTERPOLACION ───────────────────────────────────────────
for i = 1:length(dataset_tejidos)
    FuncN = dataset_tejidos(i).nombre;
    FuncN = regexprep(FuncN, '[+]', 'mas');
    FuncN = regexprep(FuncN, '[-]', 'menos');
    FuncN = regexprep(FuncN, '[.]', '');
    if isstrprop(FuncN(1),'digit'), FuncN = sprintf('f_%s', FuncN); end
    Nint  = sprintf('int%d', i);
    data  = dataset_tejidos(i).datos;
    if size(data,2)==3, cData = data(:,[1,3]); else, cData = data; end
    cDataStr = arrayfun(@num2str, cData, 'UniformOutput', false);
    model.component('comp1').func.create(Nint, 'Interpolation');
    model.component('comp1').func(Nint).label(FuncN);
    model.component('comp1').func(Nint).set('source',   'table');
    model.component('comp1').func(Nint).set('table',    cDataStr);
    model.component('comp1').func(Nint).set('funcname', FuncN);
    Prop = dataset_tejidos(i).propiedad;
    unit = '1'; if isKey(uni, Prop), unit = uni(Prop); end
    model.component('comp1').func(Nint).setIndex('argunit','K',   0);
    model.component('comp1').func(Nint).setIndex('fununit', unit, 0);
    model.component('comp1').func(Nint).set('interp','piecewisecubic');
    model.component('comp1').func(Nint).set('extrap','const');
end

%% ── VARIABLES DE TEJIDOS ──────────────────────────────────────────────────
VT = 'Vars_Tejidos';
model.component('comp1').variable.create(VT);
model.component('comp1').variable(VT).label('Propiedades de Tejidos');

tejidos_n = {'hueso','musc','grasa','piel'};
tejidos_p = {'hueso','musculo','grasa','piel'};
for i = 1:4
    tej = tejidos_n{i}; tejp = tejidos_p{i};
    sig_e = cell(1,9); k_e = cell(1,9);
    sig_e{1} = sprintf('sigma_%s', tejp);
    k_e{1}   = sprintf('k_%s',     tejp);
    for c = 1:8
        tipo_str = 'exp'; if c>4, tipo_str = 'lineal'; end
        switch mod(c-1,4)+1
            case 1, vs='15_2'; ks='mas15';
            case 2, vs='15_4'; ks='menos15';
            case 3, vs='2_2';  ks='mas15';
            case 4, vs='2_4';  ks='menos15';
        end
        sig_e{c+1} = sprintf('sigma_%s_%s_%s(T)', tej, tipo_str, vs);
        k_e{c+1}   = sprintf('k_%s_lineal_%s(T)',  tej, ks);
    end
    ss = sig_e{9}; sk = k_e{9};
    for c = 7:-1:0
        ss = sprintf('if(idx_caso==%d,%s,%s)', c, sig_e{c+1}, ss);
        sk = sprintf('if(idx_caso==%d,%s,%s)', c, k_e{c+1},   sk);
    end
    model.component('comp1').variable(VT).set(sprintf('sigma_%s_act',tej), ss);
    model.component('comp1').variable(VT).set(sprintf('k_%s_act',tej),     sk);
end

model.component('comp1').variable(VT).set('Meta_hueso_act', 'if(idx_caso==0,m_hueso,   if(idx_caso<=4,Meta_hueso_exp(T),Meta_hueso_lineal(T)))');
model.component('comp1').variable(VT).set('Meta_musc_act',  'if(idx_caso==0,m_musculo, if(idx_caso<=4,Meta_musc_exp(T),Meta_musc_lineal(T)))');
model.component('comp1').variable(VT).set('Meta_grasa_act', 'if(idx_caso==0,m_grasa_1, if(idx_caso<=4,Meta_grasa_exp(T),Meta_grasa_lineal(T)))');
model.component('comp1').variable(VT).set('Meta_piel_act',  'if(idx_caso==0,m_piel,    if(idx_caso<=4,Meta_piel_exp(T),Meta_piel_lineal(T)))');

str_w = 'if(idx_caso==0,omega_%s,if(idx_caso==1||idx_caso==5,w_%s_1(T),if(idx_caso==2||idx_caso==6,w_%s_2(T),if(idx_caso==3||idx_caso==7,w_%s_3(T),w_%s_4(T)))))';
model.component('comp1').variable(VT).set('omega_hueso_act','omega_hueso');
model.component('comp1').variable(VT).set('omega_musc_act', sprintf(str_w,'musculo','musc','musc','musc','musc'));
model.component('comp1').variable(VT).set('omega_grasa_act',sprintf(str_w,'grasa','grasa','grasa','grasa','grasa'));
model.component('comp1').variable(VT).set('omega_piel_act', sprintf(str_w,'piel','piel','piel','piel','piel'));

%% ── GEOMETRIA (SIN TUMOR) ─────────────────────────────────────────────────
model.component('comp1').geom('geom1').lengthUnit('mm');

model.component('comp1').geom('geom1').create('cyl1','Cylinder');
model.component('comp1').geom('geom1').feature('cyl1').label('Hueso');
model.component('comp1').geom('geom1').feature('cyl1').set('r',   50);
model.component('comp1').geom('geom1').feature('cyl1').set('h',   45);
model.component('comp1').geom('geom1').feature('cyl1').set('pos', [0 0 0]);

model.component('comp1').geom('geom1').create('cyl2','Cylinder');
model.component('comp1').geom('geom1').feature('cyl2').label('Musculo');
model.component('comp1').geom('geom1').feature('cyl2').set('r',   50);
model.component('comp1').geom('geom1').feature('cyl2').set('h',   30);
model.component('comp1').geom('geom1').feature('cyl2').set('pos', [0 0 45]);

model.component('comp1').geom('geom1').create('cyl3','Cylinder');
model.component('comp1').geom('geom1').feature('cyl3').label('Grasa');
model.component('comp1').geom('geom1').feature('cyl3').set('r',   50);
model.component('comp1').geom('geom1').feature('cyl3').set('h',   18);
model.component('comp1').geom('geom1').feature('cyl3').set('pos', [0 0 75]);

% Catéteres
cat_h   = 130;
cat_z   = 8.6 + 10;
ids_cat = cell(1, num_antenas);
for k = 1:num_antenas
    cid      = sprintf('cat%d', k);
    ids_cat{k} = cid;
    dx = posiciones(k,1);
    dy = posiciones(k,2);
    model.component('comp1').geom('geom1').create(cid,'Cylinder');
    model.component('comp1').geom('geom1').feature(cid).label(sprintf('Cateter %d', k));
    model.component('comp1').geom('geom1').feature(cid).set('r',   cfg.cat_r);
    model.component('comp1').geom('geom1').feature(cid).set('h',   cat_h);
    model.component('comp1').geom('geom1').feature(cid).set('pos', [dx dy cat_z]);
end

% Antenas
for k = 1:num_antenas
    sfx = num2str(k);
    dx  = posiciones(k,1);
    dy  = posiciones(k,2);

    imp_id = ['imp', sfx];
    model.component('comp1').geom('geom1').create(imp_id,'Import');
    model.component('comp1').geom('geom1').feature(imp_id).label([label_ant,' ',sfx]);
    model.component('comp1').geom('geom1').feature(imp_id).set('filename',       cfg.archivo);
    model.component('comp1').geom('geom1').feature(imp_id).set('includevirtual', false);
    model.component('comp1').geom('geom1').feature(imp_id).importData;
    prev = imp_id;

    sca_id = ['sca', sfx];
    model.component('comp1').geom('geom1').create(sca_id,'Scale');
    model.component('comp1').geom('geom1').feature(sca_id).selection('input').set({prev});
    model.component('comp1').geom('geom1').feature(sca_id).set('isotropic', 1000);
    prev = sca_id;

    rot_id = ['rot', sfx];
    model.component('comp1').geom('geom1').create(rot_id,'Rotate');
    model.component('comp1').geom('geom1').feature(rot_id).selection('input').set({prev});
    model.component('comp1').geom('geom1').feature(rot_id).set('axistype','x');
    model.component('comp1').geom('geom1').feature(rot_id).set('rot', cfg.rot_deg);
    prev = rot_id;

    mov_id = ['mov', sfx];
    model.component('comp1').geom('geom1').create(mov_id,'Move');
    model.component('comp1').geom('geom1').feature(mov_id).selection('input').set({prev});
    model.component('comp1').geom('geom1').feature(mov_id).set('displx', dx);
    model.component('comp1').geom('geom1').feature(mov_id).set('disply', dy);
    model.component('comp1').geom('geom1').feature(mov_id).set('displz', cfg.displ_z);
end

% Booleana: tejidos menos catéteres (SIN esfera de tumor)
model.component('comp1').geom('geom1').create('dif1','Difference');
model.component('comp1').geom('geom1').feature('dif1').selection('input').set({'cyl1','cyl2','cyl3'});
model.component('comp1').geom('geom1').feature('dif1').selection('input2').set(ids_cat);

model.component('comp1').geom('geom1').run;

%% ── MATERIALES (SIN TUMOR) ────────────────────────────────────────────────
model.component('comp1').material.create('mat1','Common');
model.component('comp1').material('mat1').label('Hueso Inteligente');
model.component('comp1').material('mat1').propertyGroup('def').set('density',             '1908[kg/m^3]');
model.component('comp1').material('mat1').propertyGroup('def').set('heatcapacity',        '1313[J/(kg*K)]');
model.component('comp1').material('mat1').propertyGroup('def').set('relpermittivity',     'eps_hueso');
model.component('comp1').material('mat1').propertyGroup('def').set('relpermeability',     '1');
model.component('comp1').material('mat1').propertyGroup('def').set('electricconductivity','sigma_hueso_act');
model.component('comp1').material('mat1').propertyGroup('def').set('thermalconductivity', 'k_hueso_act');
model.component('comp1').material('mat1').selection.set(1);

model.component('comp1').material.create('mat2','Common');
model.component('comp1').material('mat2').label('Musculo Inteligente');
model.component('comp1').material('mat2').propertyGroup('def').set('density',             '1090[kg/m^3]');
model.component('comp1').material('mat2').propertyGroup('def').set('heatcapacity',        '3421[J/(kg*K)]');
model.component('comp1').material('mat2').propertyGroup('def').set('relpermittivity',     'eps_musculo');
model.component('comp1').material('mat2').propertyGroup('def').set('relpermeability',     '1');
model.component('comp1').material('mat2').propertyGroup('def').set('electricconductivity','sigma_musc_act');
model.component('comp1').material('mat2').propertyGroup('def').set('thermalconductivity', 'k_musc_act');
model.component('comp1').material('mat2').selection.set(2);

model.component('comp1').material.create('mat3','Common');
model.component('comp1').material('mat3').label('Grasa Inteligente');
model.component('comp1').material('mat3').propertyGroup('def').set('density',             '911[kg/m^3]');
model.component('comp1').material('mat3').propertyGroup('def').set('heatcapacity',        '2348[J/(kg*K)]');
model.component('comp1').material('mat3').propertyGroup('def').set('relpermittivity',     'eps_grasa');
model.component('comp1').material('mat3').propertyGroup('def').set('relpermeability',     '1');
model.component('comp1').material('mat3').propertyGroup('def').set('electricconductivity','sigma_grasa_act');
model.component('comp1').material('mat3').propertyGroup('def').set('thermalconductivity', 'k_grasa_act');
model.component('comp1').material('mat3').propertyGroup('def').set('frequencyfactor',     '4.43e16');
model.component('comp1').material('mat3').propertyGroup('def').set('activationenergy',    '1.3e5');
model.component('comp1').material('mat3').selection.set(3);

model.component('comp1').material.create('mat4','Common');
model.component('comp1').material('mat4').label('Dielectrico PTFE');
model.component('comp1').material('mat4').propertyGroup('def').set('heatcapacity',        '1050[J/(kg*K)]');
model.component('comp1').material('mat4').propertyGroup('def').set('density',             '2200[kg/m^3]');
model.component('comp1').material('mat4').propertyGroup('def').set('thermalconductivity', {'0.24[W/(m*K)]' '0' '0' '0' '0.24[W/(m*K)]' '0' '0' '0' '0.24[W/(m*K)]'});
model.component('comp1').material('mat4').propertyGroup('def').set('relpermittivity',     '2.1');
model.component('comp1').material('mat4').propertyGroup('def').set('electricconductivity','0');
model.component('comp1').material('mat4').propertyGroup('def').set('relpermeability',     '1');
model.component('comp1').material('mat4').selection.set(dom_diel_total);

model.component('comp1').material.create('mat5','Common');
model.component('comp1').material('mat5').label('Catheter');
model.component('comp1').material('mat5').propertyGroup('def').set('electricconductivity','0');
model.component('comp1').material('mat5').propertyGroup('def').set('relpermeability',     '1');
model.component('comp1').material('mat5').propertyGroup('def').set('relpermittivity',     'eps_cat');
model.component('comp1').material('mat5').selection.set(dom_cat_total);

if tipo_antena ~= 'b'
    model.component('comp1').material.create('mat6','Common');
    model.component('comp1').material('mat6').label('Aire');
    model.component('comp1').material('mat6').set('family','air');
    model.component('comp1').material('mat6').propertyGroup('def').set('relpermeability',     {'1' '0' '0' '0' '1' '0' '0' '0' '1'});
    model.component('comp1').material('mat6').propertyGroup('def').set('relpermittivity',     {'1' '0' '0' '0' '1' '0' '0' '0' '1'});
    model.component('comp1').material('mat6').propertyGroup('def').set('electricconductivity',{'0[S/m]' '0' '0' '0' '0[S/m]' '0' '0' '0' '0[S/m]'});
    model.component('comp1').material('mat6').selection.set(dom_aire_total);
end
% mat7 (Tumor) eliminado completamente

%% ── SELECCIONES ───────────────────────────────────────────────────────────
model.component('comp1').selection.create('dom_tejidos_ext','Explicit');
model.component('comp1').selection('dom_tejidos_ext').geom('geom1',3);
model.component('comp1').selection('dom_tejidos_ext').set([1 2 3]);

model.component('comp1').selection.create('bnd_scattering','Adjacent');
model.component('comp1').selection('bnd_scattering').set('input',     {'dom_tejidos_ext'});
model.component('comp1').selection('bnd_scattering').set('outputdim', 2);
model.component('comp1').selection('bnd_scattering').set('exterior',  true);

bnd_data             = mphgetselection(model.component('comp1').selection('bnd_scattering'));
bnd_tejidos_ids      = bnd_data.entities;
todos_los_boundaries = unique([bnd_tejidos_ids, cfg.dom_cat_b]);

%% ── FISICA EMW ────────────────────────────────────────────────────────────
model.component('comp1').physics('emw').create('sctr1','Scattering',2);
model.component('comp1').physics('emw').feature('sctr1').selection.set(todos_los_boundaries);

for k = 1:num_antenas
    pid = sprintf('port%d', k);
    model.component('comp1').physics('emw').create(pid,'Port',2);
    model.component('comp1').physics('emw').feature(pid).selection.set(cfg.port_bnd{k});
    model.component('comp1').physics('emw').feature(pid).set('PortType',      'Coaxial');
    model.component('comp1').physics('emw').feature(pid).set('Pin',           'P_in');
    model.component('comp1').physics('emw').feature(pid).set('PortExcitation','on');
end

%% ── FISICA BIOHEAT (SIN TUMOR) ────────────────────────────────────────────
model.component('comp1').physics('ht').selection.set([1 2 3]);

bioheat_cfg = { ...
    'bh1', 1, 'omega_hueso_act', 'Meta_hueso_act'; ...
    'bh2', 2, 'omega_musc_act',  'Meta_musc_act';  ...
    'bh3', 3, 'omega_grasa_act', 'Meta_grasa_act'  };
labels_ht = {'Hueso', 'Musculo', 'Grasa'};

bt = model.component('comp1').physics('ht').feature('bt1');
for i = 1:size(bioheat_cfg,1)
    id  = bioheat_cfg{i,1};
    dom = bioheat_cfg{i,2};
    om  = bioheat_cfg{i,3};
    qm  = bioheat_cfg{i,4};
    if i > 1
        bt.create(id,'Bioheat',3);
        bt.feature(id).selection.set(dom);
    end
    bt.feature(id).label(labels_ht{i});
    bt.feature(id).set('Tb',     'T_sangre');
    bt.feature(id).set('Cp_b',   'Cp_sangre');
    bt.feature(id).set('rhobl',  'rho_sangre');
    bt.feature(id).set('omegab', om);
    bt.feature(id).set('Qmet',   qm);
end
model.component('comp1').physics('ht').feature('init1').set('Tinit','T_sangre');
model.component('comp1').multiphysics.create('emh1','ElectromagneticHeating',3);

%% ── MALLA (SIN TUMOR) ─────────────────────────────────────────────────────
model.component('comp1').mesh('mesh1').create('ftet1','FreeTet');
model.component('comp1').mesh('mesh1').feature('ftet1').selection.geom('geom1',3);
model.component('comp1').mesh('mesh1').feature('ftet1').selection.set([1 2 3]);  % sin dom_tumor
model.component('comp1').mesh('mesh1').feature('ftet1').create('size1','Size');
model.component('comp1').mesh('mesh1').feature('ftet1').feature('size1').set('custom',       true);
model.component('comp1').mesh('mesh1').feature('ftet1').feature('size1').set('hmaxactive',   true);
model.component('comp1').mesh('mesh1').feature('ftet1').feature('size1').set('hmax',         '0.005[m]');
model.component('comp1').mesh('mesh1').feature('ftet1').feature('size1').set('hminactive',   true);
model.component('comp1').mesh('mesh1').feature('ftet1').feature('size1').set('hmin',         '3E-4[m]');
model.component('comp1').mesh('mesh1').feature('ftet1').feature('size1').set('hgradactive',  true);
model.component('comp1').mesh('mesh1').feature('ftet1').feature('size1').set('hgrad',        1.4);
model.component('comp1').mesh('mesh1').feature('ftet1').feature('size1').set('hcurveactive', true);
model.component('comp1').mesh('mesh1').feature('ftet1').feature('size1').set('hcurve',       0.4);
model.component('comp1').mesh('mesh1').feature('ftet1').feature('size1').set('hnarrowactive',true);
model.component('comp1').mesh('mesh1').feature('ftet1').feature('size1').set('hnarrow',      0.7);

model.component('comp1').mesh('mesh1').create('ftet2','FreeTet');
model.component('comp1').mesh('mesh1').feature.move('ftet2',2);
model.component('comp1').mesh('mesh1').feature('ftet2').selection.geom('geom1',3);
model.component('comp1').mesh('mesh1').feature('ftet2').selection.set(dom_ant_total);
model.component('comp1').mesh('mesh1').feature('ftet2').create('size1','Size');
model.component('comp1').mesh('mesh1').feature('ftet2').feature('size1').set('custom',       true);
model.component('comp1').mesh('mesh1').feature('ftet2').feature('size1').set('hmaxactive',   true);
model.component('comp1').mesh('mesh1').feature('ftet2').feature('size1').set('hmax',         '0.00456[m]');
model.component('comp1').mesh('mesh1').feature('ftet2').feature('size1').set('hminactive',   true);
model.component('comp1').mesh('mesh1').feature('ftet2').feature('size1').set('hmin',         '1.2E-4[m]');
model.component('comp1').mesh('mesh1').feature('ftet2').feature('size1').set('hgradactive',  true);
model.component('comp1').mesh('mesh1').feature('ftet2').feature('size1').set('hgrad',        1.35);
model.component('comp1').mesh('mesh1').feature('ftet2').feature('size1').set('hcurveactive', true);
model.component('comp1').mesh('mesh1').feature('ftet2').feature('size1').set('hcurve',       0.3);
model.component('comp1').mesh('mesh1').feature('ftet2').feature('size1').set('hnarrowactive',true);
model.component('comp1').mesh('mesh1').feature('ftet2').feature('size1').set('hnarrow',      0.85);

model.component('comp1').mesh('mesh1').run();

fprintf('   Modelo base (sin tumor) construido.\n');
end


%% ============================================================
%  crear_study  —  identica al original
%% ============================================================
function crear_study(model, tag_std, tag_sol, tiempo_simulacion_min, paso_tiempo_min)
if nargin < 4 || isempty(tiempo_simulacion_min), tiempo_simulacion_min = 20; end
if nargin < 5 || isempty(paso_tiempo_min), paso_tiempo_min = 1; end
tlist_expr = sprintf('range(0,%.12g,%.12g)', paso_tiempo_min, tiempo_simulacion_min);

model.study.create(tag_std);
model.study(tag_std).label(sprintf('Study %s', tag_std));
model.study(tag_std).create('freq','Frequency');
model.study(tag_std).feature('freq').set('plist','f');
model.study(tag_std).create('time','Transient');
model.study(tag_std).feature('time').set('tunit','min');
model.study(tag_std).feature('time').set('tlist', tlist_expr);

model.sol.create(tag_sol);
model.sol(tag_sol).study(tag_std);

model.sol(tag_sol).create('st1','StudyStep');
model.sol(tag_sol).feature('st1').set('study',     tag_std);
model.sol(tag_sol).feature('st1').set('studystep', 'freq');

model.sol(tag_sol).create('v1','Variables');
model.sol(tag_sol).feature('v1').set('control','freq');

model.sol(tag_sol).create('s1','Stationary');
model.sol(tag_sol).feature('s1').set('stol',    0.01);
model.sol(tag_sol).feature('s1').set('control', 'freq');
model.sol(tag_sol).feature('s1').feature('aDef').set('complexfun',   true);
model.sol(tag_sol).feature('s1').feature('aDef').set('cachepattern', false);
model.sol(tag_sol).feature('s1').create('p1','Parametric');
model.sol(tag_sol).feature('s1').feature.remove('pDef');
model.sol(tag_sol).feature('s1').feature('p1').set('pname',    {'freq'});
model.sol(tag_sol).feature('s1').feature('p1').set('plistarr', {'f'});
model.sol(tag_sol).feature('s1').feature('p1').set('punit',    {'GHz'});
model.sol(tag_sol).feature('s1').feature('p1').set('control',  'freq');
model.sol(tag_sol).feature('s1').create('i1','Iterative');
model.sol(tag_sol).feature('s1').feature('i1').set('linsolver',  'gmres');
model.sol(tag_sol).feature('s1').feature('i1').set('prefuntype', 'right');
model.sol(tag_sol).feature('s1').feature('i1').set('itrestart',  '300');
model.sol(tag_sol).feature('s1').feature('i1').create('mg1','Multigrid');
model.sol(tag_sol).feature('s1').feature('i1').feature('mg1').set('iter',1);
model.sol(tag_sol).feature('s1').feature('i1').feature('mg1').feature('pr').create('sv1','SORVector');
model.sol(tag_sol).feature('s1').feature('i1').feature('mg1').feature('pr').feature('sv1').set('prefun',    'sorvec');
model.sol(tag_sol).feature('s1').feature('i1').feature('mg1').feature('pr').feature('sv1').set('iter',      2);
model.sol(tag_sol).feature('s1').feature('i1').feature('mg1').feature('pr').feature('sv1').set('relax',     1);
model.sol(tag_sol).feature('s1').feature('i1').feature('mg1').feature('pr').feature('sv1').set('sorvecdof', {'comp1_E'});
model.sol(tag_sol).feature('s1').feature('i1').feature('mg1').feature('po').create('sv1','SORVector');
model.sol(tag_sol).feature('s1').feature('i1').feature('mg1').feature('po').feature('sv1').set('prefun',    'soruvec');
model.sol(tag_sol).feature('s1').feature('i1').feature('mg1').feature('po').feature('sv1').set('iter',      2);
model.sol(tag_sol).feature('s1').feature('i1').feature('mg1').feature('po').feature('sv1').set('relax',     1);
model.sol(tag_sol).feature('s1').feature('i1').feature('mg1').feature('po').feature('sv1').set('sorvecdof', {'comp1_E'});
model.sol(tag_sol).feature('s1').feature('i1').feature('mg1').feature('cs').create('d1','Direct');
model.sol(tag_sol).feature('s1').feature('i1').feature('mg1').feature('cs').feature('d1').set('linsolver','pardiso');
model.sol(tag_sol).feature('s1').create('fc1','FullyCoupled');
model.sol(tag_sol).feature('s1').feature('fc1').set('linsolver','i1');
model.sol(tag_sol).feature('s1').feature.remove('fcDef');

model.sol(tag_sol).create('su1','StoreSolution');
model.sol(tag_sol).feature('su1').label('Solution Store 1');

model.sol(tag_sol).create('st2','StudyStep');
model.sol(tag_sol).feature('st2').set('study',     tag_std);
model.sol(tag_sol).feature('st2').set('studystep', 'time');

model.sol(tag_sol).create('v2','Variables');
model.sol(tag_sol).feature('v2').set('initmethod',   'sol');
model.sol(tag_sol).feature('v2').set('initsol',      tag_sol);
model.sol(tag_sol).feature('v2').set('initsoluse',   'su1');
model.sol(tag_sol).feature('v2').set('notsolmethod', 'sol');
model.sol(tag_sol).feature('v2').set('notsol',       tag_sol);
model.sol(tag_sol).feature('v2').set('notsoluse',    'su1');
model.sol(tag_sol).feature('v2').set('control',      'time');

model.sol(tag_sol).create('t1','Time');
model.sol(tag_sol).feature('t1').set('tlist',                tlist_expr);
model.sol(tag_sol).feature('t1').set('plot',                 false);
model.sol(tag_sol).feature('t1').set('plotfreq',             'tout');
model.sol(tag_sol).feature('t1').set('atolglobalvaluemethod','factor');
model.sol(tag_sol).feature('t1').set('atolmethod',  {'comp1_E' 'global' 'comp1_T' 'global'});
model.sol(tag_sol).feature('t1').set('atol',        {'comp1_E' '1e-3'   'comp1_T' '1e-3'});
model.sol(tag_sol).feature('t1').set('atolvaluemethod',{'comp1_E' 'factor' 'comp1_T' 'factor'});
model.sol(tag_sol).feature('t1').set('reacf',                true);
model.sol(tag_sol).feature('t1').set('storeudot',            true);
model.sol(tag_sol).feature('t1').set('endtimeinterpolation', true);
model.sol(tag_sol).feature('t1').set('estrat',               'exclude');
model.sol(tag_sol).feature('t1').set('maxorder',             2);
model.sol(tag_sol).feature('t1').set('control',              'time');
model.sol(tag_sol).feature('t1').create('fc1','FullyCoupled');
model.sol(tag_sol).feature('t1').feature('fc1').set('jtech',     'once');
model.sol(tag_sol).feature('t1').feature('fc1').set('damp',      0.9);
model.sol(tag_sol).feature('t1').feature('fc1').set('stabacc',   'aacc');
model.sol(tag_sol).feature('t1').feature('fc1').set('aaccdim',   5);
model.sol(tag_sol).feature('t1').feature('fc1').set('aaccmix',   0.9);
model.sol(tag_sol).feature('t1').feature('fc1').set('aaccdelay', 1);
model.sol(tag_sol).feature('t1').create('i1','Iterative');
model.sol(tag_sol).feature('t1').feature('i1').set('linsolver',  'gmres');
model.sol(tag_sol).feature('t1').feature('i1').set('prefuntype', 'left');
model.sol(tag_sol).feature('t1').feature('i1').set('itrestart',  50);
model.sol(tag_sol).feature('t1').feature('i1').set('rhob',       20);
model.sol(tag_sol).feature('t1').feature('i1').set('maxlinit',   10000);
model.sol(tag_sol).feature('t1').feature('i1').set('nlinnormuse','on');
model.sol(tag_sol).feature('t1').feature('i1').label('AMG, heat transfer variables (ht)');
model.sol(tag_sol).feature('t1').feature('i1').create('mg1','Multigrid');
mg = model.sol(tag_sol).feature('t1').feature('i1').feature('mg1');
mg.set('prefun','saamg');  mg.set('mgcycle','v');  mg.set('maxcoarsedof',50000);
mg.set('strconn',0.01);    mg.set('nullspace','constant');
mg.set('usesmooth',false);  mg.set('saamgcompwise',true);
mg.set('loweramg',true);    mg.set('compactaggregation',false);
mg.feature('pr').create('so1','SOR');
mg.feature('pr').feature('so1').set('iter',2);  mg.feature('pr').feature('so1').set('relax',0.9);
mg.feature('po').create('so1','SOR');
mg.feature('po').feature('so1').set('iter',2);  mg.feature('po').feature('so1').set('relax',0.9);
mg.feature('cs').create('d1','Direct');
mg.feature('cs').feature('d1').set('linsolver',   'pardiso');
mg.feature('cs').feature('d1').set('pivotperturb', 1e-13);
model.sol(tag_sol).feature('t1').create('d1','Direct');
model.sol(tag_sol).feature('t1').feature('d1').set('linsolver',   'pardiso');
model.sol(tag_sol).feature('t1').feature('d1').set('pivotperturb', 1e-13);
model.sol(tag_sol).feature('t1').feature('d1').label('Direct, heat transfer variables (ht)');
model.sol(tag_sol).feature('t1').feature('fc1').set('linsolver','i1');
model.sol(tag_sol).feature('t1').feature.remove('fcDef');

model.sol(tag_sol).attach(tag_std);
end


%% ============================================================
%  FUNCIONES AUXILIARES  —  identicas al original
%% ============================================================

function tabla = init_tabla()
    tabla = struct('tag_std',{},'tag_sol',{},'tag_dset',{}, ...
        'idx_caso',{},'P_ant',{},'P_tot',{},'estado',{},'t_sim_min',{});
end

function posiciones = calcular_posiciones(num_antenas)
    d = 20;
    switch num_antenas
        case 1,  posiciones = [0, 0];
        case 2,  posiciones = [-d/2, 0; d/2, 0];
        case 3,  R = d/sqrt(3); posiciones = [0,R; d/2,-R/2; -d/2,-R/2];
        case 4,  posiciones = [-d/2,-d/2; d/2,-d/2; -d/2,d/2; d/2,d/2];
    end
end

function existe = solucion_existe(model, tabla, tag_sol)
    existe = false;
    info = buscar(tabla, tag_sol);
    if isempty(info) || ismember(info.estado, {'FALLO','SALTADO_CARBON'})
        return;
    end
    try
        tags = cell(model.sol.tags());
        if any(strcmp(tags, tag_sol))
            sinfo = mphsolinfo(model, 'soltag', tag_sol);
            existe = ~isempty(sinfo.solvals);
        end
    catch
        existe = false;
    end
end

function limpiar(model, tag_std, tag_sol, tag_dset)
    try model.result.dataset.remove(tag_dset); catch, end
    try model.sol(tag_sol).clearSolution();    catch, end
    try model.sol(tag_sol).detach();           catch, end
    try model.sol.remove(tag_sol);             catch, end
    try model.study.remove(tag_std);           catch, end
end

function carbon = detectar_carbonizacion(model, tag_dset, T_CRITICA)
    if nargin < 3, T_CRITICA = 500; end
    carbon = false;
    try
        sol_tag = char(model.result.dataset(tag_dset).getString('solution'));
        info = mphsolinfo(model, 'soltag', sol_tag);
        t_vals = double(info.solvals(:));
        if isempty(t_vals)
            fprintf('    [WARN] solucion sin tiempos para revisar carbonizacion.\n');
            return;
        end

        t_min = t_vals / 60;
        [dt_min, idx_t1] = min(abs(t_min - 1));
        if dt_min > 0.51
            fprintf(['    [WARN] t=1min no encontrado ' ...
                '(mas cercano: %.2f min)\n'], t_min(idx_t1));
            return;
        end

        idx_eval = find(t_min >= t_min(idx_t1) - 1e-9);
        tmax = nan(numel(idx_eval), 1);
        for i = 1:numel(idx_eval)
            datos = mpheval(model, 'T', 'dataset', tag_dset, ...
                'solnum', idx_eval(i), 'unit', 'degC');
            valores = double(datos.d1(:));
            valores = valores(isfinite(valores));
            if ~isempty(valores)
                tmax(i) = max(valores);
            end
        end

        excede = isfinite(tmax) & tmax > T_CRITICA;
        carbon = ~isempty(excede) && all(excede);
        if carbon
            fprintf(['    [INFO] Carbonizacion sostenida desde %.2f min: ' ...
                'Tmax inicial %.1f degC | Tmax global %.1f degC\n'], ...
                t_min(idx_t1), tmax(1), max(tmax));
        elseif ~isempty(excede) && excede(1)
            fprintf(['    [INFO] Tmax en t=%.2f min supera %.1f degC ' ...
                '(%.1f degC), pero no es sostenida. No se detienen ' ...
                'potencias posteriores.\n'], ...
                t_min(idx_t1), T_CRITICA, tmax(1));
        end
    catch ME
        fprintf('    [WARN] detectar_carbonizacion: %s\n', ME.message);
        carbon = false;
    end
end

function tabla = registrar(tabla, tag_std, tag_sol, tag_dset, ...
        idx_caso, P_ant, P_tot, estado, t_sim_min)
    for k = 1:length(tabla)
        if strcmp(tabla(k).tag_sol, tag_sol)
            tabla(k).estado    = estado;
            tabla(k).t_sim_min = t_sim_min;
            return;
        end
    end
    n = length(tabla) + 1;
    tabla(n).tag_std    = tag_std;
    tabla(n).tag_sol    = tag_sol;
    tabla(n).tag_dset   = tag_dset;
    tabla(n).idx_caso   = idx_caso;
    tabla(n).P_ant      = P_ant;
    tabla(n).P_tot      = P_tot;
    tabla(n).estado     = estado;
    tabla(n).t_sim_min  = t_sim_min;
end

function info = buscar(tabla, tag_sol)
    info = [];
    for k = 1:length(tabla)
        if strcmp(tabla(k).tag_sol, tag_sol)
            info = tabla(k);
            return;
        end
    end
end

function guardar_coordenadas(ruta_carpeta, num_antenas, posiciones)
    ruta_txt = fullfile(ruta_carpeta, 'Coordenadas_Antenas.txt');
    if exist(ruta_txt, 'file'), return; end
    fid = fopen(ruta_txt, 'w');
    fprintf(fid, 'Sistema de Coordenadas (%d antenas)\n', num_antenas);
    fprintf(fid, 'Antena\tX (mm)\tY (mm)\tZ (mm)\n');
    for k = 1:num_antenas
        fprintf(fid, '%d\t\t%.2f\t\t%.2f\t\t25.00\n', k, posiciones(k,1), posiciones(k,2));
    end
    fclose(fid);
end


function [completo, pendientes] = verificar_modelo_mat(ruta_indice, potencias, casos)

estados_finales = {'OK','CARBON_MIN1','CARBON_SOSTENIDA_MIN1', ...
    'SALTADO_CARBON','FALLO'};
pendientes = struct('idx_caso',{},'potencia_actual',{});

if ~exist(ruta_indice, 'file')
    completo = false;
    return
end

try
    indice = load(ruta_indice);
    tabla  = indice.tags_completos;
catch
    completo = false;
    return
end

for ic = 1:length(casos)
    idx_caso = casos(ic);

    tag_p1   = sprintf('sol_c%d_p%d', idx_caso, potencias(1));
    info_p1  = buscar(tabla, tag_p1);
    if ~isempty(info_p1) && strcmp(info_p1.estado, 'CARBON_SOSTENIDA_MIN1')
        continue 
    end

    for ip = 1:length(potencias)
        potencia_actual = potencias(ip);
        tag_sol  = sprintf('sol_c%d_p%d', idx_caso, potencia_actual);
        info     = buscar(tabla, tag_sol);

        if isempty(info) || ~ismember(info.estado, estados_finales)
            n = length(pendientes) + 1;
            pendientes(n).idx_caso = idx_caso;
            pendientes(n).potencia_actual = potencia_actual;
        end
    end
end

completo = isempty(pendientes);
end

function config = normalizar_config_generador(config_ui, nombres_tipos)
    if nargin < 2 || isempty(nombres_tipos)
        nombres_tipos = {'Doble_slot', 'Monopolo', 'Un_slot'};
    end

    casos = crear_rango_entero( ...
        obtener_campo_config(config_ui, 'caso_inicio', 0), ...
        obtener_campo_config(config_ui, 'caso_fin', 0), 1, 0, 8, 'casos termodependientes');

    numeros_antenas = crear_rango_entero( ...
        obtener_campo_config(config_ui, 'num_antenas_inicio', 1), ...
        obtener_campo_config(config_ui, 'num_antenas_fin', 4), 1, 1, 4, 'numero de antenas');

    potencia_inicio = obtener_campo_config(config_ui, 'potencia_inicio', 30);
    potencia_fin = obtener_campo_config(config_ui, 'potencia_fin', potencia_inicio);
    potencia_paso = obtener_campo_config(config_ui, 'potencia_paso', 5);
    potencias = crear_rango_entero(potencia_inicio, potencia_fin, potencia_paso, ...
        0, Inf, 'potencias');

    tiempo_simulacion_min = obtener_campo_config(config_ui, 'tiempo_simulacion_min', 20);
    paso_tiempo_min = obtener_campo_config(config_ui, 'paso_tiempo_min', 1);
    if ~isnumeric(tiempo_simulacion_min) || ~isscalar(tiempo_simulacion_min) || tiempo_simulacion_min <= 0
        error('El tiempo de simulacion debe ser un numero positivo en minutos.');
    end
    if ~isnumeric(paso_tiempo_min) || ~isscalar(paso_tiempo_min) || paso_tiempo_min <= 0
        error('El paso temporal debe ser un numero positivo en minutos.');
    end
    if paso_tiempo_min > tiempo_simulacion_min
        error('El paso temporal no puede ser mayor que el tiempo total de simulacion.');
    end

    tipos_seleccionados = obtener_campo_config(config_ui, 'tipos_antena', {'Monopolo'});
    if ischar(tipos_seleccionados) || isstring(tipos_seleccionados)
        tipos_seleccionados = cellstr(tipos_seleccionados);
    end
    if isempty(tipos_seleccionados)
        error('Debe seleccionarse al menos un tipo de antena.');
    end
    idx_tipos = [];
    for k = 1:numel(tipos_seleccionados)
        idx = find(strcmpi(nombres_tipos, char(tipos_seleccionados{k})), 1);
        if isempty(idx)
            error('Tipo de antena no reconocido: %s', char(tipos_seleccionados{k}));
        end
        idx_tipos(end+1) = idx; %#ok<AGROW>
    end
    idx_tipos = unique(idx_tipos, 'stable');

    config = struct( ...
        'casos', casos, ...
        'idx_tipos', idx_tipos, ...
        'numeros_antenas', numeros_antenas, ...
        'potencias', potencias, ...
        'tiempo_simulacion_min', tiempo_simulacion_min, ...
        'paso_tiempo_min', paso_tiempo_min);
end

function potencia_total_max = potencia_total_maxima_generador( ...
        num_antenas, potencia_total_max_1a3, potencia_total_max_4ant)
    if num_antenas == 4
        potencia_total_max = potencia_total_max_4ant;
    else
        potencia_total_max = potencia_total_max_1a3;
    end
end

function umbral = umbral_carbonizacion_generador(umbrales, idx_caso)
    posicion = idx_caso + 1;
    if posicion < 1 || posicion > numel(umbrales)
        error('No existe umbral de carbonizacion para el caso %d.', ...
            idx_caso);
    end
    umbral = umbrales(posicion);
end

function valores = crear_rango_entero(inicio, fin, paso, minimo, maximo, etiqueta)
    if ~isnumeric(inicio) || ~isscalar(inicio) || ~isnumeric(fin) || ~isscalar(fin)
        error('El rango de %s debe usar valores numericos escalares.', etiqueta);
    end
    if ~isnumeric(paso) || ~isscalar(paso) || paso <= 0
        error('El paso de %s debe ser un numero positivo.', etiqueta);
    end
    if inicio > fin
        error('El inicio de %s no puede ser mayor que el fin.', etiqueta);
    end
    if inicio < minimo || fin > maximo
        error('El rango de %s debe estar entre %.3g y %.3g.', etiqueta, minimo, maximo);
    end
    if inicio == fin
        valores = inicio;
    else
        valores = inicio:paso:fin;
        if isempty(valores) || valores(end) ~= fin
            valores = unique([valores, fin], 'stable');
        end
    end
    valores = unique(round(valores), 'stable');
end

function disponibles = detectar_antenas_disponibles(ruta_antenas)
    disponibles = {};
    if isempty(ruta_antenas) || ~isfolder(ruta_antenas)
        return;
    end
    patrones = {
        'Doble_slot', 'Antena_doble_slot_12cm_3D.mphbin';
        'Monopolo',   'Antena_monopolo_1.4219cm_3D.mphbin';
        'Un_slot',    'Antena_un_slot_12cm_3D.mphbin'};
    for k = 1:size(patrones, 1)
        if isfile(fullfile(ruta_antenas, patrones{k, 2}))
            disponibles{end+1} = patrones{k, 1}; %#ok<AGROW>
        end
    end
end

function lineas = inspeccionar_simulaciones_generador(ruta_raiz)
    lineas = {};
    if isempty(ruta_raiz) || ~isfolder(ruta_raiz)
        lineas = {'Root no valido o inexistente.'};
        return;
    end

    rutas_dataset = {
        fullfile(ruta_raiz, 'Dataset_SinMetales_SinTumor2');
        fullfile(ruta_raiz, 'Dataset_SinMetales_SinTumor')};
    ruta_dataset = '';
    for k = 1:numel(rutas_dataset)
        if isfolder(rutas_dataset{k})
            ruta_dataset = rutas_dataset{k};
            break;
        end
    end
    if isempty(ruta_dataset)
        lineas = {
            sprintf('Root: %s', ruta_raiz);
            'No se encontro Dataset_SinMetales_SinTumor2 ni Dataset_SinMetales_SinTumor.';
            'Al ejecutar el generador se creara Dataset_SinMetales_SinTumor2.'};
        return;
    end

    indices = dir(fullfile(ruta_dataset, '**', 'Indice_Soluciones.mat'));
    lineas{end+1} = sprintf('Dataset encontrado: %s', ruta_dataset);
    lineas{end+1} = sprintf('Indices de soluciones encontrados: %d', numel(indices));
    if isempty(indices)
        lineas{end+1} = 'La carpeta existe, pero aun no contiene Indice_Soluciones.mat.';
        return;
    end

    total_sols = 0;
    estados_globales = struct();
    for i = 1:numel(indices)
        ruta_indice = fullfile(indices(i).folder, indices(i).name);
        [~, modelo] = fileparts(indices(i).folder);
        try
            datos = load(ruta_indice);
            campos = fieldnames(datos);
            if isfield(datos, 'tags_completos')
                tabla = datos.tags_completos;
            else
                tabla = struct([]);
            end
        catch ME
            lineas{end+1} = sprintf('[ERROR] %s: %s', ruta_indice, ME.message); %#ok<AGROW>
            continue;
        end

        n = numel(tabla);
        total_sols = total_sols + n;
        estados = contar_estados(tabla);
        nombres_estados = fieldnames(estados);
        for e = 1:numel(nombres_estados)
            campo_estado = nombres_estados{e};
            if ~isfield(estados_globales, campo_estado)
                estados_globales.(campo_estado) = 0;
            end
            estados_globales.(campo_estado) = estados_globales.(campo_estado) + estados.(campo_estado);
        end

        casos = valores_unicos_tabla(tabla, 'idx_caso');
        pot = valores_unicos_tabla(tabla, 'P_ant');
        ptot = valores_unicos_tabla(tabla, 'P_tot');
        lineas{end+1} = sprintf('%s | soluciones: %d | estados: %s', ...
            modelo, n, formatear_estados(estados)); %#ok<AGROW>
        lineas{end+1} = sprintf('  Casos: %s | P_ant: %s W | P_tot: %s W', ...
            mat2str(casos), mat2str(pot), mat2str(ptot)); %#ok<AGROW>
        lineas{end+1} = sprintf('  MAT contiene variables: %s', strjoin(campos, ', ')); %#ok<AGROW>
        if ~isempty(tabla)
            lineas{end+1} = sprintf('  tags_completos contiene campos: %s', ...
                strjoin(fieldnames(tabla), ', ')); %#ok<AGROW>
        end
    end
    lineas{2} = sprintf('%s | soluciones registradas: %d | estados globales: %s', ...
        lineas{2}, total_sols, formatear_estados(estados_globales));
end

function estados = contar_estados(tabla)
    estados = struct();
    if isempty(tabla) || ~isfield(tabla, 'estado')
        return;
    end
    for k = 1:numel(tabla)
        nombre = matlab.lang.makeValidName(char(tabla(k).estado));
        if ~isfield(estados, nombre)
            estados.(nombre) = 0;
        end
        estados.(nombre) = estados.(nombre) + 1;
    end
end

function txt = formatear_estados(estados)
    nombres = fieldnames(estados);
    if isempty(nombres)
        txt = '(sin estados)';
        return;
    end
    partes = cell(numel(nombres), 1);
    for k = 1:numel(nombres)
        partes{k} = sprintf('%s=%d', nombres{k}, estados.(nombres{k}));
    end
    txt = strjoin(partes, ', ');
end

function valores = valores_unicos_tabla(tabla, campo)
    valores = [];
    if isempty(tabla) || ~isfield(tabla, campo)
        return;
    end
    try
        valores = unique([tabla.(campo)]);
    catch
        valores = [];
    end
end

function valor = obtener_campo_config(config, campo, valor_default)
    valor = valor_default;
    if isstruct(config) && isfield(config, campo) && ~isempty(config.(campo))
        valor = config.(campo);
    end
end

% ---- Fin copia local: generador_sin_metales_multi_solucion_sin_tumor.m ----
end
% ---- Inicio copia local: extractor_comsol_masivo.m ----
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
    if nargin == 0
        error('Use modulo_interaccion_comsol para abrir la UI integrada o pase ''run'', config.');
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
        data_paths = tesis_auxiliares('dataset_paths');
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
        'fecha',          char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
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
                'fecha_extraccion', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
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

% ---- Fin copia local: extractor_comsol_masivo.m ----
