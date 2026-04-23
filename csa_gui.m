function csa_gui()
%  Input file format (CSV, fixed — do not change):
%    Header row:  x_mm,y_mm,thickness_mm
%    Data rows:   comma-separated floats, boustrophedon scan order
%
%  Features:
%   - Reads CSV correctly (header skipped, comma delimiter)
%   - Per-Y cross-sectional area via trapz
%   - 1-D cubic interpolation of area vs Y
%   - Area vs Y-position plot (bar + interpolated line)
%   - Total volume display
%   - "Show 3D Model" button  -> separate surface figure
%   - "Save Area Data" button -> writes area report to .txt
    Nintp     = 50;    % interpolation resolution
    THRESHOLD = 0.5;  % thickness values <= this treated as zero
                       % (noise floor; real data values are 0.0861+)

    %% ----------------------------------------------------------------
    %  Build GUI
    %% ----------------------------------------------------------------
    fig = uifigure('Name',     'Cross Sectional Area Analysis Dashboard', ...
                   'Position', [80 80 1020 580]);

    % --- Top bar -------------------------------------------------------
    uilabel(fig, ...
        'Text',       'Cross Sectional Area Analysis Dashboard', ...
        'Position',   [20 542 600 28], ...
        'FontSize',   16, ...
        'FontWeight', 'bold');

    uibutton(fig, 'push', ...
        'Text',            'Select Input File', ...
        'Position',        [20 502 155 32], ...
        'ButtonPushedFcn', @(~,~) cb_load());

    btn3D = uibutton(fig, 'push', ...
        'Text',            'Show 3D Model', ...
        'Position',        [185 502 145 32], ...
        'Enable',          'off', ...
        'ButtonPushedFcn', @(~,~) cb_show3D());

    btnSave = uibutton(fig, 'push', ...
        'Text',            'Save Area Data...', ...
        'Position',        [340 502 145 32], ...
        'Enable',          'off', ...
        'ButtonPushedFcn', @(~,~) cb_save());

    % --- Plot (left) ---------------------------------------------------
    ax = uiaxes(fig, 'Position', [20 90 590 395]);
    xlabel(ax, 'Y-position (mm)', 'FontWeight', 'bold');
    ylabel(ax, 'Area (mm2)',      'FontWeight', 'bold');
    title(ax,  'Load a file to begin...');
    grid(ax, 'on');

    % --- Stats strip ---------------------------------------------------
    statsLabel = uilabel(fig, ...
        'Text',     '', ...
        'Position', [20 58 590 28], ...
        'FontSize', 11);

    % --- Volume label --------------------------------------------------
    volLabel = uilabel(fig, ...
        'Text',       'Total Volume: -- mm3', ...
        'Position',   [20 18 590 32], ...
        'FontSize',   14, ...
        'FontWeight', 'bold', ...
        'FontColor',  [0 0.45 0.74]);

    % --- Data table (right) -------------------------------------------
    uit = uitable(fig, ...
        'Position',   [630 15 370 520], ...
        'ColumnName', {'Y (mm)', 'Area (mm2)'}, ...
        'RowName',    {});

    % --- Shared state (struct updated by cb_load) ----------------------
    appData.x        = [];
    appData.y        = [];
    appData.z        = [];
    appData.unique_y = [];
    appData.areas    = [];
    appData.Lintp    = [];
    appData.Aintp    = [];
    appData.filename = '';
    appData.fnm      = '';
    appData.ext      = '';
    appData.rpt_txt  = {};

    %% ================================================================
    %  CALLBACK: Load & analyse
    %% ================================================================
    function cb_load()
        [file, path] = uigetfile( ...
            {'*.txt;*.csv', 'Data files (*.txt, *.csv)'; ...
             '*.*',         'All files'}, ...
            'Select Washer Data File (x_mm, y_mm, thickness_mm)');
        if isequal(file, 0), return; end

        fname = fullfile(path, file);
        [~, fnm, ext] = fileparts(fname);

        try
            %% ---- Read CSV (skip header, comma-delimited) ----------------
           % Auto-detect delimiter (comma, tab, or space)
            data = readmatrix(fname, 'NumHeaderLines', 1, ...
                         'Delimiter', {',', '\t', ' '});

            if size(data, 2) < 3
                uialert(fig, ...
                    'File must have 3 columns: x_mm, y_mm, thickness_mm.', ...
                    'Format Error');
                return;
            end

            x_raw = data(:,1);
            y_raw = data(:,2);
            z_raw = data(:,3);

            % Drop NaN rows (trailing blank lines etc.)
            ok = ~isnan(x_raw) & ~isnan(y_raw) & ~isnan(z_raw);
            x_raw = x_raw(ok);
            y_raw = y_raw(ok);
            z_raw = z_raw(ok);

            %% ---- Threshold (noise floor) --------------------------------
            z_clean        = z_raw;
            z_clean(z_clean <= THRESHOLD) = 0;

            %% ---- Per-Y cross-sectional area via trapz -------------------
            unique_y = sort(unique(y_raw));
            areas    = zeros(length(unique_y), 1);

            for i = 1:length(unique_y)
                idx = (y_raw == unique_y(i));
                cx  = x_raw(idx);
                ct  = z_clean(idx);

                [cx, uIdx] = unique(cx);
                ct = ct(uIdx);
                [cx, sIdx] = sort(cx);      
                ct = ct(sIdx);

                if length(cx) > 1
                    areas(i) = trapz(cx, ct);
                end
            end

            %% ---- 1-D cubic interpolation --------------------------------
            Lintp = linspace(min(unique_y), max(unique_y), Nintp)';
            try
                Aintp = interp1(unique_y, areas, Lintp, 'cubic');
            catch
                Aintp = interp1(unique_y, areas, Lintp, 'linear');
            end

            %% ---- Volume -------------------------------------------------
            total_volume = trapz(unique_y, areas);

            %% ---- Save state --------------------------------------------
            appData.x        = x_raw;
            appData.y        = y_raw;
            appData.z        = z_clean;
            appData.unique_y = unique_y;
            appData.areas    = areas;
            appData.Lintp    = Lintp;
            appData.Aintp    = Aintp;
            appData.filename = fname;
            appData.fnm      = fnm;
            appData.ext      = ext;
            appData.rpt_txt  = build_report(unique_y, areas, Lintp, Aintp);

            %% ---- Update plot -------------------------------------------
            cla(ax);
            hold(ax, 'on');
            bar(ax, unique_y, areas, ...
                'FaceColor',  [0.18 0.55 0.80], ...
                'EdgeColor',  'none', ...
                'DisplayName', 'Per-Y CSA');
            valid_i = ~isnan(Aintp);
            plot(ax, Lintp(valid_i), Aintp(valid_i), 'r-', ...
                 'LineWidth',   2, ...
                 'DisplayName', '1D-Interpolated');
            hold(ax, 'off');
            legend(ax, 'Location', 'northwest');
            xlabel(ax, 'Y-position (mm)', 'FontWeight', 'bold', 'FontSize', 11);
            ylabel(ax, 'Area (mm2)',       'FontWeight', 'bold', 'FontSize', 11);
            title(ax, sprintf('Area vs Length  -  %s%s', fnm, ext), ...
                  'Interpreter', 'none', 'FontSize', 12, 'FontWeight', 'bold');
            grid(ax, 'on');

            %% ---- Update table ------------------------------------------
            mask = areas > 0;
            if any(mask)
                uit.ColumnName = {'Y (mm)', 'Area (mm2)'};
                uit.Data       = [unique_y(mask), areas(mask)];
            else
                uit.ColumnName = {'Y (mm)', 'Area (mm2)'};
                uit.Data       = [unique_y, areas];
            end

            %% ---- Update text labels ------------------------------------
            if any(valid_i)
                % Yses only the actual data points shown in the table
                mask = areas > 0;
                statsLabel.Text = sprintf( ...
                    'Mean area: %.4f mm2', ...
                    mean(areas(mask)));
            end
volLabel.Text = sprintf('Total Volume: %.4f mm3', total_volume);

            btn3D.Enable   = 'on';
            btnSave.Enable = 'on';

        catch ME
            uialert(fig, ['Error: ' ME.message], 'Analysis Error');
        end
    end  % cb_load


    %% ================================================================
    %  CALLBACK: Show 3D surface (separate figure)
    %% ================================================================
    function cb_show3D()
        if isempty(appData.x)
            uialert(fig, 'Load a file first.', 'No Data');
            return;
        end
        show_3d_surface(appData.x, appData.y, appData.z, ...
                        appData.unique_y, appData.areas, ...
                        [appData.fnm, appData.ext]);
    end


    %% ================================================================
    %  CALLBACK: Save area report
    %% ================================================================
    function cb_save()
        if isempty(appData.rpt_txt), return; end
        default_save = regexprep(appData.filename, '\.(txt|csv)$', '_area.txt');
        [file, path] = uiputfile('*_area.txt', 'Save Area Data As...', ...
                                  default_save);
        if isequal(file, 0), return; end
        write_report(appData.rpt_txt, fullfile(path, file));
        uialert(fig, ['Saved: ' fullfile(path, file)], ...
                'Save Complete', 'Icon', 'success');
    end

end  % washer_dashboard_gui


%% ====================================================================
%  3D SURFACE FIGURE  (standalone, outside dashboard)
%% ====================================================================
function show_3d_surface(x, y, z, ~, ~, ~)
    Nintp     = 120;
    THRESHOLD = 0;  % same noise floor used in cb_load

    x_rng = linspace(min(x), max(x), Nintp);
    y_rng = linspace(min(y), max(y), Nintp);
    [Xg, Yg] = meshgrid(x_rng, y_rng);

    Zg = griddata(x, y, z, Xg, Yg, 'natural');
    Zg(Zg < 0) = 0;
    % Values at or below the threshold become NaN so surf skips them entirely,
    % producing a clean surface with no flat zero-plane fill.
    Zg(Zg <= THRESHOLD) = NaN;

    Zmx = max(Zg(:), [], 'omitnan');   % ignore NaN holes

    hfig = findobj('Tag', 'washer-3d-fig');
    if isempty(hfig)
        hfig = figure('Tag', 'washer-3d-fig', 'Name', '3D Thickness Surface', ...
                      'NumberTitle', 'off', 'Position', [130 100 860 600]);
    else
        figure(hfig); clf(hfig);
    end

    ax3 = axes(hfig);
    hs = surf(ax3, Xg, Yg, Zg);
    set(hs, 'EdgeColor', 'none', 'FaceColor', 'interp');
    colormap(ax3, jet);

    % COLORBAR REMOVED

    if Zmx > 0
        clim(ax3, [0, Zmx]); % Note: caxis is deprecated in newer MATLAB, clim is preferred
        zlim(ax3, [0, Zmx * 1.1]);
    end

    shading(ax3,  'interp');
    lighting(ax3, 'gouraud');
    camlight(ax3, 'headlight');
    axis(ax3, 'tight');
    view(ax3, -40, 30);

    xlabel(ax3, 'X (mm)',         'FontWeight', 'bold');
    ylabel(ax3, 'Y (mm)',         'FontWeight', 'bold');
    zlabel(ax3, 'Thickness (mm)', 'FontWeight', 'bold');
    
    % UPDATED TITLE
    title(ax3, 'Reconstructed 3D Model', 'FontSize', 13, 'FontWeight', 'bold');

    % WHITE LINE OVERLAY REMOVED

    drawnow;
end


%% ====================================================================
%  UTILITIES
%% ====================================================================

function rpt = build_report(unique_y, areas, ~, ~)
%BUILD_REPORT  Builds report containing only the displayed table data.
    % Filter for non-zero areas to match the table display logic
    mask = areas > 0;
    y_data = unique_y(mask);
    a_data = areas(mask);
    
    n_meas = length(y_data);
    rpt    = cell(n_meas + 2, 1);
    r = 1;

    rpt{r} = '% Y-position(mm)  Area(mm2)'; r = r+1;
    for i = 1:n_meas
        rpt{r} = sprintf('%.4f\t%.6f', y_data(i), a_data(i));
        r = r+1;
    end

    rpt = rpt(1:r-1);
end


function write_report(txt_cell, filepath)
%WRITE_REPORT  Write cell array of strings to a text file.
    fid = fopen(filepath, 'w');
    if fid == -1
        error('Cannot open file for writing: %s', filepath);
    end
    for i = 1:numel(txt_cell)
        fprintf(fid, '%s\n', txt_cell{i});
    end
    fclose(fid);
end