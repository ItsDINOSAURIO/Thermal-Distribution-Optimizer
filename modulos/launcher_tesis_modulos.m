function launcher_tesis_modulos()
%LAUNCHER_TESIS_MODULOS Entrada central ligera del framework.
%
% El launcher solo muestra y lanza los modulos principales definidos en
% tesis_auxiliares('modulos_catalogo'). La logica de cada etapa vive dentro
% de su modulo correspondiente.

    carpeta_launcher = fileparts(mfilename('fullpath'));
    addpath(carpeta_launcher);
    addpath(fullfile(carpeta_launcher, '..', 'aux_codes'));
    root_proyecto = tesis_auxiliares('configurar_paths', carpeta_launcher);

    theme = tesis_auxiliares('tema_ui');
    modulos = tesis_auxiliares('modulos_catalogo');
    estado = struct();
    estado.modulo_activo = 1;
    estado.estado_modulo = gobjects(numel(modulos), 1);
    estado.detalle_modulo = gobjects(numel(modulos), 1);

    fig = uifigure('Name', 'Launcher Tesis - Flujo Termico 3D', ...
        'Position', theme.layout.launcherPosition, ...
        'Color', theme.colors.bg, ...
        'CloseRequestFcn', @confirmar_cierre_launcher);

    gl = uigridlayout(fig, [3, 1]);
    gl.RowHeight = {theme.layout.headerHeight, '1x', theme.layout.logHeight};
    gl.ColumnWidth = {'1x'};
    gl.Padding = [10 10 10 10];
    gl.RowSpacing = 10;
    gl.ColumnSpacing = 10;
    activar_scroll(gl);

    header_panel = uipanel(gl, 'BorderType', 'none');
    header_panel.Layout.Row = 1;
    header_panel.Layout.Column = 1;
    tesis_auxiliares('tema_ui', 'card', header_panel);
    header_grid = uigridlayout(header_panel, [1, 3]);
    header_grid.ColumnWidth = {'1x', 200, 180};
    header_grid.Padding = [14 8 14 8];
    header_grid.ColumnSpacing = 10;
    titulo = uilabel(header_grid, ...
        'Text', 'Flujo integrado de simulacion, procesamiento y verificacion', ...
        'HorizontalAlignment', 'left');
    tesis_auxiliares('tema_ui', 'label', titulo, 'title');
    btn_root = uibutton(header_grid, 'Text', 'Abrir carpeta del proyecto', ...
        'ButtonPushedFcn', @(~, ~) abrir_root());
    tesis_auxiliares('tema_ui', 'button', btn_root, 'secondary');
    btn_refresh = uibutton(header_grid, 'Text', 'Verificar modulos', ...
        'ButtonPushedFcn', @(~, ~) verificar_modulos());
    tesis_auxiliares('tema_ui', 'button', btn_refresh, 'primary');

    modules_panel = uipanel(gl, 'Title', 'Modulos disponibles');
    modules_panel.Layout.Row = 2;
    modules_panel.Layout.Column = 1;
    tesis_auxiliares('tema_ui', 'panel', modules_panel);
    activar_scroll(modules_panel);
    n_modulos = numel(modulos);
    ncols = min(3, max(1, n_modulos));
    nrows = max(1, ceil(n_modulos / ncols));
    modules_grid = uigridlayout(modules_panel, [nrows, ncols]);
    modules_grid.Padding = [10 10 10 10];
    modules_grid.RowSpacing = 10;
    modules_grid.ColumnSpacing = 10;
    modules_grid.RowHeight = repmat({'1x'}, 1, nrows);
    modules_grid.ColumnWidth = repmat({'1x'}, 1, ncols);
    activar_scroll(modules_grid);
    for i = 1:n_modulos
        crear_tarjeta_modulo(modules_grid, i);
    end

    log_panel = uipanel(gl, 'Title', 'Consola de eventos');
    log_panel.Layout.Row = 3;
    log_panel.Layout.Column = 1;
    tesis_auxiliares('tema_ui', 'panel', log_panel);
    activar_scroll(log_panel);
    log_grid = uigridlayout(log_panel, [1, 1]);
    log_grid.Padding = [6 6 6 6];
    activar_scroll(log_grid);
    estado.txt_log = uitextarea(log_grid, 'Editable', 'off', 'Value', {'Listo.'});
    tesis_auxiliares('tema_ui', 'textarea', estado.txt_log);
    tesis_auxiliares('tema_ui', 'apply', fig);
    tesis_auxiliares('tema_ui', 'textarea', estado.txt_log);

    verificar_modulos();
    registrar_evento('Launcher iniciado desde: %s', root_proyecto);

    function crear_tarjeta_modulo(parent, idx)
        modulo = modulos(idx);
        card = uipanel(parent, 'Title', sprintf('%02d', modulo.orden));
        tesis_auxiliares('tema_ui', 'card', card);
        activar_scroll(card);

        grid = uigridlayout(card, [6, 1]);
        grid.Padding = [10 8 10 8];
        grid.RowSpacing = 5;
        grid.RowHeight = {24, 36, '1x', 22, 30, 20};
        activar_scroll(grid);

        titulo = uilabel(grid, 'Text', modulo.nombre, 'WordWrap', 'on');
        tesis_auxiliares('tema_ui', 'label', titulo, 'section');

        subtitulo = uilabel(grid, 'Text', modulo.funcion, 'WordWrap', 'on');
        tesis_auxiliares('tema_ui', 'label', subtitulo, 'muted');

        descripcion = uilabel(grid, 'Text', modulo.descripcion, 'WordWrap', 'on');
        tesis_auxiliares('tema_ui', 'label', descripcion, 'normal');

        estado_lbl = uilabel(grid, 'Text', 'No verificado');
        tesis_auxiliares('tema_ui', 'label', estado_lbl, 'status');
        estado.estado_modulo(idx) = estado_lbl;

        btn = uibutton(grid, 'Text', 'Ejecutar modulo', ...
            'ButtonPushedFcn', @(~, ~) ejecutar_modulo(idx));
        tesis_auxiliares('tema_ui', 'button', btn, 'success');

        detalle = uilabel(grid, 'Text', '', 'WordWrap', 'on');
        tesis_auxiliares('tema_ui', 'label', detalle, 'muted');
        estado.detalle_modulo(idx) = detalle;
    end

    function ejecutar_modulo(idx)
        modulo = modulos(idx);
        estado.modulo_activo = idx;
        registrar_evento('Modulo seleccionado: %s', modulo.nombre);

        ruta = which(modulo.funcion);
        if isempty(ruta)
            registrar_evento('ERROR: no se encontro %s en el path.', modulo.funcion);
            uialert(fig, sprintf('No se encontro el modulo:\n%s', modulo.funcion), ...
                'Modulo no disponible');
            return;
        end

        estado.txt_log.Value = [repmat({''}, 5, 1); estado.txt_log.Value(:)];
        drawnow limitrate;
        registrar_evento('Abriendo %s...', modulo.funcion);
        figuras_antes = obtener_figuras_abiertas();

        try
            fig.CloseRequestFcn = [];
            delete(fig);
            drawnow limitrate;

            feval(modulo.funcion);
            drawnow;

            figuras_nuevas = detectar_figuras_nuevas(figuras_antes);
            if isempty(figuras_nuevas)
                abrir_launcher_seguro();
                error('El modulo %s no abrio una ventana detectable.', modulo.funcion);
            end
            instalar_retorno_launcher(figuras_nuevas, modulo.nombre);
        catch ME
            abrir_launcher_seguro();
            advertir_error_lanzamiento(ME, modulo.nombre_corto);
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

    function confirmar_cierre_launcher(src, ~)
        seleccion = confirmar_cierre(src, 'Cerrar el lanzador?');
        if strcmp(seleccion, 'Si')
            delete(src);
        end
    end

    function seleccion = confirmar_cierre(src, mensaje)
        try
            seleccion = uiconfirm(src, mensaje, 'Confirmar cierre', ...
                'Options', {'Si', 'No'}, ...
                'DefaultOption', 2, ...
                'CancelOption', 2);
        catch
            seleccion = questdlg(mensaje, 'Confirmar cierre', 'Si', 'No', 'No');
            if isempty(seleccion)
                seleccion = 'No';
            end
        end
    end

    function figuras = obtener_figuras_abiertas()
        figuras = findall(groot, 'Type', 'figure');
    end

    function figuras_nuevas = detectar_figuras_nuevas(figuras_antes)
        figuras_antes = figuras_antes(isgraphics(figuras_antes));
        figuras_despues = obtener_figuras_abiertas();
        if isempty(figuras_despues)
            figuras_nuevas = gobjects(0);
            return;
        end
        es_nueva = false(size(figuras_despues));
        for k_fig = 1:numel(figuras_despues)
            es_nueva(k_fig) = ~any(figuras_despues(k_fig) == figuras_antes);
        end
        figuras_nuevas = figuras_despues(es_nueva);
    end

    function instalar_retorno_launcher(figuras_modulo, nombre_modulo)
        for k_fig = 1:numel(figuras_modulo)
            if isgraphics(figuras_modulo(k_fig)) && isprop(figuras_modulo(k_fig), 'CloseRequestFcn')
                figuras_modulo(k_fig).CloseRequestFcn = ...
                    @(src, evt) cerrar_modulo_y_volver(src, evt, nombre_modulo);
            end
        end
    end

    function cerrar_modulo_y_volver(src, ~, nombre_modulo)
        mensaje = sprintf('Cerrar %s y volver al lanzador?', nombre_modulo);
        seleccion = confirmar_cierre(src, mensaje);
        if strcmp(seleccion, 'Si')
            if isgraphics(src)
                delete(src);
            end
            drawnow limitrate;
            abrir_launcher_seguro();
        end
    end

    function abrir_launcher_seguro()
        try
            tesis_auxiliares('configurar_paths', root_proyecto);
            launcher_existente = findall(groot, 'Type', 'figure', ...
                'Name', 'Launcher Tesis - Flujo Termico 3D');
            if isempty(launcher_existente)
                launcher_tesis_modulos();
            else
                launcher_existente(1).Visible = 'on';
                drawnow limitrate;
            end
        catch ME_launcher
            warning('launcher_tesis_modulos:retornoFallido', ...
                'No se pudo reabrir el launcher: %s', ME_launcher.message);
        end
    end

    function advertir_error_lanzamiento(ME, nombre_corto)
        launcher = findall(groot, 'Type', 'figure', ...
            'Name', 'Launcher Tesis - Flujo Termico 3D');
        if ~isempty(launcher)
            try
                uialert(launcher(1), ME.message, sprintf('Error en %s', nombre_corto));
            catch
                warning('launcher_tesis_modulos:errorModulo', '%s', ME.message);
            end
        else
            warning('launcher_tesis_modulos:errorModulo', '%s', ME.message);
        end
    end
    function verificar_modulos()
        tesis_auxiliares('configurar_paths', root_proyecto);
        for k = 1:numel(modulos)
            ruta = which(modulos(k).funcion);
            if isempty(ruta)
                estado.estado_modulo(k).Text = 'No encontrado';
                estado.estado_modulo(k).FontColor = theme.colors.danger;
                estado.detalle_modulo(k).Text = 'Revise nombre o ubicacion.';
            else
                estado.estado_modulo(k).Text = 'Disponible';
                estado.estado_modulo(k).FontColor = theme.colors.success;
                [~, archivo, ext] = fileparts(ruta);
                estado.detalle_modulo(k).Text = [archivo ext];
            end
        end
        registrar_evento('Verificacion de modulos completada.');
    end

    function abrir_root()
        if ispc
            winopen(root_proyecto);
        else
            registrar_evento('Root del proyecto: %s', root_proyecto);
        end
    end

    function registrar_evento(formato, varargin)
        mensaje = sprintf(formato, varargin{:});
        marca_tiempo = char(datetime('now', 'Format', 'HH:mm:ss'));
        linea = sprintf('[%s] %s', marca_tiempo, mensaje);
        estado.txt_log.Value = [{linea}; estado.txt_log.Value(:)];
        drawnow limitrate;
    end
end
