function plotPmtDataB3(mainPath, varargin)
% PMT analysis for TIFF files with voltage-based names from Bay3
% Expected structure: mainPath/background/ and mainPath/signal/

% Parse inputs
p = inputParser;
addRequired(p, 'mainPath', @ischar);
addParameter(p, 'ColorScheme', 'viridis', @ischar);
addParameter(p, 'Alpha', 0.3, @isnumeric);
addParameter(p, 'LineWidth', 1.5, @isnumeric);
addParameter(p, 'FontSize', 12, @isnumeric);
addParameter(p, 'ShowMode', false, @islogical);
addParameter(p, 'FrameRange', [], @isnumeric);
addParameter(p, 'SamplingRate', 1.0, @isnumeric);
addParameter(p, 'GainRange', [], @isnumeric);
addParameter(p, 'FigureTitle', '', @ischar);
addParameter(p, 'CullZeros', true, @islogical);
parse(p, mainPath, varargin{:});
opt = p.Results; % Simplify struct access

bgPath = fullfile(mainPath, 'background');
sigPath = fullfile(mainPath, 'signal');
if ~exist(bgPath, 'dir'), error('Background dir missing: %s', bgPath); end
if ~exist(sigPath, 'dir'), error('Signal dir missing: %s', sigPath); end

% Locate files
bgFiles = dir(fullfile(bgPath, '*.tif'));
bgFiles = bgFiles(~[bgFiles.isdir]);
results = struct('gain', {}, 'mean', {}, 'std', {}, 'data', {});

% Process pairs
for i = 1:length(bgFiles)
    bgFile = bgFiles(i).name;
    gainVal = sscanf(bgFile, '%f');
    
    if isempty(gainVal), continue; end
    if ~isempty(opt.GainRange) && (gainVal < opt.GainRange(1) || gainVal > opt.GainRange(2)), continue; end
    
    sigFile = fullfile(sigPath, bgFile);
    if ~exist(sigFile, 'file'), continue; end
    
    try
        % Read, average, and calculate offsets
        bgMean = mean(double(readTifFile(fullfile(bgPath, bgFile), opt.FrameRange)), 3);
        sigMean = mean(double(readTifFile(sigFile, opt.FrameRange)), 3);
        if ~isequal(size(sigMean), size(bgMean)), continue; end
        
        corrData = (sigMean - getOffset(sigMean)) - (bgMean - getOffset(bgMean));
        corrVals = corrData(:);
        
        % Subsample & Cull
        if opt.CullZeros, corrVals = corrVals(corrVals ~= 0); end
        if opt.SamplingRate < 1.0
            idx = randperm(length(corrVals), round(length(corrVals) * opt.SamplingRate));
            corrVals = corrVals(idx);
        end
        
        results(end+1) = struct('gain', gainVal, 'mean', mean(corrVals), ...
                                'std', std(corrVals), 'data', {corrVals});
    catch
        continue;
    end
end

if isempty(results), error('No valid data pairs found.'); end

% Sort and extract data
[~, sortIdx] = sort([results.gain]);
results = results(sortIdx);
gains = [results.gain];
vMean = [results.mean];
vStd = [results.std];
vData = {results.data};
nValid = length(gains);

% Print summary
fprintf('=== FINAL SUMMARY ===\n');
for i = 1:nValid
    fprintf('Gain %g: Mean=%.1f, Std=%.1f, Min=%.1f, Max=%.1f\n', ...
        gains(i), vMean(i), vStd(i), min(vData{i}), max(vData{i}));
end
fprintf('===================\n\n');

colors = getColors(opt.ColorScheme, nValid);
baseTitle = opt.FigureTitle;
if isempty(baseTitle), baseTitle = sprintf('Corrected TIFF Analysis\n%s', strrep(mainPath, '\', '/')); end

% Fig 1: Histograms
figure('Name', 'Histograms', 'Position', [50, 50, 1000, 800]); hold on;
legEntries = cell(nValid, 1);
for i = 1:nValid
    legEntries{i} = sprintf('Gain %g (1 pair)', gains(i));
    histogram(vData{i}, 100, 'EdgeColor', 'none', 'FaceColor', colors(i, :), ...
        'FaceAlpha', opt.Alpha, 'DisplayName', legEntries{i});
    
    if opt.ShowMode
        md = mode(round(vData{i}));
        yL = ylim; line([md, md], [1, yL(2)], 'Color', colors(i, :), 'LineWidth', opt.LineWidth, ...
            'LineStyle', '--', 'HandleVisibility', 'off');
    end
end
set(gca, 'YScale', 'log');
legend(legEntries, 'Location', 'best', 'FontSize', opt.FontSize-1);
formatAx('Pixel Intensity', 'Frequency', 'Histograms by Gain', opt.FontSize);
sgtitle([baseTitle ' - Histograms'], 'FontSize', opt.FontSize+2, 'FontWeight', 'bold');
hold off;

% Fig 2: Gain Analysis
figure('Name', 'Analysis Plots', 'Position', [100, 100, 1200, 800]);

subplot(2, 2, 1);
plot(gains, vMean, 'o-', 'LineWidth', 2, 'MarkerSize', 8, 'Color', [0.2, 0.4, 0.8], 'MarkerFaceColor', [0.2, 0.4, 0.8]);
formatAx('Gain', 'Mean Intensity', 'Mean vs Gain', opt.FontSize);

subplot(2, 2, 2);
plot(gains, vStd, 's-', 'LineWidth', 2, 'MarkerSize', 8, 'Color', [0.8, 0.2, 0.2], 'MarkerFaceColor', [0.8, 0.2, 0.2]);
formatAx('Gain', 'Standard Deviation', 'Std vs Gain', opt.FontSize);

subplot(2, 2, 3);
plot(gains, vMean ./ vStd, '^-', 'LineWidth', 2, 'MarkerSize', 8, 'Color', [0.2, 0.8, 0.2], 'MarkerFaceColor', [0.2, 0.8, 0.2]);
formatAx('Gain', 'Mean/Std Ratio', 'Mean/Std vs Gain', opt.FontSize);

subplot(2, 2, 4);
bar(gains, ones(1, nValid), 'FaceColor', [0.6, 0.4, 0.8], 'EdgeColor', 'k');
formatAx('Gain', 'Processed Pairs', 'Pairs vs Gain', opt.FontSize);

sgtitle([baseTitle ' - Gain Analysis'], 'FontSize', opt.FontSize+2, 'FontWeight', 'bold');
end

% --- Helper Functions ---

function formatAx(xLbl, yLbl, tLbl, fs)
    xlabel(xLbl, 'FontSize', fs, 'FontWeight', 'bold');
    ylabel(yLbl, 'FontSize', fs, 'FontWeight', 'bold');
    title(tLbl, 'FontSize', fs+1, 'FontWeight', 'bold');
    grid on; set(gca, 'FontSize', fs);
end

function colors = getColors(scheme, n)
    switch lower(scheme)
        case 'default', colors = lines(n);
        case 'viridis', x = linspace(0, 1, n)'; colors = max(0, min(1, [0.267*x.^0.5, 0.005 + 0.5*x.^1.5, 0.33 + 0.67*x]));
        case 'plasma',  x = linspace(0, 1, n)'; colors = max(0, min(1, [0.8*x.^0.8, 0.1 + 0.4*x.^2, 0.9 - 0.6*x.^0.7]));
        case 'turbo',   colors = turbo(n);
        case 'rainbow', colors = hsv(n);
        case 'cool',    colors = cool(n);
        case 'hot',     colors = hot(n);
        otherwise,      colors = parula(n);
    end
end

function data = readTifFile(fname, fRange)
    info = imfinfo(fname);
    nF = numel(info);
    sF = 1; eF = nF;
    if ~isempty(fRange), sF = max(1, fRange(1)); eF = min(nF, fRange(2)); end
    
    nRead = eF - sF + 1;
    if nRead <= 0, data = []; return; end
    
    f1 = imread(fname, sF);
    data = zeros(size(f1, 1), size(f1, 2), nRead, class(f1));
    data(:,:,1) = f1;
    for i = 2:nRead
        data(:,:,i) = imread(fname, sF + i - 1, 'Info', info);
    end
end

function off = getOffset(img)
    p = sort(img(:));
    off = mean(p(1:max(1, ceil(numel(p) * 0.01))));
end