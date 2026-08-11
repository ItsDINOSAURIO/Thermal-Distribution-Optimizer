function salida = graficador_estadistico_optimizador(entrada)
%GRAFICADOR_ESTADISTICO_OPTIMIZADOR Analiza historiales MAT del optimizador 3D.
%   Sin argumentos abre un selector de archivos. También acepta una ruta,
%   un arreglo string o una celda de rutas a MAT que contengan la variable hs.
%   Use 'selftest' para ejecutar las pruebas internas sin crear archivos.

if nargin == 1 && (ischar(entrada) || (isstring(entrada) && isscalar(entrada))) && ...
        strcmpi(char(entrada), 'selftest')
    ejecutar_selftest();
    salida = struct('selftest', true);
    return;
end

carpeta_modulo = fileparts(mfilename('fullpath'));
raiz_proyecto = fileparts(carpeta_modulo);
if nargin < 1 || isempty(entrada)
    [nombres, carpeta] = uigetfile(fullfile(raiz_proyecto, 'datasets', '*.mat'), ...
        'Seleccionar historiales del optimizador', 'MultiSelect', 'on');
    if isequal(nombres, 0), salida = struct('cancelado', true); return; end
    if ischar(nombres), nombres = {nombres}; end
    rutas = cellfun(@(n) fullfile(carpeta, n), nombres, 'UniformOutput', false);
else
    rutas = normalizar_rutas(entrada);
end

[corridas, avisos] = cargar_corridas(rutas);
if isempty(corridas)
    error('graficador_estadistico:sinCorridas', ...
        'Los MAT seleccionados no contienen corridas incluidas para análisis.');
end

marca_tiempo = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
carpeta_salida = fullfile(raiz_proyecto, 'datasets', ...
    'resultados_estadisticos_optimizador', marca_tiempo);
carpeta_csv = fullfile(carpeta_salida, 'csv');
carpeta_png = fullfile(carpeta_salida, 'png');
carpeta_fig = fullfile(carpeta_salida, 'fig');
crear_carpeta(carpeta_csv); crear_carpeta(carpeta_png); crear_carpeta(carpeta_fig);

firmas = unique(string({corridas.cohorte}), 'stable');
resultados_cohortes = repmat(struct('firma', '', 'corridas', table(), ...
    'grupos', table(), 'iteraciones', table(), 'kruskal_wallis', table(), ...
    'comparaciones', table(), 'carpeta', ''), numel(firmas), 1);

for idx_cohorte = 1:numel(firmas)
    seleccion = strcmp({corridas.cohorte}, char(firmas(idx_cohorte)));
    [corridas_cohorte, tabla_corridas, tabla_grupos, tabla_iteraciones, ...
        tabla_kw, tabla_pares] = analizar_cohorte(corridas(seleccion));
    corridas(seleccion) = corridas_cohorte;
    nombre_cohorte = sprintf('cohorte_%02d', idx_cohorte);
    carpeta_cohorte = fullfile(carpeta_salida, nombre_cohorte);
    crear_carpeta(carpeta_cohorte);
    writetable(tabla_corridas, fullfile(carpeta_cohorte, 'resumen_corridas.csv'));
    writetable(tabla_grupos, fullfile(carpeta_cohorte, 'estadisticas_grupos.csv'));
    writetable(tabla_iteraciones, fullfile(carpeta_cohorte, 'estadisticas_iteracion.csv'));
    if ~isempty(tabla_kw), writetable(tabla_kw, fullfile(carpeta_cohorte, 'kruskal_wallis.csv')); end
    if ~isempty(tabla_pares), writetable(tabla_pares, fullfile(carpeta_cohorte, 'comparaciones_exploratorias.csv')); end
    generar_graficas(corridas_cohorte, tabla_iteraciones, tabla_grupos, ...
        carpeta_png, carpeta_fig, nombre_cohorte);
    resultados_cohortes(idx_cohorte).firma = char(firmas(idx_cohorte));
    resultados_cohortes(idx_cohorte).corridas = tabla_corridas;
    resultados_cohortes(idx_cohorte).grupos = tabla_grupos;
    resultados_cohortes(idx_cohorte).iteraciones = tabla_iteraciones;
    resultados_cohortes(idx_cohorte).kruskal_wallis = tabla_kw;
    resultados_cohortes(idx_cohorte).comparaciones = tabla_pares;
    resultados_cohortes(idx_cohorte).carpeta = carpeta_cohorte;
end

tabla_maestra = tabla_corridas_normalizadas(corridas);
writetable(tabla_maestra, fullfile(carpeta_csv, 'corridas_normalizadas.csv'));
save(fullfile(carpeta_salida, 'datos_normalizados.mat'), ...
    'corridas', 'resultados_cohortes', 'rutas', 'avisos', '-v7.3');
if ~isempty(avisos)
    fid = fopen(fullfile(carpeta_salida, 'avisos.txt'), 'w');
    if fid >= 0
        limpieza = onCleanup(@() fclose(fid));
        fprintf(fid, '%s\n', avisos{:});
    end
end
fprintf('GRAFICADOR_OPTIMIZADOR_OK corridas=%d cohortes=%d salida=%s\n', ...
    numel(corridas), numel(firmas), carpeta_salida);
salida = struct('cancelado', false, 'carpeta', carpeta_salida, ...
    'corridas', numel(corridas), 'cohortes', resultados_cohortes, 'avisos', {avisos});
end

function rutas = normalizar_rutas(entrada)
if ischar(entrada)
    rutas = {entrada};
elseif isstring(entrada)
    rutas = cellstr(entrada(:));
elseif iscell(entrada)
    rutas = cellfun(@char, entrada(:), 'UniformOutput', false);
else
    error('graficador_estadistico:rutasInvalidas', ...
        'Las rutas deben ser texto, string o celda de textos.');
end
for k = 1:numel(rutas)
    if ~isfile(rutas{k})
        error('graficador_estadistico:archivoInexistente', ...
            'No existe el archivo: %s', rutas{k});
    end
end
end

function [corridas, avisos] = cargar_corridas(rutas)
corridas = repmat(plantilla_corrida(), 0, 1);
avisos = {};
for idx_archivo = 1:numel(rutas)
    variables = whos('-file', rutas{idx_archivo});
    if ~any(strcmp({variables.name}, 'hs'))
        avisos{end+1} = sprintf('Omitido sin variable hs: %s', rutas{idx_archivo}); %#ok<AGROW>
        continue;
    end
    contenido = load(rutas{idx_archivo}, 'hs');
    historial = contenido.hs;
    if isstruct(historial), historial = num2cell(historial); end
    if ~iscell(historial)
        avisos{end+1} = sprintf('Omitido porque hs no es celda/struct: %s', rutas{idx_archivo}); %#ok<AGROW>
        continue;
    end
    for idx_corrida = 1:numel(historial)
        corrida = historial{idx_corrida};
        if ~isstruct(corrida), continue; end
        [incluir, es_legacy] = debe_incluir_corrida(corrida);
        if ~incluir, continue; end
        normalizada = normalizar_corrida(corrida, rutas{idx_archivo}, es_legacy);
        if ~isfinite(normalizada.antenas)
            avisos{end+1} = sprintf('Corrida sin número de antenas en %s.', rutas{idx_archivo}); %#ok<AGROW>
        end
        corridas(end+1,1) = normalizada; %#ok<AGROW>
    end
end
[corridas, duplicadas] = deduplicar_corridas(corridas);
if duplicadas > 0, avisos{end+1} = sprintf('Se eliminaron %d corridas duplicadas.', duplicadas); end
if ~isempty(corridas) && any([corridas.legacy])
    avisos{end+1} = ['Se incluyeron historiales antiguos sin marca estadística; ' ...
        'sus métricas por iteración son limitadas.'];
end
end

function [incluir, legacy] = debe_incluir_corrida(corrida)
legacy = ~isfield(corrida, 'incluir_estadisticas');
if legacy
    incluir = true;
else
    valor = corrida.incluir_estadisticas;
    incluir = (islogical(valor) || isnumeric(valor)) && isscalar(valor) && logical(valor);
end
end

function r = normalizar_corrida(c, fuente, legacy)
r = plantilla_corrida(); r.fuente_mat = fuente; r.legacy = legacy;
if isfield(c, 'id'), r.id_corrida = campo_texto(c, 'id'); end
r.timestamp = campo_texto(c, 'timestamp');
if isfield(c, 'parametros') && isstruct(c.parametros), p = c.parametros; else, p = struct(); end
r.tipo_antena = campo_texto(p, 'tipo_antena'); r.caso = campo_texto(p, 'caso');
r.potencia = campo_texto(p, 'potencia'); r.distribucion = campo_texto(p, 'distribucion_termica');
r.antenas = numero_antenas(p); r.fitness_fino = campo_numerico(p, 'fitness_fino');
r.fitness_pso = campo_numerico(p, 'fitness_pso'); r.tiempo_total_s = campo_numerico(c, 'tiempo_total');
r.cobertura_pct = campo_numerico(p, 'porcentaje_interior'); r.exterior_pct = campo_numerico(p, 'porcentaje_exterior');
r.volumen_tumor_mm3 = campo_numerico(p, 'volumen_tumor');
r.volumen_distribucion_mm3 = campo_numerico(p, 'volumen_distribucion_termica');
r.volumen_exterior_mm3 = campo_numerico(p, 'volumen_exterior');
if isfield(p, 'posicion') && isnumeric(p.posicion)
    posicion = double(p.posicion(:).'); r.posicion(1:min(5,numel(posicion))) = posicion(1:min(5,numel(posicion)));
end
r.historia_f1 = vector_numerico(c, 'historia_f1'); r.historia_f2 = vector_numerico(c, 'historia_f2');
if ~isempty(r.historia_f1) || ~isempty(r.historia_f2)
    r.historia = [r.historia_f1; r.historia_f2];
else
    r.historia = vector_numerico(c, 'historia_pso');
end
estadisticas = struct();
if isfield(c, 'estadisticas_pso') && isstruct(c.estadisticas_pso)
    estadisticas = c.estadisticas_pso;
    r.id_estadistico = campo_texto(estadisticas, 'id_estadistico');
    r.traza_f1 = normalizar_traza(campo_struct(estadisticas, 'traza_fase_1'));
    r.traza_f2 = normalizar_traza(campo_struct(estadisticas, 'traza_fase_2'));
end
r.cohorte = clave_cohorte(c, p, estadisticas);
r.clave_deduplicacion = clave_deduplicacion(r);
end

function r = plantilla_corrida()
r = struct('fuente_mat', '', 'legacy', false, 'id_corrida', '', ...
    'id_estadistico', '', 'timestamp', '', 'antenas', NaN, 'tipo_antena', '', ...
    'caso', '', 'potencia', '', 'distribucion', '', 'fitness_fino', NaN, ...
    'fitness_pso', NaN, 'tiempo_total_s', NaN, 'cobertura_pct', NaN, ...
    'exterior_pct', NaN, 'volumen_tumor_mm3', NaN, ...
    'volumen_distribucion_mm3', NaN, 'volumen_exterior_mm3', NaN, ...
    'posicion', nan(1,5), 'historia_f1', zeros(0,1), ...
    'historia_f2', zeros(0,1), 'historia', zeros(0,1), ...
    'traza_f1', traza_vacia(), 'traza_f2', traza_vacia(), ...
    'cohorte', '', 'clave_deduplicacion', '', ...
    'fitness_convergencia_final', NaN, 'auc_normalizada', NaN, ...
    'primer_objetivo_1', NaN, 'primer_objetivo_5', NaN);
end

function traza = traza_vacia()
traza = struct('iteracion',zeros(0,1), 'mejor_fitness',zeros(0,1), ...
    'fitness_medio',zeros(0,1), 'evaluaciones',zeros(0,1), ...
    'estancamiento',zeros(0,1), 'tiempo_iteracion_s',zeros(0,1), ...
    'mejor_posicion',zeros(0,5));
end

function traza = normalizar_traza(origen)
traza = traza_vacia(); if isempty(fieldnames(origen)), return; end
campos = {'iteracion','mejor_fitness','fitness_medio','evaluaciones','estancamiento','tiempo_iteracion_s'};
for k = 1:numel(campos)
    if isfield(origen, campos{k}) && isnumeric(origen.(campos{k}))
        traza.(campos{k}) = double(origen.(campos{k})(:));
    end
end
if isfield(origen, 'mejor_posicion') && isnumeric(origen.mejor_posicion)
    posiciones = double(origen.mejor_posicion); if isvector(posiciones), posiciones = posiciones(:).'; end
    if size(posiciones,2) < 5, posiciones(:,end+1:5) = NaN; end
    traza.mejor_posicion = posiciones(:,1:5);
end
end

function [corridas, duplicadas] = deduplicar_corridas(corridas)
if isempty(corridas), duplicadas = 0; return; end
claves = string({corridas.clave_deduplicacion}); [~, indices] = unique(claves, 'stable');
duplicadas = numel(corridas) - numel(indices); corridas = corridas(sort(indices));
end

function clave = clave_deduplicacion(r)
if ~isempty(r.id_estadistico), clave = ['id|' r.id_estadistico]; return; end
inicial = NaN; final = NaN;
if ~isempty(r.historia), inicial = r.historia(1); final = r.historia(end); end
clave = sprintf('legacy|%s|%s|%s|%.15g|%.15g|%.15g|%d|%.15g|%.15g', ...
    r.timestamp, r.id_corrida, r.distribucion, r.fitness_fino, ...
    r.tiempo_total_s, r.fitness_pso, numel(r.historia), inicial, final);
end

function clave = clave_cohorte(c, p, e)
metodo = campo_texto(p, 'metodo_voxel'); tipo = campo_texto(p, 'tipo_antena'); caso = campo_texto(p, 'caso');
firma = ''; res_fina = NaN; res_gruesa = NaN; filtros = struct(); criterio = struct();
if ~isempty(fieldnames(e))
    firma = campo_texto(e, 'firma_geometria'); metodo = campo_texto_preferido(e, 'metodo_voxel', metodo);
    res_fina = campo_numerico(e, 'resolucion_fina_mm'); res_gruesa = campo_numerico(e, 'resolucion_gruesa_mm');
    filtros = campo_struct(e, 'filtros_activos'); criterio = campo_struct(e, 'criterio_fitness');
elseif isfield(p, 'criterio_fitness') && isstruct(p.criterio_fitness)
    criterio = p.criterio_fitness;
end
if isempty(firma) && isfield(c, 'vertices_tumor') && isnumeric(c.vertices_tumor)
    v = double(c.vertices_tumor); firma = sprintf('legacy_n%d_s%.9g_q%.9g', size(v,1), sum(v(:)), sum(v(:).^2));
end
clave = sprintf('geom=%s|tipo=%s|caso=%s|metodo=%s|rf=%.9g|rg=%.9g|%s|%s', ...
    firma, tipo, caso, metodo, res_fina, res_gruesa, ...
    serializar_filtros(filtros), serializar_estructura_numerica(criterio));
end

function texto = serializar_filtros(filtros)
if isempty(fieldnames(filtros)), texto = 'filtros=legacy'; return; end
campos = sort(fieldnames(filtros)); partes = {};
for k = 1:numel(campos)
    if strcmp(campos{k}, 'antenas'), continue; end
    valor = filtros.(campos{k});
    if iscell(valor) || isstring(valor) || ischar(valor)
        valores = sort(string(valor(:))); partes{end+1} = sprintf('%s=%s', campos{k}, strjoin(valores, ',')); %#ok<AGROW>
    end
end
texto = strjoin(partes, ';');
end

function texto = serializar_estructura_numerica(s)
if isempty(fieldnames(s)), texto = 'criterio=legacy'; return; end
campos = sort(fieldnames(s)); partes = {};
for k = 1:numel(campos)
    valor = s.(campos{k});
    if isnumeric(valor) && isscalar(valor), partes{end+1} = sprintf('%s=%.12g', campos{k}, double(valor)); end %#ok<AGROW>
end
texto = strjoin(partes, ';');
end

function [corridas, tabla_corridas, tabla_grupos, tabla_iteraciones, tabla_kw, tabla_pares] = analizar_cohorte(corridas)
grupos = unique([corridas.antenas]); grupos = grupos(isfinite(grupos));
for k = 1:numel(corridas)
    h = corridas(k).historia; validos = h(isfinite(h));
    if ~isempty(validos), corridas(k).fitness_convergencia_final = validos(end); end
    corridas(k).auc_normalizada = auc_normalizada(h);
end
for idx_grupo = 1:numel(grupos)
    indices = find([corridas.antenas] == grupos(idx_grupo));
    finales = [corridas(indices).fitness_convergencia_final]; finales = finales(isfinite(finales));
    if isempty(finales), continue; end
    mejor = min(finales); objetivo_1 = mejor + 0.01 * abs(mejor); objetivo_5 = mejor + 0.05 * abs(mejor);
    for idx = indices
        corridas(idx).primer_objetivo_1 = primer_impacto(corridas(idx).historia, objetivo_1);
        corridas(idx).primer_objetivo_5 = primer_impacto(corridas(idx).historia, objetivo_5);
    end
end
tabla_corridas = tabla_corridas_normalizadas(corridas);
[tabla_grupos, tabla_iteraciones] = resumir_grupos(corridas, grupos);
[tabla_kw, tabla_pares] = comparaciones_exploratorias(corridas, grupos);
end

function tabla = tabla_corridas_normalizadas(corridas)
n = numel(corridas);
fuente=strings(n,1); legacy=false(n,1); id=strings(n,1); fecha=strings(n,1); antenas=nan(n,1);
tipo=strings(n,1); caso=strings(n,1); potencia=strings(n,1); distribucion=strings(n,1);
fino=nan(n,1); pso=nan(n,1); conv=nan(n,1); tiempo=nan(n,1); it1=zeros(n,1); it2=zeros(n,1);
cobertura=nan(n,1); exterior=nan(n,1); auc=nan(n,1); hit1=nan(n,1); hit5=nan(n,1);
posicion=nan(n,5); cohorte=strings(n,1);
for k=1:n
    fuente(k)=corridas(k).fuente_mat; legacy(k)=corridas(k).legacy;
    if isempty(corridas(k).id_estadistico), id(k)=corridas(k).id_corrida; else, id(k)=corridas(k).id_estadistico; end
    fecha(k)=corridas(k).timestamp; antenas(k)=corridas(k).antenas; tipo(k)=corridas(k).tipo_antena;
    caso(k)=corridas(k).caso; potencia(k)=corridas(k).potencia; distribucion(k)=corridas(k).distribucion;
    fino(k)=corridas(k).fitness_fino; pso(k)=corridas(k).fitness_pso; conv(k)=corridas(k).fitness_convergencia_final;
    tiempo(k)=corridas(k).tiempo_total_s; it1(k)=numel(corridas(k).historia_f1); it2(k)=numel(corridas(k).historia_f2);
    cobertura(k)=corridas(k).cobertura_pct; exterior(k)=corridas(k).exterior_pct;
    auc(k)=corridas(k).auc_normalizada; hit1(k)=corridas(k).primer_objetivo_1; hit5(k)=corridas(k).primer_objetivo_5;
    posicion(k,:)=corridas(k).posicion; cohorte(k)=corridas(k).cohorte;
end
tabla = table(fuente,legacy,id,fecha,antenas,tipo,caso,potencia,distribucion, ...
    fino,pso,conv,tiempo,it1,it2,cobertura,exterior,auc,hit1,hit5, ...
    posicion(:,1),posicion(:,2),posicion(:,3),rad2deg(posicion(:,4)),rad2deg(posicion(:,5)),cohorte, ...
    'VariableNames', {'FuenteMAT','EsquemaAntiguo','IdEstadistico','Fecha','Antenas', ...
    'TipoAntena','Caso','Potencia','Distribucion','FitnessFino','FitnessPSO', ...
    'FitnessConvergenciaFinal','TiempoTotal_s','IteracionesF1','IteracionesF2', ...
    'Cobertura_pct','Exterior_pct','AUCNormalizada','PrimerObjetivo1_iter', ...
    'PrimerObjetivo5_iter','X_mm','Y_mm','Z_mm','Rotacion1_deg','Rotacion2_deg','FirmaConfiguracion'});
end

function [tabla_grupos, tabla_iteraciones] = resumir_grupos(corridas, grupos)
filas = repmat(struct(), 0, 1); tabla_iteraciones = table();
for g = grupos
    c = corridas([corridas.antenas] == g); n = numel(c);
    fino=[c.fitness_fino]; pso=[c.fitness_pso]; tiempo=[c.tiempo_total_s]; cobertura=[c.cobertura_pct];
    exterior=[c.exterior_pct]; auc=[c.auc_normalizada]; conv=[c.fitness_convergencia_final]; conv=conv(isfinite(conv));
    if isempty(conv), objetivo5=NaN; else, objetivo5=min(conv)+0.05*abs(min(conv)); end
    hits=[c.primer_objetivo_5]; [mlo,mhi,medlo,medhi]=intervalos_bootstrap(fino); q=cuantiles(fino,[.25 .75]);
    fila=struct('Antenas',g,'Corridas',n,'FitnessFinoMedia',media_finita(fino), ...
        'FitnessFinoIC95Bajo',mlo,'FitnessFinoIC95Alto',mhi,'FitnessFinoMediana',mediana_finita(fino), ...
        'FitnessMedianaIC95Bajo',medlo,'FitnessMedianaIC95Alto',medhi, ...
        'FitnessFinoVarianza',varianza_finita(fino),'FitnessFinoDE',desviacion_finita(fino), ...
        'FitnessFinoQ1',q(1),'FitnessFinoQ3',q(2),'FitnessFinoMin',min_finito(fino), ...
        'FitnessFinoMax',max_finito(fino),'FitnessFinoCV_pct',cv_finito(fino), ...
        'FitnessPSOMedia',media_finita(pso),'FitnessPSODE',desviacion_finita(pso), ...
        'TiempoMedia_s',media_finita(tiempo),'TiempoDE_s',desviacion_finita(tiempo), ...
        'CoberturaMedia_pct',media_finita(cobertura),'CoberturaDE_pct',desviacion_finita(cobertura), ...
        'ExteriorMedia_pct',media_finita(exterior),'ExteriorDE_pct',desviacion_finita(exterior), ...
        'AUCMedia',media_finita(auc),'AUCDE',desviacion_finita(auc),'Objetivo5',objetivo5, ...
        'Exito5_pct',100*mean(isfinite(hits)),'MedianaPrimerObjetivo5_iter',mediana_finita(hits));
    if isempty(filas), filas=fila; else, filas(end+1,1)=fila; end %#ok<AGROW>
    matriz=matriz_historias(c);
    if ~isempty(matriz)
        iter=(1:size(matriz,2)).'; cuenta=sum(isfinite(matriz),1).'; media=mean(matriz,1,'omitnan').';
        de=std(matriz,0,1,'omitnan').'; mediana=median(matriz,1,'omitnan').';
        tg=table(repmat(g,numel(iter),1),iter,cuenta,media,de,mediana, ...
            'VariableNames',{'Antenas','Iteracion','N','Media','DesviacionEstandar','Mediana'});
        tabla_iteraciones=[tabla_iteraciones;tg]; %#ok<AGROW>
    end
end
if isempty(filas), tabla_grupos=table(); else, tabla_grupos=struct2table(filas); end
end

function [tabla_kw, tabla_pares] = comparaciones_exploratorias(corridas, grupos)
datos=cell(0,1); etiquetas=[];
for g=grupos
    x=[corridas([corridas.antenas]==g).fitness_fino]; x=x(isfinite(x));
    if numel(x)>=2, datos{end+1,1}=x(:); etiquetas(end+1)=g; end %#ok<AGROW>
end
if numel(datos)<2, tabla_kw=table(); tabla_pares=table(); return; end
[H,p]=kruskal_wallis_manual(datos); tabla_kw=table(H,numel(datos)-1,p,'VariableNames',{'H','GradosLibertad','ValorP'});
filas=repmat(struct(),0,1); m=numel(datos)*(numel(datos)-1)/2;
for i=1:numel(datos)-1
    for j=i+1:numel(datos)
        [U,pU,z]=mann_whitney_manual(datos{i},datos{j}); delta=cliff_delta(datos{i},datos{j});
        fila=struct('AntenasA',etiquetas(i),'AntenasB',etiquetas(j),'U',U,'Z',z, ...
            'ValorP',pU,'ValorPAjustadoBonferroni',min(1,pU*m),'DeltaCliff_A_menos_B',delta);
        if isempty(filas), filas=fila; else, filas(end+1,1)=fila; end %#ok<AGROW>
    end
end
tabla_pares=struct2table(filas);
end

function generar_graficas(corridas, tabla_iter, tabla_grupos, carpeta_png, carpeta_fig, prefijo)
grupos=unique([corridas.antenas]); grupos=grupos(isfinite(grupos)); if isempty(grupos),return;end
f=figura_nueva('Corridas y convergencia media',numel(grupos));
t=tiledlayout(f,numel(grupos),1,'TileSpacing','compact','Padding','compact');
for i=1:numel(grupos)
    ax=nexttile(t);hold(ax,'on');c=corridas([corridas.antenas]==grupos(i));M=matriz_historias(c);
    for r=1:size(M,1),plot(ax,M(r,:),'-','Color',[.72 .72 .72],'LineWidth',.6,'HandleVisibility','off');end
    plot(ax,mean(M,1,'omitnan'),'-','Color',[.64 .08 .18],'LineWidth',2.2,'DisplayName','Media');
    title(ax,sprintf('%s %s',panel(i),etiqueta_antenas(grupos(i))));grid(ax,'on');estilo_ejes(ax);
    legend(ax,{'Media'},'Location','best');if i<numel(grupos),ax.XTickLabel=[];end
end
xlabel(t,'Iteración');ylabel(t,'Función objetivo');title(t,'Corridas y convergencia media del PSO');estilo_layout(t);
guardar_figura(f,carpeta_png,carpeta_fig,[prefijo '_convergencia_corridas_media']);

f=figura_nueva('Media y desviación estándar',numel(grupos));
t=tiledlayout(f,numel(grupos),1,'TileSpacing','compact','Padding','compact');colores=lines(max(4,numel(grupos)));
for i=1:numel(grupos)
    ax=nexttile(t);hold(ax,'on');filas=tabla_iter.Antenas==grupos(i);x=tabla_iter.Iteracion(filas);
    mu=tabla_iter.Media(filas);sd=tabla_iter.DesviacionEstandar(filas);color=colores(i,:);
    plot(ax,x,mu,'Color',color,'LineWidth',2.1,'DisplayName','Media');
    plot(ax,x,mu+sd,'--','Color',aclarar(color,.55),'LineWidth',1.4,'DisplayName','± 1 DE');
    plot(ax,x,mu-sd,'--','Color',aclarar(color,.55),'LineWidth',1.4,'HandleVisibility','off');
    title(ax,sprintf('%s %s',panel(i),etiqueta_antenas(grupos(i))));grid(ax,'on');estilo_ejes(ax);
    legend(ax,'Location','best');if i<numel(grupos),ax.XTickLabel=[];end
end
xlabel(t,'Iteración');ylabel(t,'Función objetivo');title(t,'Convergencia media ± 1 desviación estándar');estilo_layout(t);
guardar_figura(f,carpeta_png,carpeta_fig,[prefijo '_convergencia_media_de']);

graficar_distribucion(corridas,grupos,'fitness_fino','Fitness fino final','Fitness fino', ...
    [prefijo '_distribucion_fitness_fino'],carpeta_png,carpeta_fig);
graficar_distribucion(corridas,grupos,'tiempo_total_s','Tiempo total de optimización','Tiempo (s)', ...
    [prefijo '_distribucion_tiempo'],carpeta_png,carpeta_fig);
f=figure('Name','Cobertura y exterior','Color','w','Position',[100 100 950 560]);ax=axes(f);
medias=[tabla_grupos.CoberturaMedia_pct tabla_grupos.ExteriorMedia_pct];
b=bar(ax,(1:height(tabla_grupos)).',medias,'grouped');
b(1).FaceColor=[.20 .60 .30];b(2).FaceColor=[.75 .25 .20];xticks(ax,1:height(tabla_grupos));
xticklabels(ax,arrayfun(@etiqueta_antenas,tabla_grupos.Antenas,'UniformOutput',false));
ylabel(ax,'Porcentaje (%)');title(ax,'Cobertura tumoral y distribución exterior');
legend(ax,{'Cobertura tumoral','Distribución exterior'},'Location','best');grid(ax,'on');estilo_ejes(ax);
guardar_figura(f,carpeta_png,carpeta_fig,[prefijo '_cobertura_exterior']);
graficar_parametros(corridas,grupos,carpeta_png,carpeta_fig,prefijo);
graficar_exito(corridas,grupos,carpeta_png,carpeta_fig,prefijo);
end

function graficar_distribucion(corridas,grupos,campo,titulo_grafica,etiqueta_y,nombre,carpeta_png,carpeta_fig)
valores=[];indices=[];
for i=1:numel(grupos)
    x=[corridas([corridas.antenas]==grupos(i)).(campo)];validos=isfinite(x);
    valores=[valores x(validos)];indices=[indices repmat(i,1,sum(validos))]; %#ok<AGROW>
end
if isempty(valores),return;end
f=figure('Name',titulo_grafica,'Color','w','Position',[100 100 900 560]);ax=axes(f);
boxchart(ax,indices(:),valores(:),'BoxFaceColor',[.25 .45 .70]);xticks(ax,1:numel(grupos));
xticklabels(ax,arrayfun(@etiqueta_antenas,grupos,'UniformOutput',false));
xlabel(ax,'Número de antenas');ylabel(ax,etiqueta_y);title(ax,titulo_grafica);grid(ax,'on');estilo_ejes(ax);
guardar_figura(f,carpeta_png,carpeta_fig,nombre);
end

function graficar_parametros(corridas,grupos,carpeta_png,carpeta_fig,prefijo)
seleccionados=repmat(plantilla_corrida(),0,1);
for g=grupos
    candidatos=corridas([corridas.antenas]==g);
    tiene=arrayfun(@(c)~isempty(c.traza_f1.mejor_posicion)||~isempty(c.traza_f2.mejor_posicion),candidatos);
    candidatos=candidatos(tiene);if isempty(candidatos),continue;end
    valor=arrayfun(@fitness_primario,candidatos);[~,idx]=min(valor);seleccionados(end+1)=candidatos(idx); %#ok<AGROW>
end
if isempty(seleccionados),return;end
f=figura_nueva('Evolución de parámetros',numel(seleccionados));
t=tiledlayout(f,numel(seleccionados),1,'TileSpacing','compact','Padding','compact');colores=lines(5);
for i=1:numel(seleccionados)
    ax=nexttile(t);hold(ax,'on');P=[seleccionados(i).traza_f1.mejor_posicion;seleccionados(i).traza_f2.mejor_posicion];
    P(:,4:5)=rad2deg(P(:,4:5));etiquetas={'X','Y','Z','Rotación 1','Rotación 2'};
    for k=1:5,plot(ax,P(:,k),'Color',colores(k,:),'LineWidth',1.5,'DisplayName',etiquetas{k});end
    title(ax,sprintf('%s %s',panel(i),etiqueta_antenas(seleccionados(i).antenas)));
    legend(ax,'Location','best','NumColumns',5);grid(ax,'on');estilo_ejes(ax);if i<numel(seleccionados),ax.XTickLabel=[];end
end
xlabel(t,'Iteración');ylabel(t,'Posición (mm) / rotación (°)');title(t,'Evolución de parámetros de la mejor corrida');estilo_layout(t);
guardar_figura(f,carpeta_png,carpeta_fig,[prefijo '_evolucion_parametros']);
end

function graficar_exito(corridas,grupos,carpeta_png,carpeta_fig,prefijo)
f=figure('Name','Objetivo del 5 %','Color','w','Position',[100 100 950 560]);ax=axes(f);hold(ax,'on');
colores=lines(max(4,numel(grupos)));hay=false;
for i=1:numel(grupos)
    c=corridas([corridas.antenas]==grupos(i));finales=[c.fitness_convergencia_final];finales=finales(isfinite(finales));
    if isempty(finales),continue;end
    objetivo=min(finales)+.05*abs(min(finales));M=matriz_historias(c);fraccion=zeros(1,size(M,2));
    for k=1:size(M,2),fraccion(k)=100*mean(any(M(:,1:k)<=objetivo,2));end
    stairs(ax,1:numel(fraccion),fraccion,'Color',colores(i,:),'LineWidth',1.8, ...
        'DisplayName',etiqueta_antenas(grupos(i)));hay=true;
end
if ~hay,close(f);return;end
xlabel(ax,'Iteración');ylabel(ax,'Corridas que alcanzaron el objetivo (%)');ylim(ax,[0 100]);
title(ax,'Convergencia al objetivo del 5 %');legend(ax,'Location','best');grid(ax,'on');estilo_ejes(ax);
guardar_figura(f,carpeta_png,carpeta_fig,[prefijo '_exito_objetivo_5']);
end

function f=figura_nueva(nombre,paneles)
f=figure('Name',nombre,'Color','w','Position',[80 30 1100 max(600,260*paneles)]);
end

function guardar_figura(f,carpeta_png,carpeta_fig,nombre)
neutro=[.15 .15 .15];
ejes=findall(f,'Type','axes');
for k=1:numel(ejes),estilo_ejes(ejes(k));end
textos=findall(f,'Type','text');
for k=1:numel(textos),textos(k).Color=neutro;end
leyendas=findall(f,'Type','legend');
for k=1:numel(leyendas)
    leyendas(k).Color='w';leyendas(k).TextColor=neutro;leyendas(k).EdgeColor=neutro;
end
exportgraphics(f,fullfile(carpeta_png,[nombre '.png']),'Resolution',300);
savefig(f,fullfile(carpeta_fig,[nombre '.fig']));
end

function estilo_ejes(ax)
neutro=[.15 .15 .15];ax.Color='w';ax.XColor=neutro;ax.ZColor=neutro;
for k=1:numel(ax.YAxis),ax.YAxis(k).Color=neutro;end
ax.GridColor=[.72 .72 .72];ax.GridAlpha=.35;ax.FontName='Times New Roman';ax.FontSize=12;box(ax,'on');
end

function estilo_layout(t)
neutro=[.15 .15 .15];
t.Title.Color=neutro;t.XLabel.Color=neutro;t.YLabel.Color=neutro;
end

function M=matriz_historias(corridas)
longitudes=arrayfun(@(c)numel(c.historia),corridas);maximo=max([longitudes(:);0]);
if maximo==0,M=zeros(0,0);return;end
M=nan(numel(corridas),maximo);for k=1:numel(corridas),h=corridas(k).historia(:).';M(k,1:numel(h))=h;end
end

function a=auc_normalizada(h)
h=h(:);h=h(isfinite(h));if isempty(h),a=NaN;return;end
if isscalar(h),a=1;return;end
den=h(1)-h(end);if abs(den)<=eps(max(1,abs(h(1)))),a=1;else,a=trapz((h(1)-h)./den)/(numel(h)-1);end
end

function hit=primer_impacto(h,objetivo)
hit=NaN;idx=find(isfinite(h)&h<=objetivo,1,'first');if ~isempty(idx),hit=idx;end
end

function valor=fitness_primario(c)
valor=c.fitness_fino;if ~isfinite(valor),valor=c.fitness_pso;end
if ~isfinite(valor),valor=c.fitness_convergencia_final;end
end

function [mlo,mhi,medlo,medhi]=intervalos_bootstrap(x)
x=x(isfinite(x));if numel(x)<2,mlo=NaN;mhi=NaN;medlo=NaN;medhi=NaN;return;end
estado=rng;limpieza=onCleanup(@()rng(estado));
rng(20260711);B=10000;muestras=x(randi(numel(x),numel(x),B));
qm=cuantiles(mean(muestras,1),[.025 .975]);qmed=cuantiles(median(muestras,1),[.025 .975]);
mlo=qm(1);mhi=qm(2);medlo=qmed(1);medhi=qmed(2);
end

function q=cuantiles(x,p)
x=sort(x(isfinite(x)));q=nan(size(p));if isempty(x),return;end
for k=1:numel(p),pos=1+(numel(x)-1)*p(k);lo=floor(pos);hi=ceil(pos);q(k)=x(lo)+(pos-lo)*(x(hi)-x(lo));end
end

function [H,p]=kruskal_wallis_manual(grupos)
x=vertcat(grupos{:});etiquetas=[];
for k=1:numel(grupos),etiquetas=[etiquetas;repmat(k,numel(grupos{k}),1)];end %#ok<AGROW>
r=rangos_empates(x);N=numel(x);H=0;
for k=1:numel(grupos),rk=r(etiquetas==k);H=H+numel(rk)*mean(rk)^2;end
H=12*H/(N*(N+1))-3*(N+1);[~,~,ic]=unique(x);cuentas=accumarray(ic,1);
C=1-sum(cuentas.^3-cuentas)/(N^3-N);if C>0,H=H/C;end
p=gammainc(H/2,(numel(grupos)-1)/2,'upper');
end

function [U,p,z]=mann_whitney_manual(x,y)
x=x(:);y=y(:);n1=numel(x);n2=numel(y);todo=[x;y];r=rangos_empates(todo);
U=sum(r(1:n1))-n1*(n1+1)/2;mu=n1*n2/2;[~,~,ic]=unique(todo);t=accumarray(ic,1);
varU=n1*n2/12*((n1+n2+1)-sum(t.^3-t)/((n1+n2)*(n1+n2-1)));
if varU<=0,z=0;p=1;else,z=(U-mu)/sqrt(varU);p=erfc(abs(z)/sqrt(2));end
end

function r=rangos_empates(x)
[sx,orden]=sort(x);r=zeros(size(x));i=1;
while i<=numel(sx),j=i;while j<numel(sx)&&sx(j+1)==sx(i),j=j+1;end;r(orden(i:j))=(i+j)/2;i=j+1;end
end

function d=cliff_delta(x,y)
d=mean(sign(x(:)-y(:).'),'all');
end

function valor=media_finita(x),x=x(isfinite(x));if isempty(x),valor=NaN;else,valor=mean(x);end,end
function valor=mediana_finita(x),x=x(isfinite(x));if isempty(x),valor=NaN;else,valor=median(x);end,end
function valor=varianza_finita(x),x=x(isfinite(x));if numel(x)<2,valor=NaN;else,valor=var(x,0);end,end
function valor=desviacion_finita(x),x=x(isfinite(x));if numel(x)<2,valor=NaN;else,valor=std(x,0);end,end
function valor=min_finito(x),x=x(isfinite(x));if isempty(x),valor=NaN;else,valor=min(x);end,end
function valor=max_finito(x),x=x(isfinite(x));if isempty(x),valor=NaN;else,valor=max(x);end,end
function valor=cv_finito(x),m=media_finita(x);s=desviacion_finita(x);if ~isfinite(m)||abs(m)<eps,valor=NaN;else,valor=100*s/abs(m);end,end

function n=numero_antenas(p)
n=campo_numerico(p,'numero_antenas');if isfinite(n),return;end
texto=campo_texto(p,'numero_antenas');token=regexp(texto,'\d+','match','once');if isempty(token),n=NaN;else,n=str2double(token);end
end

function v=campo_numerico(s,campo)
v=NaN;if isstruct(s)&&isfield(s,campo)&&isnumeric(s.(campo))&&isscalar(s.(campo))&&isfinite(double(s.(campo))),v=double(s.(campo));end
end

function texto=campo_texto(s,campo)
texto='';if isstruct(s)&&isfield(s,campo)&&~isempty(s.(campo)),texto=char(string(s.(campo)));end
end

function texto=campo_texto_preferido(s,campo,respaldo)
texto=campo_texto(s,campo);if isempty(texto),texto=respaldo;end
end

function s=campo_struct(origen,campo)
s=struct();if isstruct(origen)&&isfield(origen,campo)&&isstruct(origen.(campo)),s=origen.(campo);end
end

function v=vector_numerico(s,campo)
v=zeros(0,1);if isstruct(s)&&isfield(s,campo)&&isnumeric(s.(campo)),v=double(s.(campo)(:));end
end

function texto=etiqueta_antenas(n)
if n==1,texto='1 antena';else,texto=sprintf('%d antenas',round(n));end
end

function texto=panel(i)
letras='ABCDEFGHIJKLMNOPQRSTUVWXYZ';if i<=numel(letras),texto=sprintf('%c)',letras(i));else,texto=sprintf('%d)',i);end
end

function c=aclarar(color,factor),c=color+(1-color)*factor;end
function crear_carpeta(carpeta),if ~isfolder(carpeta),mkdir(carpeta);end,end

function ejecutar_selftest()
p=struct('numero_antenas','2ant','tipo_antena','Monopolo','caso','Caso_1', ...
    'potencia','Potencia_30W','distribucion_termica','demo','fitness_fino',-12, ...
    'fitness_pso',-11,'porcentaje_interior',90,'porcentaje_exterior',8, ...
    'posicion',[1 2 3 .1 .2],'metodo_voxel','sdf');
c=struct('id',1,'timestamp','2026-08-07 12:00:00','parametros',p, ...
    'historia_pso',[10;9],'historia_f1',[10;8],'historia_f2',[7;6], ...
    'tiempo_total',4,'vertices_tumor',[0 0 0;1 0 0],'incluir_estadisticas',true);
t=traza_vacia();t.mejor_posicion=[1 2 3 .1 .2;2 3 4 .2 .3];t.mejor_fitness=[10;8];
c.estadisticas_pso=struct('id_estadistico','demo-1','firma_geometria','geom-demo', ...
    'metodo_voxel','sdf','resolucion_fina_mm',.5,'resolucion_gruesa_mm',1.5, ...
    'traza_fase_1',t,'traza_fase_2',t,'filtros_activos',struct(),'criterio_fitness',struct());
r1=normalizar_corrida(c,'demo.mat',false);assert(isequal(r1.historia,[10;8;7;6]));
assert(r1.antenas==2&&size(r1.traza_f1.mejor_posicion,2)==5);
c2=c;c2.id=2;c2.timestamp='2026-08-07 12:01:00';c2.estadisticas_pso.id_estadistico='demo-2';
c2.parametros.fitness_fino=-14;c2.historia_f1=[11;9];c2.historia_f2=[8;5];
r2=normalizar_corrida(c2,'demo2.mat',false);
[unicas,duplicadas]=deduplicar_corridas([r1;r1;r2]);assert(numel(unicas)==2&&duplicadas==1);
[~,tc,tg,ti,~,~]=analizar_cohorte([r1;r2]);assert(height(tc)==2&&height(tg)==1&&height(ti)==4);
c.incluir_estadisticas=false;[incluir,legacy]=debe_incluir_corrida(c);assert(~incluir&&~legacy);
c=rmfield(c,'incluir_estadisticas');[incluir,legacy]=debe_incluir_corrida(c);assert(incluir&&legacy);
fprintf('SELFTEST_GRAFICADOR_ESTADISTICO_OK\n');
end
