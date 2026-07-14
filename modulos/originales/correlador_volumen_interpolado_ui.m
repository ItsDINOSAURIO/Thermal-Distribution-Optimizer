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
    % Permite ejecutar el modulo desde el launcher o directamente.
    carpeta_modulo = fileparts(mfilename('fullpath'));
    candidatos_aux = {fullfile(carpeta_modulo, '..', 'Aux_Codes'), ...
        fullfile(carpeta_modulo, '..', '..', 'Aux_Codes')};
    for k_aux = 1:numel(candidatos_aux)
        if isfolder(candidatos_aux{k_aux}), addpath(candidatos_aux{k_aux}); end
    end
    if exist('tesis_auxiliares', 'file') == 2
        tesis_auxiliares('configurar_paths', carpeta_modulo);
    end

    if nargin > 0 && ischar(varargin{1}) && strcmpi(varargin{1}, 'selftest')
        ejecutar_selftest(varargin{2:end});
        return;
    end

    theme = tesis_auxiliares('tema_ui');
    state = struct();
    state.ruta_exp = '';
    state.ruta_sim = '';
    state.ruta_dataset = '';
    state.ruta_correccion_externa = '';
    data_paths = tesis_auxiliares('asegurar_dataset_paths');
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
    crear_mini_label('Nt:', 438, 350);
    edNtFine = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl+350 416 98 24], 'Value', 200, 'Limits', [10 1000]);

    crear_mini_label('T abl:', 388, 0);
    edTAbl = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl 366 98 24], 'Value', 60);
    crear_mini_label('Fin ext (min):', 388, 116);
    edTExtra = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl+116 366 98 24], 'Value', 0, ...
        'Tooltip', 'Minuto final de extrapolacion. Si es 0, se usa automatico: 1.5x el tiempo simulado.');
    crear_mini_label('N extrap:', 388, 232);
    edNtExt = uieditfield(fig, 'numeric', ...
        'Position', [xCtrl+232 366 98 24], 'Value', 80, 'Limits', [0 500], ...
        'Tooltip', 'Numero de puntos temporales generados para el tramo extrapolado.');

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

    btnCorrExt = uibutton(fig, 'Position', [xCtrl 236 162 28], ...
        'Text', 'Cargar correccion', ...
        'ButtonPushedFcn', @cargar_correccion_externa);
    lblCorrExt = uilabel(fig, 'Position', [xCtrl+172 240 276 20], ...
        'Text', 'usa la generada si existe', 'Interpreter', 'none');

    btnExportDir = uibutton(fig, 'Position', [xCtrl 202 162 28], ...
        'Text', 'Carpeta exportacion', ...
        'ButtonPushedFcn', @seleccionar_exportacion);
    lblExportDir = uilabel(fig, 'Position', [xCtrl+172 206 276 20], ...
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
    tesis_auxiliares('tema_ui', 'button', btnCorrExt, 'secondary');
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
            nombre_correccion_default(state.correccion));
        [file, path] = uiputfile('*.mat', ...
            'Guardar correccion termica', ruta_default_corr);
        if isequal(file, 0)
            return;
        end
        guardar_correccion_mat(fullfile(path, file), state.correccion);
        establecer_estado('Correccion guardada: %s', fullfile(path, file));
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
        cfg.nombre_exp = nombre_archivo(state.ruta_exp);
        cfg.nombre_sim = nombre_archivo(state.ruta_sim);
    end

    function cargar_dataset(~, ~)
        [file, path] = uigetfile('*.mat', 'Selecciona Dataset_Termico_Masivo.mat', ...
            data_paths.datasets_masivos);
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

    function cargar_correccion_externa(~, ~)
        [file, path] = uigetfile('*.mat', 'Selecciona correccion termica', ...
            data_paths.correlaciones);
        if isequal(file, 0)
            return;
        end
        ruta = fullfile(path, file);
        try
            raw = load(ruta);
            state.correccion = cargar_correccion_desde_struct(raw, file);
            state.ruta_correccion_externa = ruta;
            lblCorrExt.Text = file;
            dibujar_funcion_correccion_4d();
            actualizar_correccion_4d_y_redibujar();
            establecer_estado('Correccion externa cargada: %s.', file);
        catch ME
            uialert(fig, ME.message, 'Error correccion');
            establecer_estado('Error al cargar correccion externa.');
        end
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
        cfg.nt_fine = round(edNtFine.Value);
        cfg.T_abl = edTAbl.Value;
        cfg.t_extra_max = edTExtra.Value;
        cfg.nt_ext = round(edNtExt.Value);
        cfg.estrategia = ddEstrategia.Value;
        cfg.carpeta_exportacion = state.carpeta_exportacion;
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
            'LineWidth', 1.4, 'DisplayName', 'V base interp');
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
            txt = 'simulado/interpolado';
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

function guardar_correccion_mat(ruta, corr)
    t_comun = corr.t_comun;
    y_exp_interp = corr.y_exp_interp;
    y_sim_interp = corr.y_sim_interp;
    p_arreglo = corr.p_arreglo;
    y_delta = corr.y_delta;
    correccion_termica = corr.correccion_termica;
    save(ruta, 't_comun', 'y_exp_interp', 'y_sim_interp', ...
        'p_arreglo', 'y_delta', 'correccion_termica');
end

function nombre = nombre_correccion_default(corr)
    [~, base_exp] = fileparts(corr.nombre_exp);
    [~, base_sim] = fileparts(corr.nombre_sim);
    tag_exp = simplificar_tag_correlacion(base_exp);
    tag_sim = simplificar_tag_archivo(base_sim, 12);
    sufijo = 'global';
    if isfield(corr, 'correccion_termica') && ...
            isfield(corr.correccion_termica, 'zonas') && ...
            ~isempty(corr.correccion_termica.zonas)
        sufijo = sprintf('z%d', numel(corr.correccion_termica.zonas));
    end
    if strcmp(tag_exp, 'datos')
        nombre = sprintf('corr_%s_%s.mat', tag_sim, sufijo);
    else
        nombre = sprintf('corr_%s_%s.mat', tag_exp, sufijo);
    end
    nombre = regexprep(nombre, '[^\w\-.]', '_');
end

function tag = simplificar_tag_correlacion(txt)
    raw = lower(regexprep(txt, '[^\w]+', '_'));
    ant = regexp(raw, '(\d+)_?ant(?:enas)?', 'tokens', 'once');
    watt = regexp(raw, '(\d+)_?w(?:att)?', 'tokens', 'once');
    mins = regexp(raw, '(\d+)_?min', 'tokens', 'once');
    partes = {};
    if ~isempty(ant), partes{end+1} = sprintf('%sant', ant{1}); end
    if ~isempty(watt), partes{end+1} = sprintf('%sw', watt{1}); end
    if ~isempty(mins), partes{end+1} = sprintf('%smin', mins{1}); end
    if isempty(partes)
        tag = simplificar_tag_archivo(txt, 24);
    else
        tag = strjoin(partes, '_');
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

function corr = cargar_correccion_desde_struct(raw, nombre)
    if ~isfield(raw, 'correccion_termica')
        error('El archivo no contiene correccion_termica.');
    end
    corr = struct();
    corr.nombre_exp = nombre;
    corr.nombre_sim = nombre;
    campos = {'t_comun', 'y_exp_interp', 'y_sim_interp', 'p_arreglo', 'y_delta'};
    for k = 1:numel(campos)
        if isfield(raw, campos{k})
            corr.(campos{k}) = raw.(campos{k});
        else
            corr.(campos{k}) = [];
        end
    end
    corr.correccion_termica = raw.correccion_termica;
end

function dataset = cargar_dataset_termico(ruta)
    raw = load(ruta);
    if isfield(raw, 'dataset')
        dataset = raw.dataset;
        return;
    end
    vars = fieldnames(raw);
    for k = 1:numel(vars)
        if isstruct(raw.(vars{k}))
            dataset = raw.(vars{k});
            return;
        end
    end
    error('No se encontro una estructura dataset en el archivo.');
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
            logfn('Interpolado espacial %d/%d.', ti, nTimes);
        end
    end

    validTimes = any(isfinite(T_grid_time), 1);
    if ~any(validTimes)
        error('No se pudo interpolar ningun instante.');
    end
    T_grid_time = T_grid_time(:, validTimes);
    t_valid = t_min_orig(validTimes);
    cfg.nt_fine = max(10, round(cfg.nt_fine));
    t_fine = linspace(min(t_valid), max(t_valid), cfg.nt_fine);
    T_4D_vec = NaN(nGrid, cfg.nt_fine);
    for vi = 1:nGrid
        serie = T_grid_time(vi, :);
        T_4D_vec(vi, :) = interp1(t_valid, serie, t_fine, 'pchip', NaN);
    end
    logfn('Campo 4D interpolado construido.');

    voxel_vol = (bbox.xmax-bbox.xmin)/(cfg.nx-1) * ...
        (bbox.ymax-bbox.ymin)/(cfg.ny-1) * ...
        (bbox.zmax-bbox.zmin)/(cfg.nz-1);
    V_base = calcular_volumen_por_tiempo(T_4D_vec, cfg.T_abl, voxel_vol);

    if isempty(cfg.t_extra_max) || cfg.t_extra_max <= max(t_fine)
        cfg.t_extra_max = max(t_fine) * 1.5;
    end
    cfg.nt_ext = max(0, round(cfg.nt_ext));
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

    tag = sanitizar_tag(sprintf('%s_%s', cfg.modelo, cfg.dsName));
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

function extrap = construir_extrapolacion_campo(T_4D_vec, t_fine, nt_ext, t_extra_max, T_abl, voxel_vol)
    if nt_ext <= 0
        extrap = struct('t_ext_only', [], 'grad', [], 'lowess', [], 'pca', [], ...
            'sigma_grad', [], 'sigma_low', [], 'sigma_pca', [], ...
            'V_grad', [], 'V_lowess', [], 'V_pca', [], ...
            'meta_grad', struct(), 'meta_low', struct(), 'meta_pca', struct());
        return;
    end
    nt_fine = numel(t_fine);
    nGrid = size(T_4D_vec, 1);
    dt = median(diff(t_fine));
    t_ext_only = linspace(max(t_fine) + dt, t_extra_max, nt_ext);
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
            aplicado = false;
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
                aplicado = true;
            end
            if aplicado
                T_nd_corr(:,:,:,ti) = Ttmp;
            end
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
        'intensidad_correccion', cfg.intensidad_correccion, ...
        'aplicar_offset_base', cfg.aplicar_offset_base);
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
    archivos = exportar_resultados_volumen(cfg, res.tag, res.Fgrid_ext, ...
        res.xg, res.yg, res.zg, res.t_full, res.t_fine, res.V_base, ...
        res.V_corr, modelo_sel, voxel_vol, correccion_exportada, logfn);
end

function archivos = exportar_resultados_volumen(cfg, tag, Fgrid_ext, xg, yg, zg, ...
        t_full, t_fine, V_base, V_corr, modelo_sel, voxel_vol, correccion_exportada, logfn)
    archivos = struct('mat', '', 'm', '', 'rbf', '');
    if ~isfolder(cfg.carpeta_exportacion)
        mkdir(cfg.carpeta_exportacion);
    end
    if cfg.export_mat
        out_mat = fullfile(cfg.carpeta_exportacion, sprintf('T4D_%s.mat', tag));
        xg_exp = xg; yg_exp = yg; zg_exp = zg; t_exp = t_full;
        T_abl_exp = cfg.T_abl;
        V_base_exp = V_base;
        if ~isempty(V_corr)
            V_base_exp = V_corr;
        end
        t_fine_exp = t_fine;
        modelo_nombre = modelo_sel.tipo;
        modelo_params = modelo_sel.params;
        modelo_tipo = modelo_sel.tipo;
        nx = cfg.nx; ny = cfg.ny; nz = cfg.nz;
        p_corr_save = [];
        save(out_mat, 'Fgrid_ext', 'xg_exp', 'yg_exp', 'zg_exp', 't_exp', ...
            'T_abl_exp', 'V_base_exp', 't_fine_exp', ...
            'modelo_nombre', 'modelo_params', 'modelo_tipo', ...
            'nx', 'ny', 'nz', 'voxel_vol', 'p_corr_save', ...
            'correccion_exportada', '-v7.3');
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

function name = nombre_archivo(ruta)
    [~, base, ext] = fileparts(ruta);
    name = [base ext];
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
