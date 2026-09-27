function selftest_tabla_reporte_optimizacion()
p=struct('numero_antenas','1ant','volumen_tumor',103661.625, ...
    'porcentaje_exterior',0.00531,'fitness_fino',-0.111790, ...
    'posicion',[-20.65 -11.61 53.65 deg2rad(-0.03) deg2rad(98.28)], ...
    'ejes_a_rotar',[2 3],'profundidad_total_mm',43.67,'tipo_antena','Monopolo');
c=struct('id',1,'parametros',p,'historia_f1',zeros(40,1), ...
    'historia_f2',zeros(16,1),'tiempo_total',1075.97);
d=tabla_reporte_optimizacion({c,c});
assert(isequal(size(d),[24 3]));
assert(strcmp(d{2,2},'103661.625') && strcmp(d{7,2},'0.00531'));
assert(strcmp(d{8,2},'-0.111790') && strcmp(d{12,2},'56'));
assert(strcmp(d{13,2},'1075.97') && strcmp(d{18,2},'-0.03'));
assert(strcmp(d{19,2},'98.28') && strcmp(d{20,2},'43.67'));
c=rmfield(c,{'historia_f1','historia_f2','tiempo_total'});
c.historia_pso=zeros(12,1);
d=tabla_reporte_optimizacion({c});
assert(strcmp(d{10,2},'n/d') && strcmp(d{11,2},'n/d'));
assert(strcmp(d{12,2},'12') && strcmp(d{13,2},'n/d'));
fprintf('SELFTEST_TABLA_REPORTE_OPTIMIZACION_OK\n');
end
