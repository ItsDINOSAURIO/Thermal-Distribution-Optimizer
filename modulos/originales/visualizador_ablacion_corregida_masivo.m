function visualizador_ablacion_corregida_masivo(varargin)
%VISUALIZADOR_ABLACION_CORREGIDA_MASIVO Dashboard fusionado.
%
% Une el visor masivo de ablacion y el visualizador de simulacion corregida
% sin eliminar ni modificar los modulos originales.
%
% Flujo:
%   1. Cargar Dataset_Termico_Masivo.mat.
%   2. Cargar el .mat de correccion termica/correlacion.
%   3. Seleccionar modelo, dataset e instante por listados.
%   4. Comparar zona de ablacion original, simulacion corregida y sondas.
%   5. Exportar el dataset corregido conservando el contrato "dataset".
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

    state = struct();
    state.simData = [];
    state.simPath = '';
    state.corrPath = '';
    state.sol_list = {};
    state.sol_idx = 1;
    state.snapshot_actual = 1;
    state.modelo_actual = '';
    state.dataset_actual = '';
    state.snapshots = [];
    state.full_field = struct();
    state.times_min = [];
    state.time_items = {'(sin tiempos)'};
    state.correccion_cargada = false;
    state.coeficientes_polinomio = [];
    state.t_correccion_rel_min = [];
    state.delta_correccion_C = [];
    state.factor_enfriamiento = [];
    state.zonas_correccion = struct([]);
    state.modo_correccion_espacial = 'global';
    state.extrapolacion_factor = struct();
    state.intervalo_correccion_min = [];
    state.temperatura_base_exp_C = NaN;
    state.temperatura_base_sim_C = NaN;
    state.offset_base_C = 0;
    state.t_origen_dataset_min = 0;
    state.t_origen_correccion_sugerido_min = NaN;
    state.metodo_correccion = 'ninguno';
    state.aplicar_offset_base = true;
    state.k = 1.0;
    state.filtro_activo = false;
    state.filtro_minimo = 30;
    state.filtro_maximo = 200;
    state.datos_correlacion_completa = [];
    state.figura_funcion_correccion = [];
    state.anim_timer = [];
    state.timer_on = false;
    state.actualizando_ui = false;
    state.max_puntos_scatter = 120000;
    state.max_puntos_surface = 25000;
    state.theme = tesis_auxiliares('tema_ui');
    data_paths = tesis_auxiliares('asegurar_dataset_paths');

    theme = state.theme;
    Wapp = 1500;
    H = 920;
    xCtrl = 12;
    wCtrl = 390;
    xMain = 420;
    wMain = 1060;

    f = uifigure('Name', 'Visualizador Ablacion + Simulacion Corregida', ...
        'Position', [30 30 Wapp H], ...
        'Color', theme.colors.bg, ...
        'Resize', 'off');
    f.KeyPressFcn = @al_presionar_tecla;
    f.CloseRequestFcn = @cerrar_dashboard;

    uilabel(f, 'Position', [xCtrl 878 wCtrl 28], ...
        'Text', 'ABLACION Y SIMULACION CORREGIDA', ...
        'HorizontalAlignment', 'center', ...
        'FontSize', 14, 'FontWeight', 'bold', ...
        'FontColor', theme.colors.accent);

    pnlOriginal = uipanel(f, 'Title', 'Zona de ablacion / Simulacion original', ...
        'Position', [xMain 545 515 350]);
    axOriginal = uiaxes(pnlOriginal, 'Position', [10 10 495 315]);

    pnlCorregida = uipanel(f, 'Title', 'Simulacion corregida', ...
        'Position', [xMain + 530 545 515 350]);
    axCorregida = uiaxes(pnlCorregida, 'Position', [10 10 495 315]);

    pnlSondas = uipanel(f, 'Title', 'Sondas en tiempo', ...
        'Position', [xMain 185 wMain 345]);
    axSondas = uiaxes(pnlSondas, 'Position', [10 10 wMain-20 310]);

    pnlLog = uipanel(f, 'Title', 'Registro de eventos', ...
        'Position', [xMain 20 wMain 150]);
    txtLog = uitextarea(pnlLog, ...
        'Position', [8 8 wMain-16 116], ...
        'Editable', 'off', ...
        'Value', {'Listo.'});

    crear_seccion('1. Archivos', 846);
    btnLoadSim = uibutton(f, 'Position', [xCtrl 818 180 28], ...
        'Text', 'Cargar simulacion .mat', ...
        'ButtonPushedFcn', @cargar_simulacion);
    lblSimFile = uilabel(f, 'Position', [xCtrl+190 822 198 20], ...
        'Text', '--', 'Interpreter', 'none');

    btnLoadCorr = uibutton(f, 'Position', [xCtrl 784 180 28], ...
        'Text', 'Cargar correccion .mat', ...
        'ButtonPushedFcn', @cargar_correccion);
    lblCorrFile = uilabel(f, 'Position', [xCtrl+190 788 198 20], ...
        'Text', '--', 'Interpreter', 'none');

    crear_seccion('2. Solucion e instante', 744);
    uilabel(f, 'Position', [xCtrl 718 70 20], 'Text', 'Modelo:');
    ddModel = uidropdown(f, 'Position', [xCtrl+72 716 316 24], ...
        'Items', {'(sin simulacion)'}, ...
        'Value', '(sin simulacion)', ...
        'ValueChangedFcn', @al_cambiar_modelo);

    uilabel(f, 'Position', [xCtrl 688 70 20], 'Text', 'Dataset:');
    ddDataset = uidropdown(f, 'Position', [xCtrl+72 686 316 24], ...
        'Items', {'(sin dataset)'}, ...
        'Value', '(sin dataset)', ...
        'ValueChangedFcn', @al_cambiar_dataset);

    uilabel(f, 'Position', [xCtrl 658 70 20], 'Text', 'Tiempo:');
    ddTiempo = uidropdown(f, 'Position', [xCtrl+72 656 316 24], ...
        'Items', {'(sin tiempos)'}, ...
        'Value', '(sin tiempos)', ...
        'ValueChangedFcn', @al_cambiar_tiempo);

    lblInfo = uilabel(f, 'Position', [xCtrl 630 wCtrl 20], ...
        'Text', 'Sin datos cargados.', ...
        'FontSize', 9, 'FontColor', theme.colors.thermalBlue);

    crear_seccion('3. Navegacion', 602);
    btnPrevSol = uibutton(f, 'Position', [xCtrl 574 88 26], ...
        'Text', '< Sol', ...
        'ButtonPushedFcn', @(~,~) navegar_solucion(-1));
    btnNextSol = uibutton(f, 'Position', [xCtrl+96 574 88 26], ...
        'Text', 'Sol >', ...
        'ButtonPushedFcn', @(~,~) navegar_solucion(+1));
    btnPrevT = uibutton(f, 'Position', [xCtrl+198 574 88 26], ...
        'Text', '< t', ...
        'ButtonPushedFcn', @(~,~) navegar_snapshot(-1));
    btnNextT = uibutton(f, 'Position', [xCtrl+294 574 94 26], ...
        'Text', 't >', ...
        'ButtonPushedFcn', @(~,~) navegar_snapshot(+1));
    btnAuto = uibutton(f, 'Position', [xCtrl 542 wCtrl 26], ...
        'Text', 'Auto tiempo', ...
        'ButtonPushedFcn', @alternar_animacion);

    crear_seccion('4. Visualizacion 3D', 510);
    uilabel(f, 'Position', [xCtrl 484 96 20], 'Text', 'Modo:');
    ddViz = uidropdown(f, 'Position', [xCtrl+100 482 288 24], ...
        'Items', {'Scatter + Surface', 'Scatter (solo puntos)', 'Surface (solo alphaShape)'}, ...
        'Value', 'Scatter + Surface', ...
        'ValueChangedFcn', @actualizar_graficas);

    uilabel(f, 'Position', [xCtrl 454 96 20], 'Text', 'Alpha radius:');
    editAlpha = uieditfield(f, 'numeric', 'Position', [xCtrl+100 452 74 24], ...
        'Value', 0, ...
        'ValueChangedFcn', @actualizar_graficas);
    uilabel(f, 'Position', [xCtrl+182 454 76 20], ...
        'Text', '0 = auto', 'FontSize', 9);
    uilabel(f, 'Position', [xCtrl+262 454 70 20], 'Text', 'Punto:');
    editPointSize = uieditfield(f, 'numeric', ...
        'Position', [xCtrl+318 452 70 24], ...
        'Value', 18, 'Limits', [1 100], ...
        'ValueChangedFcn', @actualizar_graficas);

    crear_seccion('5. Correccion termica', 420);
    chkOffset = uicheckbox(f, 'Position', [xCtrl 392 230 22], ...
        'Text', 'Aplicar offset basal experimental', ...
        'Value', true, ...
        'ValueChangedFcn', @actualizar_offset_base);
    uilabel(f, 'Position', [xCtrl 364 105 20], 'Text', 'Intensidad 0-1:');
    editFactor = uieditfield(f, 'numeric', ...
        'Position', [xCtrl+110 362 72 24], ...
        'Value', 1.0, 'Limits', [0 1], ...
        'ValueChangedFcn', @actualizar_factor);

    chkFilter = uicheckbox(f, 'Position', [xCtrl 332 230 22], ...
        'Text', 'Filtro de temperatura', ...
        'Value', false, ...
        'ValueChangedFcn', @actualizar_filtro);
    uilabel(f, 'Position', [xCtrl 304 34 20], 'Text', 'Min:');
    editMinT = uieditfield(f, 'numeric', ...
        'Position', [xCtrl+38 302 70 24], ...
        'Value', 30, 'Limits', [-273.15 5000], ...
        'ValueChangedFcn', @actualizar_filtro);
    uilabel(f, 'Position', [xCtrl+122 304 34 20], 'Text', 'Max:');
    editMaxT = uieditfield(f, 'numeric', ...
        'Position', [xCtrl+160 302 70 24], ...
        'Value', 200, 'Limits', [-273.15 5000], ...
        'ValueChangedFcn', @actualizar_filtro);

    crear_seccion('6. Sondas 1D', 270);
    uilabel(f, 'Position', [xCtrl 244 70 20], 'Text', 'Sonda:');
    ddProbe = uidropdown(f, 'Position', [xCtrl+72 242 316 24], ...
        'Items', {'(sin sondas)'}, ...
        'Value', '(sin sondas)', ...
        'ValueChangedFcn', @actualizar_graficas);
    uilabel(f, 'Position', [xCtrl 214 28 20], 'Text', 'T0:');
    editT0 = uieditfield(f, 'numeric', ...
        'Position', [xCtrl+34 212 75 24], ...
        'Value', 0, ...
        'ValueChangedFcn', @actualizar_graficas);
    uilabel(f, 'Position', [xCtrl+126 214 28 20], 'Text', 'T1:');
    editT1 = uieditfield(f, 'numeric', ...
        'Position', [xCtrl+160 212 75 24], ...
        'Value', 15, ...
        'ValueChangedFcn', @actualizar_graficas);

    crear_seccion('7. Acciones', 180);
    btnActualizar = uibutton(f, 'Position', [xCtrl 150 wCtrl 28], ...
        'Text', 'Actualizar graficas', ...
        'ButtonPushedFcn', @actualizar_graficas);
    btnExportar = uibutton(f, 'Position', [xCtrl 116 wCtrl 28], ...
        'Text', 'Exportar dataset corregido', ...
        'ButtonPushedFcn', @exportar_corregido);
    btnFuncion = uibutton(f, 'Position', [xCtrl 82 wCtrl 28], ...
        'Text', 'Mostrar funcion de correccion', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @mostrar_funcion_correccion);

    lblStatus = uilabel(f, 'Position', [xCtrl 44 wCtrl 24], ...
        'Text', 'Listo.', ...
        'FontSize', 9, ...
        'FontColor', theme.colors.thermalBlue);

    tesis_auxiliares('tema_ui', 'apply', f);
    tesis_auxiliares('tema_ui', 'axes', axOriginal);
    tesis_auxiliares('tema_ui', 'axes', axCorregida);
    tesis_auxiliares('tema_ui', 'axes', axSondas);
    tesis_auxiliares('tema_ui', 'textarea', txtLog);
    tesis_auxiliares('tema_ui', 'button', btnLoadSim, 'primary');
    tesis_auxiliares('tema_ui', 'button', btnLoadCorr, 'primary');
    tesis_auxiliares('tema_ui', 'button', btnAuto, 'secondary');
    tesis_auxiliares('tema_ui', 'button', btnActualizar, 'success');
    tesis_auxiliares('tema_ui', 'button', btnExportar, 'primary');
    tesis_auxiliares('tema_ui', 'button', btnFuncion, 'warning');
    tesis_auxiliares('tema_ui', 'button', btnPrevSol, 'secondary');
    tesis_auxiliares('tema_ui', 'button', btnNextSol, 'secondary');
    tesis_auxiliares('tema_ui', 'button', btnPrevT, 'secondary');
    tesis_auxiliares('tema_ui', 'button', btnNextT, 'secondary');
    establecer_estado('Modulo fusionado iniciado.');

    function crear_seccion(txt, y)
        uilabel(f, 'Position', [xCtrl y wCtrl 20], ...
            'Text', txt, ...
            'FontSize', 11, ...
            'FontWeight', 'bold', ...
            'FontColor', theme.colors.accent);
    end

    function cargar_simulacion(~, ~)
        [file, path] = uigetfile('*.mat', ...
            'Selecciona el archivo .mat del Extractor Masivo', ...
            data_paths.datasets_masivos);
        if isequal(file, 0)
            return;
        end
        fullpath = fullfile(path, file);
        establecer_estado('Cargando simulacion masiva...');
        try
            raw = load(fullpath);
            if isfield(raw, 'dataset')
                state.simData = raw.dataset;
            else
                fn = fieldnames(raw);
                state.simData = raw.(fn{1});
            end
            state.simPath = fullpath;
            lblSimFile.Text = file;
            configurar_soluciones();
            establecer_estado(sprintf('Simulacion cargada: %d soluciones.', ...
                numel(state.sol_list)));
        catch ME
            uialert(f, ['Error al cargar simulacion: ' ME.message], 'Error');
            establecer_estado('Error al cargar simulacion.');
        end
    end

    function cargar_correccion(~, ~)
        [file, path] = uigetfile('*.mat', ...
            'Selecciona archivo .mat de correccion termica', ...
            data_paths.correlaciones);
        if isequal(file, 0)
            return;
        end
        fullpath = fullfile(path, file);
        establecer_estado('Cargando correccion termica...');
        try
            tmp = load(fullpath);
            cargar_modelo_correccion(tmp);
            state.corrPath = fullpath;
            lblCorrFile.Text = file;
            state.correccion_cargada = true;
            actualizar_origen_temporal();
            if ~isempty(state.datos_correlacion_completa)
                btnFuncion.Enable = 'on';
            else
                btnFuncion.Enable = 'off';
            end
            establecer_estado(sprintf('Correccion cargada: %s | zonas=%d.', ...
                state.metodo_correccion, numel(state.zonas_correccion)));
            actualizar_graficas();
        catch ME
            uialert(f, ['Error al cargar correccion: ' ME.message], 'Error');
            establecer_estado('Error al cargar correccion.');
        end
    end

    function cargar_modelo_correccion(tmp)
        if ~isfield(tmp, 'p_arreglo') && ~isfield(tmp, 'correccion_termica') && ...
                ~(isfield(tmp, 't_comun') && isfield(tmp, 'y_exp_interp') && ...
                  isfield(tmp, 'y_sim_interp'))
            error('El archivo no contiene correccion_termica, p_arreglo o curvas reconocidas.');
        end

        if isfield(tmp, 'p_arreglo')
            state.coeficientes_polinomio = tmp.p_arreglo(:)';
        else
            state.coeficientes_polinomio = [];
        end

        state.t_correccion_rel_min = [];
        state.delta_correccion_C = [];
        state.factor_enfriamiento = [];
        state.zonas_correccion = struct([]);
        state.modo_correccion_espacial = 'global';
        state.extrapolacion_factor = struct();
        state.intervalo_correccion_min = [];
        state.temperatura_base_exp_C = NaN;
        state.temperatura_base_sim_C = NaN;
        state.offset_base_C = 0;
        state.t_origen_correccion_sugerido_min = NaN;
        state.metodo_correccion = 'factor_incremento_derivado';

        if isfield(tmp, 'correccion_termica') && ...
                isfield(tmp.correccion_termica, 't_rel_min') && ...
                isfield(tmp.correccion_termica, 'factor_enfriamiento')
            ct = tmp.correccion_termica;
            state.t_correccion_rel_min = ct.t_rel_min(:);
            state.factor_enfriamiento = ct.factor_enfriamiento(:);
            state.metodo_correccion = 'factor_incremento_pchip';
            if isfield(ct, 'temperatura_base_exp_C')
                state.temperatura_base_exp_C = ct.temperatura_base_exp_C;
            end
            if isfield(ct, 'temperatura_base_sim_C')
                state.temperatura_base_sim_C = ct.temperatura_base_sim_C;
            end
            if isfield(ct, 'offset_base_C')
                state.offset_base_C = ct.offset_base_C;
            end
            if isfield(ct, 'extrapolacion_factor')
                state.extrapolacion_factor = ct.extrapolacion_factor;
            end
            if isfield(ct, 'delta_T_C')
                state.delta_correccion_C = ct.delta_T_C(:);
            end
            if isfield(ct, 't_origen_simulacion_min')
                state.t_origen_correccion_sugerido_min = ...
                    ct.t_origen_simulacion_min;
            end
            if isfield(ct, 'zonas') && ~isempty(ct.zonas)
                state.zonas_correccion = ct.zonas(:);
                state.modo_correccion_espacial = 'zonas_profundidad_z';
                state.metodo_correccion = 'factor_incremento_pchip_pca_ssa_zonal';
            elseif isfield(ct, 'modo_espacial')
                state.modo_correccion_espacial = char(ct.modo_espacial);
            end
        elseif isfield(tmp, 't_comun') && isfield(tmp, 'y_exp_interp') && ...
                isfield(tmp, 'y_sim_interp')
            state.t_correccion_rel_min = tmp.t_comun(:);
            [state.factor_enfriamiento, state.temperatura_base_exp_C, ...
                state.temperatura_base_sim_C, state.offset_base_C] = ...
                construir_factor_desde_curvas( ...
                    tmp.y_exp_interp(:), tmp.y_sim_interp(:));
            if isfield(tmp, 'y_delta')
                state.delta_correccion_C = tmp.y_delta(:);
            end
        end

        if ~isempty(state.t_correccion_rel_min)
            [state.t_correccion_rel_min, idx_unique] = unique( ...
                state.t_correccion_rel_min, 'stable');
            state.factor_enfriamiento = state.factor_enfriamiento(idx_unique);
            if numel(state.delta_correccion_C) >= max(idx_unique)
                state.delta_correccion_C = state.delta_correccion_C(idx_unique);
            end
            state.intervalo_correccion_min = [ ...
                min(state.t_correccion_rel_min), ...
                max(state.t_correccion_rel_min)];
            if isempty(fieldnames(state.extrapolacion_factor)) || ...
                    ~isfield(state.extrapolacion_factor, 'metodo') || ...
                    ~strcmp(state.extrapolacion_factor.metodo, ...
                        'pca_temporal_embebido_ssa')
                state.extrapolacion_factor = crear_extrapolacion_factor( ...
                    state.t_correccion_rel_min, state.factor_enfriamiento);
            end
            if isempty(state.zonas_correccion)
                state.metodo_correccion = 'factor_incremento_pchip_pca_ssa';
            else
                state.metodo_correccion = 'factor_incremento_pchip_pca_ssa_zonal';
            end
        elseif isfield(tmp, 't_comun') && ~isempty(tmp.t_comun)
            state.intervalo_correccion_min = [min(tmp.t_comun), max(tmp.t_comun)];
        end

        if isfield(tmp, 't_comun') && isfield(tmp, 'y_exp_interp') && ...
                isfield(tmp, 'y_sim_interp')
            state.datos_correlacion_completa = struct();
            state.datos_correlacion_completa.t_comun = tmp.t_comun(:);
            state.datos_correlacion_completa.y_exp = tmp.y_exp_interp(:);
            state.datos_correlacion_completa.y_sim = tmp.y_sim_interp(:);
            state.datos_correlacion_completa.p_arreglo = ...
                state.coeficientes_polinomio;
            if isfield(tmp, 'y_delta')
                state.datos_correlacion_completa.y_delta = tmp.y_delta(:);
            else
                state.datos_correlacion_completa.y_delta = ...
                    state.datos_correlacion_completa.y_sim - ...
                    state.datos_correlacion_completa.y_exp;
            end
        else
            state.datos_correlacion_completa = [];
        end
    end

    function configurar_soluciones()
        state.sol_list = construir_lista_soluciones(state.simData);
        if isempty(state.sol_list)
            ddModel.Items = {'(sin modelos)'};
            ddModel.Value = '(sin modelos)';
            ddDataset.Items = {'(sin dataset)'};
            ddDataset.Value = '(sin dataset)';
            ddTiempo.Items = {'(sin tiempos)'};
            ddTiempo.Value = '(sin tiempos)';
            lblInfo.Text = 'No se encontraron soluciones con snapshots.';
            return;
        end

        modelos = unique(cellfun(@(x) x{1}, state.sol_list, ...
            'UniformOutput', false), 'stable');
        state.actualizando_ui = true;
        ddModel.Items = modelos;
        ddModel.Value = modelos{1};
        state.actualizando_ui = false;
        actualizar_lista_datasets();
    end

    function al_cambiar_modelo(~, ~)
        if state.actualizando_ui
            return;
        end
        actualizar_lista_datasets();
    end

    function actualizar_lista_datasets()
        if isempty(state.simData) || isempty(state.sol_list)
            return;
        end
        modelo = ddModel.Value;
        if ~isfield(state.simData, modelo)
            return;
        end
        md = state.simData.(modelo);
        nombres = fieldnames(md);
        nombres = nombres(~strcmp(nombres, 'session_meta'));
        nombres = nombres(cellfun(@(dn) isstruct(md.(dn)) && ...
            isfield(md.(dn), 'snapshots'), nombres));
        if isempty(nombres)
            nombres = {'(sin dataset)'};
        end
        state.actualizando_ui = true;
        ddDataset.Items = nombres;
        ddDataset.Value = nombres{1};
        state.actualizando_ui = false;
        cargar_dataset_seleccionado();
    end

    function al_cambiar_dataset(~, ~)
        if state.actualizando_ui
            return;
        end
        cargar_dataset_seleccionado();
    end

    function cargar_dataset_seleccionado()
        if isempty(state.simData) || isempty(ddModel.Value) || ...
                isempty(ddDataset.Value) || startsWith(ddDataset.Value, '(')
            return;
        end
        modelo = ddModel.Value;
        dsName = ddDataset.Value;
        if ~isfield(state.simData, modelo) || ...
                ~isfield(state.simData.(modelo), dsName)
            return;
        end

        state.modelo_actual = modelo;
        state.dataset_actual = dsName;
        state.sol_idx = buscar_solucion(modelo, dsName);
        dsData = state.simData.(modelo).(dsName);
        state.snapshots = dsData.snapshots;
        if isfield(dsData, 'full_field')
            state.full_field = dsData.full_field;
        else
            state.full_field = struct();
        end
        if isfield(dsData, 't_min')
            state.times_min = dsData.t_min(:);
        else
            state.times_min = arrayfun(@(s) s.t_min, state.snapshots(:));
            state.times_min = state.times_min(:);
        end
        if isempty(state.times_min)
            state.times_min = zeros(numel(state.snapshots), 1);
        end
        state.snapshot_actual = 1;
        actualizar_origen_temporal();
        actualizar_lista_tiempos();
        actualizar_lista_sondas(dsData);
        configurar_rango_sondas();
        actualizar_graficas();
    end

    function actualizar_lista_tiempos()
        nT = max(1, numel(state.times_min));
        items = cell(nT, 1);
        for k = 1:nT
            if k <= numel(state.times_min) && isfinite(state.times_min(k))
                items{k} = sprintf('%03d | %.4f min', k, state.times_min(k));
            else
                items{k} = sprintf('%03d | sin tiempo', k);
            end
        end
        state.time_items = items;
        state.actualizando_ui = true;
        ddTiempo.Items = items;
        ddTiempo.Value = items{max(1, min(state.snapshot_actual, numel(items)))};
        state.actualizando_ui = false;
        actualizar_info();
    end

    function al_cambiar_tiempo(~, ~)
        if state.actualizando_ui || isempty(state.time_items)
            return;
        end
        idx = find(strcmp(state.time_items, ddTiempo.Value), 1);
        if isempty(idx)
            return;
        end
        state.snapshot_actual = idx;
        actualizar_info();
        actualizar_graficas();
    end

    function actualizar_lista_sondas(dsData)
        if isfield(dsData, 'probes') && isstruct(dsData.probes) && ...
                ~isempty(fieldnames(dsData.probes))
            probe_names = fieldnames(dsData.probes);
            items = [{'Todas'}; probe_names(:)];
        else
            items = {'(sin sondas)'};
        end
        state.actualizando_ui = true;
        ddProbe.Items = items;
        ddProbe.Value = items{1};
        state.actualizando_ui = false;
    end

    function configurar_rango_sondas()
        tv = state.times_min(isfinite(state.times_min));
        if isempty(tv)
            editT0.Value = 0;
            editT1.Value = 15;
            return;
        end
        editT0.Value = min(tv);
        editT1.Value = max(tv);
    end

    function navegar_solucion(delta)
        if isempty(state.sol_list)
            return;
        end
        n = numel(state.sol_list);
        state.sol_idx = mod(state.sol_idx - 1 + delta, n) + 1;
        sol = state.sol_list{state.sol_idx};
        state.actualizando_ui = true;
        ddModel.Value = sol{1};
        actualizar_lista_datasets_sin_cargar(sol{1}, sol{2});
        ddDataset.Value = sol{2};
        state.actualizando_ui = false;
        cargar_dataset_seleccionado();
    end

    function actualizar_lista_datasets_sin_cargar(modelo, dataset_sel)
        md = state.simData.(modelo);
        nombres = fieldnames(md);
        nombres = nombres(~strcmp(nombres, 'session_meta'));
        nombres = nombres(cellfun(@(dn) isstruct(md.(dn)) && ...
            isfield(md.(dn), 'snapshots'), nombres));
        if isempty(nombres)
            nombres = {'(sin dataset)'};
        end
        ddDataset.Items = nombres;
        if nargin >= 2 && ismember(dataset_sel, nombres)
            ddDataset.Value = dataset_sel;
        else
            ddDataset.Value = nombres{1};
        end
    end

    function navegar_snapshot(delta)
        if isempty(state.snapshots)
            return;
        end
        nT = numel(state.snapshots);
        state.snapshot_actual = max(1, min(nT, state.snapshot_actual + delta));
        state.actualizando_ui = true;
        ddTiempo.Value = state.time_items{state.snapshot_actual};
        state.actualizando_ui = false;
        actualizar_info();
        actualizar_graficas();
    end

    function alternar_animacion(~, ~)
        if state.timer_on
            detener_timer();
            btnAuto.Text = 'Auto tiempo';
            tesis_auxiliares('tema_ui', 'button', btnAuto, 'secondary');
            establecer_estado('Animacion detenida.');
        else
            if isempty(state.snapshots)
                return;
            end
            state.anim_timer = timer('ExecutionMode', 'fixedRate', ...
                'Period', 0.8, 'TimerFcn', @paso_animacion);
            start(state.anim_timer);
            state.timer_on = true;
            btnAuto.Text = 'Detener auto';
            tesis_auxiliares('tema_ui', 'button', btnAuto, 'danger');
            establecer_estado('Animacion iniciada.');
        end
    end

    function paso_animacion(~, ~)
        if isempty(state.snapshots) || ~isvalid(f)
            detener_timer();
            return;
        end
        nT = numel(state.snapshots);
        state.snapshot_actual = mod(state.snapshot_actual, nT) + 1;
        state.actualizando_ui = true;
        ddTiempo.Value = state.time_items{state.snapshot_actual};
        state.actualizando_ui = false;
        actualizar_info();
        actualizar_graficas();
    end

    function al_presionar_tecla(~, ev)
        switch ev.Key
            case 'leftarrow'
                navegar_snapshot(-1);
            case 'rightarrow'
                navegar_snapshot(+1);
            case 'a'
                navegar_solucion(-1);
            case 'd'
                navegar_solucion(+1);
            case 'space'
                alternar_animacion();
        end
    end

    function actualizar_offset_base(~, ~)
        state.aplicar_offset_base = chkOffset.Value;
        actualizar_graficas();
    end

    function actualizar_factor(~, ~)
        state.k = max(0, min(1, editFactor.Value));
        editFactor.Value = state.k;
        actualizar_graficas();
    end

    function actualizar_filtro(~, ~)
        state.filtro_activo = chkFilter.Value;
        state.filtro_minimo = min(editMinT.Value, editMaxT.Value);
        state.filtro_maximo = max(editMinT.Value, editMaxT.Value);
        editMinT.Value = state.filtro_minimo;
        editMaxT.Value = state.filtro_maximo;
        actualizar_graficas();
    end

    function actualizar_graficas(origen, ~)
        if nargin >= 1 && isa(origen, 'matlab.ui.control.Button')
            insertar_separacion_log();
        end
        if isempty(state.snapshots)
            limpiar_ejes('Carga una simulacion para visualizar.');
            return;
        end
        idx = max(1, min(state.snapshot_actual, numel(state.snapshots)));
        snap = state.snapshots(idx);
        t_cur = obtener_tiempo_actual(snap, idx);
        [pts_all, T_orig, T_base] = obtener_campo_instante(idx);

        if isempty(pts_all) || isempty(T_orig)
            limpiar_ejes('No hay puntos termicos validos en este instante.');
            return;
        end

        [T_corr, factor_aplicado, t_rel_min, correccion_activa] = ...
            aplicar_correccion(T_orig, T_base, t_cur, pts_all);
        umbral_ablacion = obtener_umbral_ablacion(obtener_solucion_activa());

        [pts_orig_plot, T_orig_plot, etiqueta_orig] = ...
            preparar_puntos_originales(pts_all, T_orig, snap, umbral_ablacion);
        [pts_corr_plot, T_corr_plot, etiqueta_corr] = ...
            preparar_puntos_corregidos(pts_all, T_corr, umbral_ablacion);

        graficar_3d(axOriginal, pts_orig_plot, T_orig_plot, ...
            sprintf('Original | %s | t=%.4f min', etiqueta_orig, t_cur));
        graficar_3d(axCorregida, pts_corr_plot, T_corr_plot, ...
            sprintf('Corregida | %s | f=%.4f | t=%.4f min', ...
            etiqueta_corr, factor_aplicado, t_cur));
        graficar_sondas();

        actualizar_info();
        if correccion_activa
            if ~isempty(state.intervalo_correccion_min) && ...
                    t_rel_min > state.intervalo_correccion_min(2)
                detalle = sprintf('factor extrapolado=%.4f', factor_aplicado);
            else
                detalle = sprintf('factor aplicado=%.4f', factor_aplicado);
            end
        else
            detalle = 'sin correccion activa';
        end
        establecer_estado(sprintf('Instante %d/%d | t=%.4f min | %s.', ...
            idx, numel(state.snapshots), t_cur, detalle));
    end

    function limpiar_ejes(msg)
        limpiar_un_eje(axOriginal, msg);
        limpiar_un_eje(axCorregida, msg);
        limpiar_un_eje(axSondas, msg);
    end

    function limpiar_un_eje(ax, msg)
        colorbar(ax, 'off');
        cla(ax, 'reset');
        tesis_auxiliares('tema_ui', 'axes', ax);
        text(ax, 0.5, 0.5, msg, ...
            'Units', 'normalized', ...
            'HorizontalAlignment', 'center', ...
            'Color', theme.colors.textMuted);
        grid(ax, 'on');
    end

    function [pts_plot, T_plot, etiqueta] = ...
            preparar_puntos_originales(pts_all, T_orig, snap, umbral_ablacion)
        if state.filtro_activo
            mask = isfinite(T_orig) & ...
                T_orig >= state.filtro_minimo & T_orig <= state.filtro_maximo;
            pts_plot = pts_all(mask, :);
            T_plot = T_orig(mask);
            etiqueta = sprintf('filtro %.1f-%.1f C', ...
                state.filtro_minimo, state.filtro_maximo);
            return;
        end

        if isfield(snap, 'points') && ~isempty(snap.points) && ...
                isfield(snap, 'T') && ~isempty(snap.T)
            pts_plot = double(snap.points);
            T_plot = double(snap.T(:));
        else
            mask = isfinite(T_orig) & T_orig >= umbral_ablacion;
            pts_plot = pts_all(mask, :);
            T_plot = T_orig(mask);
        end
        etiqueta = sprintf('ablacion >= %.1f C', umbral_ablacion);
    end

    function [pts_plot, T_plot, etiqueta] = ...
            preparar_puntos_corregidos(pts_all, T_corr, umbral_ablacion)
        if state.filtro_activo
            mask = isfinite(T_corr) & ...
                T_corr >= state.filtro_minimo & T_corr <= state.filtro_maximo;
            pts_plot = pts_all(mask, :);
            T_plot = T_corr(mask);
            etiqueta = sprintf('filtro %.1f-%.1f C', ...
                state.filtro_minimo, state.filtro_maximo);
        else
            mask = isfinite(T_corr) & T_corr >= umbral_ablacion;
            pts_plot = pts_all(mask, :);
            T_plot = T_corr(mask);
            etiqueta = sprintf('ablacion >= %.1f C', umbral_ablacion);
        end
    end

    function graficar_3d(ax, pts, Tvals, titulo)
        colorbar(ax, 'off');
        cla(ax, 'reset');
        tesis_auxiliares('tema_ui', 'axes', ax);
        hold(ax, 'on');

        if isempty(pts) || isempty(Tvals)
            text(ax, 0.5, 0.5, 0.5, ...
                'Sin puntos para el rango actual', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'Color', theme.colors.textMuted);
            title(ax, titulo, 'Color', theme.colors.accent, ...
                'Interpreter', 'none', 'FontSize', 9);
            xlabel(ax, 'X (mm)');
            ylabel(ax, 'Y (mm)');
            zlabel(ax, 'Z (mm)');
            grid(ax, 'on');
            view(ax, 3);
            hold(ax, 'off');
            return;
        end

        pts = double(pts);
        Tvals = double(Tvals(:));
        validos = all(isfinite(pts), 2) & isfinite(Tvals);
        pts = pts(validos, :);
        Tvals = Tvals(validos);

        if isempty(pts)
            hold(ax, 'off');
            return;
        end

        modo = ddViz.Value;
        [pts_scatter, T_scatter] = limitar_puntos( ...
            pts, Tvals, state.max_puntos_scatter);
        if contains(modo, 'Scatter')
            scatter3(ax, pts_scatter(:,1), pts_scatter(:,2), pts_scatter(:,3), ...
                max(1, round(editPointSize.Value)), T_scatter, 'filled', ...
                'MarkerFaceAlpha', 0.72);
            colormap(ax, mapa_plasma(256));
            aplicar_limites_color(ax, T_scatter);
            cb = colorbar(ax);
            cb.Color = theme.colors.text;
            cb.Label.String = 'Temperatura (C)';
            cb.Label.Color = theme.colors.text;
        end

        if contains(modo, 'Surface') && size(pts, 1) >= 4
            try
                [pts_surface, ~] = limitar_puntos( ...
                    pts, Tvals, state.max_puntos_surface);
                aR = editAlpha.Value;
                if aR <= 0
                    ext = max(pts_surface) - min(pts_surface);
                    aR = max(2.0, ...
                        (prod(ext + eps) / size(pts_surface, 1))^(1/3) * 2.2);
                end
                shp = alphaShape(pts_surface(:,1), pts_surface(:,2), ...
                    pts_surface(:,3), aR);
                if numRegions(shp) == 0
                    aR = criticalAlpha(shp, 'one-region');
                    shp = alphaShape(pts_surface(:,1), pts_surface(:,2), ...
                        pts_surface(:,3), aR);
                end
                if numRegions(shp) >= 1
                    [tri, nod] = boundaryFacets(shp);
                    if size(tri, 1) >= 4
                        [tri, nod] = suavizado_laplaciano(tri, nod, 4);
                        patch(ax, 'Faces', tri, 'Vertices', nod, ...
                            'FaceColor', theme.colors.thermalRed, ...
                            'EdgeColor', 'none', ...
                            'FaceAlpha', 0.28);
                    end
                end
            catch ME
                escribir_log(sprintf('alphaShape omitido: %s', ME.message));
            end
        end

        hold(ax, 'off');
        xlabel(ax, 'X (mm)', 'Color', theme.colors.textMuted);
        ylabel(ax, 'Y (mm)', 'Color', theme.colors.textMuted);
        zlabel(ax, 'Z (mm)', 'Color', theme.colors.textMuted);
        title(ax, titulo, 'Color', theme.colors.accent, ...
            'Interpreter', 'none', 'FontSize', 9);
        grid(ax, 'on');
        view(ax, 3);
    end

    function graficar_sondas()
        colorbar(axSondas, 'off');
        cla(axSondas, 'reset');
        tesis_auxiliares('tema_ui', 'axes', axSondas);
        hold(axSondas, 'on');

        r = obtener_solucion_activa();
        if isempty(r) || ~isfield(r, 'probes') || ...
                ~isstruct(r.probes) || isempty(fieldnames(r.probes))
            text(axSondas, 0.5, 0.5, 'Sin datos de sondas', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'Color', theme.colors.textMuted);
            hold(axSondas, 'off');
            return;
        end

        probe_names = fieldnames(r.probes);
        seleccionado = ddProbe.Value;
        if strcmp(seleccionado, 'Todas') || startsWith(seleccionado, '(')
            to_plot = probe_names;
        elseif ismember(seleccionado, probe_names)
            to_plot = {seleccionado};
        else
            to_plot = probe_names;
        end

        t0 = min(editT0.Value, editT1.Value);
        t1 = max(editT0.Value, editT1.Value);
        colores = [
            0.95 0.45 0.12;
            0.35 0.78 0.95;
            0.58 0.92 0.38;
            0.95 0.75 0.22;
            0.88 0.38 0.80;
            0.72 0.72 0.72];
        plotted_any = false;

        for pi = 1:numel(to_plot)
            pn = to_plot{pi};
            pr = r.probes.(pn);
            if ~isfield(pr, 'T') || isempty(pr.T)
                continue;
            end
            T = double(pr.T(:));
            if isfield(pr, 't_min') && numel(pr.t_min) == numel(T)
                tv = double(pr.t_min(:));
            else
                tv = double(r.t_min(:));
                tv = tv(1:min(numel(tv), numel(T)));
                T = T(1:numel(tv));
            end
            win = isfinite(tv) & isfinite(T) & tv >= t0 & tv <= t1;
            if ~any(win)
                continue;
            end
            col = colores(mod(pi-1, size(colores, 1)) + 1, :);
            plot(axSondas, tv(win), T(win), 'o-', ...
                'LineWidth', 1.6, ...
                'MarkerSize', 3.2, ...
                'Color', col, ...
                'MarkerFaceColor', col, ...
                'DisplayName', sprintf('%s original', pn));
            plotted_any = true;

            if state.correccion_cargada
                Tbase = repmat(T(1), size(T));
                TcorrProbe = T;
                coord_probe = obtener_coordenada_sonda(pr);
                for kk = 1:numel(T)
                    TcorrProbe(kk) = aplicar_correccion( ...
                        T(kk), Tbase(kk), tv(kk), coord_probe);
                end
                plot(axSondas, tv(win), TcorrProbe(win), '--', ...
                    'LineWidth', 1.8, ...
                    'Color', min(1, col + 0.18), ...
                    'DisplayName', sprintf('%s corregida', pn));
            end
        end

        if plotted_any
            t_cur = obtener_tiempo_actual(state.snapshots(state.snapshot_actual), ...
                state.snapshot_actual);
            yl = ylim(axSondas);
            plot(axSondas, [t_cur t_cur], yl, '-', ...
                'Color', [0.85 0.85 0.85], ...
                'LineWidth', 1.0, ...
                'HandleVisibility', 'off');
            lg = legend(axSondas, 'show', 'Location', 'northwest');
            lg.TextColor = theme.colors.text;
            lg.Color = theme.colors.card;
            lg.EdgeColor = theme.colors.border;
        else
            text(axSondas, 0.5, 0.5, ...
                'No hay sondas dentro del intervalo seleccionado', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'Color', theme.colors.textMuted);
        end

        hold(axSondas, 'off');
        xlabel(axSondas, 'Tiempo (min)', 'Color', theme.colors.textMuted);
        ylabel(axSondas, 'Temperatura (C)', 'Color', theme.colors.textMuted);
        title(axSondas, sprintf('%s / %s - sondas', ...
            state.modelo_actual, state.dataset_actual), ...
            'Color', theme.colors.accent, ...
            'Interpreter', 'none', 'FontSize', 9);
        if t0 < t1
            xlim(axSondas, [t0 t1]);
        end
        grid(axSondas, 'on');
    end

    function [puntos, temperatura, temperatura_base] = obtener_campo_instante(idx)
        puntos = [];
        temperatura = [];
        tiene_campo_completo = isstruct(state.full_field) && ...
            isfield(state.full_field, 'points') && ...
            isfield(state.full_field, 'T_C') && ...
            size(state.full_field.T_C, 2) >= idx;

        if tiene_campo_completo
            puntos_todos = double(state.full_field.points);
            temperatura_todos = double(state.full_field.T_C(:, idx));
            temperatura_base_todos = double(state.full_field.T_C(:, 1));
            validos = all(isfinite(puntos_todos), 2) & ...
                isfinite(temperatura_todos) & isfinite(temperatura_base_todos);
            puntos = puntos_todos(validos, :);
            temperatura = temperatura_todos(validos);
            temperatura_base = temperatura_base_todos(validos);
        else
            snap = state.snapshots(idx);
            if isfield(snap, 'points')
                puntos = double(snap.points);
            end
            if isfield(snap, 'T')
                temperatura = double(snap.T(:));
            end
            if isfinite(state.temperatura_base_sim_C)
                temperatura_base = repmat(state.temperatura_base_sim_C, ...
                    size(temperatura));
            else
                temperatura_base = repmat(37, size(temperatura));
            end
        end
    end

    function [T_corr, factor_aplicado, t_rel_min, correccion_activa] = ...
            aplicar_correccion(T_orig, T_base, t_min, puntos)
        if nargin < 4
            puntos = [];
        end
        if ~isempty(state.zonas_correccion) && ~isempty(puntos)
            [T_corr, factor_aplicado, t_rel_min, correccion_activa] = ...
                aplicar_correccion_zonal(T_orig, T_base, t_min, puntos);
            return;
        end

        [factor_modelo, t_rel_min, correccion_activa] = ...
            evaluar_factor_correccion(t_min);
        if ~correccion_activa
            T_corr = T_orig;
            factor_aplicado = 1;
            return;
        end

        factor_aplicado = 1 + state.k * (factor_modelo - 1);
        offset_aplicado_C = 0;
        if state.aplicar_offset_base
            offset_aplicado_C = state.k * state.offset_base_C;
        end
        T_corr = T_base + offset_aplicado_C + ...
            factor_aplicado .* (T_orig - T_base);
    end

    function [T_corr, factor_promedio, t_rel_ref, correccion_activa] = ...
            aplicar_correccion_zonal(T_orig, T_base, t_min, puntos)
        T_corr = T_orig;
        factor_promedio = 1;
        correccion_activa = false;
        t_rel_ref = t_min - state.t_origen_dataset_min;
        if ~state.correccion_cargada || isempty(state.zonas_correccion)
            return;
        end
        if size(puntos, 1) == 1 && numel(T_orig) > 1
            puntos = repmat(puntos, numel(T_orig), 1);
        end
        if size(puntos, 1) ~= numel(T_orig) || size(puntos, 2) < 3
            [T_corr, factor_promedio, t_rel_ref, correccion_activa] = ...
                aplicar_correccion(T_orig, T_base, t_min);
            return;
        end

        factores_aplicados = NaN(numel(state.zonas_correccion), 1);
        for zi = 1:numel(state.zonas_correccion)
            zona = state.zonas_correccion(zi);
            [factor_modelo, t_rel_z, activa_z] = evaluar_factor_zona(t_min, zona);
            if ~activa_z
                continue;
            end
            mask_z = mascara_zona_puntos(puntos, zona, zi, ...
                numel(state.zonas_correccion));
            if ~any(mask_z)
                continue;
            end
            factor_z = 1 + state.k * (factor_modelo - 1);
            offset_z = 0;
            if state.aplicar_offset_base && isfield(zona, 'offset_base_C')
                offset_z = state.k * zona.offset_base_C;
            elseif state.aplicar_offset_base
                offset_z = state.k * state.offset_base_C;
            end
            T_corr(mask_z) = T_base(mask_z) + offset_z + ...
                factor_z .* (T_orig(mask_z) - T_base(mask_z));
            factores_aplicados(zi) = factor_z;
            t_rel_ref = t_rel_z;
            correccion_activa = true;
        end
        if correccion_activa
            factor_promedio = mean(factores_aplicados(isfinite(factores_aplicados)), ...
                'omitnan');
        end
        if ~isfinite(factor_promedio)
            factor_promedio = 1;
        end
    end

    function [factor, t_rel_min, correccion_activa] = evaluar_factor_zona(t_min, zona)
        factor = 1;
        correccion_activa = false;
        if isfield(zona, 't_origen_simulacion_min') && ...
                isscalar(zona.t_origen_simulacion_min) && ...
                isfinite(zona.t_origen_simulacion_min)
            t_rel_min = t_min - zona.t_origen_simulacion_min;
        else
            t_rel_min = t_min - state.t_origen_dataset_min;
        end
        if ~isfield(zona, 't_rel_min') || ~isfield(zona, 'factor_enfriamiento')
            return;
        end
        t_z = zona.t_rel_min(:);
        f_z = zona.factor_enfriamiento(:);
        if numel(t_z) < 2 || numel(t_z) ~= numel(f_z)
            return;
        end
        if t_rel_min < min(t_z) - 1e-9
            return;
        end
        if t_rel_min <= max(t_z) + 1e-9
            factor = interp1(t_z, f_z, t_rel_min, 'pchip');
        elseif isfield(zona, 'extrapolacion_factor')
            factor = extrapolar_factor(t_rel_min, zona.extrapolacion_factor);
        else
            factor = f_z(end);
        end
        factor = max(0, min(1, factor));
        correccion_activa = isfinite(factor);
        if ~correccion_activa
            factor = 1;
        end
    end

    function mask_z = mascara_zona_puntos(puntos, zona, idx_zona, n_zonas)
        z_min = -Inf;
        z_max = Inf;
        if isfield(zona, 'z_min_mm')
            z_min = zona.z_min_mm;
        end
        if isfield(zona, 'z_max_mm')
            z_max = zona.z_max_mm;
        end
        z = puntos(:, 3);
        if idx_zona == n_zonas
            mask_z = z >= z_min & z <= z_max;
        else
            mask_z = z >= z_min & z < z_max;
        end
    end

    function coord = obtener_coordenada_sonda(sonda)
        coord = [];
        candidatos = {'coord_mm', 'coords_mm', 'point_mm', 'pos_mm', ...
            'position_mm', 'coord', 'coords', 'point', 'position'};
        for ci = 1:numel(candidatos)
            campo = candidatos{ci};
            if isfield(sonda, campo)
                valor = double(sonda.(campo));
                if numel(valor) >= 3 && all(isfinite(valor(1:3)))
                    coord = reshape(valor(1:3), 1, 3);
                    return;
                end
            end
        end
    end

    function [factor, t_rel_min, correccion_activa] = ...
            evaluar_factor_correccion(t_min)
        factor = 1;
        correccion_activa = false;
        t_rel_min = t_min - state.t_origen_dataset_min;
        if ~state.correccion_cargada || isempty(state.intervalo_correccion_min)
            return;
        end
        if numel(state.t_correccion_rel_min) < 2 || ...
                numel(state.factor_enfriamiento) ~= ...
                numel(state.t_correccion_rel_min)
            return;
        end
        if t_rel_min < state.intervalo_correccion_min(1) - 1e-9
            return;
        end
        if t_rel_min <= state.intervalo_correccion_min(2) + 1e-9
            factor = interp1(state.t_correccion_rel_min, ...
                state.factor_enfriamiento, t_rel_min, 'pchip');
        else
            factor = extrapolar_factor(t_rel_min, state.extrapolacion_factor);
        end
        factor = max(0, min(1, factor));
        correccion_activa = isfinite(factor);
        if ~correccion_activa
            factor = 1;
        end
    end

    function actualizar_origen_temporal()
        if isempty(state.times_min)
            return;
        end
        tv = state.times_min(isfinite(state.times_min));
        if isempty(tv)
            return;
        end
        t_min_dataset = min(tv);
        t_max_dataset = max(tv);
        t_sugerido = state.t_origen_correccion_sugerido_min;
        if isscalar(t_sugerido) && isfinite(t_sugerido) && ...
                t_sugerido >= t_min_dataset && t_sugerido <= t_max_dataset
            state.t_origen_dataset_min = t_sugerido;
        else
            state.t_origen_dataset_min = t_min_dataset;
        end
    end

    function exportar_corregido(~, ~)
        if isempty(state.simData) || isempty(state.snapshots)
            uialert(f, 'No hay simulacion cargada.', 'Error');
            return;
        end
        if ~state.correccion_cargada
            uialert(f, 'Carga primero el archivo de correccion termica.', 'Error');
            return;
        end
        insertar_separacion_log();

        nombre_default = sprintf('%s_%s_corregido.mat', ...
            state.modelo_actual, state.dataset_actual);
        ruta_default = fullfile(data_paths.datasets_corregidos, nombre_default);
        [file, path] = uiputfile('*.mat', ...
            'Guardar dataset corregido', ruta_default);
        if isequal(file, 0)
            return;
        end

        establecer_estado('Exportando dataset corregido...');
        ds_orig = state.simData.(state.modelo_actual).(state.dataset_actual);
        ds_corr = ds_orig;
        umbral_ablacion = obtener_umbral_ablacion(ds_orig);
        tiene_campo_completo = isfield(ds_orig, 'full_field') && ...
            isfield(ds_orig.full_field, 'points') && ...
            isfield(ds_orig.full_field, 'T_C');

        if tiene_campo_completo
            puntos_campo = double(ds_orig.full_field.points);
            T_base_campo = double(ds_orig.full_field.T_C(:, 1));
            T_campo_corregido = nan(size(ds_orig.full_field.T_C), 'single');
        end

        for k = 1:numel(ds_corr.snapshots)
            t_k = obtener_tiempo_dataset(ds_orig, k);
            if tiene_campo_completo && size(ds_orig.full_field.T_C, 2) >= k
                T_orig_k = double(ds_orig.full_field.T_C(:, k));
                T_base_k = T_base_campo;
                puntos_k = puntos_campo;
            else
                T_orig_k = double(ds_orig.snapshots(k).T(:));
                if isfinite(state.temperatura_base_sim_C)
                    T_base_k = repmat(state.temperatura_base_sim_C, ...
                        size(T_orig_k));
                else
                    T_base_k = repmat(37, size(T_orig_k));
                end
                puntos_k = double(ds_orig.snapshots(k).points);
            end

            [T_corr_k, factor_aplicado, t_rel_min, correccion_activa] = ...
                aplicar_correccion(T_orig_k, T_base_k, t_k, puntos_k);

            if tiene_campo_completo && size(T_campo_corregido, 2) >= k
                T_campo_corregido(:, k) = single(T_corr_k);
            end

            validos = isfinite(T_corr_k) & all(isfinite(puntos_k), 2);
            mascara_ablacion = validos & T_corr_k >= umbral_ablacion;
            ds_corr.snapshots(k).factor_enfriamiento_aplicado = factor_aplicado;
            ds_corr.snapshots(k).t_correccion_rel_min = t_rel_min;
            ds_corr.snapshots(k).correccion_activa = correccion_activa;
            ds_corr.snapshots(k).mask_ablacion_corregida = mascara_ablacion;
            ds_corr.snapshots(k).points = puntos_k(mascara_ablacion, :);
            ds_corr.snapshots(k).T = T_corr_k(mascara_ablacion);
            ds_corr.snapshots(k).points_ablacion_corregida = ...
                ds_corr.snapshots(k).points;
            ds_corr.snapshots(k).T_ablacion_corregida = ...
                ds_corr.snapshots(k).T;
            ds_corr.snapshots(k).n_pts_ablacion_corregida = ...
                sum(mascara_ablacion);
            ds_corr.snapshots(k).n_pts_filtered = sum(mascara_ablacion);
            ds_corr.snapshots(k).n_pts_total = sum(validos);
            if any(validos)
                ds_corr.snapshots(k).T_min_C = min(T_corr_k(validos));
                ds_corr.snapshots(k).T_max_C = max(T_corr_k(validos));
            else
                ds_corr.snapshots(k).T_min_C = NaN;
                ds_corr.snapshots(k).T_max_C = NaN;
            end
        end

        if tiene_campo_completo
            ds_corr.full_field.T_C = T_campo_corregido;
            ds_corr.full_field.descripcion = ...
                ['Campo completo corregido mediante factor temporal ', ...
                 'sobre incremento termico local.'];
        end

        ds_corr = corregir_sondas_dataset(ds_corr);
        if ~isfield(ds_corr, 'metadata') || ~isstruct(ds_corr.metadata)
            ds_corr.metadata = struct();
        end
        ds_corr.metadata.correccion_termica = struct( ...
            'convencion', 'factor_sobre_incremento_termico_local', ...
            'formula', ['T_corr = T_base_local + offset_base + ', ...
                'factor*(T_original - T_base_local)'], ...
            'metodo', state.metodo_correccion, ...
            'modo_espacial', state.modo_correccion_espacial, ...
            'intensidad_correccion', state.k, ...
            'aplicar_offset_base', state.aplicar_offset_base, ...
            'temperatura_base_exp_C', state.temperatura_base_exp_C, ...
            'temperatura_base_sim_C', state.temperatura_base_sim_C, ...
            'offset_base_C', state.offset_base_C, ...
            't_origen_dataset_min', state.t_origen_dataset_min, ...
            'intervalo_relativo_valido_min', state.intervalo_correccion_min, ...
            't_rel_min', state.t_correccion_rel_min, ...
            'factor_enfriamiento', state.factor_enfriamiento, ...
            'zonas', state.zonas_correccion, ...
            'extrapolacion_factor', state.extrapolacion_factor, ...
            'umbral_ablacion_C', umbral_ablacion, ...
            'fecha_aplicacion', char(datetime('now', ...
                'Format', 'yyyy-MM-dd HH:mm:ss')));

        dataset = struct();
        dataset.(state.modelo_actual).(state.dataset_actual) = ds_corr;
        if isfield(state.simData.(state.modelo_actual), 'session_meta')
            dataset.(state.modelo_actual).session_meta = ...
                state.simData.(state.modelo_actual).session_meta;
        end
        save(fullfile(path, file), 'dataset', '-v7.3');
        establecer_estado(sprintf('Dataset corregido exportado: %s', file));
        uialert(f, 'Exportacion completada.', 'Exito', 'Icon', 'success');
    end

    function ds_corr = corregir_sondas_dataset(ds_corr)
        if ~isfield(ds_corr, 'probes') || ~isstruct(ds_corr.probes)
            return;
        end
        nombres_sondas = fieldnames(ds_corr.probes);
        for p = 1:numel(nombres_sondas)
            nombre = nombres_sondas{p};
            sonda = ds_corr.probes.(nombre);
            if ~isfield(sonda, 'T') || isempty(sonda.T)
                continue;
            end
            T = double(sonda.T(:));
            if isfield(sonda, 't_min') && numel(sonda.t_min) == numel(T)
                tv = double(sonda.t_min(:));
            else
                tv = double(ds_corr.t_min(:));
                tv = tv(1:min(numel(tv), numel(T)));
                T = T(1:numel(tv));
            end
            T_base = repmat(T(1), size(T));
            T_corr = T;
            coord_probe = obtener_coordenada_sonda(sonda);
            for kk = 1:min(numel(T), numel(tv))
                T_corr(kk) = aplicar_correccion(T(kk), T_base(kk), tv(kk), ...
                    coord_probe);
            end
            ds_corr.probes.(nombre).T_original = reshape(sonda.T, size(sonda.T));
            ds_corr.probes.(nombre).T = reshape(T_corr, size(T_corr));
        end
    end

    function mostrar_funcion_correccion(~, ~)
        if isempty(state.datos_correlacion_completa)
            uialert(f, ['No hay curvas completas de correlacion. ', ...
                'Carga un .mat generado por el correlador.'], 'Informacion');
            return;
        end
        insertar_separacion_log();

        data = state.datos_correlacion_completa;
        t = data.t_comun(:);
        y_exp = data.y_exp(:);
        y_sim = data.y_sim(:);
        factor = interp1(state.t_correccion_rel_min, ...
            state.factor_enfriamiento, t, 'pchip', 'extrap');
        factor = max(0, min(1, factor));
        y_sim_corr = state.temperatura_base_sim_C + state.offset_base_C + ...
            factor .* (y_sim - state.temperatura_base_sim_C);
        if ~isempty(data.p_arreglo)
            p_vals = polyval(data.p_arreglo, t);
        else
            p_vals = NaN(size(t));
        end
        delta_orig = y_sim - y_exp;

        if isempty(state.figura_funcion_correccion) || ...
                ~isvalid(state.figura_funcion_correccion)
            state.figura_funcion_correccion = figure( ...
                'Name', 'Funcion de correccion termica', ...
                'Position', [60 60 980 430], ...
                'Color', theme.colors.bg);
        else
            figure(state.figura_funcion_correccion);
            clf(state.figura_funcion_correccion);
        end

        ax1 = subplot(1, 2, 1, 'Parent', state.figura_funcion_correccion);
        plot(ax1, t, y_sim, 'Color', [0.35 0.65 1.0], 'LineWidth', 2);
        hold(ax1, 'on');
        plot(ax1, t, y_exp, '--', 'Color', [1.0 0.35 0.25], 'LineWidth', 1.6);
        plot(ax1, t, y_sim_corr, '-.', 'Color', [0.45 0.90 0.35], 'LineWidth', 2);
        hold(ax1, 'off');
        xlabel(ax1, 'Tiempo relativo (min)');
        ylabel(ax1, 'Temperatura (C)');
        title(ax1, 'Curvas de correccion');
        legend(ax1, {'Simulacion', 'Experimental', 'Simulacion corregida'}, ...
            'Location', 'best');
        grid(ax1, 'on');

        ax2 = subplot(1, 2, 2, 'Parent', state.figura_funcion_correccion);
        yyaxis(ax2, 'left');
        if isempty(state.zonas_correccion)
            plot(ax2, t, factor, 'Color', [0.45 0.90 0.35], ...
                'LineWidth', 2, 'DisplayName', 'Factor');
        else
            colores_z = lines(numel(state.zonas_correccion));
            hold(ax2, 'on');
            for zi = 1:numel(state.zonas_correccion)
                zona = state.zonas_correccion(zi);
                plot(ax2, zona.t_rel_min(:), zona.factor_enfriamiento(:), ...
                    'Color', colores_z(zi, :), 'LineWidth', 1.8, ...
                    'DisplayName', sprintf('%s z=%.1f mm', ...
                    zona.label, zona.profundidad_sim_mm));
            end
            plot(ax2, t, factor, ':', ...
                'Color', [0.45 0.90 0.35], 'LineWidth', 1.1, ...
                'DisplayName', 'Global/seleccion');
            hold(ax2, 'off');
        end
        ylabel(ax2, 'Factor de enfriamiento');
        ylim(ax2, [0 1]);
        yyaxis(ax2, 'right');
        plot(ax2, t, delta_orig, 'Color', [0.35 0.65 1.0], ...
            'LineWidth', 1.2, 'DisplayName', 'Delta Sim-Exp');
        hold(ax2, 'on');
        plot(ax2, t, p_vals, '--', 'Color', [0.92 0.92 0.92], ...
            'LineWidth', 1.0, 'DisplayName', 'Polinomio');
        hold(ax2, 'off');
        xlabel(ax2, 'Tiempo relativo (min)');
        ylabel(ax2, 'Delta T historica (C)');
        title(ax2, 'Factor y polinomio legado');
        legend(ax2, 'show', 'Location', 'best');
        grid(ax2, 'on');
        establecer_estado('Funcion de correccion mostrada.');
    end

    function actualizar_info()
        if isempty(state.snapshots)
            lblInfo.Text = 'Sin datos cargados.';
            return;
        end
        idx = max(1, min(state.snapshot_actual, numel(state.snapshots)));
        t_cur = obtener_tiempo_actual(state.snapshots(idx), idx);
        lblInfo.Text = sprintf('%d/%d soluciones | inst %d/%d | t=%.4f min', ...
            max(1, numel(state.sol_list)), numel(state.sol_list), ...
            idx, numel(state.snapshots), t_cur);
    end

    function idx = buscar_solucion(modelo, dsName)
        idx = 1;
        for k = 1:numel(state.sol_list)
            if strcmp(state.sol_list{k}{1}, modelo) && ...
                    strcmp(state.sol_list{k}{2}, dsName)
                idx = k;
                return;
            end
        end
    end

    function r = obtener_solucion_activa()
        r = [];
        if isempty(state.simData) || isempty(state.modelo_actual) || ...
                isempty(state.dataset_actual)
            return;
        end
        try
            r = state.simData.(state.modelo_actual).(state.dataset_actual);
        catch
            r = [];
        end
    end

    function t = obtener_tiempo_actual(snap, idx)
        if isfield(snap, 't_min') && isfinite(snap.t_min)
            t = snap.t_min;
        elseif idx <= numel(state.times_min)
            t = state.times_min(idx);
        else
            t = idx - 1;
        end
    end

    function t = obtener_tiempo_dataset(dsData, idx)
        if isfield(dsData, 'snapshots') && idx <= numel(dsData.snapshots) && ...
                isfield(dsData.snapshots(idx), 't_min') && ...
                isfinite(dsData.snapshots(idx).t_min)
            t = dsData.snapshots(idx).t_min;
        elseif isfield(dsData, 't_min') && idx <= numel(dsData.t_min)
            t = dsData.t_min(idx);
        else
            t = idx - 1;
        end
    end

    function umbral = obtener_umbral_ablacion(dsData)
        umbral = 60;
        if isstruct(dsData) && isfield(dsData, 'metadata') && ...
                isfield(dsData.metadata, 'T_ablacion') && ...
                isfinite(dsData.metadata.T_ablacion)
            umbral = dsData.metadata.T_ablacion;
        end
    end

    function establecer_estado(msg)
        lblStatus.Text = msg;
        escribir_log(msg);
        drawnow limitrate;
    end

    function escribir_log(msg)
        if exist('txtLog', 'var') && isvalid(txtLog)
            marca = char(datetime('now', 'Format', 'HH:mm:ss'));
            txtLog.Value = [{sprintf('[%s] %s', marca, msg)}; txtLog.Value(:)];
        end
    end

    function insertar_separacion_log()
        if exist('txtLog', 'var') && isvalid(txtLog)
            txtLog.Value = [repmat({''}, 5, 1); txtLog.Value(:)];
        end
        drawnow limitrate;
    end

    function detener_timer()
        if ~isempty(state.anim_timer)
            try
                stop(state.anim_timer);
                delete(state.anim_timer);
            catch
            end
        end
        state.anim_timer = [];
        state.timer_on = false;
    end

    function cerrar_dashboard(~, ~)
        detener_timer();
        if ~isempty(state.figura_funcion_correccion) && ...
                isvalid(state.figura_funcion_correccion)
            try
                close(state.figura_funcion_correccion);
            catch
            end
        end
        delete(f);
    end
end

function sol_list = construir_lista_soluciones(ds)
    sol_list = {};
    if isempty(ds) || ~isstruct(ds)
        return;
    end
    model_names = fieldnames(ds);
    for mi = 1:numel(model_names)
        mn = model_names{mi};
        if strcmp(mn, 'session_meta')
            continue;
        end
        md = ds.(mn);
        if ~isstruct(md)
            continue;
        end
        ds_names = fieldnames(md);
        for di = 1:numel(ds_names)
            dn = ds_names{di};
            if strcmp(dn, 'session_meta')
                continue;
            end
            r = md.(dn);
            if isstruct(r) && isfield(r, 'snapshots')
                sol_list{end+1} = {mn, dn}; %#ok<AGROW>
            end
        end
    end
end

function [pts_out, T_out] = limitar_puntos(pts, Tvals, max_puntos)
    n = size(pts, 1);
    if n <= max_puntos
        pts_out = pts;
        T_out = Tvals;
        return;
    end
    idx = unique(round(linspace(1, n, max_puntos)));
    pts_out = pts(idx, :);
    T_out = Tvals(idx);
end

function aplicar_limites_color(ax, Tvals)
    tmin = min(Tvals);
    tmax = max(Tvals);
    if ~isfinite(tmin) || ~isfinite(tmax)
        return;
    end
    if tmin == tmax
        tmin = tmin - 0.5;
        tmax = tmax + 0.5;
    end
    clim(ax, [tmin tmax]);
end

function [tri_o, nod_o] = suavizado_laplaciano(tri, nod, n)
    nod_o = nod;
    nn = size(nod, 1);
    for it = 1:n
        nb = nod_o;
        for ii = 1:nn
            [r, ~] = find(tri == ii);
            v = unique(tri(r, :));
            v(v == ii) = [];
            if ~isempty(v)
                nb(ii,:) = mean(nod_o(v,:), 1);
            end
        end
        nod_o = nb;
    end
    tri_o = tri;
end

function cmap = mapa_plasma(n)
    if nargin < 1
        n = 256;
    end
    kt = [0; 0.25; 0.50; 0.75; 1];
    kc = [0.050, 0.030, 0.528;
          0.479, 0.015, 0.683;
          0.799, 0.159, 0.450;
          0.973, 0.463, 0.183;
          0.940, 0.975, 0.131];
    t = linspace(0, 1, n)';
    cmap = max(0, min(1, [interp1(kt, kc(:,1), t, 'pchip'), ...
                          interp1(kt, kc(:,2), t, 'pchip'), ...
                          interp1(kt, kc(:,3), t, 'pchip')]));
end

function [factor, base_exp_C, base_sim_C, offset_base_C] = ...
        construir_factor_desde_curvas(y_exp, y_sim)
    base_exp_C = y_exp(1);
    base_sim_C = y_sim(1);
    incremento_exp = y_exp - base_exp_C;
    incremento_sim = y_sim - base_sim_C;
    umbral = max(0.5, 0.01 * max(abs(incremento_sim)));
    validos = isfinite(incremento_exp) & isfinite(incremento_sim) & ...
        incremento_sim >= umbral;
    if ~any(validos)
        error('No existe calentamiento suficiente para calcular el factor.');
    end
    muestras = incremento_exp(validos) ./ incremento_sim(validos);
    muestras = max(0, min(1, muestras));
    indices = (1:numel(y_exp))';
    factor = interp1(indices(validos), muestras, indices, 'pchip', 'extrap');
    factor = max(0, min(1, factor));
    primer_valido = find(validos, 1, 'first');
    factor(1:primer_valido-1) = factor(primer_valido);
    offset_base_C = base_exp_C - base_sim_C;
end

function modelo = crear_extrapolacion_factor(t_min, factor)
    t_min = t_min(:);
    factor = factor(:);
    validos = isfinite(t_min) & isfinite(factor);
    t_min = t_min(validos);
    factor = factor(validos);
    [t_min, idx_unique] = unique(t_min, 'stable');
    factor = factor(idx_unique);
    if numel(t_min) < 12 || t_min(end) <= t_min(1)
        modelo = crear_modelo_factor_constante(t_min, factor);
        return;
    end

    fraccion_entrenamiento = 0.50;
    t_inicio = t_min(end) - fraccion_entrenamiento * ...
        (t_min(end) - t_min(1));
    idx_train = t_min >= t_inicio;
    n_uniforme = min(301, max(40, sum(idx_train)));
    t_uniforme = linspace(t_min(find(idx_train, 1, 'first')), ...
        t_min(end), n_uniforme)';
    factor_uniforme = interp1(t_min, factor, t_uniforme, 'pchip');

    n_muestras = numel(factor_uniforme);
    longitud_ventana = min(80, max(12, floor(n_muestras / 4)));
    longitud_ventana = min(longitud_ventana, n_muestras - 2);
    n_columnas = n_muestras - longitud_ventana + 1;
    media_factor = mean(factor_uniforme);
    factor_centrado = factor_uniforme - media_factor;
    matriz_trayectoria = zeros(longitud_ventana, n_columnas);
    for c = 1:n_columnas
        matriz_trayectoria(:, c) = factor_centrado(c:c+longitud_ventana-1);
    end

    [modos_pca, valores_singulares, ~] = svd(matriz_trayectoria, 'econ');
    energia = diag(valores_singulares).^2;
    if ~any(energia > 0)
        modelo = crear_modelo_factor_constante(t_min, factor);
        return;
    end
    energia_acumulada = cumsum(energia) / sum(energia);
    rango_pca = find(energia_acumulada >= 0.99, 1, 'first');
    rango_pca = max(1, min([rango_pca, 8, longitud_ventana - 2]));
    modos_retenidos = modos_pca(:, 1:rango_pca);
    ultima_fila = modos_retenidos(end, :);
    denominador = 1 - sum(ultima_fila.^2);
    if denominador <= 1e-8
        modelo = crear_modelo_factor_constante(t_min, factor);
        return;
    end
    coeficientes = ...
        (modos_retenidos(1:end-1, :) * ultima_fila') / denominador;

    n_cambios = min(40, n_muestras - 1);
    cambios = diff(factor_uniforme(end-n_cambios:end));
    max_cambio = max(1e-6, 5 * median(abs(cambios)));
    margen = max(0.01, 0.20 * range(factor_uniforme));
    limites_extrapolacion = [ ...
        max(0, min(factor_uniforme) - margen), ...
        min(1, max(factor_uniforme) + margen)];
    modelo = struct( ...
        'metodo', 'pca_temporal_embebido_ssa', ...
        't_inicio_min', t_min(end), ...
        'factor_inicio', factor(end), ...
        'paso_min', median(diff(t_uniforme)), ...
        'media_factor', media_factor, ...
        'longitud_ventana', longitud_ventana, ...
        'rango_pca', rango_pca, ...
        'energia_retenida', energia_acumulada(rango_pca), ...
        'coeficientes_recurrencia', coeficientes(:), ...
        'historia_centrada', factor_centrado(end-longitud_ventana+2:end), ...
        'max_cambio_por_paso', max_cambio, ...
        'limites_factor', [0, 1], ...
        'limites_extrapolacion', limites_extrapolacion, ...
        'fraccion_entrenamiento', fraccion_entrenamiento, ...
        'continua_en_valor', true);
end

function modelo = crear_modelo_factor_constante(t_min, factor)
    if isempty(t_min) || isempty(factor)
        t_inicio = 0;
        factor_inicio = 1;
    else
        t_inicio = t_min(end);
        factor_inicio = max(0, min(1, factor(end)));
    end
    modelo = struct( ...
        'metodo', 'factor_constante_respaldo', ...
        't_inicio_min', t_inicio, ...
        'factor_inicio', factor_inicio, ...
        'limites_factor', [0, 1], ...
        'continua_en_valor', true);
end

function factor = extrapolar_factor(t_rel_min, modelo)
    if isempty(fieldnames(modelo))
        factor = 1;
        return;
    end
    if strcmp(modelo.metodo, 'pca_temporal_embebido_ssa')
        factor = extrapolar_factor_pca(t_rel_min, modelo);
    elseif isfield(modelo, 'constante_relajacion_min')
        dt = max(0, t_rel_min - modelo.t_inicio_min);
        tau = max(eps, modelo.constante_relajacion_min);
        factor = modelo.factor_asintotico + ...
            (modelo.factor_inicio - modelo.factor_asintotico) * exp(-dt / tau);
    else
        factor = modelo.factor_inicio;
    end
end

function factor = extrapolar_factor_pca(t_rel_min, modelo)
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

function ejecutar_selftest(varargin)
    sim_path = 'Dataset_Termico_Masivo.mat';
    corr_path = 'Correlacion_4 antenas_30 watt_antena 15min_vs_Registro_Sondas_Temperatura.mat';
    if numel(varargin) >= 1 && ~isempty(varargin{1})
        sim_path = varargin{1};
    end
    if numel(varargin) >= 2 && ~isempty(varargin{2})
        corr_path = varargin{2};
    end

    assert(isfile(sim_path), 'No existe el .mat de simulacion: %s', sim_path);
    assert(isfile(corr_path), 'No existe el .mat de correccion: %s', corr_path);

    raw = load(sim_path, 'dataset');
    ds = raw.dataset;
    sol_list = construir_lista_soluciones(ds);
    assert(~isempty(sol_list), 'No se encontraron soluciones.');
    sol = sol_list{1};
    r = ds.(sol{1}).(sol{2});
    assert(isfield(r, 'snapshots') && ~isempty(r.snapshots), ...
        'La solucion no contiene snapshots.');
    assert(isfield(r, 'probes'), 'La solucion no contiene probes.');
    assert(isfield(r, 'full_field') && isfield(r.full_field, 'T_C'), ...
        'La solucion no contiene full_field.T_C.');

    corr = load(corr_path);
    offset_base = 0;
    if isfield(corr, 'correccion_termica')
        ct = corr.correccion_termica;
        assert(isfield(ct, 't_rel_min') && isfield(ct, 'factor_enfriamiento'), ...
            'correccion_termica incompleta.');
        t_corr = ct.t_rel_min(:);
        factor = ct.factor_enfriamiento(:);
        if isfield(ct, 'offset_base_C')
            offset_base = ct.offset_base_C;
        end
    else
        [factor, ~, ~, ~] = construir_factor_desde_curvas( ...
            corr.y_exp_interp(:), corr.y_sim_interp(:));
        t_corr = corr.t_comun(:);
    end
    modelo = crear_extrapolacion_factor(t_corr, factor);
    f1 = interp1(t_corr, factor, t_corr(1), 'pchip');
    f2 = extrapolar_factor(max(t_corr) + 1, modelo);
    assert(isfinite(f1) && isfinite(f2), ...
        'La correccion/extrapolacion produjo valores no finitos.');

    idx_t = min(size(r.full_field.T_C, 2), numel(r.snapshots));
    T_base = double(r.full_field.T_C(:, 1));
    T_orig = double(r.full_field.T_C(:, idx_t));
    validos = isfinite(T_base) & isfinite(T_orig);
    t_dataset = r.t_min(:);
    t_rel = t_dataset(idx_t) - min(t_dataset);
    if t_rel <= max(t_corr)
        factor_aplicado = interp1(t_corr, factor, t_rel, 'pchip');
    else
        factor_aplicado = extrapolar_factor(t_rel, modelo);
    end
    factor_aplicado = max(0, min(1, factor_aplicado));
    T_corr = T_base + offset_base + factor_aplicado .* (T_orig - T_base);
    assert(any(isfinite(T_corr(validos))), ...
        'La correccion del campo no produjo temperaturas finitas.');
    umbral = 60;
    if isfield(r, 'metadata') && isfield(r.metadata, 'T_ablacion')
        umbral = r.metadata.T_ablacion;
    end
    n_orig = sum(validos & T_orig >= umbral);
    n_corr = sum(validos & T_corr >= umbral);

    fprintf(['SELFTEST_OK soluciones=%d primera=%s/%s snaps=%d probes=%d ', ...
        'factor_ini=%.4f factor_extra=%.4f abl_orig=%d abl_corr=%d\n'], ...
        numel(sol_list), sol{1}, sol{2}, numel(r.snapshots), ...
        numel(fieldnames(r.probes)), f1, f2, n_orig, n_corr);
end
