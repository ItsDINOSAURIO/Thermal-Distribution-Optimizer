function iniciar_tesis()
% Configuración de paths para modulos y auxiliares

    root_proyecto = fileparts(mfilename('fullpath'));
    addpath(fullfile(root_proyecto, 'aux_codes'));
    tesis_auxiliares('configurar_paths', root_proyecto);
    paths = tesis_auxiliares('dataset_paths', root_proyecto);
    if ~isfolder(paths.root), mkdir(paths.root); end
    launcher_tesis_modulos();
end
