function launcher_tesis_modulos()
%LAUNCHER_TESIS_MODULOS Entrada central para el flujo completo del proyecto.
%
% Este launcher no fusiona la logica numerica de los modulos. Mantiene cada
% etapa como funcion independiente y ofrece una interfaz unica, consistente y
% reproducible desde el root del proyecto.

    carpeta_launcher = fileparts(mfilename('fullpath'));
    addpath(carpeta_launcher);
    addpath(fullfile(carpeta_launcher, '..', 'Aux_Codes'));
    root_proyecto = tesis_auxiliares('configurar_paths', carpeta_launcher);

    theme = tesis_auxiliares('tema_ui');
    modulos = tesis_auxiliares('modulos_catalogo');
    estado = struct();
    estado.modulo_activo = 1;
    estado.botones_modulo = gobjects(numel(modulos), 1);
    estado.estado_modulo = gobjects(numel(modulos), 1);
    estado.detalle_modulo = gobjects(numel(modulos), 1);

    fig = uifigure('Name', 'Launcher Tesis - Flujo Termico 3D', ...
        'Position', theme.layout.launcherPosition, ...
        'Color', theme.colors.bg);

    gl = uigridlayout(fig, [3, 2]);
    gl.RowHeight = {theme.layout.headerHeight, '1x', theme.layout.logHeight};
    gl.ColumnWidth = {theme.layout.sidebarWidth, '1x'};
    gl.Padding = [10 10 10 10];
    gl.RowSpacing = 10;
    gl.ColumnSpacing = 10;

    crear_header(gl);
    crear_sidebar(gl);
    crear_panel_modulos(gl);
    crear_log(gl);
    tesis_auxiliares('tema_ui', 'apply', fig);
    tesis_auxiliares('tema_ui', 'textarea', estado.txt_log);

    verificar_modulos();
    registrar_evento('Launcher iniciado desde: %s', root_proyecto);

    function crear_header(parent)
        pnl = uipanel(parent, 'BorderType', 'none');
        pnl.Layout.Row = 1;
        pnl.Layout.Column = [1 2];
        tesis_auxiliares('tema_ui', 'card', pnl);

        grid = uigridlayout(pnl, [1, 4]);
        grid.ColumnWidth = {'1x', 200, 180, 150};
        grid.Padding = [14 8 14 8];
        grid.ColumnSpacing = 10;

        titulo = uilabel(grid, ...
            'Text', 'Flujo integrado de simulacion, correccion y optimizacion', ...
            'HorizontalAlignment', 'left');
        tesis_auxiliares('tema_ui', 'label', titulo, 'title');

        btn_root = uibutton(grid, 'Text', 'Abrir carpeta del proyecto', ...
            'ButtonPushedFcn', @(~, ~) abrir_root());
        tesis_auxiliares('tema_ui', 'button', btn_root, 'secondary');

        btn_refresh = uibutton(grid, 'Text', 'Verificar modulos', ...
            'ButtonPushedFcn', @(~, ~) verificar_modulos());
        tesis_auxiliares('tema_ui', 'button', btn_refresh, 'primary');

        btn_export = uibutton(grid, 'Text', 'Exportar log', ...
            'ButtonPushedFcn', @(~, ~) exportar_log());
        tesis_auxiliares('tema_ui', 'button', btn_export, 'secondary');
    end

    function crear_sidebar(parent)
        pnl = uipanel(parent, 'Title', 'Pipeline del proyecto');
        pnl.Layout.Row = 2;
        pnl.Layout.Column = 1;
        tesis_auxiliares('tema_ui', 'panel', pnl);

        n_modulos = numel(modulos);
        grid = uigridlayout(pnl, [n_modulos + 3, 1]);
        grid.Padding = [10 10 10 10];
        grid.RowSpacing = 6;
        grid.RowHeight = [{24}, repmat({34}, 1, n_modulos), {18}, {'1x'}];

        lbl_principal = uilabel(grid, 'Text', 'Modulos integrados');
        tesis_auxiliares('tema_ui', 'label', lbl_principal, 'section');

        for idx_modulo = 1:n_modulos
            crear_boton_sidebar(grid, idx_modulo);
        end

        separador = uilabel(grid, 'Text', 'Flujo simplificado');
        tesis_auxiliares('tema_ui', 'label', separador, 'section');

        nota = uilabel(grid, ...
            'Text', 'Los modulos visibles agrupan las herramientas internas por etapa del flujo.', ...
            'WordWrap', 'on');
        tesis_auxiliares('tema_ui', 'label', nota, 'muted');
    end
    function crear_boton_sidebar(parent, idx)
        texto = sprintf('%d. %s', modulos(idx).orden, modulos(idx).nombre_corto);
        btn = uibutton(parent, 'Text', texto, ...
            'ButtonPushedFcn', @(~, ~) seleccionar_modulo(idx));
        tesis_auxiliares('tema_ui', 'button', btn, 'secondary');
        estado.botones_modulo(idx) = btn;
    end

    function crear_panel_modulos(parent)
        pnl = uipanel(parent, 'Title', 'Modulos disponibles');
        pnl.Layout.Row = 2;
        pnl.Layout.Column = 2;
        tesis_auxiliares('tema_ui', 'panel', pnl);

        n_modulos = numel(modulos);
        ncols = min(3, max(1, n_modulos));
        nrows = max(1, ceil(n_modulos / ncols));
        grid = uigridlayout(pnl, [nrows, ncols]);
        grid.Padding = [10 10 10 10];
        grid.RowSpacing = 10;
        grid.ColumnSpacing = 10;
        grid.RowHeight = repmat({'1x'}, 1, nrows);
        grid.ColumnWidth = repmat({'1x'}, 1, ncols);

        for i = 1:n_modulos
            crear_tarjeta_modulo(grid, i);
        end
    end
    function crear_tarjeta_modulo(parent, idx)
        modulo = modulos(idx);
        card = uipanel(parent, 'Title', sprintf('%02d', modulo.orden));
        tesis_auxiliares('tema_ui', 'card', card);

        grid = uigridlayout(card, [6, 1]);
        grid.Padding = [10 8 10 8];
        grid.RowSpacing = 5;
        grid.RowHeight = {24, 36, '1x', 22, 30, 20};

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

    function crear_log(parent)
        pnl = uipanel(parent, 'Title', 'Consola de eventos');
        pnl.Layout.Row = 3;
        pnl.Layout.Column = [1 2];
        tesis_auxiliares('tema_ui', 'panel', pnl);

        grid = uigridlayout(pnl, [1, 1]);
        grid.Padding = [6 6 6 6];
        txt_log = uitextarea(grid, ...
            'Editable', 'off', ...
            'Value', {'Listo.'});
        tesis_auxiliares('tema_ui', 'textarea', txt_log);
        estado.txt_log = txt_log;
    end

    function seleccionar_modulo(idx)
        estado.modulo_activo = idx;
        for k = 1:numel(estado.botones_modulo)
            if isgraphics(estado.botones_modulo(k))
                if k == idx
                    tesis_auxiliares('tema_ui', 'button', estado.botones_modulo(k), 'accent');
                else
                    tesis_auxiliares('tema_ui', 'button', estado.botones_modulo(k), 'secondary');
                end
            end
        end
        registrar_evento('Modulo seleccionado: %s', modulos(idx).nombre);
    end

    function ejecutar_modulo(idx)
        modulo = modulos(idx);
        seleccionar_modulo(idx);

        ruta = which(modulo.funcion);
        if isempty(ruta)
            registrar_evento('ERROR: no se encontro %s en el path.', modulo.funcion);
            uialert(fig, sprintf('No se encontro el modulo:\n%s', modulo.funcion), ...
                'Modulo no disponible');
            return;
        end

        insertar_separacion_log();
        registrar_evento('Ejecutando %s...', modulo.funcion);
        try
            feval(modulo.funcion);
            registrar_evento('Modulo lanzado: %s', modulo.funcion);
        catch ME
            registrar_evento('ERROR en %s: %s', modulo.funcion, ME.message);
            uialert(fig, ME.message, sprintf('Error en %s', modulo.nombre_corto));
        end
    end

    function insertar_separacion_log()
        estado.txt_log.Value = [repmat({''}, 5, 1); estado.txt_log.Value(:)];
        drawnow limitrate;
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
        seleccionar_modulo(estado.modulo_activo);
        registrar_evento('Verificacion de modulos completada.');
    end

    function abrir_root()
        if ispc
            winopen(root_proyecto);
        else
            registrar_evento('Root del proyecto: %s', root_proyecto);
        end
    end

    function exportar_log()
        [archivo, carpeta] = uiputfile('*.txt', ...
            'Exportar log del launcher', 'launcher_tesis_log.txt');
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
        lineas = flipud(estado.txt_log.Value(:));
        for k = 1:numel(lineas)
            fprintf(fid, '%s\n', lineas{k});
        end
        registrar_evento('Log exportado: %s', ruta);
    end

    function registrar_evento(formato, varargin)
        mensaje = sprintf(formato, varargin{:});
        marca_tiempo = char(datetime('now', 'Format', 'HH:mm:ss'));
        linea = sprintf('[%s] %s', marca_tiempo, mensaje);
        estado.txt_log.Value = [{linea}; estado.txt_log.Value(:)];
        drawnow limitrate;
    end
end
