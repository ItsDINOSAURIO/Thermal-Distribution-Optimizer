%AUDITAR_DATASETS_MASIVOS_LIGERO Inventory MAT v7.3 datasets without loading arrays.
%
% Usage:
%   matlab -batch "run('/mnt/personal/TT_FINAL/auditar_datasets_masivos_ligero.m')"
%
% This only walks HDF5 group names under /dataset. It does not load thermal
% matrices, snapshots, probes, or full_field arrays into RAM.

root = fileparts(mfilename('fullpath'));
datasets_dir = fullfile(root, 'DATASETS', 'datasets_masivos');
checks_dir = fullfile(root, 'CHECKS');
if ~isfolder(checks_dir)
    mkdir(checks_dir);
end

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
csv_file = fullfile(checks_dir, ['auditoria_datasets_masivos_' stamp '.csv']);
txt_file = fullfile(checks_dir, ['auditoria_datasets_masivos_' stamp '.txt']);
latest_csv = fullfile(checks_dir, 'auditoria_datasets_masivos_latest.csv');
latest_txt = fullfile(checks_dir, 'auditoria_datasets_masivos_latest.txt');

mat_files = dir(fullfile(datasets_dir, '*.mat'));
mat_files = mat_files(~[mat_files.isdir]);
[~, order] = sort({mat_files.name});
mat_files = mat_files(order);

rows = crear_fila(0);
file_summary = strings(0, 1);

for i = 1:numel(mat_files)
    ruta = fullfile(mat_files(i).folder, mat_files(i).name);
    fprintf('[%d/%d] %s\n', i, numel(mat_files), mat_files(i).name);
    [file_rows, summary_line] = inventariar_mat_hdf5(ruta, mat_files(i));
    rows = [rows; file_rows]; %#ok<AGROW>
    file_summary(end + 1, 1) = summary_line; %#ok<SAGROW>
end

write_inventory_csv(csv_file, rows);
copyfile(csv_file, latest_csv);

report = build_report(root, datasets_dir, mat_files, rows, file_summary);
write_text(txt_file, report);
write_text(latest_txt, report);

fprintf('%s\n', report);
fprintf('\nReportes escritos:\n  %s\n  %s\n  %s\n  %s\n', ...
    csv_file, latest_csv, txt_file, latest_txt);

function [rows, summary_line] = inventariar_mat_hdf5(ruta, fileinfo)
    rows = crear_fila(0);
    fid = [];
    try
        fid = H5F.open(ruta, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
        modelos = listar_grupos(fid, '/dataset');
        n_datasets = 0;
        for mi = 1:numel(modelos)
            modelo = modelos{mi};
            if strcmp(modelo, 'session_meta')
                continue;
            end
            ruta_modelo = unir_h5('/dataset', modelo);
            tags = listar_grupos(fid, ruta_modelo);
            for ti = 1:numel(tags)
                tag = tags{ti};
                if ~startsWith(tag, 'dset_')
                    continue;
                end
                ruta_tag = unir_h5(ruta_modelo, tag);
                hijos = listar_hijos(fid, ruta_tag);
                meta = parsear_metadata(modelo, tag);
                row = crear_fila(1);
                row.archivo = string(fileinfo.name);
                row.bytes = fileinfo.bytes;
                row.modelo = string(modelo);
                row.dataset = string(tag);
                row.tipo = string(meta.tipo);
                row.antena = string(meta.antena);
                row.num_antenas = meta.num_antenas;
                row.caso = meta.caso;
                row.potencia_W = meta.potencia_W;
                row.tiene_snapshots = any(strcmp(hijos, 'snapshots'));
                row.tiene_full_field = any(strcmp(hijos, 'full_field'));
                row.tiene_probes = any(strcmp(hijos, 'probes'));
                row.tiene_t_min = any(strcmp(hijos, 't_min'));
                row.ruta_hdf5 = string(ruta_tag);
                rows(end + 1, 1) = row; %#ok<AGROW>
                n_datasets = n_datasets + 1;
            end
        end
        H5F.close(fid);
        summary_line = sprintf('%s | modelos=%d | datasets=%d | %.3f GB', ...
            fileinfo.name, numel(modelos), n_datasets, fileinfo.bytes / 1024^3);
    catch ME
        if ~isempty(fid)
            try, H5F.close(fid); catch, end
        end
        row = crear_fila(1);
        row.archivo = string(fileinfo.name);
        row.bytes = fileinfo.bytes;
        row.modelo = "ERROR";
        row.dataset = string(ME.message);
        rows = row;
        summary_line = sprintf('%s | ERROR | %s', fileinfo.name, ME.message);
    end
end

function rows = crear_fila(n)
    plantilla = struct( ...
        'archivo', "", ...
        'bytes', 0, ...
        'modelo', "", ...
        'dataset', "", ...
        'tipo', "", ...
        'antena', "", ...
        'num_antenas', NaN, ...
        'caso', NaN, ...
        'potencia_W', NaN, ...
        'tiene_snapshots', false, ...
        'tiene_full_field', false, ...
        'tiene_probes', false, ...
        'tiene_t_min', false, ...
        'ruta_hdf5', "");
    if n == 0
        rows = plantilla([]);
    else
        rows = repmat(plantilla, n, 1);
    end
end

function nombres = listar_grupos(fid, ruta)
    hijos = listar_hijos(fid, ruta);
    keep = false(size(hijos));
    for i = 1:numel(hijos)
        try
            gid = H5G.open(fid, unir_h5(ruta, hijos{i}));
            H5G.close(gid);
            keep(i) = true;
        catch
            keep(i) = false;
        end
    end
    nombres = hijos(keep);
end

function nombres = listar_hijos(fid, ruta)
    nombres = {};
    gid = H5G.open(fid, ruta);
    cleaner = onCleanup(@() H5G.close(gid));
    info = H5G.get_info(gid);
    for idx = 0:double(info.nlinks) - 1
        nombre = H5L.get_name_by_idx(fid, ruta, 'H5_INDEX_NAME', ...
            'H5_ITER_INC', idx, 'H5P_DEFAULT');
        nombres{end + 1} = nombre; %#ok<AGROW>
    end
    clear cleaner;
end

function ruta = unir_h5(parent, child)
    if strcmp(parent, '/')
        ruta = ['/' child];
    else
        ruta = [parent '/' child];
    end
end

function meta = parsear_metadata(modelo, tag)
    texto_modelo = char(modelo);
    texto_tag = char(tag);
    m = regexp(texto_modelo, 'modelo_(Doble_slot|Monopolo|Un_slot)_(\d+)ant', ...
        'tokens', 'once');
    c = regexp(texto_tag, '(?:^|[_-])c(?:aso)?_?(\d+)(?=$|[_-])', ...
        'tokens', 'once');
    p = regexp(texto_tag, '(?:^|[_-])p(?:otencia)?_?(\d+)(?:w)?(?=$|[_-])', ...
        'tokens', 'once');

    meta = struct('tipo', '', 'antena', '', 'num_antenas', NaN, ...
        'caso', NaN, 'potencia_W', NaN);
    if ~isempty(m)
        meta.tipo = m{1};
        meta.num_antenas = str2double(m{2});
        meta.antena = sprintf('%dant', meta.num_antenas);
    end
    if ~isempty(c)
        meta.caso = str2double(c{1});
    end
    if ~isempty(p)
        meta.potencia_W = str2double(p{1});
    end
end

function report = build_report(root, datasets_dir, mat_files, rows, file_summary)
    lines = {
        'Auditoria ligera DATASETS/datasets_masivos'
        ['Fecha: ' char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))]
        ['Root: ' root]
        ['Carpeta: ' datasets_dir]
        sprintf('Archivos MAT: %d', numel(mat_files))
        sprintf('Entradas dataset inventariadas: %d', numel(rows))
        ''
        'Por archivo:'
        };
    for i = 1:numel(file_summary)
        lines{end + 1, 1} = char(file_summary(i)); %#ok<AGROW>
    end

    keys_model = arrayfun(@(r) string(r.modelo) + "|" + string(r.dataset), ...
        rows, 'UniformOutput', false);
    keys_model = string(keys_model);
    keys_visual = arrayfun(@(r) string(r.tipo) + "|" + string(r.antena) + "|" + ...
        string(r.caso) + "|" + string(r.potencia_W) + "|" + string(r.dataset), ...
        rows, 'UniformOutput', false);
    keys_visual = string(keys_visual);

    lines{end + 1, 1} = ''; %#ok<AGROW>
    lines{end + 1, 1} = sprintf('Unicos modelo|dataset: %d', numel(unique(keys_model))); %#ok<AGROW>
    lines{end + 1, 1} = sprintf('Unicos clave visual antigua: %d', numel(unique(keys_visual))); %#ok<AGROW>
    lines{end + 1, 1} = sprintf('Filas que se colapsarian con clave visual antigua: %d', ...
        numel(keys_visual) - numel(unique(keys_visual))); %#ok<AGROW>

    report = strjoin(lines, newline);
end

function write_inventory_csv(path_out, rows)
    fid = fopen(path_out, 'w');
    if fid < 0
        error('No se pudo escribir: %s', path_out);
    end
    cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, ['archivo,bytes,modelo,dataset,tipo,antena,num_antenas,caso,', ...
        'potencia_W,tiene_snapshots,tiene_full_field,tiene_probes,tiene_t_min,ruta_hdf5\n']);
    for i = 1:numel(rows)
        fprintf(fid, '"%s",%d,"%s","%s","%s","%s",%g,%g,%g,%d,%d,%d,%d,"%s"\n', ...
            rows(i).archivo, rows(i).bytes, rows(i).modelo, rows(i).dataset, ...
            rows(i).tipo, rows(i).antena, rows(i).num_antenas, rows(i).caso, ...
            rows(i).potencia_W, rows(i).tiene_snapshots, rows(i).tiene_full_field, ...
            rows(i).tiene_probes, rows(i).tiene_t_min, rows(i).ruta_hdf5);
    end
    clear cleaner;
end

function write_text(path_out, text)
    fid = fopen(path_out, 'w');
    if fid < 0
        error('No se pudo escribir: %s', path_out);
    end
    cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', text);
    clear cleaner;
end
