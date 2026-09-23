function convertir_historiales_sinfactor()
% Convierte los historiales identificados con escala 1000, sin sobrescribir.
raiz = fileparts(fileparts(mfilename('fullpath')));
nombres = {'historial_sesion', 'historial_sesion_exp', 'historial_sesion_grabado'};
for i = 1:numel(nombres)
    origen = fullfile(raiz, 'datasets', [nombres{i} '.mat']);
    destino = fullfile(raiz, 'datasets', [nombres{i} '_sinfactor.mat']);
    assert(~isfile(destino), 'La copia ya existe: %s', destino);
    original = load(origen);
    convertido = original;
    for k = 1:numel(original.hs)
        c = original.hs{k};
        p = c.parametros;
        factor = p.criterio_fitness.escala_fitness;
        assert(isequal(factor, 1000), 'Factor inesperado en %s.', origen);
        % Estos archivos no contienen medias del enjambre: una media con
        % penalizaciones invalidas de 1e6 no se puede desescalar directamente.
        assert(~isfield(c, 'estadisticas_pso') || isempty(c.estadisticas_pso), ...
            'El historial contiene estadisticas que requieren revision.');
        m = p.metricas_fitness;
        esperado = -m.cobertura + m.penalizacion_fuga + ...
            m.penalizacion_centroide + m.penalizacion_profundidad;
        assert(abs(p.fitness_fino / factor - esperado) < 1e-12);
        assert(isequaln(m.fitness, p.fitness_fino));
        p.fitness_fino = p.fitness_fino / factor;
        p.fitness_pso = quitar_factor(p.fitness_pso, factor);
        p.metricas_fitness.fitness = p.metricas_fitness.fitness / factor;
        p.criterio_fitness.escala_fitness = 1;
        c.parametros = p;
        for campo = {'historia_pso', 'historia_f1', 'historia_f2'}
            nombre = campo{1};
            c.(nombre) = quitar_factor(c.(nombre), factor);
        end
        convertido.hs{k} = c;
        fprintf('%s, corrida %d: fino %.15g -> %.15g; PSO %.15g -> %.15g\n', ...
            nombres{i}, k, original.hs{k}.parametros.fitness_fino, ...
            p.fitness_fino, original.hs{k}.parametros.fitness_pso, p.fitness_pso);
    end
    save(destino, '-struct', 'convertido', '-v7.3');
    assert(isequaln(load(destino), convertido), 'La copia no coincide.');
    assert(isequaln(load(origen), original), 'El original cambio.');
    fprintf('Copia verificada: %s\n', destino);
end
end

function valores = quitar_factor(valores, factor)
% La penalizacion de geometria invalida se asigna antes del multiplicador.
validos = valores ~= 1e6;
valores(validos) = valores(validos) / factor;
end
