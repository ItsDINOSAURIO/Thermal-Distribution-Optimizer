function datos = tabla_reporte_optimizacion(corridas)
% Valores registrados, sin agrupar ni elegir corridas del mismo arreglo.
etiquetas = {'Volumen de tejido (mm^3)'; 'Volumen de ablacion (mm^3)'; ...
    'Interseccion con tejido (mm^3)'; 'Volumen exterior (mm^3)'; ...
    'Cobertura del tejido (%)'; 'Ablacion exterior (%)'; ...
    'Fitness fino'; 'Fitness PSO'; 'Iteraciones F1'; 'Iteraciones F2'; ...
    'Iteraciones totales registradas'; 'Tiempo total de ejecucion (s)'; ...
    'Traslacion x (mm)'; 'Traslacion y (mm)'; 'Traslacion z (mm)'; ...
    'Rotacion Rx (grados)'; 'Rotacion Ry (grados)'; 'Rotacion Rz (grados)'; ...
    'Profundidad total de A1 (mm)'; 'Tipo de antena'; 'Potencia'; 'Caso'; 'Distribucion'};
datos = repmat({'n/d'}, numel(etiquetas)+1, numel(corridas)+1);
datos(:,1) = [{'Parametro'}; etiquetas];
campos = {'volumen_tumor','volumen_distribucion_termica','volumen_interior', ...
    'volumen_exterior','porcentaje_interior','porcentaje_exterior', ...
    'fitness_fino','fitness_pso'};
precision = [3 3 3 3 4 5 6 6 0 0 0 2 2 2 2 2 2 2 2];
for k = 1:numel(corridas)
    c = corridas{k}; p = c.parametros;
    datos{1,k+1} = sprintf('%s | corrida #%g', char(string(p.numero_antenas)), c.id);
    v = NaN(19,1);
    for j = 1:numel(campos)
        if isfield(p,campos{j}), v(j) = p.(campos{j}); end
    end
    if isfield(c,'historia_f1') && ~isempty(c.historia_f1), v(9)=numel(c.historia_f1); end
    if isfield(c,'historia_f2') && ~isempty(c.historia_f2), v(10)=numel(c.historia_f2); end
    if all(isfinite(v(9:10)))
        v(11)=sum(v(9:10));
    elseif isfield(c,'historia_pso') && ~isempty(c.historia_pso)
        v(11)=numel(c.historia_pso);
    end
    if isfield(c,'tiempo_total'), v(12)=c.tiempo_total; end
    if isfield(p,'posicion') && numel(p.posicion)>=5
        v(13:15)=p.posicion(1:3);
        ejes=[];
        if isfield(p,'ejes_a_rotar'), ejes=p.ejes_a_rotar;
        elseif isfield(c,'ejes_a_rotar'), ejes=c.ejes_a_rotar; end
        if numel(ejes)==2 && all(ismember(ejes,1:3))
            rot=zeros(3,1); rot(ejes)=rad2deg(p.posicion(4:5)); v(16:18)=rot;
        end
    end
    if isfield(p,'profundidad_total_mm'), v(19)=p.profundidad_total_mm; end
    for j=1:numel(v)
        if isfinite(v(j)), datos{j+1,k+1}=sprintf('%.*f',precision(j),v(j)); end
    end
    textos={'tipo_antena','potencia','caso','distribucion_termica'};
    for j=1:numel(textos)
        if isfield(p,textos{j}), datos{20+j,k+1}=char(string(p.(textos{j}))); end
    end
end
end
