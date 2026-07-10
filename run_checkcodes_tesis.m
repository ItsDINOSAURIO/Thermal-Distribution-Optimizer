%RUN_CHECKCODES_TESIS Run MATLAB checkcode for the thesis entry modules.
%
% Usage from the project root:
%   matlab -batch "run_checkcodes_tesis"
%
% Keep MATLAB logic in this file. Chaining MATLAB statements with semicolons
% inside the shell command can break the managed command runner.

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'Aux_Codes'));
addpath(fullfile(root, 'modulos'));

files = {
    'iniciar_tesis.m'
    'modulos/launcher_tesis_modulos.m'
    'modulos/modulo_procesamiento_datos.m'
    'modulos/modulo_manejador_visual_datos.m'
    'modulos/dividir_datasets_masivos_por_metadata.m'
    'modulos/optimizador_3d_final.m'
    'modulos/modulo_interaccion_comsol.m'
    'modulos/Interfaz_Ablacion_AlphaShape.m'
    };

out_dir = fullfile(root, 'CHECKS');
if ~isfolder(out_dir)
    mkdir(out_dir);
end

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
report_file = fullfile(out_dir, ['checkcode_' stamp '.txt']);
latest_file = fullfile(out_dir, 'checkcode_latest.txt');

[report, total_issues, total_errors] = build_report(root, files);
write_text(report_file, report);
write_text(latest_file, report);

fprintf('%s\n', report);
fprintf('\nReportes escritos:\n  %s\n  %s\n', report_file, latest_file);
fprintf('Resumen: issues=%d | errores_checkcode=%d\n', total_issues, total_errors);

function [report, total_issues, total_errors] = build_report(root, files)
    lines = {
        'MATLAB checkcode - TT_FINAL'
        ['Fecha: ' char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))]
        ['Root: ' root]
        ''
        };
    total_issues = 0;
    total_errors = 0;

    for k = 1:numel(files)
        rel = files{k};
        abs_path = fullfile(root, rel);
        lines{end + 1, 1} = ['== ' rel ' ==']; %#ok<AGROW>

        if ~isfile(abs_path)
            total_errors = total_errors + 1;
            lines{end + 1, 1} = 'ERROR: archivo no encontrado.'; %#ok<AGROW>
            lines{end + 1, 1} = ''; %#ok<AGROW>
            continue;
        end

        try
            issues = checkcode(abs_path, '-id');
            total_issues = total_issues + numel(issues);
            lines{end + 1, 1} = sprintf('issues=%d', numel(issues)); %#ok<AGROW>
            for j = 1:numel(issues)
                lines{end + 1, 1} = format_issue(issues(j)); %#ok<AGROW>
            end
        catch ME
            total_errors = total_errors + 1;
            lines{end + 1, 1} = sprintf('ERROR checkcode: %s', ME.message); %#ok<AGROW>
        end

        lines{end + 1, 1} = ''; %#ok<AGROW>
    end

    lines{end + 1, 1} = sprintf('TOTAL issues=%d | errores_checkcode=%d', ...
        total_issues, total_errors);
    report = strjoin(lines, newline);
end

function line = format_issue(issue)
    line_no = getfield_default(issue, 'line', NaN);
    col_no = getfield_default(issue, 'column', NaN);
    id = getfield_default(issue, 'id', '');
    msg = getfield_default(issue, 'message', '');

    line_no = first_number(line_no);
    col_no = first_number(col_no);

    if isempty(id)
        id = 'checkcode';
    end
    line = sprintf('L%d C%d %s %s', line_no, col_no, id, msg);
end

function value = first_number(value)
    if isempty(value) || ~isnumeric(value)
        value = NaN;
    else
        value = value(1);
    end
end

function value = getfield_default(s, name, default_value)
    if isfield(s, name)
        value = s.(name);
    else
        value = default_value;
    end
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
