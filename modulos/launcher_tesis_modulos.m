% launcher_tesis_modulos: modulo de navegacion del proyecto.
% Muestra los modulos disponibles, gestiona su apertura y registra eventos.
% Confirma cierres y recupera el lanzador al cerrar modulos o fallar.

% Construye el menu principal y conecta los modulos disponibles.
function launcher_tesis_modulos()
    carpeta_launcher = fileparts(mfilename('fullpath'));
    addpath(fullfile(carpeta_launcher, '..', 'aux_codes'));
    root_proyecto = tesis_auxiliares('configurar_paths', carpeta_launcher);

    theme = tesis_auxiliares('tema_ui');
    modulos = tesis_auxiliares('modulos_catalogo');

    fig = uifigure('Name', 'Lanzador', ...
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
    header_grid = uigridlayout(header_panel, [1, 1]);
    header_grid.ColumnWidth = {'1x'};
    header_grid.Padding = [14 8 14 8];
    titulo = uilabel(header_grid, ...
        'Text', 'Trabajo Terminal', ...
        'HorizontalAlignment', 'center');
    tesis_auxiliares('tema_ui', 'label', titulo, 'title');
    titulo.FontSize = theme.fonts.titleSize + 4;
    titulo.FontWeight = 'bold';
    titulo.FontColor = [0.20 0.78 0.82];

    n_modulos = numel(modulos);
    modules_grid = uigridlayout(gl, [n_modulos, 1]);
    modules_grid.Layout.Row = 2;
    modules_grid.Layout.Column = 1;
    modules_grid.Padding = [0 0 0 0];
    modules_grid.RowSpacing = 10;
    modules_grid.ColumnSpacing = 10;
    modules_grid.RowHeight = repmat({'1x'}, 1, n_modulos);
    modules_grid.ColumnWidth = {'1x'};
    activar_scroll(modules_grid);
    for i = 1:n_modulos
        modulo_boton = modulos(i);
        btn = uibutton(modules_grid, ...
            'Text', sprintf('%02d  %s', modulo_boton.orden, modulo_boton.nombre), ...
            'Tooltip', modulo_boton.descripcion, ...
            'ButtonPushedFcn', @(~, ~) ejecutar_modulo(i));
        btn.Layout.Row = i;
        btn.Layout.Column = 1;
        btn.FontSize = theme.fonts.sectionSize;
        tesis_auxiliares('tema_ui', 'button', btn, 'success');
        if isempty(which(modulo_boton.funcion))
            btn.Enable = 'off';
            btn.Tooltip = sprintf('%s\nModulo no disponible.', modulo_boton.descripcion);
        end
    end

    log_panel = uipanel(gl, 'Title', 'Registro de eventos');
    log_panel.Layout.Row = 3;
    log_panel.Layout.Column = 1;
    tesis_auxiliares('tema_ui', 'panel', log_panel);
    activar_scroll(log_panel);
    log_grid = uigridlayout(log_panel, [1, 1]);
    log_grid.Padding = [6 6 6 6];
    activar_scroll(log_grid);
    txt_log = uitextarea(log_grid, 'Editable', 'off', 'Value', {'Listo.'});
    tesis_auxiliares('tema_ui', 'apply', fig);

    registrar_evento('Verificacion de modulos completada.');
    registrar_evento('Launcher iniciado desde: %s', root_proyecto);

    % Abre el modulo seleccionado y prepara su retorno.
    function ejecutar_modulo(idx)
        modulo = modulos(idx);
        registrar_evento('Modulo seleccionado: %s', modulo.nombre);

        ruta = which(modulo.funcion);
        if isempty(ruta)
            registrar_evento('ERROR: no se encontro el modulo %s.', modulo.nombre);
            uialert(fig, sprintf('No se encontro el modulo:\n%s', modulo.nombre), ...
                'Modulo no disponible');
            return;
        end

        txt_log.Value = [repmat({''}, 5, 1); txt_log.Value(:)];
        drawnow limitrate;
        registrar_evento('Abriendo %s...', modulo.nombre);
        figuras_antes = findall(groot, 'Type', 'figure');

        try
            fig.CloseRequestFcn = [];
            delete(fig);
            drawnow limitrate;

            feval(modulo.funcion);
            drawnow;

            figuras_antes = figuras_antes(isgraphics(figuras_antes));
            figuras_despues = findall(groot, 'Type', 'figure');
            es_nueva = false(size(figuras_despues));
            for k_fig = 1:numel(figuras_despues)
                es_nueva(k_fig) = ~any(figuras_despues(k_fig) == figuras_antes);
            end
            figuras_nuevas = figuras_despues(es_nueva);
            if isempty(figuras_nuevas)
                error('El modulo %s no abrio una ventana detectable.', modulo.nombre);
            end
            for k_fig = 1:numel(figuras_nuevas)
                if isgraphics(figuras_nuevas(k_fig)) && isprop(figuras_nuevas(k_fig), 'CloseRequestFcn')
                    figuras_nuevas(k_fig).CloseRequestFcn = ...
                        @(src, evt) cerrar_modulo_y_volver(src, evt, modulo.nombre);
                end
            end
        catch ME
            abrir_launcher_seguro();
            launcher = findall(groot, 'Type', 'figure', 'Name', 'Lanzador');
            if ~isempty(launcher)
                try
                    uialert(launcher(1), ME.message, sprintf('Error en %s', modulo.nombre_corto));
                catch
                    warning('launcher_tesis_modulos:errorModulo', '%s', ME.message);
                end
            else
                warning('launcher_tesis_modulos:errorModulo', '%s', ME.message);
            end
        end
    end

    % Habilita desplazamiento en los contenedores del lanzador.
    function activar_scroll(obj)
        if isprop(obj, 'Scrollable')
            try
                obj.Scrollable = 'on';
            catch
                obj.Scrollable = true;
            end
        end
    end

    % Confirma la salida del menu principal.
    function confirmar_cierre_launcher(src, ~)
        seleccion = confirmar_cierre(src, 'Cerrar el lanzador?');
        if strcmp(seleccion, 'Si')
            delete(src);
        end
    end

    % Solicita confirmacion antes de cerrar una ventana.
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

    % Cierra el modulo y regresa al menu principal.
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

    % Recupera el lanzador sin duplicar ventanas existentes.
    function abrir_launcher_seguro()
        try
            tesis_auxiliares('configurar_paths', root_proyecto);
            launcher_existente = findall(groot, 'Type', 'figure', ...
                'Name', 'Lanzador');
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

    % Registra eventos del lanzador con su hora.
    function registrar_evento(formato, varargin)
        mensaje = sprintf(formato, varargin{:});
        marca_tiempo = char(datetime('now', 'Format', 'HH:mm:ss'));
        linea = sprintf('[%s] %s', marca_tiempo, mensaje);
        txt_log.Value = [{linea}; txt_log.Value(:)];
        drawnow limitrate;
    end
end
