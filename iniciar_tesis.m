function iniciar_tesis()
% Configuración de paths para modulos y auxiliares

    root_proyecto = fileparts(mfilename('fullpath'));
    addpath(fullfile(root_proyecto, 'Aux_Codes'));
    tesis_auxiliares('configurar_paths', root_proyecto);
    launcher_tesis_modulos();
end
