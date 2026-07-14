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
if nargin == 0
    lanzar_ui_generador_sin_metales();
    return;
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
    temperatura_carbonizacion = umbral_carbonizacion_ui_generador( ...
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

            potencia_total_max = potencia_total_maxima_ui_generador( ...
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
                cfg.dom_diel  = {[7]};
                cfg.dom_cat   = {[4]};
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
                cfg.dom_diel  = {[5]};
                cfg.dom_cat   = {[4]};
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
                cfg.dom_diel  = {[6]};
                cfg.dom_cat   = {[4]};
                cfg.dom_cat_b = [24 25 26 27 61 62 89 95];
                cfg.dom_aire  = {[5]};
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
    if isstrprop(FuncN(1),'digit'), FuncN = ['f_', FuncN]; end
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
model.component('comp1').material('mat1').selection.set([1]);

model.component('comp1').material.create('mat2','Common');
model.component('comp1').material('mat2').label('Musculo Inteligente');
model.component('comp1').material('mat2').propertyGroup('def').set('density',             '1090[kg/m^3]');
model.component('comp1').material('mat2').propertyGroup('def').set('heatcapacity',        '3421[J/(kg*K)]');
model.component('comp1').material('mat2').propertyGroup('def').set('relpermittivity',     'eps_musculo');
model.component('comp1').material('mat2').propertyGroup('def').set('relpermeability',     '1');
model.component('comp1').material('mat2').propertyGroup('def').set('electricconductivity','sigma_musc_act');
model.component('comp1').material('mat2').propertyGroup('def').set('thermalconductivity', 'k_musc_act');
model.component('comp1').material('mat2').selection.set([2]);

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
model.component('comp1').material('mat3').selection.set([3]);

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
    'bh1', [1], 'omega_hueso_act', 'Meta_hueso_act'; ...
    'bh2', [2], 'omega_musc_act',  'Meta_musc_act';  ...
    'bh3', [3], 'omega_grasa_act', 'Meta_grasa_act'  };
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

function lanzar_ui_generador_sin_metales()
    theme = tesis_auxiliares('tema_ui');
    fig = uifigure('Name', 'Generador Multisolucion', ...
        'Position', theme.layout.launcherPosition, ...
        'Color', theme.colors.bg);

    gl = uigridlayout(fig, [2, 2]);
    gl.RowHeight = {'1x', 155};
    gl.ColumnWidth = {480, '1x'};
    gl.Padding = [12 12 12 12];
    gl.RowSpacing = 12;
    gl.ColumnSpacing = 12;

    pnl_control = uipanel(gl, 'Title', 'Panel de Control');
    pnl_control.Layout.Row = 1;
    pnl_control.Layout.Column = 1;
    pnl_control.Scrollable = 'on';

    ctrl = uigridlayout(pnl_control, [28, 2]);
    ctrl.RowHeight = repmat({36}, 1, 28);
    ctrl.RowHeight{1} = 52;
    ctrl.RowHeight{5} = 64;
    ctrl.RowHeight{8} = 40;
    ctrl.RowHeight{11} = 34;
    ctrl.RowHeight{12} = 34;
    ctrl.RowHeight{13} = 34;
    ctrl.RowHeight{14} = 42;
    ctrl.RowHeight{15} = 42;
    ctrl.RowHeight{16} = 42;
    ctrl.ColumnWidth = {170, '1x'};
    ctrl.Padding = [14 14 14 14];
    ctrl.RowSpacing = 10;
    ctrl.ColumnSpacing = 12;

    titulo = uilabel(ctrl, 'Text', 'Configuracion de campana COMSOL', ...
        'FontWeight', 'bold');
    titulo.Layout.Column = [1 2];
    tesis_auxiliares('tema_ui', 'label', titulo, 'section');

    [ed_raiz, btn_raiz] = crear_selector(ctrl, 2, 'Root simulaciones', 'Seleccionar...');
    [ed_antenas, btn_antenas] = crear_selector(ctrl, 3, 'Antenas3D', 'Seleccionar...');
    [ed_tejidos, btn_tejidos] = crear_selector(ctrl, 4, 'DatosTejidos.mat', 'Seleccionar...');

    ed_raiz.Value = '';
    ed_antenas.Value = '';
    ed_tejidos.Value = '';

    btn_raiz.ButtonPushedFcn = @(~,~) seleccionar_carpeta(ed_raiz, 'Selecciona root de simulaciones');
    btn_antenas.ButtonPushedFcn = @(~,~) seleccionar_antenas();
    btn_tejidos.ButtonPushedFcn = @(~,~) seleccionar_archivo(ed_tejidos, '*.mat', 'Selecciona DatosTejidos.mat');

    nota = uilabel(ctrl, ...
        'Text', 'Si inicio = fin, se interpreta como una unica opcion (un caso, potencia o numero de antenas).', ...
        'WordWrap', 'on');
    nota.Layout.Row = 5;
    nota.Layout.Column = [1 2];
    tesis_auxiliares('tema_ui', 'label', nota, 'muted');

    crear_label(ctrl, 6, 'Casos inicio/fin');
    gl_casos = uigridlayout(ctrl, [1, 2]);
    gl_casos.Layout.Row = 6;
    gl_casos.Layout.Column = 2;
    gl_casos.ColumnWidth = {'1x', '1x'};
    gl_casos.Padding = [0 3 0 3];
    gl_casos.ColumnSpacing = 10;
    ed_caso_ini = uieditfield(gl_casos, 'numeric', 'Value', 0, 'Limits', [0 8]);
    ed_caso_fin = uieditfield(gl_casos, 'numeric', 'Value', 0, 'Limits', [0 8]);

    crear_label(ctrl, 7, 'Potencia W ini/fin/paso');
    gl_pot = uigridlayout(ctrl, [1, 3]);
    gl_pot.Layout.Row = 7;
    gl_pot.Layout.Column = 2;
    gl_pot.ColumnWidth = {'1x', '1x', '1x'};
    gl_pot.Padding = [0 3 0 3];
    gl_pot.ColumnSpacing = 10;
    ed_pot_ini = uieditfield(gl_pot, 'numeric', 'Value', 30, 'Limits', [0 Inf]);
    ed_pot_fin = uieditfield(gl_pot, 'numeric', 'Value', 30, 'Limits', [0 Inf]);
    ed_pot_paso = uieditfield(gl_pot, 'numeric', 'Value', 5, 'Limits', [eps Inf]);

    crear_label(ctrl, 8, 'Tiempo min / paso min');
    gl_tiempo = uigridlayout(ctrl, [1, 2]);
    gl_tiempo.Layout.Row = 8;
    gl_tiempo.Layout.Column = 2;
    gl_tiempo.ColumnWidth = {'1x', '1x'};
    gl_tiempo.Padding = [0 3 0 3];
    gl_tiempo.ColumnSpacing = 10;
    ed_tiempo = uieditfield(gl_tiempo, 'numeric', 'Value', 20, 'Limits', [eps Inf]);
    ed_paso_tiempo = uieditfield(gl_tiempo, 'numeric', 'Value', 1, 'Limits', [eps Inf]);

    crear_label(ctrl, 9, 'Num. antenas inicio/fin');
    gl_num = uigridlayout(ctrl, [1, 2]);
    gl_num.Layout.Row = 9;
    gl_num.Layout.Column = 2;
    gl_num.ColumnWidth = {'1x', '1x'};
    gl_num.Padding = [0 3 0 3];
    gl_num.ColumnSpacing = 10;
    ed_num_ini = uieditfield(gl_num, 'numeric', 'Value', 1, 'Limits', [1 4], 'RoundFractionalValues', 'on');
    ed_num_fin = uieditfield(gl_num, 'numeric', 'Value', 4, 'Limits', [1 4], 'RoundFractionalValues', 'on');

    lbl_antenas = uilabel(ctrl, 'Text', 'Tipos de antena encontrados');
    lbl_antenas.Layout.Row = 10;
    lbl_antenas.Layout.Column = [1 2];
    tesis_auxiliares('tema_ui', 'label', lbl_antenas, 'section');

    gl_checks = uigridlayout(ctrl, [3, 1]);
    gl_checks.Layout.Row = [11 13];
    gl_checks.Layout.Column = [1 2];
    gl_checks.RowHeight = {30, 30, 30};
    gl_checks.Padding = [8 4 8 4];
    gl_checks.RowSpacing = 6;
    cb_doble = uicheckbox(gl_checks, 'Text', 'Doble_slot', 'Value', false);
    cb_mono = uicheckbox(gl_checks, 'Text', 'Monopolo', 'Value', true);
    cb_un = uicheckbox(gl_checks, 'Text', 'Un_slot', 'Value', false);

    btn_inspeccionar = uibutton(ctrl, 'Text', 'Inspeccionar carpeta', ...
        'ButtonPushedFcn', @(~,~) inspeccionar_desde_ui());
    btn_inspeccionar.Layout.Row = 14;
    btn_inspeccionar.Layout.Column = [1 2];
    tesis_auxiliares('tema_ui', 'button', btn_inspeccionar, 'primary');

    btn_ejecutar = uibutton(ctrl, 'Text', 'Ejecutar generador', ...
        'ButtonPushedFcn', @(~,~) ejecutar_desde_ui());
    btn_ejecutar.Layout.Row = 15;
    btn_ejecutar.Layout.Column = [1 2];
    tesis_auxiliares('tema_ui', 'button', btn_ejecutar, 'success');

    btn_export_log = uibutton(ctrl, 'Text', 'Exportar log', ...
        'ButtonPushedFcn', @(~,~) exportar_log());
    btn_export_log.Layout.Row = 16;
    btn_export_log.Layout.Column = [1 2];
    tesis_auxiliares('tema_ui', 'button', btn_export_log, 'secondary');

    pnl_dash = uipanel(gl, 'Title', 'Dashboard de Simulaciones');
    pnl_dash.Layout.Row = 1;
    pnl_dash.Layout.Column = 2;
    dash = uigridlayout(pnl_dash, [3, 1]);
    dash.RowHeight = {32, '1x', 32};
    dash.Padding = [14 14 14 14];
    dash.RowSpacing = 10;

    lbl_estado = uilabel(dash, 'Text', 'Seleccione rutas e inspeccione la carpeta.');
    tesis_auxiliares('tema_ui', 'label', lbl_estado, 'status');
    txt_resumen = uitextarea(dash, 'Editable', 'off', ...
        'Value', {'Sin inspeccion.'});
    tesis_auxiliares('tema_ui', 'textarea', txt_resumen);
    lbl_config = uilabel(dash, 'Text', 'Configuracion activa: caso 0, Monopolo, antenas 1-4, 30 W, 20 min.');
    tesis_auxiliares('tema_ui', 'label', lbl_config, 'muted');

    pnl_log = uipanel(gl, 'Title', 'Registro de Eventos (Consola)');
    pnl_log.Layout.Row = 2;
    pnl_log.Layout.Column = [1 2];
    gl_log = uigridlayout(pnl_log, [1, 1]);
    gl_log.Padding = [2 2 2 2];
    txt_log = uitextarea(gl_log, 'Editable', 'off', 'Value', {'Listo.'});
    tesis_auxiliares('tema_ui', 'textarea', txt_log);

    tesis_auxiliares('tema_ui', 'apply', fig);
    tesis_auxiliares('tema_ui', 'textarea', txt_log);
    tesis_auxiliares('tema_ui', 'textarea', txt_resumen);
    actualizar_config_label();

    function [ed, btn] = crear_selector(parent, row, etiqueta, texto_boton)
        crear_label(parent, row, etiqueta);
        line = uigridlayout(parent, [1, 2]);
        line.Layout.Row = row;
        line.Layout.Column = 2;
        line.ColumnWidth = {'1x', 125};
        line.Padding = [0 3 0 3];
        line.ColumnSpacing = 10;
        ed = uieditfield(line, 'text');
        btn = uibutton(line, 'Text', texto_boton);
        tesis_auxiliares('tema_ui', 'button', btn, 'secondary');
    end

    function crear_label(parent, row, texto)
        lbl = uilabel(parent, 'Text', texto, 'FontWeight', 'bold');
        lbl.Layout.Row = row;
        lbl.Layout.Column = 1;
        tesis_auxiliares('tema_ui', 'label', lbl, 'normal');
    end

    function seleccionar_carpeta(ed, titulo_dialogo)
        ruta = uigetdir(pwd, titulo_dialogo);
        if isequal(ruta, 0)
            return;
        end
        ed.Value = ruta;
        if isequal(ed, ed_raiz) && isempty(ed_antenas.Value)
            sugerida = fullfile(ruta, 'Antenas3D');
            if isfolder(sugerida)
                ed_antenas.Value = sugerida;
            end
            sugerido_mat = fullfile(ruta, 'DatosTejidos.mat');
            if isfile(sugerido_mat)
                ed_tejidos.Value = sugerido_mat;
            end
        end
        actualizar_antenas_disponibles();
        actualizar_config_label();
        log_evento('Carpeta seleccionada: %s', ruta);
        if isequal(ed, ed_raiz)
            inspeccionar_desde_ui();
        end
    end

    function seleccionar_antenas()
        seleccionar_carpeta(ed_antenas, 'Selecciona la carpeta Antenas3D');
        actualizar_antenas_disponibles();
    end

    function seleccionar_archivo(ed, filtro, titulo_dialogo)
        [archivo, carpeta] = uigetfile(filtro, titulo_dialogo);
        if isequal(archivo, 0)
            return;
        end
        ed.Value = fullfile(carpeta, archivo);
        actualizar_config_label();
        log_evento('Archivo seleccionado: %s', ed.Value);
    end

    function actualizar_antenas_disponibles()
        disponibles = detectar_antenas_disponibles(ed_antenas.Value);
        cbs = {cb_doble, cb_mono, cb_un};
        nombres = {'Doble_slot', 'Monopolo', 'Un_slot'};
        for k = 1:numel(cbs)
            existe = ismember(nombres{k}, disponibles);
            if existe
                cbs{k}.Enable = 'on';
            else
                cbs{k}.Enable = 'off';
                cbs{k}.Value = false;
            end
            if existe && strcmp(nombres{k}, 'Monopolo')
                cbs{k}.Value = true;
            end
        end
        log_evento('Antenas detectadas: %s', strjoin(disponibles, ', '));
    end

    function valores = obtener_valores_ui()
        tipos = {};
        if cb_doble.Value, tipos{end+1} = 'Doble_slot'; end %#ok<AGROW>
        if cb_mono.Value, tipos{end+1} = 'Monopolo'; end %#ok<AGROW>
        if cb_un.Value, tipos{end+1} = 'Un_slot'; end %#ok<AGROW>
        valores = struct( ...
            'ruta_raiz', strtrim(ed_raiz.Value), ...
            'ruta_antenas', strtrim(ed_antenas.Value), ...
            'ruta_datos_tejidos', strtrim(ed_tejidos.Value), ...
            'caso_inicio', ed_caso_ini.Value, ...
            'caso_fin', ed_caso_fin.Value, ...
            'potencia_inicio', ed_pot_ini.Value, ...
            'potencia_fin', ed_pot_fin.Value, ...
            'potencia_paso', ed_pot_paso.Value, ...
            'tiempo_simulacion_min', ed_tiempo.Value, ...
            'paso_tiempo_min', ed_paso_tiempo.Value, ...
            'num_antenas_inicio', ed_num_ini.Value, ...
            'num_antenas_fin', ed_num_fin.Value, ...
            'tipos_antena', {tipos});
    end

    function inspeccionar_desde_ui()
        valores = obtener_valores_ui();
        if isempty(valores.ruta_raiz) || ~isfolder(valores.ruta_raiz)
            uialert(fig, 'Selecciona un root de simulaciones valido.', 'Ruta requerida');
            return;
        end
        resumen = inspeccionar_simulaciones_generador(valores.ruta_raiz);
        txt_resumen.Value = resumen(:);
        lbl_estado.Text = sprintf('Inspeccion completada: %s', valores.ruta_raiz);
        actualizar_config_label();
        log_evento('Inspeccion completada.');
    end

    function ejecutar_desde_ui()
        valores = obtener_valores_ui();
        validar_config_ui(valores);
        insertar_separacion_log();
        log_evento('Raiz de simulaciones: %s', valores.ruta_raiz);
        log_evento('Antenas3D: %s', valores.ruta_antenas);
        log_evento('Datos de tejidos: %s', valores.ruta_datos_tejidos);
        cfg = normalizar_config_generador(valores, {'Doble_slot', 'Monopolo', 'Un_slot'});
        log_evento('Plan: casos %s | potencias %s W | antenas %s | tipos %s | tiempo %.2f min.', ...
            mat2str(cfg.casos), mat2str(cfg.potencias), mat2str(cfg.numeros_antenas), ...
            strjoin(valores.tipos_antena, ', '), cfg.tiempo_simulacion_min);
        generador_sin_metales_multi_solucion_sin_tumor('run', valores);
        log_evento('Generacion multisolucion finalizada.');
    end

    function validar_config_ui(valores)
        if isempty(valores.ruta_raiz) || ~isfolder(valores.ruta_raiz)
            error('Selecciona una carpeta raiz valida.');
        end
        if isempty(valores.ruta_antenas) || ~isfolder(valores.ruta_antenas)
            error('Selecciona una carpeta Antenas3D valida.');
        end
        if isempty(valores.ruta_datos_tejidos) || ~isfile(valores.ruta_datos_tejidos)
            error('Selecciona un archivo DatosTejidos.mat valido.');
        end
        if isempty(valores.tipos_antena)
            error('Selecciona al menos un tipo de antena disponible.');
        end
        normalizar_config_generador(valores, {'Doble_slot', 'Monopolo', 'Un_slot'});
    end

    function actualizar_config_label()
        valores = obtener_valores_ui();
        tipos = valores.tipos_antena;
        if isempty(tipos), tipos = {'(sin antena seleccionada)'}; end
        lbl_config.Text = sprintf(['Configuracion activa: casos %.0f-%.0f, ', ...
            'potencias %.1f-%.1f paso %.1f W, antenas %.0f-%.0f, tipos %s, tiempo %.1f min.'], ...
            valores.caso_inicio, valores.caso_fin, valores.potencia_inicio, ...
            valores.potencia_fin, valores.potencia_paso, valores.num_antenas_inicio, ...
            valores.num_antenas_fin, strjoin(tipos, ', '), valores.tiempo_simulacion_min);
    end

    function exportar_log()
        [archivo, carpeta] = uiputfile('*.txt', 'Exportar log', 'generador_multisolucion_log.txt');
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
        lineas = flipud(txt_log.Value(:));
        for k = 1:numel(lineas)
            fprintf(fid, '%s\n', lineas{k});
        end
        log_evento('Log exportado: %s', ruta);
    end

    function insertar_separacion_log()
        txt_log.Value = [repmat({''}, 5, 1); txt_log.Value(:)];
        drawnow limitrate;
    end

    function log_evento(formato, varargin)
        marca = char(datetime('now', 'Format', 'HH:mm:ss'));
        linea = sprintf('[%s] %s', marca, sprintf(formato, varargin{:}));
        txt_log.Value = [{linea}; txt_log.Value(:)];
        drawnow limitrate;
    end
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

function potencia_total_max = potencia_total_maxima_ui_generador( ...
        num_antenas, potencia_total_max_1a3, potencia_total_max_4ant)
    if num_antenas == 4
        potencia_total_max = potencia_total_max_4ant;
    else
        potencia_total_max = potencia_total_max_1a3;
    end
end

function umbral = umbral_carbonizacion_ui_generador(umbrales, idx_caso)
    posicion = idx_caso + 1;
    if posicion < 1 || posicion > numel(umbrales)
        error('No existe umbral de carbonizacion para el caso %d.', ...
            idx_caso);
    end
    umbral = umbrales(posicion);
end

function valores = crear_rango_entero(inicio, fin, paso, minimo, maximo, etiqueta)
    valores = crear_rango_numerico(inicio, fin, paso, minimo, maximo, etiqueta);
    valores = unique(round(valores), 'stable');
end

function valores = crear_rango_numerico(inicio, fin, paso, minimo, maximo, etiqueta)
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
    lineas{end+1} = sprintf('Dataset encontrado: %s', ruta_dataset); %#ok<AGROW>
    lineas{end+1} = sprintf('Indices de soluciones encontrados: %d', numel(indices)); %#ok<AGROW>
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
