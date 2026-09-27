% iniciar_tesis: modulo de arranque del proyecto.
% Configura rutas, prepara la carpeta datasets y abre el lanzador.

% Prepara el entorno y abre el lanzador de modulos.
function iniciar_tesis()
    root_proyecto = fileparts(mfilename('fullpath'));
    addpath(fullfile(root_proyecto, 'aux_codes'));
    tesis_auxiliares('configurar_paths', root_proyecto);
    paths = tesis_auxiliares('dataset_paths', root_proyecto);
    if ~isfolder(paths.root), mkdir(paths.root); end
    launcher_tesis_modulos();
end
