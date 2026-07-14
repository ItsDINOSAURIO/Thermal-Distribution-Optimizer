function Interfaz_Ablacion_AlphaShape()
clc;
close all;

app = struct();
app.carpeta = "";
app.fileList = [];
app.nFiles = 0;
app.BW = {};
app.contorno = {};
app.imagenes_validas = [];
app.cara_imagen = [];
app.BW_hueso_alineado = {};
app.BW_ablacion = {};
app.contorno_ablacion = {};
app.imagenes_alineadas = {};
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
app.STL_fijo="";
app.STL_lib = "";
app.RotX = 0;
app.RotY = 0;
app.RotZ = 0;
app.V_gota = [];
app.R = eye(3);
app.T = [0 0 0];



fig = uifigure('Name', 'Segmentación y reconstrucción 3D de ablación', 'Position', [40 40 1500 700]);

panelControles = uipanel(fig, 'Title', 'Flujo de trabajo', 'Position', [15 15 330 780]);

uilabel(panelControles, 'Text', 'Carpeta de imágenes', 'Position', [15 740 180 22]);

txtCarpeta = uieditfield(panelControles, 'text', 'Editable', false, 'Position', [5 710 300 28]);

btnCarpeta = uibutton(panelControles, 'Text', 'Seleccionar carpeta', 'Position', [15 670 145 32], 'ButtonPushedFcn', @(~, ~) seleccionarCarpeta());

btnProcesar = uibutton(panelControles, 'Text', '1. Segmentar hueso', 'Position', [170 670 145 32], 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) procesarImagenes());

uilabel(panelControles, 'Text', 'K-means', 'Position', [160 609 75 22]);

spnClusters = uispinner(panelControles, 'Limits', [2 8], 'Value', 4, 'Step', 1, 'Position', [220 609 80 24]);

uilabel(panelControles, 'Text', 'Área mínima', 'Position', [15 642 95 22]);
spnArea = uispinner(panelControles, 'Limits', [50 50000], 'Value', 3000, 'Step', 100, 'Position', [105 642 80 24]);

uilabel(panelControles, 'Text', 'Cierre', 'Position', [15 609 95 22]);
spnCierre = uispinner(panelControles, 'Limits', [1 80], 'Value', 18, 'Step', 1, 'Position', [70 609 80 24]);

uilabel(panelControles, 'Text', 'Alpha x', 'Position', [15 566 95 22]);
spnAlpha = uispinner(panelControles, 'Limits', [0.5 10], 'Value', 5, 'Step', 0.25, 'Position', [105 566 80 24]);

uilabel(panelControles, 'Text', 'Subdivisión', 'Position', [15 533 95 22]);
spnSubdiv = uispinner(panelControles, 'Limits', [0 3], 'Value', 2, 'Step', 1, 'Position', [105 533 80 24]);

uilabel(panelControles, 'Text', 'Suavizado', 'Position', [15 500 95 22]);

spnSuavizado = uispinner(panelControles, 'Limits', [0 250],'Value', 120, 'Step', 10, 'Position', [105 500 80 24]);

btnCalibrar = uibutton(panelControles, 'Text', '2. Calibrar y alinear', 'Position', [15 450 300 34], 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) calibrarYAlinear());

btnAblacion = uibutton(panelControles, 'Text', '3. Segmentar ablación', 'Position', [15 408 300 34], 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) segmentarAblacion());

btnGrosores = uibutton(panelControles, 'Text', '4. Capturar grosores', 'Position', [15 366 300 34], 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) capturarGrosores());

btnReconstruir = uibutton(panelControles, 'Text', '5. Reconstruir y guardar STL', 'Position', [15 324 300 34], 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) reconstruir3D());

btnCalcular = uibutton(panelControles, 'Text', '6. Calcular volumen del STL', 'Position', [15 280 300 34], 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) CalcularVol());

btnComparar = uibutton(panelControles, 'Text', '7. Comparar volumen del STL', 'Position', [15 235 300 34], 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) CompaVol());


lstImagenes = uilistbox(panelControles,'Position', [15 125 300 100], 'Items', {'Sin carpeta cargada'});

txtEstado = uitextarea(panelControles, 'Editable', false, 'Position', [15 15 300 95], 'Value', {'Selecciona una carpeta para iniciar.'});

tabs = uitabgroup(fig, 'Position', [365 15 1165 780]);

tabSeg = uitab(tabs, 'Title', 'Segmentación');
axOriginal = uiaxes(tabSeg, 'Position', [15 350 360 360]);
axKmeans = uiaxes(tabSeg, 'Position', [395 350 360 360]);
axContorno = uiaxes(tabSeg, 'Position', [775 350 360 360]);
axOverlay = uiaxes(tabSeg, 'Position', [15 10 540 360]);
axAblacion = uiaxes(tabSeg, 'Position', [575 10 560 360]);

tab3D = uitab(tabs, 'Title', 'Reconstrucción 3D');
ax3D = uiaxes(tab3D, 'Position', [20 20 1120 760]);

tab3D_1 = uitab(tabs, 'Title', 'Comparacion de volumen');
ax3D_1 = uiaxes(tab3D_1, 'Position', [20 20 900 600]);
btnSTLfijo = uibutton(tab3D_1, 'Text', 'Seleccionar STL fijo', 'Position', [400 670 145 32], 'ButtonPushedFcn', @(~, ~) SelecionarSTL_fij());
btnSTLRot = uibutton(tab3D_1, 'Text', 'Seleccionar STL libre', 'Position', [600 670 145 32], 'ButtonPushedFcn', @(~, ~) SelecionarSTL_rot());
btnSTLNormZ = uibutton(tab3D_1, 'Text', 'Seleccionar punto para rotar a z', 'Position', [100 670 200 32], 'ButtonPushedFcn', @(~, ~) RotarZ());
btnSTlHueso = uibutton(tab3D_1, 'Text', 'Generar STL de hueso', 'Position', [800 670 200 32], 'ButtonPushedFcn', @(~, ~) CalculSTLhues());
uilabel(tab3D_1,'Text', 'Rotacional X','Position', [985 600 200 22]);
btnMasX = uibutton(tab3D_1, 'Text', '+', 'Position', [985 570 30 32], 'ButtonPushedFcn', @(~, ~) RotarMaX());
btnMenX = uibutton(tab3D_1, 'Text', '-', 'Position', [1030 570 30 32], 'ButtonPushedFcn', @(~, ~) RotarMeX());
uilabel(tab3D_1,'Text', 'Rotacional Y','Position', [985 540 200 22]);
btnMasY = uibutton(tab3D_1, 'Text', '+', 'Position', [985 510 30 32], 'ButtonPushedFcn', @(~, ~) RotarMaY());
btnMenY = uibutton(tab3D_1, 'Text', '-', 'Position', [1030 510 30 32], 'ButtonPushedFcn', @(~, ~) RotarMeY());
uilabel(tab3D_1,'Text', 'Rotacional Z','Position', [985 480 200 22]);
btnMasZ = uibutton(tab3D_1, 'Text', '+', 'Position', [985 450 30 32], 'ButtonPushedFcn', @(~, ~) RotarMaZ());
btnMenZ = uibutton(tab3D_1, 'Text', '-', 'Position', [1030 450 30 32], 'ButtonPushedFcn', @(~, ~) RotarMeZ());

uilabel(tab3D_1,'Text', 'Translación X','Position', [985 400 200 22]);
btnMasXTr = uibutton(tab3D_1, 'Text', '+', 'Position', [985 370 30 32], 'ButtonPushedFcn', @(~, ~) TranslMaX());
btnMenXTr = uibutton(tab3D_1, 'Text', '-', 'Position', [1030 370 30 32], 'ButtonPushedFcn', @(~, ~) TranslMeX());
uilabel(tab3D_1,'Text', 'Translación Y','Position', [985 340 200 22]);
btnMasYTr = uibutton(tab3D_1, 'Text', '+', 'Position', [985 310 30 32], 'ButtonPushedFcn', @(~, ~) TranslMaY());
btnMenYTr = uibutton(tab3D_1, 'Text', '-', 'Position', [1030 310 30 32], 'ButtonPushedFcn', @(~, ~) TranslMeY());
uilabel(tab3D_1,'Text', 'Translación Z','Position', [985 280 200 22]);
btnMasZTr = uibutton(tab3D_1, 'Text', '+', 'Position', [985 250 30 32], 'ButtonPushedFcn', @(~, ~) TranslMaZ());
btnMenZTr = uibutton(tab3D_1, 'Text', '-', 'Position', [1030 250 30 32], 'ButtonPushedFcn', @(~, ~) TranslMeZ());

btnSTlHueso.Enable = 'off';
btnSTLNormZ.Enable = 'off';
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

limpiarAxes();

    function seleccionarCarpeta()
        carpeta = uigetdir(char(app.carpeta), 'Seleccione la carpeta con imágenes JPEG');

        if isequal(carpeta, 0)
            return;
        end

        app.carpeta = string(carpeta);
        txtCarpeta.Value = char(app.carpeta);

        fileList2 = dir(fullfile(app.carpeta, '*.JPEG'));

        if isempty(fileList2)
            fileList2 = dir(fullfile(app.carpeta, '*.jpg'));
        end

        if isempty(fileList2)
            fileList2 = dir(fullfile(app.carpeta, '*.jpeg'));
        end

        if isempty(fileList2)
            uialert(fig, 'No se encontraron imágenes JPEG/JPG en la carpeta.', 'Sin imágenes');
            return;
        end

        app.fileList = ordenarPorNumero(fileList2);
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
        logEstado(['Carpeta cargada: ' num2str(app.nFiles) ' imágenes.']);
    end

    function procesarImagenes()
        if app.nFiles == 0
            return;
        end

        carpeta_salida = fullfile(app.carpeta, 'Alineadas');
        crearCarpeta(carpeta_salida);

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

    function segmentarAblacion()
        carpeta_ablacion = fullfile(app.carpeta, 'Ablacion_segmentada');
        carpeta_salida = fullfile(app.carpeta, 'Alineadas');
        crearCarpeta(carpeta_ablacion);

        nValidas = length(app.idx_validas);
        app.BW_ablacion = cell(nValidas, 1);
        app.contorno_ablacion = cell(nValidas, 1);
        app.imagenes_alineadas = cell(nValidas, 1);

        for k = 1:nValidas
            idx_img = app.idx_validas(k);
            nombreImg = app.fileList(idx_img).name;
            img_alineada = imread(fullfile(carpeta_salida, nombreImg));
            app.imagenes_alineadas{k} = img_alineada;

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
            else 
                continue
            end
            

        save(fullfile(carpeta_ablacion, 'contornos_ablacion.mat'), '-struct', 'app', 'BW_ablacion', 'contorno_ablacion', 'cara_imagen', 'idx_validas', 'fileList');

        btnGrosores.Enable = 'on';
        logEstado('Segmentación de ablación terminada.');
        end
    end

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
            'archivoSTL');

        btnCalcular.Enable = 'on';
        btnSTLfijo.Enable = 'on';

        logEstado(['STL guardado: ' char(app.archivoSTL)]);
        btnSTlHueso.Enable = 'on';
    end

    function CalculSTLhues()
         if isempty(app.z_cortes)
            uialert(fig, 'Primero capture los grosores.', 'Faltan grosores');
            return;
        end
        BW_hueso_valido = app.BW_hueso_alineado(app.idx_validas);
        [app.shp_hueso, app.puntos3D_hueso] = reconstruirAblacion3DAlphaShape( BW_hueso_valido ,app.z_cortes, app.mmPorPixel, spnAlpha.Value);

        [app.carasSTL_hueso, app.verticesSTL_hueso] = boundaryFacets(app.shp_hueso);

        if spnSubdiv.Value > 0
            [app.carasSTL_hueso, app.verticesSTL_hueso] = subdividirMallaTriangular( app.carasSTL, app.verticesSTL, round(spnSubdiv.Value));
        end

        if spnSuavizado.Value > 0
            app.verticesSTL_hueso = suavizarMallaTaubin( app.carasSTL_hueso, app.verticesSTL_hueso, round(spnSuavizado.Value), 0.45, -0.48);
        end

        carpeta_ablacion = fullfile(app.carpeta, 'Ablacion_segmentada');
        app.archivoSTL_hueso = string(fullfile(carpeta_ablacion, 'reconstruccion_hueso_3D.stl'));
        escribirSTLASCII(app.archivoSTL_hueso, app.carasSTL_hueso, app.verticesSTL_hueso);

        logEstado(['STL de hueso guardado: ' char(app.archivoSTL_hueso)]);
    end

    function limpiarAxes()
        ejes = [axOriginal axKmeans axContorno axOverlay axAblacion ax3D];

        for e = 1:numel(ejes)
            cla(ejes(e));
            title(ejes(e), '');
            axis(ejes(e), 'off');
        end
    end

    function logEstado(msg)
        anterior = txtEstado.Value;
        if ischar(anterior)
            anterior = {anterior};
        end
        txtEstado.Value = [{char(msg)}; anterior(:)];
        drawnow;
    end

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
    
    function SelecionarSTL_fij()
        [archivo, ruta] = uigetfile({'*.stl', 'Archivos STL (*.stl)'}, 'Selecciona el STL fijo');

        if isequal(archivo, 0)
            return;
        end
        
        app.STL_fijo = fullfile(ruta, archivo);

        TR_1 = stlread(app.STL_fijo);
        V_Fija = TR_1.Points; 
        F_Fija = TR_1.ConnectivityList;
        
        V_Fija = V_Fija - mean(V_Fija);

        app.V_Fija = V_Fija;
        app.F_Fija = F_Fija;
                
        cla(ax3D_1);

        hold((ax3D_1),"on"); axis(ax3D_1, 'equal'); view(ax3D_1,3)
        xlabel(ax3D_1,'X'); ylabel(ax3D_1, 'Y'); zlabel(ax3D_1, 'Z');
        title(ax3D_1,'Comparación de volumen');
        
        patch(ax3D_1,'Faces',F_Fija,'Vertices',V_Fija,'FaceColor',[1 0 0],'EdgeColor','none','FaceAlpha',0.3);
        
        camlight(ax3D_1); lighting(ax3D_1, 'gouraud');
        legend(ax3D_1,{'STL fijo','Reconstruido'});
        hold(ax3D_1,'on');
        
    end

    function SelecionarSTL_rot()
        [archivo, ruta] = uigetfile({'*.stl', 'Archivos STL (*.stl)'}, 'Selecciona el STL libre');

        if isequal(archivo, 0)
            return;
        end
        
        app.STL_lib = fullfile(ruta, archivo);

        TR = stlread(app.STL_lib);
        V_lib = TR.Points;
        F_lib = TR.ConnectivityList;
        
        V_lib = V_lib - mean(V_lib);

        app.F_lib = F_lib;
        app.V_lib = V_lib;
        app.V_lib_ori = V_lib;

        hold((ax3D_1),"on"); axis(ax3D_1, 'equal'); view(ax3D_1,3)
        xlabel(ax3D_1,'X'); ylabel(ax3D_1, 'Y'); zlabel(ax3D_1, 'Z');
        title(ax3D_1,'Comparación de volumen');

        patch(ax3D_1,'Faces',F_lib,'Vertices',V_lib,'FaceColor',[0 0 1],'EdgeColor','none','FaceAlpha',0.6);
        
        camlight(ax3D_1); lighting(ax3D_1, 'gouraud');
        legend(ax3D_1,{'STL fijo','Reconstruido'});
        hold(ax3D_1,'on');

        btnComparar.Enable = 'on';
        btnMasX.Enable = 'on';
        btnMenX.Enable = 'on';
        btnMasY.Enable = 'on';
        btnMenY.Enable = 'on';
        btnMasZ.Enable = 'on';
        btnMenZ.Enable = 'on';
        btnMasXTr.Enable = 'on';
        btnMenXTr.Enable = 'on';
        btnMasYTr.Enable = 'on';
        btnMenYTr.Enable = 'on';
        btnMasZTr.Enable = 'on';
        btnMenZTr.Enable = 'on';
        btnSTLNormZ.Enable = 'on';
        
    end
    
    function actualiza3Drot()

        if app.RotX ~= 0 || app.RotY ~= 0 || app.RotZ ~= 0
            Rx = [1 0 0; 0 cos(deg2rad(app.RotX)) -sin(deg2rad(app.RotX)); 0 sin(deg2rad(app.RotX)) cos(deg2rad(app.RotX))];
            Ry = [cos(deg2rad(app.RotY)) 0 sin(deg2rad(app.RotY)); 0 1 0; -sin(deg2rad(app.RotY)) 0 cos(deg2rad(app.RotY))];
            Rz = [cos(deg2rad(app.RotZ)) -sin(deg2rad(app.RotZ)) 0; sin(deg2rad(app.RotZ)) cos(deg2rad(app.RotZ)) 0; 0 0 1];
            app.R = Rz * Ry * Rx;
            app.V_lib = (app.R * app.V_lib_ori')';
            app.V_lib = app.V_lib + app.T;
        else
            app.V_lib = app.V_lib_ori;
        end
        
        cla(ax3D_1);
        hold((ax3D_1),"on"); axis(ax3D_1, 'equal'); view(ax3D_1,3)
        xlabel(ax3D_1,'X'); ylabel(ax3D_1, 'Y'); zlabel(ax3D_1, 'Z');
        title(ax3D_1,'Comparación de volumen');
        
        patch(ax3D_1,'Faces',app.F_Fija,'Vertices',app.V_Fija,'FaceColor',[1 0 0],'EdgeColor','none','FaceAlpha',0.3);
        patch(ax3D_1,'Faces',app.F_lib,'Vertices',app.V_lib,'FaceColor',[0 0 1],'EdgeColor','none','FaceAlpha',0.6);
        
        camlight(ax3D_1); lighting(ax3D_1, 'gouraud');
        legend(ax3D_1,{'STL fijo','Reconstruido'});
        hold(ax3D_1,'on');
    end

    function RotarMaX()
        pasoRotacion = 5;
        app.RotX = app.RotX + pasoRotacion;
        actualiza3Drot()
    end
    function RotarMeX()
        pasoRotacion = 5;
        app.RotX = app.RotX - pasoRotacion;
        actualiza3Drot()
    end
    function RotarMaY()
        pasoRotacion = 5;
        app.RotY = app.RotY + pasoRotacion;
        actualiza3Drot()
    end
    function RotarMeY()
        pasoRotacion = 5;
        app.RotY = app.RotY - pasoRotacion;
        actualiza3Drot()
    end
    function RotarMaZ()
        pasoRotacion = 5;
        app.RotZ = app.RotZ + pasoRotacion;
        actualiza3Drot()
    end
    function RotarMeZ()
        pasoRotacion = 5;
        app.RotZ = app.RotZ - pasoRotacion;
        actualiza3Drot()
    end
    
    function TranslMaX()
        pasoTranslacion = 2;
        app.V_lib = app.V_lib + [pasoTranslacion 0 0];
        app.T = app.T + [pasoTranslacion 0 0];
        cla(ax3D_1);
        hold((ax3D_1),"on"); axis(ax3D_1, 'equal'); view(ax3D_1,3)
        xlabel(ax3D_1,'X'); ylabel(ax3D_1, 'Y'); zlabel(ax3D_1, 'Z');
        title(ax3D_1,'Comparación de volumen');
        
        patch(ax3D_1,'Faces',app.F_Fija,'Vertices',app.V_Fija,'FaceColor',[1 0 0],'EdgeColor','none','FaceAlpha',0.3);
        patch(ax3D_1,'Faces',app.F_lib,'Vertices',app.V_lib,'FaceColor',[0 0 1],'EdgeColor','none','FaceAlpha',0.6);
        
        camlight(ax3D_1); lighting(ax3D_1, 'gouraud');
        legend(ax3D_1,{'STL fijo','Reconstruido'});
        hold(ax3D_1,'on');
    end

    function TranslMeX()
        pasoTranslacion = -2;
        app.V_lib = app.V_lib + [pasoTranslacion 0 0];
        app.T = app.T + [pasoTranslacion 0 0];
        cla(ax3D_1);
        hold((ax3D_1),"on"); axis(ax3D_1, 'equal'); view(ax3D_1,3)
        xlabel(ax3D_1,'X'); ylabel(ax3D_1, 'Y'); zlabel(ax3D_1, 'Z');
        title(ax3D_1,'Comparación de volumen');
        
        patch(ax3D_1,'Faces',app.F_Fija,'Vertices',app.V_Fija,'FaceColor',[1 0 0],'EdgeColor','none','FaceAlpha',0.3);
        patch(ax3D_1,'Faces',app.F_lib,'Vertices',app.V_lib,'FaceColor',[0 0 1],'EdgeColor','none','FaceAlpha',0.6);
        
        camlight(ax3D_1); lighting(ax3D_1, 'gouraud');
        legend(ax3D_1,{'STL fijo','Reconstruido'});
        hold(ax3D_1,'on');
    end

    function TranslMaY()
        pasoTranslacion = 2;
        app.V_lib = app.V_lib + [0 pasoTranslacion 0];
        app.T = app.T + [0 pasoTranslacion 0];
        cla(ax3D_1);
        hold((ax3D_1),"on"); axis(ax3D_1, 'equal'); view(ax3D_1,3)
        xlabel(ax3D_1,'X'); ylabel(ax3D_1, 'Y'); zlabel(ax3D_1, 'Z');
        title(ax3D_1,'Comparación de volumen');
        
        patch(ax3D_1,'Faces',app.F_Fija,'Vertices',app.V_Fija,'FaceColor',[1 0 0],'EdgeColor','none','FaceAlpha',0.3);
        patch(ax3D_1,'Faces',app.F_lib,'Vertices',app.V_lib,'FaceColor',[0 0 1],'EdgeColor','none','FaceAlpha',0.6);
        
        camlight(ax3D_1); lighting(ax3D_1, 'gouraud');
        legend(ax3D_1,{'STL fijo','Reconstruido'});
        hold(ax3D_1,'on');
    end

    function TranslMeY()
        pasoTranslacion = -2;
        app.V_lib = app.V_lib + [0 pasoTranslacion 0];
        app.T = app.T + [0 pasoTranslacion 0];
        cla(ax3D_1);
        hold((ax3D_1),"on"); axis(ax3D_1, 'equal'); view(ax3D_1,3)
        xlabel(ax3D_1,'X'); ylabel(ax3D_1, 'Y'); zlabel(ax3D_1, 'Z');
        title(ax3D_1,'Comparación de volumen');
        
        patch(ax3D_1,'Faces',app.F_Fija,'Vertices',app.V_Fija,'FaceColor',[1 0 0],'EdgeColor','none','FaceAlpha',0.3);
        patch(ax3D_1,'Faces',app.F_lib,'Vertices',app.V_lib,'FaceColor',[0 0 1],'EdgeColor','none','FaceAlpha',0.6);
        
        camlight(ax3D_1); lighting(ax3D_1, 'gouraud');
        legend(ax3D_1,{'STL fijo','Reconstruido'});
        hold(ax3D_1,'on');
    end

    function TranslMaZ()
        pasoTranslacion = 2;
        app.V_lib = app.V_lib + [0 0 pasoTranslacion];
        app.T = app.T + [0 0 pasoTranslacion];
        cla(ax3D_1);
        hold((ax3D_1),"on"); axis(ax3D_1, 'equal'); view(ax3D_1,3)
        xlabel(ax3D_1,'X'); ylabel(ax3D_1, 'Y'); zlabel(ax3D_1, 'Z');
        title(ax3D_1,'Comparación de volumen');
        
        patch(ax3D_1,'Faces',app.F_Fija,'Vertices',app.V_Fija,'FaceColor',[1 0 0],'EdgeColor','none','FaceAlpha',0.3);
        patch(ax3D_1,'Faces',app.F_lib,'Vertices',app.V_lib,'FaceColor',[0 0 1],'EdgeColor','none','FaceAlpha',0.6);
        
        camlight(ax3D_1); lighting(ax3D_1, 'gouraud');
        legend(ax3D_1,{'STL fijo','Reconstruido'});
        hold(ax3D_1,'on');
    end

    function TranslMeZ()
        pasoTranslacion = -2;
        app.V_lib = app.V_lib + [0 0 pasoTranslacion];
        app.T = app.T + [0 0 pasoTranslacion];
        cla(ax3D_1);
        hold((ax3D_1),"on"); axis(ax3D_1, 'equal'); view(ax3D_1,3)
        xlabel(ax3D_1,'X'); ylabel(ax3D_1, 'Y'); zlabel(ax3D_1, 'Z');
        title(ax3D_1,'Comparación de volumen');
        
        patch(ax3D_1,'Faces',app.F_Fija,'Vertices',app.V_Fija,'FaceColor',[1 0 0],'EdgeColor','none','FaceAlpha',0.3);
        patch(ax3D_1,'Faces',app.F_lib,'Vertices',app.V_lib,'FaceColor',[0 0 1],'EdgeColor','none','FaceAlpha',0.6);
        
        camlight(ax3D_1); lighting(ax3D_1, 'gouraud');
        legend(ax3D_1,{'STL fijo','Reconstruido'});
        hold(ax3D_1,'on');
    end

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
        legend(ax3D_1,{'STL fijo','Reconstruido'});
        hold(ax3D_1,'on');

        function seleccionarPuntoParaZ(~, evento)
            punto_objetivo = evento.IntersectionPoint(:);
            z_axis = [0; 0; 1];

            if norm(punto_objetivo) < eps
                uialert(fig, 'El punto seleccionado esta demasiado cerca del origen.', 'Punto no valido');
                return;
            end

            punto_objetivo_norm = punto_objetivo / norm(punto_objetivo);
            cos_ang = dot(punto_objetivo_norm, z_axis);
            cos_ang = max(min(cos_ang, 1), -1);
            eje_rotacion = cross(punto_objetivo_norm, z_axis);
            norma_eje = norm(eje_rotacion);
        
            if norma_eje < eps
                if cos_ang > 0
                    R = eye(3);
                else
                    R = [1 0 0; 0 -1 0; 0 0 -1];
                end
            else
                eje_rotacion = eje_rotacion / norma_eje;
                angulo = atan2(norma_eje, cos_ang);
            % Crear la matriz de rotación usando la fórmula de Rodrigues
                K = [0, -eje_rotacion(3), eje_rotacion(2); ...
                     eje_rotacion(3), 0, -eje_rotacion(1); ...
                    -eje_rotacion(2), eje_rotacion(1), 0];
                R = eye(3) + sin(angulo)*K + (1-cos(angulo))*(K^2);
            end
        
        % Rotar todos los vértices del modelo
            app.V_Fija = (R * app.V_Fija')';
            app.V_lib = (R * app.V_lib')';
            app.V_lib_ori = app.V_lib;
            app.RotX = 0;
            app.RotY = 0;
            app.RotZ = 0;
        
        cla(ax3D_1);
        hold((ax3D_1),"on"); axis(ax3D_1, 'equal'); view(ax3D_1,3)
        xlabel(ax3D_1,'X'); ylabel(ax3D_1, 'Y'); zlabel(ax3D_1, 'Z');
        title(ax3D_1,'Comparación de volumen');
        
        patch(ax3D_1,'Faces',app.F_Fija,'Vertices',app.V_Fija,'FaceColor',[1 0 0],'EdgeColor','none','FaceAlpha',0.3);
        patch(ax3D_1,'Faces',app.F_lib,'Vertices',app.V_lib,'FaceColor',[0 0 1],'EdgeColor','none','FaceAlpha',0.6);
        
        camlight(ax3D_1); lighting(ax3D_1, 'gouraud');
        legend(ax3D_1,{'STL fijo','Reconstruido'});
        hold(ax3D_1,'on');
    
        end

    end

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

        logEstado(['Volumen del STL Movil : ' num2str(Vtotal_gota) ' mm^3']);
        logEstado(['Volumen del STL de Referencia : ' num2str(Vtotal_Fija) ' mm^3']);
        logEstado(['Volumen interseccion:' num2str(Vdentro) ' mm^3']);
        logEstado(['Porcentaje cobertura: ' num2str(porc_ocup_Fija) ' %']);
        logEstado(['Volumen no coincidente : ' num2str(Vfuera) ' mm^3']);
        logEstado(['Porcentaje no coincidente: ' num2str(porc_fuera) ' %']);
        logEstado(['Coeficiente de semejanza Dice: ' num2str(Dice) ' %']);
        logEstado(['Coeficiente de semejanza IoU: ' num2str(IoU) ' %']);
    end

end


function fileList = ordenarPorNumero(fileList)

nombres = {fileList.name};
numeros = zeros(length(nombres), 1);

for i = 1:length(nombres)
    token = regexp(nombres{i}, '\d+', 'match', 'once');

    if isempty(token)
        numeros(i) = i;
    else
        numeros(i) = str2double(token);
    end
end

[~, idx] = sort(numeros);
fileList = fileList(idx);

end

function crearCarpeta(carpeta)

if ~exist(carpeta, 'dir')
    mkdir(carpeta);
end

end

function mostrarImagen(ax, img, textoTitulo)

cla(ax);
imshow(img, 'Parent', ax);
title(ax, textoTitulo, 'Interpreter', 'none');
axis(ax, 'image');

end

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

function [BW_final, contorno] = segmentarAblacionCafeCarbonizada(img, BW_hueso)

imgDouble = im2double(img);
hsvImg = rgb2hsv(imgDouble);
labImg = rgb2lab(imgDouble);

H = hsvImg(:, :, 1);
S = hsvImg(:, :, 2);
V = hsvImg(:, :, 3);
L = labImg(:, :, 1);
A = labImg(:, :, 2);
B = labImg(:, :, 3);

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

function verticesNuevos = pasoSuavizado(vertices, A, grado, verticesValidos, factor)

verticesNuevos = vertices;
promedioVecinos = vertices;
promedioVecinos(verticesValidos, :) = (A(verticesValidos, :) * vertices) ./ grado(verticesValidos);
verticesNuevos(verticesValidos, :) = vertices(verticesValidos, :) + ...
    factor * (promedioVecinos(verticesValidos, :) - vertices(verticesValidos, :));

end
function [V,F] = lectorSTL(filename)

fid = fopen(filename,'rb');
fseek(fid,80,'bof');
numFaces = fread(fid,1,'uint32');

Vraw = zeros(numFaces*3,3);
F = zeros(numFaces,3);

for i = 1:numFaces
    fread(fid,3,'float32');
    v1 = fread(fid,3,'float32');
    v2 = fread(fid,3,'float32');
    v3 = fread(fid,3,'float32');
    fread(fid,1,'uint16');

    idx = (i-1)*3;
    Vraw(idx+1,:) = v1';
    Vraw(idx+2,:) = v2';
    Vraw(idx+3,:) = v3';
end
fclose(fid);

[V,~,ic] = unique(Vraw,'rows','stable');
F = reshape(ic,3,numFaces)';
end
