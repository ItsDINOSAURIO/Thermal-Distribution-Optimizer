% Interfaz_Ablacion_AlphaShape: reconstrucción y validación geométrica experimental.
% Segmenta imágenes, calibra cortes y exporta superficies de ablación y hueso.
% Alinea mallas experimentales y simuladas; calcula volumen, cobertura, Dice e IoU.

% Inicia la reconstrucción y validación geométrica experimental.
function Interfaz_Ablacion_AlphaShape()

carpeta_modulo = fileparts(mfilename('fullpath'));
addpath(fullfile(carpeta_modulo, '..', 'aux_codes'));
root_proyecto = tesis_auxiliares('configurar_paths', carpeta_modulo);
paths = tesis_auxiliares('dataset_paths', root_proyecto);
theme = tesis_auxiliares('tema_ui');

app = struct();
app.data_root = char(paths.reconstrucciones);
crearCarpeta(app.data_root);
app.carpeta = string(app.data_root);
app.catalogo_carpetas = struct('ruta', {}, 'etiqueta', {}, 'tipo', {}, ...
    'antena', {}, 'caso', {}, 'potencia', {}, 'fecha', {}, 'tiempo', {}, ...
    'prueba', {}, 'zonas', {});
app.metadata_dataset = struct();
app.fileList = [];
app.nFiles = 0;
app.BW = {};
app.contorno = {};
app.imagenes_validas = [];
app.cara_imagen = [];
app.BW_hueso_alineado = {};
app.BW_ablacion = {};
app.contorno_ablacion = {};
app.idx_validas = [];
app.mmPorPixel = [];
app.distanciaPixeles = [];
app.distanciaRealMm = [];
app.grosores = [];
app.grosores_segmentos = [];
app.caras_validas = [];
app.segmento_imagen = [];
app.z_cortes = [];
app.shp = [];
app.puntos3D = [];
app.carasSTL = [];
app.verticesSTL = [];
app.archivoSTL = "";
app.RotX = 0;
app.RotY = 0;
app.RotZ = 0;
app.T = [0 0 0];

fig = uifigure('Name', 'Verificación experimental', ...
    'Position', theme.layout.launcherPosition, ...
    'Color', theme.colors.bg, ...
    'Tag', 'fig_interfaz_ablacion_alphashape');

main = uigridlayout(fig, [2 1]);
main.RowHeight = {'1x', theme.layout.logHeight};
main.ColumnWidth = {'1x'};
main.Padding = repmat(theme.layout.padding, 1, 4);
main.RowSpacing = 10;
main.ColumnSpacing = 10;

body = uigridlayout(main, [1 2]);
body.Layout.Row = 1;
body.Layout.Column = 1;
body.ColumnWidth = {theme.layout.sidebarWidth, '1x'};
body.RowHeight = {'1x'};
body.Padding = [0 0 0 0];
body.ColumnSpacing = 10;

panelControles = uipanel(body, ...
    'Title', 'Flujo de trabajo', ...
    'TitlePosition', 'centertop', ...
    'Scrollable', 'on', ...
    'Tag', 'panel_controles_alphashape');
panelControles.Layout.Row = 1;
panelControles.Layout.Column = 1;

ctrl = uigridlayout(panelControles, [27 2]);
ctrl.RowHeight = {24, 30, 30, 30, 30, 30, 30, 30, 30, 30, ...
    34, 120, 24, 30, 30, 30, 30, 30, 30, 24, 34, 34, 34, 34, 34, 34, '1x'};
ctrl.ColumnWidth = {'1x', 110};
ctrl.Padding = [10 10 10 10];
ctrl.RowSpacing = 7;
ctrl.ColumnSpacing = 8;
activarScroll(panelControles);
activarScroll(ctrl);

crearLabelAncho(ctrl, 'Datos experimentales', 1, 'lbl_seccion_datos_alphashape');
[ddTipo, lblTipo] = crearFiltroMetadata(ctrl, 2, 'Tipo');
[ddAntena, lblAntena] = crearFiltroMetadata(ctrl, 3, 'Antenas');
[ddCaso, lblCaso] = crearFiltroMetadata(ctrl, 4, 'Caso');
[ddPotencia, lblPotencia] = crearFiltroMetadata(ctrl, 5, 'Potencia');
[ddFecha, lblFecha] = crearFiltroMetadata(ctrl, 6, 'Fecha');
[ddTiempo, lblTiempo] = crearFiltroMetadata(ctrl, 7, 'Tiempo');
[ddPrueba, lblPrueba] = crearFiltroMetadata(ctrl, 8, 'Prueba');
[ddZonas, lblZonas] = crearFiltroMetadata(ctrl, 9, 'Zonas');
filtrosMetadata = struct('campo', {'tipo', 'antena', 'caso', 'potencia', ...
    'fecha', 'tiempo', 'prueba', 'zonas'}, ...
    'control', {ddTipo, ddAntena, ddCaso, ddPotencia, ddFecha, ddTiempo, ddPrueba, ddZonas}, ...
    'label', {lblTipo, lblAntena, lblCaso, lblPotencia, lblFecha, lblTiempo, lblPrueba, lblZonas}, ...
    'fila', num2cell(2:9));
for idx_filtro = 1:numel(filtrosMetadata)
    filtrosMetadata(idx_filtro).control.ValueChangedFcn = @(~, ~) aplicarFiltrosMetadata();
end
[ddDataset, ~] = crearFiltroMetadata(ctrl, 10, 'Dataset');
ddDataset.Items = {'(sin carpetas)'};
ddDataset.ValueChangedFcn = @(src, ~) cargarCarpetaSeleccionada(src.Value);

btnProcesar = uibutton(ctrl, ...
    'Text', '1. Segmentar hueso', ...
    'Enable', 'off', ...
    'Tag', 'btn_segmentar_hueso_alphashape', ...
    'ButtonPushedFcn', @(~, ~) procesarImagenes());
btnProcesar.Layout.Row = 11;
btnProcesar.Layout.Column = [1 2];

lstImagenes = uilistbox(ctrl, ...
    'Items', {'Sin dataset cargado'}, ...
    'Tag', 'lst_imagenes_alphashape');
lstImagenes.Layout.Row = 12;
lstImagenes.Layout.Column = [1 2];

crearLabelAncho(ctrl, 'Parámetros', 13, 'lbl_seccion_parametros_alphashape');
crearLabel(ctrl, 'Grupos K-means', 14, 'lbl_kmeans_alphashape');
spnClusters = uispinner(ctrl, 'Limits', [2 8], 'Value', 4, 'Step', 1, ...
    'Tooltip', 'Número de grupos de color usados para segmentar el hueso.', ...
    'Tag', 'spn_clusters_alphashape');
spnClusters.Layout.Row = 14;
spnClusters.Layout.Column = 2;

crearLabel(ctrl, 'Área mínima de región (px²)', 15, 'lbl_area_minima_alphashape');
spnArea = uispinner(ctrl, 'Limits', [50 50000], 'Value', 3000, 'Step', 100, ...
    'Tooltip', 'Área mínima en píxeles para conservar una región segmentada.', ...
    'Tag', 'spn_area_alphashape');
spnArea.Layout.Row = 15;
spnArea.Layout.Column = 2;

crearLabel(ctrl, 'Radio de cierre morfológico (px)', 16, 'lbl_cierre_alphashape');
spnCierre = uispinner(ctrl, 'Limits', [1 80], 'Value', 18, 'Step', 1, ...
    'Tooltip', 'Radio morfológico usado para cerrar discontinuidades del contorno.', ...
    'Tag', 'spn_cierre_alphashape');
spnCierre.Layout.Row = 16;
spnCierre.Layout.Column = 2;

crearLabel(ctrl, 'Factor de AlphaShape', 17, 'lbl_alpha_alphashape');
spnAlpha = uispinner(ctrl, 'Limits', [0.5 10], 'Value', 5, 'Step', 0.25, ...
    'Tooltip', 'Factor alpha de la reconstrucción tridimensional a partir de contornos.', ...
    'Tag', 'spn_alpha_alphashape');
spnAlpha.Layout.Row = 17;
spnAlpha.Layout.Column = 2;

crearLabel(ctrl, 'Niveles de subdivisión', 18, 'lbl_subdivision_alphashape');
spnSubdiv = uispinner(ctrl, 'Limits', [0 3], 'Value', 2, 'Step', 1, ...
    'Tooltip', 'Número de subdivisiones aplicadas a la malla reconstruida.', ...
    'Tag', 'spn_subdivision_alphashape');
spnSubdiv.Layout.Row = 18;
spnSubdiv.Layout.Column = 2;

crearLabel(ctrl, 'Iteraciones de suavizado', 19, 'lbl_suavizado_alphashape');
spnSuavizado = uispinner(ctrl, 'Limits', [0 250], 'Value', 120, 'Step', 10, ...
    'Tooltip', 'Iteraciones de suavizado aplicadas a la superficie final.', ...
    'Tag', 'spn_suavizado_alphashape');
spnSuavizado.Layout.Row = 19;
spnSuavizado.Layout.Column = 2;

crearLabelAncho(ctrl, 'Acciones', 20, 'lbl_seccion_acciones_alphashape');
btnCalibrar = crearBoton(ctrl, '2. Calibrar y alinear', 21, 'btn_calibrar_alphashape', @(~, ~) calibrarYAlinear());
btnAblacion = crearBoton(ctrl, '3. Segmentar ablación', 22, 'btn_segmentar_ablacion_alphashape', @(~, ~) segmentarAblacion());
btnGrosores = crearBoton(ctrl, '4. Capturar grosores', 23, 'btn_grosores_alphashape', @(~, ~) capturarGrosores());
btnReconstruir = crearBoton(ctrl, '5. Reconstruir y guardar STL', 24, 'btn_reconstruir_alphashape', @(~, ~) reconstruir3D());
btnCalcular = crearBoton(ctrl, '6. Calcular volumen del STL', 25, 'btn_calcular_volumen_alphashape', @(~, ~) CalcularVol());
btnComparar = crearBoton(ctrl, '7. Comparar volumen del STL', 26, 'btn_comparar_volumen_alphashape', @(~, ~) CompaVol());

tabs = uitabgroup(body, 'Tag', 'tabs_alphashape');
tabs.Layout.Row = 1;
tabs.Layout.Column = 2;

panelLog = uipanel(main, ...
    'Title', 'Registro de eventos', ...
    'Tag', 'panel_registro_alphashape');
panelLog.Layout.Row = 2;
panelLog.Layout.Column = 1;
glog = uigridlayout(panelLog, [1 1]);
glog.Padding = [6 6 6 6];
txtEstado = uitextarea(glog, ...
    'Editable', false, ...
    'Value', {'Selecciona un dataset de imágenes para iniciar.'}, ...
    'Tag', 'txt_estado_alphashape');

tabSeg = uitab(tabs, 'Title', 'Segmentación', 'Tag', 'tab_segmentacion_alphashape');
gSeg = uigridlayout(tabSeg, [2 3]);
gSeg.RowHeight = {'1x', '1x'};
gSeg.ColumnWidth = {'1x', '1x', '1x'};
gSeg.Padding = [8 8 8 8];
gSeg.RowSpacing = 8;
gSeg.ColumnSpacing = 8;
axOriginal = crearPanelEje(gSeg, 'Original', 1, 1, 'ax_original_alphashape');
axKmeans = crearPanelEje(gSeg, 'K-means', 1, 2, 'ax_kmeans_alphashape');
axContorno = crearPanelEje(gSeg, 'Contorno hueso', 1, 3, 'ax_contorno_alphashape');
axOverlay = crearPanelEje(gSeg, 'Alineación', 2, [1 2], 'ax_overlay_alphashape');
axAblacion = crearPanelEje(gSeg, 'Ablación', 2, 3, 'ax_ablacion_alphashape');

tab3D = uitab(tabs, 'Title', 'Reconstrucción 3D', 'Tag', 'tab_reconstruccion_3d_alphashape');
g3d = uigridlayout(tab3D, [1 1]);
g3d.Padding = [8 8 8 8];
ax3D = crearPanelEje(g3d, 'Reconstrucción 3D', 1, 1, 'ax_3d_alphashape');

tab3D_1 = uitab(tabs, 'Title', 'Comparación de volumen', 'Tag', 'tab_comparacion_alphashape');
gComp = uigridlayout(tab3D_1, [1 2]);
gComp.ColumnWidth = {'1x', 285};
gComp.RowHeight = {'1x'};
gComp.Padding = [8 8 8 8];
gComp.ColumnSpacing = 8;
ax3D_1 = crearPanelEje(gComp, 'Comparación STL', 1, 1, 'ax_comparacion_alphashape');

pnlComparacion = crearPanel(gComp, 'Alineación y STL', 1, 2, 'panel_comparacion_alphashape');
gc = uigridlayout(pnlComparacion, [16 2]);
gc.RowHeight = repmat({32}, 1, 16);
gc.ColumnWidth = {'1x', '1x'};
gc.Padding = [10 10 10 10];
gc.RowSpacing = 8;
gc.ColumnSpacing = 8;

btnSTLNormZ = crearBotonComparacion(gc, 'Rotar a Z', 1, [1 2], 'btn_rotar_z_alphashape', @(~, ~) RotarZ());
btnSTLfijo = crearBotonComparacion(gc, 'Reconstruido', 2, 1, 'btn_stl_fijo_alphashape', @(~, ~) SelecionarSTL_fij());
btnSTLRot = crearBotonComparacion(gc, 'Simulado', 2, 2, 'btn_stl_libre_alphashape', @(~, ~) SelecionarSTL_rot());
btnSTlHueso = crearBotonComparacion(gc, 'Generar STL de hueso', 3, [1 2], 'btn_stl_hueso_alphashape', @(~, ~) CalculSTLhues());
btnCalibrarSTL = crearBotonComparacion(gc, 'Calibrar por puntos', 4, [1 2], 'btn_calibrar_stl_alphashape', @(~, ~) CalibrarSTLPorPuntos());

crearLabelAncho(gc, 'Rotación X', 5, 'lbl_rot_x_alphashape');
btnMasX = crearBotonComparacion(gc, '+', 6, 1, 'btn_rot_x_mas_alphashape', @(~, ~) rotarSTL('X', 5));
btnMenX = crearBotonComparacion(gc, '-', 6, 2, 'btn_rot_x_menos_alphashape', @(~, ~) rotarSTL('X', -5));
crearLabelAncho(gc, 'Rotación Y', 7, 'lbl_rot_y_alphashape');
btnMasY = crearBotonComparacion(gc, '+', 8, 1, 'btn_rot_y_mas_alphashape', @(~, ~) rotarSTL('Y', 5));
btnMenY = crearBotonComparacion(gc, '-', 8, 2, 'btn_rot_y_menos_alphashape', @(~, ~) rotarSTL('Y', -5));
crearLabelAncho(gc, 'Rotación Z', 9, 'lbl_rot_z_alphashape');
btnMasZ = crearBotonComparacion(gc, '+', 10, 1, 'btn_rot_z_mas_alphashape', @(~, ~) rotarSTL('Z', 5));
btnMenZ = crearBotonComparacion(gc, '-', 10, 2, 'btn_rot_z_menos_alphashape', @(~, ~) rotarSTL('Z', -5));

crearLabelAncho(gc, 'Traslación X', 11, 'lbl_trans_x_alphashape');
btnMasXTr = crearBotonComparacion(gc, '+', 12, 1, 'btn_trans_x_mas_alphashape', @(~, ~) trasladarSTL(1, 2));
btnMenXTr = crearBotonComparacion(gc, '-', 12, 2, 'btn_trans_x_menos_alphashape', @(~, ~) trasladarSTL(1, -2));
crearLabelAncho(gc, 'Traslación Y', 13, 'lbl_trans_y_alphashape');
btnMasYTr = crearBotonComparacion(gc, '+', 14, 1, 'btn_trans_y_mas_alphashape', @(~, ~) trasladarSTL(2, 2));
btnMenYTr = crearBotonComparacion(gc, '-', 14, 2, 'btn_trans_y_menos_alphashape', @(~, ~) trasladarSTL(2, -2));
crearLabelAncho(gc, 'Traslación Z', 15, 'lbl_trans_z_alphashape');
btnMasZTr = crearBotonComparacion(gc, '+', 16, 1, 'btn_trans_z_mas_alphashape', @(~, ~) trasladarSTL(3, 2));
btnMenZTr = crearBotonComparacion(gc, '-', 16, 2, 'btn_trans_z_menos_alphashape', @(~, ~) trasladarSTL(3, -2));
activarScroll(pnlComparacion);
activarScroll(gc);

btnSTlHueso.Enable = 'off';
btnSTLNormZ.Enable = 'off';
btnCalibrarSTL.Enable = 'off';
btnMasX.Enable = 'off';
btnMenX.Enable = 'off';
btnMasY.Enable = 'off';
btnMenY.Enable = 'off';
btnMasZ.Enable = 'off';
btnMenZ.Enable = 'off';

btnMasXTr.Enable = 'off';
btnMenXTr.Enable = 'off';
btnMasYTr.Enable = 'off';
btnMenYTr.Enable = 'off';
btnMasZTr.Enable = 'off';
btnMenZTr.Enable = 'off';

entradas_carpetas = dir(fullfile(app.data_root, '**'));
entradas_carpetas = entradas_carpetas([entradas_carpetas.isdir] & ...
    ~ismember({entradas_carpetas.name}, {'.', '..'}));
carpetas_catalogo = unique(arrayfun(@(x) ...
    fullfile(x.folder, x.name), entradas_carpetas, 'UniformOutput', false), 'stable');
for idx_catalogo = 1:numel(carpetas_catalogo)
    partes_catalogo = split(strrep(carpetas_catalogo{idx_catalogo}, '\', '/'), '/');
    if any(strcmpi(partes_catalogo, 'repetidos')) || ...
            any(startsWith(partes_catalogo, 'Alineadas', 'IgnoreCase', true)) || ...
            any(strcmpi(partes_catalogo, 'Ablacion_segmentada'))
        continue;
    end
    if isempty(listarImagenesJPEG(carpetas_catalogo{idx_catalogo}))
        continue;
    end
    md_catalogo = tesis_auxiliares('metadata_ruta', carpetas_catalogo{idx_catalogo});
    entrada_catalogo = struct('ruta', carpetas_catalogo{idx_catalogo}, ...
        'etiqueta', '', 'tipo', md_catalogo.tipo, ...
        'antena', md_catalogo.antena, 'caso', '', 'potencia', '', ...
        'fecha', md_catalogo.fecha_adquisicion, 'tiempo', '', ...
        'prueba', '', 'zonas', '');
    if isfinite(md_catalogo.caso), entrada_catalogo.caso = sprintf('Caso_%d', round(md_catalogo.caso)); end
    if isfinite(md_catalogo.potencia_W), entrada_catalogo.potencia = sprintf('Potencia_%gW', md_catalogo.potencia_W); end
    if isfinite(md_catalogo.tiempo_ejecucion_min), entrada_catalogo.tiempo = sprintf('Tiempo_%gmin', md_catalogo.tiempo_ejecucion_min); end
    if isfinite(md_catalogo.numero_prueba), entrada_catalogo.prueba = sprintf('Prueba_%d', round(md_catalogo.numero_prueba)); end
    if isfinite(md_catalogo.num_zonas), entrada_catalogo.zonas = sprintf('Zonas_%d', round(md_catalogo.num_zonas)); end
    relativa_catalogo = erase(carpetas_catalogo{idx_catalogo}, [app.data_root filesep]);
    partes_etiqueta = {entrada_catalogo.tipo, ...
        entrada_catalogo.antena, entrada_catalogo.caso, entrada_catalogo.potencia, ...
        entrada_catalogo.fecha, entrada_catalogo.tiempo, entrada_catalogo.prueba, ...
        entrada_catalogo.zonas};
    partes_etiqueta = partes_etiqueta(~cellfun('isempty', partes_etiqueta));
    entrada_catalogo.etiqueta = strjoin([partes_etiqueta, {relativa_catalogo}], ' | ');
    app.catalogo_carpetas(end + 1) = entrada_catalogo;
end
for idx_visibilidad = 1:numel(filtrosMetadata)
    campo_visibilidad = filtrosMetadata(idx_visibilidad).campo;
    valores_visibilidad = {app.catalogo_carpetas.(campo_visibilidad)};
    visible_metadata = any(~cellfun('isempty', valores_visibilidad));
    filtrosMetadata(idx_visibilidad).control.Visible = visible_metadata;
    filtrosMetadata(idx_visibilidad).label.Visible = visible_metadata;
    if visible_metadata
        ctrl.RowHeight{filtrosMetadata(idx_visibilidad).fila} = 30;
    else
        filtrosMetadata(idx_visibilidad).control.Value = 'Todos';
        ctrl.RowHeight{filtrosMetadata(idx_visibilidad).fila} = 0;
    end
end
aplicarFiltrosMetadata();
tesis_auxiliares('tema_ui', 'apply', fig);
tesis_auxiliares('tema_ui', 'textarea', txtEstado);
botones_tema = [btnProcesar btnCalibrar btnAblacion btnGrosores btnReconstruir ...
    btnCalcular btnComparar btnSTLfijo btnSTLRot btnSTLNormZ btnSTlHueso btnCalibrarSTL ...
    btnMasX btnMenX btnMasY btnMenY btnMasZ btnMenZ ...
    btnMasXTr btnMenXTr btnMasYTr btnMenYTr btnMasZTr btnMenZTr];
for idx_boton = 1:numel(botones_tema)
    tesis_auxiliares('tema_ui', 'button', botones_tema(idx_boton), 'secondary');
end
tesis_auxiliares('tema_ui', 'button', btnProcesar, 'success');
tesis_auxiliares('tema_ui', 'button', btnReconstruir, 'success');
tesis_auxiliares('tema_ui', 'button', btnComparar, 'success');
limpiarAxes();

    % Crea un panel con el estilo del proyecto.
    function p = crearPanel(parent, tituloPanel, row, col, tag)
        p = uipanel(parent, 'Title', tituloPanel, ...
            'TitlePosition', 'centertop', 'Tag', tag);
        p.Layout.Row = row;
        p.Layout.Column = col;
        tesis_auxiliares('tema_ui', 'panel', p);
    end

    % Etiqueta un parámetro de reconstrucción.
    function crearLabel(parent, texto, row, tag)
        lbl = uilabel(parent, 'Text', texto, 'Tag', tag);
        lbl.Tooltip = descripcionControlExperimental(texto);
        lbl.Layout.Row = row;
        lbl.Layout.Column = 1;
        tesis_auxiliares('tema_ui', 'label', lbl, 'normal');
    end

    % Identifica una sección de controles.
    function crearLabelAncho(parent, texto, row, tag)
        lbl = uilabel(parent, ...
            'Text', texto, ...
            'HorizontalAlignment', 'center', ...
            'Tooltip', descripcionControlExperimental(texto), ...
            'Tag', tag);
        lbl.Layout.Row = row;
        lbl.Layout.Column = [1 2];
        tesis_auxiliares('tema_ui', 'label', lbl, 'section');
    end

    % Crea un selector de metadatos experimentales.
    function [control, lbl] = crearFiltroMetadata(parent, row, texto)
        lbl = uilabel(parent, 'Text', texto);
        lbl.Layout.Row = row;
        lbl.Layout.Column = 1;
        control = uidropdown(parent, 'Items', {'Todos'}, 'Value', 'Todos');
        ayuda = descripcionControlExperimental(texto);
        lbl.Tooltip = ayuda; control.Tooltip = ayuda;
        control.Layout.Row = row;
        control.Layout.Column = 2;
        tesis_auxiliares('tema_ui', 'label', lbl, 'normal');
        tesis_auxiliares('tema_ui', 'dropdown', control);
    end

    % Crea una acción del flujo de reconstrucción.
    function btn = crearBoton(parent, texto, row, tag, callback)
        btn = uibutton(parent, ...
            'Text', texto, ...
            'Tooltip', descripcionControlExperimental(texto), ...
            'Enable', 'off', ...
            'Tag', tag, ...
            'ButtonPushedFcn', callback);
        btn.Layout.Row = row;
        btn.Layout.Column = [1 2];
    end

    % Crea una acción de alineación o comparación STL.
    function btn = crearBotonComparacion(parent, texto, row, col, tag, callback)
        btn = uibutton(parent, ...
            'Text', texto, ...
            'Tooltip', descripcionControlExperimental(texto), ...
            'Tag', tag, ...
            'ButtonPushedFcn', callback);
        btn.Layout.Row = row;
        btn.Layout.Column = col;
    end

    % Describe el propósito de los controles experimentales.
    function ayuda = descripcionControlExperimental(texto)
        clave = lower(char(texto));
        if contains(clave, 'caso')
            ayuda = 'Caso térmico asociado a las imágenes experimentales.';
        elseif contains(clave, 'potencia')
            ayuda = 'Potencia aplicada durante la ablación experimental.';
        elseif contains(clave, 'antena')
            ayuda = 'Tipo o cantidad de antenas del experimento.';
        elseif contains(clave, 'fecha')
            ayuda = 'Fecha de adquisición de la serie de imágenes.';
        elseif contains(clave, 'tiempo')
            ayuda = 'Duración del procedimiento experimental.';
        elseif contains(clave, 'prueba')
            ayuda = 'Número de repetición del experimento.';
        elseif contains(clave, 'zona')
            ayuda = 'Cantidad de regiones experimentales registradas.';
        elseif contains(clave, 'dataset') || contains(clave, 'datos experimentales')
            ayuda = 'Carpeta de imágenes localizada mediante la metadata disponible.';
        elseif contains(clave, 'k-means')
            ayuda = 'Agrupación de color usada para separar hueso, fondo y artefactos.';
        elseif contains(clave, 'área')
            ayuda = 'Umbral de área que elimina componentes segmentados pequeños.';
        elseif contains(clave, 'cierre')
            ayuda = 'Operación morfológica que une interrupciones del contorno.';
        elseif contains(clave, 'alpha')
            ayuda = 'Parámetro de AlphaShape que controla el detalle de la superficie 3D.';
        elseif contains(clave, 'subdivisión')
            ayuda = 'Refinamiento geométrico aplicado a las caras de la malla.';
        elseif contains(clave, 'suavizado')
            ayuda = 'Reducción iterativa de irregularidades de la superficie.';
        elseif contains(clave, 'rotación')
            ayuda = 'Ajuste angular del STL simulado alrededor del eje indicado.';
        elseif contains(clave, 'traslación')
            ayuda = 'Desplazamiento del STL simulado sobre el eje indicado.';
        elseif contains(clave, 'segmentar')
            ayuda = 'Ejecuta la segmentación indicada sobre las imágenes cargadas.';
        elseif contains(clave, 'calibrar')
            ayuda = 'Define escala y correspondencia espacial entre imágenes o geometrías.';
        elseif contains(clave, 'reconstruir')
            ayuda = 'Genera y guarda la superficie tridimensional desde los contornos segmentados.';
        elseif contains(clave, 'volumen')
            ayuda = 'Calcula o compara el volumen encerrado por las mallas STL.';
        else
            ayuda = 'Control de la verificación geométrica experimental.';
        end
    end

    % Habilita desplazamiento en contenedores compatibles.
    function activarScroll(obj)
        if isprop(obj, 'Scrollable')
            try
                obj.Scrollable = 'on';
            catch
                obj.Scrollable = true;
            end
        end
    end

    % Crea un área gráfica dentro de un panel.
    function ax = crearPanelEje(parent, tituloPanel, row, col, tag)
        pnl = crearPanel(parent, tituloPanel, row, col, [tag '_panel']);
        gax = uigridlayout(pnl, [1 1]);
        gax.Padding = [6 6 6 6];
        ax = uiaxes(gax, 'Tag', tag);
        ax.Layout.Row = 1;
        ax.Layout.Column = 1;
    end

    % Resuelve la carpeta inicial para seleccionar archivos STL.
    function inicio = directorioInicial()
        inicio = char(app.carpeta);
        if strlength(app.carpeta) == 0 || ~isfolder(inicio)
            inicio = app.data_root;
        end
    end

    % Filtra carpetas experimentales y sincroniza sus selectores.
    function aplicarFiltrosMetadata()
        for idx_objetivo = 1:numel(filtrosMetadata)
            control = filtrosMetadata(idx_objetivo).control;
            valor_previo = char(control.Value);
            mask_opciones = true(1, numel(app.catalogo_carpetas));
            for idx_otro = 1:numel(filtrosMetadata)
                if idx_otro == idx_objetivo
                    continue;
                end
                valor_otro = filtrosMetadata(idx_otro).control.Value;
                if ~strcmp(valor_otro, 'Todos')
                    mask_opciones = mask_opciones & strcmpi( ...
                        {app.catalogo_carpetas.(filtrosMetadata(idx_otro).campo)}, valor_otro);
                end
            end
            valores = unique( ...
                {app.catalogo_carpetas(mask_opciones).(filtrosMetadata(idx_objetivo).campo)}, ...
                'stable');
            valores = valores(~cellfun('isempty', valores));
            items = [{'Todos'}, valores];
            if any(strcmpi(items, valor_previo))
                control.Items = items;
                control.Value = valor_previo;
            else
                control.Value = 'Todos';
                control.Items = items;
                control.Value = 'Todos';
            end
        end

        mask = true(1, numel(app.catalogo_carpetas));
        for idx = 1:numel(filtrosMetadata)
            valor = filtrosMetadata(idx).control.Value;
            if ~strcmp(valor, 'Todos')
                mask = mask & strcmpi({app.catalogo_carpetas.(filtrosMetadata(idx).campo)}, valor);
            end
        end
        catalogo = app.catalogo_carpetas(mask);
        if isempty(catalogo)
            ddDataset.Items = {'(sin carpetas)'};
            ddDataset.ItemsData = {''};
            ddDataset.Value = '';
        else
            ddDataset.Items = {catalogo.etiqueta};
            ddDataset.ItemsData = {catalogo.ruta};
            ddDataset.Value = catalogo(1).ruta;
            filtros_visibles = arrayfun(@(f) ...
                strcmp(f.control.Visible, 'on'), filtrosMetadata);
            filtros_completos = any(filtros_visibles) && all(arrayfun(@(f) ...
                ~strcmp(f.control.Value, 'Todos'), filtrosMetadata(filtros_visibles)));
            if filtros_completos
                cargarCarpetaSeleccionada(ddDataset.Value);
            end
        end
    end

    % Carga y ordena las imágenes del experimento seleccionado.
    function cargarCarpetaSeleccionada(carpeta)
        if isempty(carpeta) || ~isfolder(carpeta), return; end
        app.carpeta = string(carpeta);
        app.metadata_dataset = tesis_auxiliares('metadata_ruta', carpeta);
        fileList2 = listarImagenesJPEG(app.carpeta);

        if isempty(fileList2)
            uialert(fig, 'No se encontraron imágenes JPEG/JPG en la carpeta.', 'Sin imágenes');
            return;
        end

        nombres = {fileList2.name};
        numeros = zeros(numel(nombres), 1);
        for k = 1:numel(nombres)
            token = regexp(nombres{k}, '\d+', 'match', 'once');
            if isempty(token)
                numeros(k) = k;
            else
                numeros(k) = str2double(token);
            end
        end
        [~, orden] = sort(numeros);
        app.fileList = fileList2(orden);
        app.nFiles = length(app.fileList);
        app.BW = cell(app.nFiles, 1);
        app.contorno = cell(app.nFiles, 1);
        app.imagenes_validas = false(app.nFiles, 1);
        app.cara_imagen = zeros(app.nFiles, 1);
        app.BW_hueso_alineado = cell(app.nFiles, 1);
        app.idx_validas = [];
        app.BW_ablacion = {};
        app.contorno_ablacion = {};

        lstImagenes.Items = {app.fileList.name};
        btnProcesar.Enable = 'on';
        btnCalibrar.Enable = 'off';
        btnAblacion.Enable = 'off';
        btnGrosores.Enable = 'off';
        btnReconstruir.Enable = 'off';
        btnCalcular.Enable = 'off';
        btnComparar.Enable = 'off';
        limpiarAxes();
        logEstado(['Dataset cargado: ' num2str(app.nFiles) ' imágenes.']);
    end

    % Segmenta hueso y solicita validar cada imagen.
    function procesarImagenes()
        if app.nFiles == 0
            return;
        end

        for i = 1:app.nFiles
            nombre = app.fileList(i).name;
            filename = fullfile(app.carpeta, nombre);
            img = leerImagenConOrientacion(filename);

            tabs.SelectedTab = tabSeg;
            mostrarImagen(axOriginal, img, ['Original - ' nombre]);
            drawnow;

            respuesta = uiconfirm(fig, ['¿La imagen ' nombre ' contiene ablación?'], 'Confirmar ablación', 'Options', {'Sí', 'No'}, 'DefaultOption', 1, 'CancelOption', 2);

            if strcmp(respuesta, 'No')
                app.imagenes_validas(i) = false;
                app.cara_imagen(i) = 0;
                logEstado(['Descartada: ' nombre]);
                continue;
            end

            app.imagenes_validas(i) = true;

            if i == 1
                app.cara_imagen(i) = 1;
            else
                cara = uiconfirm(fig, ['¿La imagen ' nombre ' corresponde a la cara 1 o cara 2 del segmento?'], 'Cara del segmento', 'Options', {'Cara 1', 'Cara 2'}, 'DefaultOption', 1, 'CancelOption', 1);

                if strcmp(cara, 'Cara 2')
                    app.cara_imagen(i) = 2;
                else
                    app.cara_imagen(i) = 1;
                end
            end

            [app.BW{i}, app.contorno{i}, L] = segmentarKmeansContorno( img, spnClusters.Value, spnArea.Value, spnCierre.Value);

            mostrarImagen(axKmeans, label2rgb(L), ['K-means - ' nombre]);
            mostrarImagen(axContorno, img, ['Contorno hueso - ' nombre]);
            hold(axContorno, 'on');

            if ~isempty(app.contorno{i})
                plot(axContorno, app.contorno{i}(:, 2), app.contorno{i}(:, 1), 'g', 'LineWidth', 2);
            end

            hold(axContorno, 'off');
            drawnow;

            if isempty(app.contorno{i})
                app.imagenes_validas(i) = false;
                app.cara_imagen(i) = 0;
                logEstado(['Sin contorno válido: ' nombre]);
                continue;
            end

            aceptar = uiconfirm(fig, ['Revise la segmentación de hueso de ' nombre '. ¿Desea aceptarla?'], 'Aceptar segmentación', 'Options', {'Aceptar', 'Descartar'}, 'DefaultOption', 1, 'CancelOption', 2);

            if strcmp(aceptar, 'Descartar')
                app.imagenes_validas(i) = false;
                app.cara_imagen(i) = 0;
                logEstado(['Segmentación descartada: ' nombre]);
            else
                logEstado(['Segmentación aceptada: ' nombre]);
            end
        end

        app.idx_validas = find(app.imagenes_validas);

        if isempty(app.idx_validas)
            uialert(fig, 'No hay imágenes válidas para continuar.', 'Sin imágenes válidas');
            return;
        end

        btnCalibrar.Enable = 'on';
        logEstado(['Imágenes válidas: ' num2str(length(app.idx_validas))]);
    end

    % Calibra la escala y alinea los cortes experimentales.
    function calibrarYAlinear()
        if isempty(app.idx_validas)
            return;
        end

        idx_escala = app.idx_validas(1);
        img_escala = leerImagenConOrientacion(fullfile(app.carpeta, app.fileList(idx_escala).name));
        [app.mmPorPixel, app.distanciaPixeles, app.distanciaRealMm] = calibrarEscalaDosPuntos(img_escala, app.fileList(idx_escala).name);

        carpeta_salida = fullfile(app.carpeta, 'Alineadas');
        crearCarpeta(carpeta_salida);

        img_fija_idx = app.idx_validas(1);
        fixedRGB = leerImagenConOrientacion(fullfile(app.carpeta, app.fileList(img_fija_idx).name));
        app.BW_fixed = app.BW{img_fija_idx};

        imwrite(fixedRGB, fullfile(carpeta_salida, app.fileList(img_fija_idx).name));
        app.BW_hueso_alineado{img_fija_idx} = app.BW_fixed;
        mostrarImagen(axOverlay, fixedRGB, 'Imagen fija inicial');

        for k = 2:length(app.idx_validas)
            moving_idx = app.idx_validas(k);
            movingRGB = leerImagenConOrientacion(fullfile(app.carpeta, app.fileList(moving_idx).name));
            BW_moving = app.BW{moving_idx};

            tform = ajustarContornoManual(BW_moving, app.BW_fixed);

            RGB_reg = imwarp(movingRGB, tform, 'OutputView', imref2d(size(app.BW_fixed)));
            BW_reg = imwarp(BW_moving, tform, 'OutputView', imref2d(size(app.BW_fixed))) > 0;

            app.BW_hueso_alineado{moving_idx} = BW_reg;
            imwrite(RGB_reg, fullfile(carpeta_salida, app.fileList(moving_idx).name));

            overlay = imfuse(fixedRGB, RGB_reg, 'falsecolor', 'Scaling', 'joint', 'ColorChannels', [1 2 0]);

            mostrarImagen(axOverlay, overlay, ['Overlay fija #' num2str(img_fija_idx) ' / movida #' num2str(moving_idx)]);
            drawnow;

            fixedRGB = RGB_reg;
            app.BW_fixed = BW_reg;
            img_fija_idx = moving_idx;
        end

        btnAblacion.Enable = 'on';
        logEstado(['Escala: ' num2str(app.mmPorPixel) ' mm/pixel. Alineación terminada.']);
    end

    % Segmenta ablación y permite recortar las regiones detectadas.
    function segmentarAblacion()
        carpeta_ablacion = fullfile(app.carpeta, 'Ablacion_segmentada');
        carpeta_salida = fullfile(app.carpeta, 'Alineadas');
        crearCarpeta(carpeta_ablacion);

        nValidas = length(app.idx_validas);
        app.BW_ablacion = cell(nValidas, 1);
        app.contorno_ablacion = cell(nValidas, 1);

        for k = 1:nValidas
            idx_img = app.idx_validas(k);
            nombreImg = app.fileList(idx_img).name;
            img_alineada = imread(fullfile(carpeta_salida, nombreImg));

            BW_hueso = app.BW_hueso_alineado{idx_img};
            [app.BW_ablacion{k}, app.contorno_ablacion{k}] = segmentarAblacionCafeCarbonizada(img_alineada, BW_hueso);

            imwrite(app.BW_ablacion{k}, fullfile(carpeta_ablacion, ['MASK_' nombreImg]));

            mostrarImagen(axAblacion, img_alineada, ['Ablación - ' nombreImg]);
            hold(axAblacion, 'on');

            if ~isempty(app.contorno_ablacion{k})
                plot(axAblacion, app.contorno_ablacion{k}(:, 2), app.contorno_ablacion{k}(:, 1), 'c', 'LineWidth', 2);
            end

            hold(axAblacion, 'off');
            drawnow;

            exportgraphics(axAblacion, fullfile(carpeta_ablacion, ['CONTORNO_' nombreImg]));
            respuesta = uiconfirm(fig,'¿Desea recortar manualmente esta ablación?','Edición manual','Options',{'Sí','No'});

            if respuesta == "Sí"

                imshow(img_alineada,'Parent',axAblacion);
                hold(axAblacion,'on');

                visboundaries(axAblacion,app.BW_ablacion{k},'Color','c','LineWidth',2);

                title(axAblacion,'Dibuje una línea atravesando la ablación');
                while true

                    h = drawfreehand(axAblacion,'Color','r');

                    lineMask = createMask(h);

                    lineMask = imdilate(lineMask,strel('disk',5));

                    BW_cortada = app.BW_ablacion{k};
                    BW_cortada(lineMask) = 0;

                    L = bwlabel(BW_cortada);

                    if max(L(:)) >= 2
                        break;
                    end

                    uialert(fig,'La línea no dividió la ablación. Intente nuevamente.','Corte inválido');

                end
                imshow(label2rgb(L),'Parent',axAblacion);

                title(axAblacion,'Haga clic sobre la mitad que desea conservar');

                p = drawpoint(axAblacion);
                x = p.Position(1);
                y = p.Position(2);

                fila = max(1,min(size(L,1),round(y)));
                columna = max(1,min(size(L,2),round(x)));

                etiqueta = L(fila,columna);

                if etiqueta > 0
                    app.BW_ablacion{k} = (L == etiqueta);
                end
                B = bwboundaries(app.BW_ablacion{k});

                if ~isempty(B)
                    longitudes = cellfun(@length,B);
                    [~,idxMax] = max(longitudes);
                    app.contorno_ablacion{k} = B{idxMax};
                end

                mostrarImagen(axAblacion,img_alineada,['Ablación - ' nombreImg]);

                hold(axAblacion,'on');

                if ~isempty(app.contorno_ablacion{k})
                    plot(axAblacion,app.contorno_ablacion{k}(:,2),app.contorno_ablacion{k}(:,1),'g','LineWidth',2);
                end

                hold(axAblacion,'off');
                imwrite(app.BW_ablacion{k}, fullfile(carpeta_ablacion,['MASK_' nombreImg]));
            end
        end

        save(fullfile(carpeta_ablacion, 'contornos_ablacion.mat'), '-struct', 'app', 'BW_ablacion', 'contorno_ablacion', 'cara_imagen', 'idx_validas', 'fileList');

        btnGrosores.Enable = 'on';
        logEstado('Segmentación de ablación terminada.');
    end

    % Captura espesores y calcula posiciones de los cortes.
    function capturarGrosores()
        app.caras_validas = app.cara_imagen(app.idx_validas);
        app.segmento_imagen = asignarSegmentosPorCara(app.caras_validas);
        nSegmentos = max(app.segmento_imagen);
        app.grosores_segmentos = zeros(nSegmentos, 1);

        for s = 1:nSegmentos
            idx_segmento = find(app.segmento_imagen == s);
            nombresSegmento = strjoin({app.fileList(app.idx_validas(idx_segmento)).name}, ', ');

            respuesta = inputdlg( ['Ingrese el grosor del segmento ' num2str(s) ' en mm:' newline nombresSegmento], 'Grosor del corte', [1 65], {'1'});

            if isempty(respuesta)
                app.grosores_segmentos(s) = 1;
            else
                app.grosores_segmentos(s) = str2double(respuesta{1});
            end

            if isnan(app.grosores_segmentos(s)) || app.grosores_segmentos(s) <= 0
                app.grosores_segmentos(s) = 1;
            end
        end

        app.z_cortes = calcularZPorCara(app.caras_validas, app.segmento_imagen, app.grosores_segmentos);
        app.grosores = app.grosores_segmentos;

        carpeta_ablacion = fullfile(app.carpeta, 'Ablacion_segmentada');
        save(fullfile(carpeta_ablacion, 'grosores_segmentos.mat'), '-struct', 'app', 'grosores', 'grosores_segmentos', 'caras_validas', 'segmento_imagen', 'z_cortes');

        btnReconstruir.Enable = 'on';
        logEstado('Grosores capturados.');
    end

    % Reconstruye y guarda la superficie tridimensional de ablación.
    function reconstruir3D()
        if isempty(app.z_cortes)
            uialert(fig, 'Primero capture los grosores.', 'Faltan grosores');
            return;
        end
        [app.shp, app.puntos3D] = reconstruirAblacion3DAlphaShape( app.BW_ablacion,app.z_cortes, app.mmPorPixel, spnAlpha.Value);

        [app.carasSTL, app.verticesSTL] = boundaryFacets(app.shp);

        if spnSubdiv.Value > 0
            [app.carasSTL, app.verticesSTL] = subdividirMallaTriangular( app.carasSTL, app.verticesSTL, round(spnSubdiv.Value));
        end

        if spnSuavizado.Value > 0
            app.verticesSTL = suavizarMallaTaubin( app.carasSTL, app.verticesSTL, round(spnSuavizado.Value), 0.45, -0.48);
        end

        cla(ax3D);
        patch(ax3D, 'Faces', app.carasSTL, 'Vertices', app.verticesSTL, 'FaceColor', [0.95 0.45 0.02], 'FaceAlpha', 1, 'EdgeColor', 'none');

        axis(ax3D, 'equal');
        grid(ax3D, 'on');
        view(ax3D, 3);
        camlight(ax3D);
        lighting(ax3D,'gouraud');
        xlabel(ax3D, 'X [mm]');
        ylabel(ax3D, 'Y [mm]');
        zlabel(ax3D, 'Z [mm]');
        title(ax3D, 'Reconstrucción 3D suavizada de ablación');
        tabs.SelectedTab = tab3D;

        carpeta_ablacion = fullfile(app.carpeta, 'Ablacion_segmentada');
        app.archivoSTL = fullfile(carpeta_ablacion, 'reconstruccion_ablacion_3D.stl');
        escribirSTLASCII(app.archivoSTL, app.carasSTL, app.verticesSTL);

        save(fullfile(carpeta_ablacion, 'reconstruccion_ablacion_3D.mat'), ...
            '-struct', 'app', ...
            'shp', ...
            'puntos3D', ...
            'carasSTL', ...
            'verticesSTL', ...
            'grosores', ...
            'grosores_segmentos', ...
            'caras_validas', ...
            'segmento_imagen', ...
            'z_cortes', ...
            'mmPorPixel', ...
            'distanciaPixeles', ...
            'distanciaRealMm', ...
            'metadata_dataset', ...
            'archivoSTL');

        btnCalcular.Enable = 'on';
        btnSTLfijo.Enable = 'on';

        logEstado(['STL guardado: ' char(app.archivoSTL)]);
        btnSTlHueso.Enable = 'on';
    end

    % Reconstruye y exporta la superficie tridimensional del hueso.
    function CalculSTLhues()
        if isempty(app.z_cortes)
            uialert(fig, 'Primero capture los grosores.', 'Faltan grosores');
            return;
        end
        BW_hueso_valido = app.BW_hueso_alineado(app.idx_validas);
        shp_hueso = reconstruirAblacion3DAlphaShape( BW_hueso_valido ,app.z_cortes, app.mmPorPixel, spnAlpha.Value);

        [app.carasSTL_hueso, app.verticesSTL_hueso] = boundaryFacets(shp_hueso);

        if spnSubdiv.Value > 0
            [app.carasSTL_hueso, app.verticesSTL_hueso] = subdividirMallaTriangular( app.carasSTL_hueso, app.verticesSTL_hueso, round(spnSubdiv.Value));
        end

        if spnSuavizado.Value > 0
            app.verticesSTL_hueso = suavizarMallaTaubin( app.carasSTL_hueso, app.verticesSTL_hueso, round(spnSuavizado.Value), 0.45, -0.48);
        end

        carpeta_ablacion = fullfile(app.carpeta, 'Ablacion_segmentada');
        app.archivoSTL_hueso = string(fullfile(carpeta_ablacion, 'reconstruccion_hueso_3D.stl'));
        escribirSTLASCII(app.archivoSTL_hueso, app.carasSTL_hueso, app.verticesSTL_hueso);

        logEstado(['STL de hueso guardado: ' char(app.archivoSTL_hueso)]);
    end

    % Restablece las gráficas del flujo de reconstrucción.
    function limpiarAxes()
        ejes = [axOriginal axKmeans axContorno axOverlay axAblacion ax3D];

        for e = 1:numel(ejes)
            cla(ejes(e));
            title(ejes(e), '');
            axis(ejes(e), 'off');
        end
    end

    % Registra el estado de las operaciones experimentales.
    function logEstado(msg)
        anterior = txtEstado.Value;
        if ischar(anterior)
            anterior = {anterior};
        end
        txtEstado.Value = [{char(msg)}; anterior(:)];
        drawnow;
    end

    % Calcula el volumen voxelizado del STL reconstruido.
    function CalcularVol()
        if strlength(app.archivoSTL) == 0 || ~isfile(app.archivoSTL)
            btnCalcular.Enable = 'off';
            uialert(fig, 'Primero debe reconstruir y guardar el STL completo.', 'STL no disponible');
            return;
        end

        TR = stlread(app.archivoSTL);

        V = TR.Points;
        F = TR.ConnectivityList;

        centroide = mean(V,1);

        V = V - centroide;

        resolucion = 1.5;

        minV = min(V);
        maxV = max(V);

        [xg,yg,zg] = meshgrid(minV(1):resolucion:maxV(1),minV(2):resolucion:maxV(2),minV(3):resolucion:maxV(3));

        grid = [xg(:) yg(:) zg(:)];

        mask = inpolyhedron(F,V,grid);

        volumen = sum(mask) * resolucion^3;

        logEstado(['Volumen calculado: ' num2str(volumen) ' mm^3']);

    end

    % Carga y centra la malla experimental reconstruida.
    function SelecionarSTL_fij()
        [archivo, ruta] = uigetfile({'*.stl', 'Archivos STL (*.stl)'}, ...
            'Selecciona el STL reconstruido', directorioInicial());

        if isequal(archivo, 0)
            return;
        end

        TR_1 = stlread(fullfile(ruta, archivo));
        V_Fija = TR_1.Points;
        F_Fija = TR_1.ConnectivityList;

        V_Fija = V_Fija - mean(V_Fija);

        app.V_Fija = V_Fija;
        app.F_Fija = F_Fija;

        redibujarComparacionSTL('Comparación de volumen');
        actualizarControlesSTL();

    end

    % Carga y centra la malla simulada para compararla.
    function SelecionarSTL_rot()
        [archivo, ruta] = uigetfile({'*.stl', 'Archivos STL (*.stl)'}, ...
            'Selecciona el STL simulado', directorioInicial());

        if isequal(archivo, 0)
            return;
        end

        TR = stlread(fullfile(ruta, archivo));
        V_lib = TR.Points;
        F_lib = TR.ConnectivityList;

        V_lib = V_lib - mean(V_lib);

        app.F_lib = F_lib;
        app.V_lib = V_lib;
        app.V_lib_ori = V_lib;
        app.RotX = 0;
        app.RotY = 0;
        app.RotZ = 0;
        app.T = [0 0 0];

        redibujarComparacionSTL('Comparación de volumen');
        actualizarControlesSTL();

    end

    % Habilita la comparación cuando ambas mallas están disponibles.
    function actualizarControlesSTL()
        disponibles = isfield(app, 'V_Fija') && ~isempty(app.V_Fija) && ...
            isfield(app, 'V_lib') && ~isempty(app.V_lib);
        controles = [btnComparar btnCalibrarSTL btnSTLNormZ ...
            btnMasX btnMenX btnMasY btnMenY btnMasZ btnMenZ ...
            btnMasXTr btnMenXTr btnMasYTr btnMenYTr btnMasZTr btnMenZTr];
        for k = 1:numel(controles)
            controles(k).Enable = disponibles;
        end
    end

    % Inicia la alineación de mallas mediante puntos equivalentes.
    function CalibrarSTLPorPuntos()
        if ~isfield(app,'V_Fija') || isempty(app.V_Fija) || ...
                ~isfield(app,'V_lib') || isempty(app.V_lib)
            uialert(fig, 'Carga primero el STL reconstruido y el STL simulado.', 'STL incompletos');
            return;
        end

        app.punto_cal_fijo = [];
        app.normal_cal_fijo = [];
        dibujarSeleccionCalibracion('Seleccione punto equivalente en STL reconstruido', true, false);
        fig.Pointer = 'crosshair';
        logEstado('Calibración STL: seleccione el punto equivalente en el STL reconstruido.');
    end

    % Muestra las mallas y habilita la selección correspondiente.
    function dibujarSeleccionCalibracion(titulo, seleccionarFijo, seleccionarLibre)
        cla(ax3D_1);
        hold(ax3D_1,"on"); axis(ax3D_1, 'equal'); view(ax3D_1,3)
        xlabel(ax3D_1,'X'); ylabel(ax3D_1, 'Y'); zlabel(ax3D_1, 'Z');
        title(ax3D_1,titulo);

        patch_fijo = patch(ax3D_1,'Faces',app.F_Fija,'Vertices',app.V_Fija, ...
            'FaceColor',[1 0 0],'EdgeColor','none','FaceAlpha',0.3, ...
            'PickableParts','visible','HitTest','off');
        patch_libre = patch(ax3D_1,'Faces',app.F_lib,'Vertices',app.V_lib, ...
            'FaceColor',[0 0 1],'EdgeColor','none','FaceAlpha',0.6, ...
            'PickableParts','visible','HitTest','off');
        if seleccionarFijo
            patch_fijo.HitTest = 'on';
            patch_fijo.ButtonDownFcn = @capturarPuntoCalibracionFijo;
        end
        if seleccionarLibre
            patch_libre.HitTest = 'on';
            patch_libre.ButtonDownFcn = @capturarPuntoCalibracionLibre;
        end

        if isfield(app,'punto_cal_fijo') && ~isempty(app.punto_cal_fijo)
            plot3(ax3D_1, app.punto_cal_fijo(1), app.punto_cal_fijo(2), app.punto_cal_fijo(3), ...
                'yo', 'MarkerSize', 9, 'LineWidth', 2);
        end

        camlight(ax3D_1); lighting(ax3D_1, 'gouraud');
        legend(ax3D_1,{'Reconstruido','Simulado'}, 'Location','best');
        hold(ax3D_1,'on');
    end

    % Captura el punto y normal de referencia experimental.
    function capturarPuntoCalibracionFijo(~, evento)
        [app.punto_cal_fijo, app.normal_cal_fijo] = puntoNormalMasCercano( ...
            app.V_Fija, app.F_Fija, evento.IntersectionPoint);
        dibujarSeleccionCalibracion('Seleccione el punto equivalente en STL simulado', false, true);
        logEstado('Punto del reconstruido capturado. Seleccione el punto equivalente en el STL simulado.');
    end

    % Alinea el punto y normal de la malla simulada.
    function capturarPuntoCalibracionLibre(~, evento)
        [punto_libre, normal_libre] = puntoNormalMasCercano( ...
            app.V_lib, app.F_lib, evento.IntersectionPoint);
        normal_fija = app.normal_cal_fijo;
        if dot(normal_libre, normal_fija) < 0
            normal_libre = -normal_libre;
        end

        Rcal = rotacionEntreVectores(normal_libre, normal_fija);
        app.V_lib = (Rcal * (app.V_lib - punto_libre)')' + app.punto_cal_fijo;
        app.V_lib_ori = app.V_lib;
        app.RotX = 0;
        app.RotY = 0;
        app.RotZ = 0;
        app.T = [0 0 0];
        fig.Pointer = 'arrow';

        redibujarComparacionSTL('Comparación de volumen');
        logEstado('Calibración STL aplicada: punto equivalente y normal de cara alineados.');
    end

    % Actualiza la representación de las mallas disponibles.
    function redibujarComparacionSTL(titulo)
        cla(ax3D_1);
        hold(ax3D_1, 'on'); axis(ax3D_1, 'equal'); view(ax3D_1, 3);
        xlabel(ax3D_1, 'X'); ylabel(ax3D_1, 'Y'); zlabel(ax3D_1, 'Z');
        title(ax3D_1, titulo);
        if isfield(app, 'V_Fija') && ~isempty(app.V_Fija)
            patch(ax3D_1, 'Faces', app.F_Fija, 'Vertices', app.V_Fija, ...
                'FaceColor', [1 0 0], 'EdgeColor', 'none', 'FaceAlpha', 0.3, ...
                'DisplayName', 'Reconstruido');
        end
        if isfield(app, 'V_lib') && ~isempty(app.V_lib)
            patch(ax3D_1, 'Faces', app.F_lib, 'Vertices', app.V_lib, ...
                'FaceColor', [0 0 1], 'EdgeColor', 'none', 'FaceAlpha', 0.6, ...
                'DisplayName', 'Simulado');
        end
        camlight(ax3D_1); lighting(ax3D_1, 'gouraud');
        legend(ax3D_1, 'show');
    end

    % Rota la malla simulada conservando su traslación.
    function rotarSTL(eje, paso)
        campo = ['Rot' eje];
        app.(campo) = app.(campo) + paso;
        Rx = [1 0 0; 0 cosd(app.RotX) -sind(app.RotX); 0 sind(app.RotX) cosd(app.RotX)];
        Ry = [cosd(app.RotY) 0 sind(app.RotY); 0 1 0; -sind(app.RotY) 0 cosd(app.RotY)];
        Rz = [cosd(app.RotZ) -sind(app.RotZ) 0; sind(app.RotZ) cosd(app.RotZ) 0; 0 0 1];
        app.V_lib = ((Rz * Ry * Rx) * app.V_lib_ori')' + app.T;
        redibujarComparacionSTL('Comparación de volumen');
    end

    % Desplaza la malla simulada sobre el eje indicado.
    function trasladarSTL(eje, paso)
        app.T(eje) = app.T(eje) + paso;
        app.V_lib(:, eje) = app.V_lib(:, eje) + paso;
        redibujarComparacionSTL('Comparación de volumen');
    end

    % Obtiene la normal de la cara más cercana.
    function [punto, normal] = puntoNormalMasCercano(vertices, caras, punto_click)
        punto = punto_click(:)';
        centroides = (vertices(caras(:,1),:) + vertices(caras(:,2),:) + vertices(caras(:,3),:)) / 3;
        [~, idx_cara] = min(vecnorm(centroides - punto, 2, 2));
        v1 = vertices(caras(idx_cara,1),:);
        v2 = vertices(caras(idx_cara,2),:);
        v3 = vertices(caras(idx_cara,3),:);
        normal = cross(v2 - v1, v3 - v1);
        if norm(normal) < eps
            normal = [0 0 1];
        else
            normal = normal / norm(normal);
        end
    end

    % Calcula la rotación que alinea dos direcciones.
    function Rcal = rotacionEntreVectores(origen, destino)
        origen = origen(:) / norm(origen);
        destino = destino(:) / norm(destino);
        eje = cross(origen, destino);
        seno = norm(eje);
        coseno = dot(origen, destino);
        if seno < 1e-8
            if coseno > 0
                Rcal = eye(3);
                return;
            end
            [~, idx] = min(abs(origen));
            aux = zeros(3,1);
            aux(idx) = 1;
            eje = cross(origen, aux);
            eje = eje / norm(eje);
            angulo = pi;
        else
            eje = eje / seno;
            angulo = atan2(seno, coseno);
        end
        K = [0 -eje(3) eje(2); eje(3) 0 -eje(1); -eje(2) eje(1) 0];
        Rcal = eye(3) + sin(angulo) * K + (1 - cos(angulo)) * (K * K);
    end

    % Solicita una referencia para orientar las mallas hacia Z.
    function RotarZ()

        cla(ax3D_1);
        hold((ax3D_1),"on"); axis(ax3D_1, 'equal'); view(ax3D_1,3)
        xlabel(ax3D_1,'X'); ylabel(ax3D_1, 'Y'); zlabel(ax3D_1, 'Z');
        title(ax3D_1,'Haz clic en el punto que deseas alinear con el eje Z');

        patch(ax3D_1,'Faces',app.F_Fija,'Vertices',app.V_Fija,'FaceColor',[1 0 0],'EdgeColor','none','FaceAlpha',0.3, ...
            'PickableParts','visible','HitTest','on','ButtonDownFcn',@seleccionarPuntoParaZ);
        patch(ax3D_1,'Faces',app.F_lib,'Vertices',app.V_lib,'FaceColor',[0 0 1],'EdgeColor','none','FaceAlpha',0.6, ...
            'PickableParts','visible','HitTest','on','ButtonDownFcn',@seleccionarPuntoParaZ);

        camlight(ax3D_1); lighting(ax3D_1, 'gouraud');
        legend(ax3D_1,{'Reconstruido','Simulado'});
        hold(ax3D_1,'on');

        % Orienta ambas mallas usando el punto seleccionado.
        function seleccionarPuntoParaZ(~, evento)
            punto_objetivo = evento.IntersectionPoint(:);
            z_axis = [0; 0; 1];

            if norm(punto_objetivo) < eps
                uialert(fig, 'El punto seleccionado esta demasiado cerca del origen.', 'Punto no valido');
                return;
            end

            R = rotacionEntreVectores(punto_objetivo, z_axis);

            app.V_Fija = (R * app.V_Fija')';
            app.V_lib = (R * app.V_lib')';
            app.V_lib_ori = app.V_lib;
            app.RotX = 0;
            app.RotY = 0;
            app.RotZ = 0;
            app.T = [0 0 0];

            redibujarComparacionSTL('Comparación de volumen');

        end

    end

    % Calcula cobertura, intersección, Dice e IoU entre mallas.
    function CompaVol()
        resolucion = 1.0;
        minB = min([app.V_lib; app.V_Fija]);
        maxB = max([app.V_lib; app.V_Fija]);

        minG = minB - resolucion;
        maxG = maxB + resolucion;

        [xg, yg] = meshgrid(minG(1):resolucion:maxG(1),minG(2):resolucion:maxG(2));

        z_vals = minG(3):resolucion:maxG(3);

        V_gota_contador = 0;
        V_overlap = 0;
        V_Fija_contador = 0;

        for k = 1:length(z_vals)

            z = z_vals(k);
            puntos = [xg(:), yg(:), z*ones(numel(xg),1)];

            dentro_gota = inpolyhedron(app.F_lib, app.V_lib, puntos);

            dentro_Fija = inpolyhedron(app.F_Fija, app.V_Fija, puntos);

            V_gota_contador = V_gota_contador + sum(dentro_gota);

            V_overlap = V_overlap + sum(dentro_gota & dentro_Fija);

            V_Fija_contador = V_Fija_contador + sum(dentro_Fija);

        end

        Vtotal_Fija = V_Fija_contador * resolucion^3;
        Vtotal_gota   = V_gota_contador * resolucion^3;
        Vdentro    = V_overlap * resolucion^3;
        Vfuera     = (V_gota_contador - V_overlap) * resolucion^3;
        porc_fuera = 100 * Vfuera / Vtotal_gota;
        porc_ocup_Fija = 100 * Vdentro / Vtotal_Fija;
        Dice = (2*Vdentro/(Vtotal_gota + Vtotal_Fija))*100;
        Vunion = Vtotal_gota + Vtotal_Fija - Vdentro;
        IoU = (Vdentro / Vunion)*100;

        logEstado(['Volumen del STL simulado : ' num2str(Vtotal_gota) ' mm^3']);
        logEstado(['Volumen del STL reconstruido : ' num2str(Vtotal_Fija) ' mm^3']);
        logEstado(['Volumen interseccion:' num2str(Vdentro) ' mm^3']);
        logEstado(['Porcentaje cobertura: ' num2str(porc_ocup_Fija) ' %']);
        logEstado(['Volumen no coincidente : ' num2str(Vfuera) ' mm^3']);
        logEstado(['Porcentaje no coincidente: ' num2str(porc_fuera) ' %']);
        logEstado(['Coeficiente de semejanza Dice: ' num2str(Dice) ' %']);
        logEstado(['Coeficiente de semejanza IoU: ' num2str(IoU) ' %']);
    end

end

% Localiza imágenes JPEG del experimento.
function archivos = listarImagenesJPEG(carpeta)
archivos = dir(fullfile(carpeta, '*.JPEG'));
if isempty(archivos)
    archivos = dir(fullfile(carpeta, '*.jpg'));
end
if isempty(archivos)
    archivos = dir(fullfile(carpeta, '*.jpeg'));
end
end

% Crea el directorio requerido para guardar resultados.
function crearCarpeta(carpeta)

if ~exist(carpeta, 'dir')
    mkdir(carpeta);
end

end

% Muestra una imagen experimental con su título.
function mostrarImagen(ax, img, textoTitulo)

cla(ax);
imshow(img, 'Parent', ax);
title(ax, textoTitulo, 'Interpreter', 'none');
axis(ax, 'image');

end

% Segmenta el contorno del hueso mediante agrupación cromática.
function [BW_final, contorno, L] = segmentarKmeansContorno(img, numClusters, areaMinima, radioCierre)

imgDouble = im2double(img);
lab = rgb2lab(imgDouble);
hsvImg = rgb2hsv(imgDouble);

Lch = lab(:, :, 1);
ach = lab(:, :, 2);
bch = lab(:, :, 3);
Hch = hsvImg(:, :, 1);
Sch = hsvImg(:, :, 2);
Vch = hsvImg(:, :, 3);

R = imgDouble(:, :, 1);
G = imgDouble(:, :, 2);
Bc = imgDouble(:, :, 3);

[filas, columnas, ~] = size(img);

datos = [Lch(:), ach(:), bch(:), Hch(:) * 100, Sch(:) * 100, Vch(:) * 100];
datos = normalize(datos);

rng(1);
idx = kmeans(datos, numClusters, 'Replicates', 5, 'MaxIter', 400);
L = reshape(idx, filas, columnas);

borde = false(filas, columnas);
anchoBorde = max(10, round(min(filas, columnas) * 0.03));
borde(1:anchoBorde, :) = true;
borde(end-anchoBorde+1:end, :) = true;
borde(:, 1:anchoBorde) = true;
borde(:, end-anchoBorde+1:end) = true;

etiquetasBorde = L(borde);
conteoBorde = histcounts(etiquetasBorde, 1:numClusters + 1);
[~, etiquetaFondoPrincipal] = max(conteoBorde);

clusterObjeto = false(numClusters, 1);

for c = 1:numClusters
    maskC = L == c;
    fracBorde = sum(maskC(borde)) / max(sum(maskC(:)), 1);

    meanS = mean(Sch(maskC));
    meanV = mean(Vch(maskC));
    meanA = mean(ach(maskC));
    meanR = mean(R(maskC));
    meanG = mean(G(maskC));
    meanB = mean(Bc(maskC));

    redExcess = meanR - max(meanG, meanB);

    esRojo = meanS > 0.18 && meanA > 8 && redExcess > 0.03;
    esBlancoHueso = meanV > 0.45 && meanS < 0.45 && fracBorde < 0.45;
    noEsFondo = c ~= etiquetaFondoPrincipal && fracBorde < 0.55;

    clusterObjeto(c) = (esRojo || esBlancoHueso) && noEsFondo;
end

BW_color = ismember(L, find(clusterObjeto));
BW_color = imclearborder(BW_color);
BW_color = bwareaopen(BW_color, areaMinima);

BW_silueta = imclose(BW_color, strel('disk', radioCierre));
BW_silueta = imfill(BW_silueta, 'holes');
BW_silueta = imopen(BW_silueta, strel('disk', 4));
BW_silueta = imclose(BW_silueta, strel('disk', round(radioCierre * 0.6)));
BW_silueta = bwareaopen(BW_silueta, areaMinima);

CC = bwconncomp(BW_silueta);

if CC.NumObjects == 0
    BW_final = false(filas, columnas);
    contorno = [];
    return;
end

stats = regionprops(CC, 'Area', 'PixelIdxList');
areas = [stats.Area];
[~, idxMax] = max(areas);

BW_final = false(filas, columnas);
BW_final(stats(idxMax).PixelIdxList) = true;
BW_final = imfill(BW_final, 'holes');
BW_final = imclose(BW_final, strel('disk', 8));
BW_final = imopen(BW_final, strel('disk', 3));

B = bwboundaries(BW_final);

if isempty(B)
    contorno = [];
    return;
end

areasContorno = cellfun(@length, B);
[~, idxContornoMax] = max(areasContorno);
contorno = B{idxContornoMax};

end

% Lee la imagen y aplica su orientación registrada.
function img = leerImagenConOrientacion(filename)

img = imread(filename);
info = imfinfo(filename);

if isfield(info, 'Orientation')
    switch info.Orientation
        case 2
            img = fliplr(img);
        case 3
            img = imrotate(img, 180);
        case 4
            img = flipud(img);
        case 5
            img = imrotate(fliplr(img), 90);
        case 6
            img = imrotate(img, -90);
        case 7
            img = imrotate(fliplr(img), -90);
        case 8
            img = imrotate(img, 90);
    end
end

end

% Permite alinear contornos mediante rotaciones y desplazamientos manuales.
function tform_final = ajustarContornoManual(BW_moving, BW_fixed)

angulo = 0;
dx = 0;
dy = 0;
flipH = false;
flipV = false;
pasoTraslacion = 5;
pasoRotacion = 2;

fig = figure('Name', 'Ajuste manual por contorno', 'Color', 'w', 'KeyPressFcn', @tecla);

actualizar();
uiwait(fig);

tform_final = construirTransformacion(BW_moving, BW_fixed, angulo, dx, dy, flipH, flipV);

    % Aplica los controles de teclado de la alineación.
    function tecla(~, event)
        switch event.Key
            case 'rightarrow'
                dx = dx + pasoTraslacion;
            case 'leftarrow'
                dx = dx - pasoTraslacion;
            case 'downarrow'
                dy = dy + pasoTraslacion;
            case 'uparrow'
                dy = dy - pasoTraslacion;
            case 'd'
                angulo = angulo + pasoRotacion;
            case 'a'
                angulo = angulo - pasoRotacion;
            case 'h'
                flipH = ~flipH;
            case 'v'
                flipV = ~flipV;
            case 'r'
                angulo = 0;
                dx = 0;
                dy = 0;
                flipH = false;
                flipV = false;
            case {'return', 'space'}
                uiresume(fig);
                close(fig);
                return;
            case 'escape'
                tform_final = affine2d(eye(3));
                uiresume(fig);
                close(fig);
                return;
        end

        actualizar();
    end

    % Redibuja la superposición de contornos durante la alineación.
    function actualizar()
        if ~ishandle(fig)
            return;
        end

        tform_temp = construirTransformacion(BW_moving, BW_fixed, angulo, dx, dy, flipH, flipV);
        BW_reg = imwarp(BW_moving, tform_temp, 'OutputView', imref2d(size(BW_fixed))) > 0;

        overlay = cat(3, double(BW_fixed), double(BW_reg), zeros(size(BW_fixed)));
        imshow(overlay, 'Parent', gca);
        title({ ...
            'Alineación manual por contorno', ...
            'Fijo = rojo | Movido = verde | Coincidencia = amarillo', ...
            ['Angulo: ' num2str(angulo) '° | dx: ' num2str(dx) ' | dy: ' num2str(dy) ...
            ' | FlipH: ' num2str(flipH) ' | FlipV: ' num2str(flipV)], ...
            'Flechas: mover | A/D: rotar | H: espejo horizontal | V: espejo vertical | Espacio/Enter: aceptar | R: reiniciar'});
        drawnow;
    end

end

% Combina centrado, reflexión, rotación y traslación de imágenes.
function tform = construirTransformacion(BW_moving, BW_fixed, angulo, dx, dy, flipH, flipV)

[filasM, columnasM] = size(BW_moving);
[filasF, columnasF] = size(BW_fixed);

centroMoving = [columnasM, filasM] / 2;
centroFixed = [columnasF, filasF] / 2;

theta = deg2rad(angulo);
sx = 1;
sy = 1;

if flipH
    sx = -1;
end

if flipV
    sy = -1;
end

S = [sx 0 0; 0 sy 0; 0 0 1];
R = [cos(theta) sin(theta) 0; -sin(theta) cos(theta) 0; 0 0 1];
T_centro1 = [1 0 0; 0 1 0; -centroMoving(1) -centroMoving(2) 1];
T_centro2 = [1 0 0; 0 1 0; centroFixed(1) centroFixed(2) 1];
T_trans = [1 0 0; 0 1 0; dx dy 1];

tform = affine2d(T_centro1 * S * R * T_centro2 * T_trans);

end

% Detecta la región de ablación dentro del hueso.
function [BW_final, contorno] = segmentarAblacionCafeCarbonizada(img, BW_hueso)

imgDouble = im2double(img);
hsvImg = rgb2hsv(imgDouble);
labImg = rgb2lab(imgDouble);

H = hsvImg(:, :, 1);
S = hsvImg(:, :, 2);
V = hsvImg(:, :, 3);
L = labImg(:, :, 1);

R = imgDouble(:, :, 1);
G = imgDouble(:, :, 2);
Bl = imgDouble(:, :, 3);

BW_hueso = BW_hueso > 0;
BW_hueso = imfill(BW_hueso, 'holes');
BW_hueso = imerode(BW_hueso, strel('disk', 4));

maskCafe = H > 0.025 & H < 0.18 & S > 0.07 & S < 0.60 & V > 0.18 & V < 0.92 & R > G * 0.80 & R < G * 1.65 & G >= Bl * 0.65 ;

maskCarbon = V < 0.32 & L < 36 & S > 0.06 & R < 0.42 & G < 0.42 & Bl < 0.42;

BW = (maskCafe | maskCarbon) & BW_hueso;
BW = bwareaopen(BW, 250);
BW = imclose(BW, strel('disk', 7));
BW = imfill(BW, 'holes');
BW = imopen(BW, strel('disk', 3));
BW = bwareaopen(BW, 700);

CC = bwconncomp(BW);

if CC.NumObjects == 0
    BW_final = false(size(BW));
    contorno = [];
    return;
end

stats = regionprops(CC, 'Area', 'PixelIdxList', 'Centroid');
centroHueso = regionprops(BW_hueso, 'Centroid');

if isempty(centroHueso)
    centroRef = [size(BW, 2), size(BW, 1)] / 2;
else
    centroRef = centroHueso(1).Centroid;
end

mejorScore = -inf;
mejorIdx = 1;

for k = 1:CC.NumObjects
    pix = stats(k).PixelIdxList;
    area = stats(k).Area;
    centro = stats(k).Centroid;

    meanCafe = mean(maskCafe(pix));
    meanCarbon = mean(maskCarbon(pix));
    distanciaNorm = norm(centro - centroRef) / max(size(BW));

    score = area + 1200 * meanCafe + 1200 * meanCarbon - 3000 * distanciaNorm;

    if score > mejorScore
        mejorScore = score;
        mejorIdx = k;
    end
end

BW_final = false(size(BW));
BW_final(stats(mejorIdx).PixelIdxList) = true;
BW_final = imclose(BW_final, strel('disk', 5));
BW_final = imfill(BW_final, 'holes');

Bnd = bwboundaries(BW_final);

if isempty(Bnd)
    contorno = [];
    return;
end

longitudes = cellfun(@length, Bnd);
[~, idxContorno] = max(longitudes);
contorno = Bnd{idxContorno};

end

% Reconstruye el volumen desde máscaras y posiciones de cortes.
function [shp, puntos3D] = reconstruirAblacion3DAlphaShape(BW_ablacion, z_cortes, mmPorPixel, alphaFactor)

puntos3D = [];

for k = 1:length(BW_ablacion)
    BW = BW_ablacion{k};

    if isempty(BW) || ~any(BW(:))
        continue;
    end

    [y,x] = find(BW);
    maxPuntosPorCorte = 12000;
    paso = max(1, floor(length(x) / maxPuntosPorCorte));

    x = x(1:paso:end) * mmPorPixel;
    y = y(1:paso:end) * mmPorPixel;
    z = ones(size(x)) * z_cortes(k);

    puntos3D = [puntos3D; x y z];
end

if size(puntos3D, 1) < 10
    error('No hay suficientes puntos para reconstruir la ablación en 3D.');
end

if length(unique(puntos3D(:, 3))) < 2
    error('Solo hay un corte con ablación. Se necesitan al menos 2 cortes para reconstrucción 3D.');
end

shp = alphaShape(puntos3D(:, 1), puntos3D(:, 2), puntos3D(:, 3));
alphaCritico = criticalAlpha(shp, 'one-region');
shp.Alpha = alphaCritico * alphaFactor;

end

% Agrupa las caras de los cortes por segmento.
function segmento_imagen = asignarSegmentosPorCara(caras_validas)

segmento_imagen = zeros(size(caras_validas));
segmentoActual = 1;

for k = 1:length(caras_validas)
    if k > 1
        if caras_validas(k) == 1 || caras_validas(k - 1) == 2
            segmentoActual = segmentoActual + 1;
        end
    end

    segmento_imagen(k) = segmentoActual;
end

end

% Calcula posiciones axiales usando caras y espesores.
function z_cortes = calcularZPorCara(caras_validas, segmento_imagen, grosores_segmentos)

nSegmentos = length(grosores_segmentos);
zInicioSegmento = zeros(nSegmentos, 1);

for s = 2:nSegmentos
    zInicioSegmento(s) = zInicioSegmento(s - 1) + grosores_segmentos(s - 1);
end

z_cortes = zeros(size(caras_validas));

for k = 1:length(caras_validas)
    s = segmento_imagen(k);
    z_cortes(k) = zInicioSegmento(s);

    if caras_validas(k) == 2
        z_cortes(k) = z_cortes(k) + grosores_segmentos(s);
    end
end

end

% Determina la escala física mediante dos puntos conocidos.
function [mmPorPixel, distanciaPixeles, distanciaRealMm] = calibrarEscalaDosPuntos(img, nombreImg)

fig = figure('Name', 'Calibración de escala', 'Color', 'w');
imshow(img);
title({['Calibración de escala - ' nombreImg], 'Seleccione dos puntos de una distancia conocida'}, 'Interpreter', 'none');

[x, y] = ginput(2);
hold on;
plot(x, y, 'yo-', 'LineWidth', 2, 'MarkerSize', 8);

distanciaPixeles = sqrt((x(2) - x(1))^2 + (y(2) - y(1))^2);

respuesta = inputdlg('Ingrese la distancia real entre los dos puntos seleccionados en mm:','Distancia real', [1 60], {'10'});

if isempty(respuesta)
    error('No se ingresó distancia real para la calibración.');
end

distanciaRealMm = str2double(respuesta{1});

if isnan(distanciaRealMm) || distanciaRealMm <= 0
    error('La distancia real debe ser un número positivo.');
end

mmPorPixel = distanciaRealMm / distanciaPixeles;
close(fig);

end

% Guarda la superficie triangular en formato STL ASCII.
function escribirSTLASCII(nombreArchivo, caras, vertices)

fid = fopen(nombreArchivo, 'w');

if fid == -1
    error(['No se pudo crear el archivo STL: ' char(nombreArchivo)]);
end

cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, 'solid reconstruccion_ablacion_3D\n');

for i = 1:size(caras, 1)
    v1 = vertices(caras(i, 1), :);
    v2 = vertices(caras(i, 2), :);
    v3 = vertices(caras(i, 3), :);

    normal = cross(v2 - v1, v3 - v1);
    norma = norm(normal);

    if norma > 0
        normal = normal / norma;
    else
        normal = [0 0 0];
    end

    fprintf(fid, '  facet normal %.9g %.9g %.9g\n', normal);
    fprintf(fid, '    outer loop\n');
    fprintf(fid, '      vertex %.9g %.9g %.9g\n', v1);
    fprintf(fid, '      vertex %.9g %.9g %.9g\n', v2);
    fprintf(fid, '      vertex %.9g %.9g %.9g\n', v3);
    fprintf(fid, '    endloop\n');
    fprintf(fid, '  endfacet\n');
end

fprintf(fid, 'endsolid reconstruccion_ablacion_3D\n');
clear cleanupObj;

end

% Refina las caras conservando vértices compartidos entre triángulos.
function [carasSub, verticesSub] = subdividirMallaTriangular(caras, vertices, niveles)

carasSub = caras;
verticesSub = vertices;

for nivel = 1:niveles
    nCaras = size(carasSub, 1);
    carasNuevas = zeros(nCaras * 4, 3);
    mapaAristas = containers.Map('KeyType', 'char', 'ValueType', 'double');
    contadorCaras = 1;

    for i = 1:nCaras
        v1 = carasSub(i, 1);
        v2 = carasSub(i, 2);
        v3 = carasSub(i, 3);

        v12 = puntoMedio(v1, v2);
        v23 = puntoMedio(v2, v3);
        v31 = puntoMedio(v3, v1);

        carasNuevas(contadorCaras, :) = [v1 v12 v31];
        carasNuevas(contadorCaras + 1, :) = [v12 v2 v23];
        carasNuevas(contadorCaras + 2, :) = [v31 v23 v3];
        carasNuevas(contadorCaras + 3, :) = [v12 v23 v31];
        contadorCaras = contadorCaras + 4;
    end

    carasSub = carasNuevas;
end

    % Reutiliza o crea el punto medio de una arista.
    function idxMedio = puntoMedio(a, b)
        if a < b
            clave = [num2str(a) '_' num2str(b)];
        else
            clave = [num2str(b) '_' num2str(a)];
        end

        if isKey(mapaAristas, clave)
            idxMedio = mapaAristas(clave);
            return;
        end

        verticesSub(end + 1, :) = (verticesSub(a, :) + verticesSub(b, :)) / 2;
        idxMedio = size(verticesSub, 1);
        mapaAristas(clave) = idxMedio;
    end

end

% Suaviza la superficie mediante pasos alternados de Taubin.
function verticesSuavizados = suavizarMallaTaubin(caras, vertices, iteraciones, lambda, mu)

verticesSuavizados = vertices;
nVertices = size(vertices, 1);

aristas = [caras(:, [1 2]); caras(:, [2 3]); caras(:, [3 1])];
A = sparse(aristas(:, 1), aristas(:, 2), 1, nVertices, nVertices);
A = A + A';
A = A > 0;

grado = full(sum(A, 2));
verticesValidos = grado > 0;

for i = 1:iteraciones
    verticesSuavizados = pasoSuavizado(verticesSuavizados, A, grado, verticesValidos, lambda);
    verticesSuavizados = pasoSuavizado(verticesSuavizados, A, grado, verticesValidos, mu);
end

end

% Actualiza vértices según sus vecinos y el factor indicado.
function verticesNuevos = pasoSuavizado(vertices, A, grado, verticesValidos, factor)

verticesNuevos = vertices;
promedioVecinos = vertices;
promedioVecinos(verticesValidos, :) = (A(verticesValidos, :) * vertices) ./ grado(verticesValidos);
verticesNuevos(verticesValidos, :) = vertices(verticesValidos, :) + ...
    factor * (promedioVecinos(verticesValidos, :) - vertices(verticesValidos, :));

end
