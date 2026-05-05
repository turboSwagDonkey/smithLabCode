function plotPmtDataB1(mainPath, varargin)
% Enhanced SBX analysis with individual background subtraction
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
addParameter(p, 'GainRange', [50, 75], @isnumeric);
addParameter(p, 'FigureTitle', '', @ischar);
addParameter(p, 'CullZeros', true, @islogical);
parse(p, mainPath, varargin{:});
opt = p.Results; % Simplify struct access

bgPath = fullfile(mainPath, 'background');
sigPath = fullfile(mainPath, 'signal');
if ~exist(bgPath, 'dir'), error('Background dir missing: %s', bgPath); end
if ~exist(sigPath, 'dir'), error('Signal dir missing: %s', sigPath); end

% Initialize storage
gainVals = opt.GainRange(1):opt.GainRange(2);
nVals = length(gainVals);
[allData, meanVals, stdVals, stdMeanRatios, pairsProcessed] = deal(cell(nVals, 1));
valid = false(nVals, 1);

% Process gains
for i = 1:nVals
    gain = gainVals(i);
    bgFiles = dir(fullfile(bgPath, sprintf('background_gain_%03d*.sbx', gain)));
    sigFiles = dir(fullfile(sigPath, sprintf('signal_gain_%03d*.sbx', gain)));
    if isempty(bgFiles) || isempty(sigFiles), continue; end
    
    % Map signal files for fast lookup
    sigMap = containers.Map();
    for k = 1:length(sigFiles)
        [~, name, ~] = fileparts(sigFiles(k).name);
        sigMap(name) = fullfile(sigPath, sigFiles(k).name);
    end
    
    tempData = cell(length(bgFiles), 1);
    pairCount = 0;
    
    % Process files
    for j = 1:length(bgFiles)
        [~, bgBase, ~] = fileparts(bgFiles(j).name);
        sigName = strrep(bgBase, 'background_', 'signal_');
        if ~isKey(sigMap, sigName), continue; end
        
        try
            % Read and average frames to save memory
            [bgRaw, ~] = readSbxFile(fullfile(bgPath, bgFiles(j).name), opt.FrameRange);
            bgMean = mean(double(bgRaw), 3); clear bgRaw;
            
            [sigRaw, ~] = readSbxFile(sigMap(sigName), opt.FrameRange);
            sigMean = mean(double(sigRaw), 3); clear sigRaw;
            
            corr = -(sigMean - bgMean);
            corr = corr(:);
            if opt.CullZeros, corr = corr(corr ~= 0); end
            
            tempData{j} = corr;
            pairCount = pairCount + 1;
        catch
            continue;
        end
    end
    
    tempData = tempData(~cellfun('isempty', tempData));
    gainData = vertcat(tempData{:});
    
    % Subsample and store valid data
    if pairCount > 0 && ~isempty(gainData)
        if opt.SamplingRate < 1.0
            idx = randperm(length(gainData), round(length(gainData) * opt.SamplingRate));
            gainData = gainData(idx);
        end
        if opt.CullZeros, gainData = gainData(gainData ~= 0); end
        
        allData{i} = gainData;
        meanVals{i} = mean(gainData);
        stdVals{i} = std(gainData);
        stdMeanRatios{i} = stdVals{i} / abs(meanVals{i});
        pairsProcessed{i} = pairCount;
        valid(i) = true;
    end
end

if ~any(valid), error('No valid data processed.'); end

% Filter empty entries
validGains = gainVals(valid)';
validData = allData(valid);
vMean = cell2mat(meanVals(valid));
vStd = cell2mat(stdVals(valid));
vRatio = cell2mat(stdMeanRatios(valid));
vPairs = cell2mat(pairsProcessed(valid));
nValid = length(validGains);

% Print summary
fprintf('=== FINAL SUMMARY ===\n');
for i = 1:nValid
    fprintf('Gain %d: %d pairs, Mean=%.1f, Std=%.1f, Min=%.1f, Max=%.1f\n', ...
        validGains(i), vPairs(i), vMean(i), vStd(i), min(validData{i}), max(validData{i}));
end
fprintf('===================\n\n');

colors = getColors(opt.ColorScheme, nValid);
baseTitle = opt.FigureTitle;
if isempty(baseTitle), baseTitle = sprintf('Corrected SBX\n%s', strrep(mainPath, '\', '/')); end

% Fig 1: Histograms
figure('Name', 'Histograms', 'Position', [50, 50, 1000, 800]); hold on;
legEntries = cell(nValid, 1);
for i = 1:nValid
    legEntries{i} = sprintf('Gain %d (%d pairs)', validGains(i), vPairs(i));
    histogram(validData{i}, 100, 'EdgeColor', 'none', 'FaceColor', colors(i, :), ...
        'FaceAlpha', opt.Alpha, 'DisplayName', legEntries{i});
    
    if opt.ShowMode
        md = mode(round(validData{i}));
        yL = ylim;
        line([md, md], [1, yL(2)], 'Color', colors(i, :), 'LineWidth', opt.LineWidth, ...
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
plot(validGains, vMean, 'o-', 'LineWidth', 2, 'MarkerSize', 8, 'Color', [0.2, 0.4, 0.8], 'MarkerFaceColor', [0.2, 0.4, 0.8]);
formatAx('Gain', 'Mean Intensity', 'Mean vs Gain', opt.FontSize);

subplot(2, 2, 2);
plot(validGains, vStd, 's-', 'LineWidth', 2, 'MarkerSize', 8, 'Color', [0.8, 0.2, 0.2], 'MarkerFaceColor', [0.8, 0.2, 0.2]);
formatAx('Gain', 'Standard Deviation', 'Std vs Gain', opt.FontSize);

subplot(2, 2, 3);
plot(validGains, vMean ./ vStd, '^-', 'LineWidth', 2, 'MarkerSize', 8, 'Color', [0.2, 0.8, 0.2], 'MarkerFaceColor', [0.2, 0.8, 0.2]);
formatAx('Gain', 'Mean/Std Ratio', 'Mean/Std vs Gain', opt.FontSize);

subplot(2, 2, 4);
bar(validGains, vPairs, 'FaceColor', [0.6, 0.4, 0.8], 'EdgeColor', 'k');
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

function [data, info] = readSbxFile(filename, frameRange)
    [filepath, name, ~] = fileparts(filename);
    infoFile = fullfile(filepath, [name '.mat']);
    info = struct();
    if exist(infoFile, 'file')
        tmp = load(infoFile);
        if isfield(tmp, 'info'), info = tmp.info; end
    end

    % 1: sbxread
    if exist('sbxread', 'file')
        try
            if isempty(frameRange)
                N = 1000; if isfield(info, 'max_idx'), N = info.max_idx + 1; end
                data = sbxread(filename, 0, N);
            else
                data = sbxread(filename, frameRange(1), frameRange(2) - frameRange(1) + 1);
            end
            return;
        catch, end
    end

    % 2: Binary
    try
        fid = fopen(filename, 'rb');
        fseek(fid, 0, 'eof'); fileSize = ftell(fid); fseek(fid, 0, 'bof');
        
        h = 512; w = 512;
        if isfield(info, 'sz'), h = info.sz(1); w = info.sz(2); end
        
        totFrames = floor(fileSize / (h * w * 2));
        startF = 1; endF = totFrames;
        if ~isempty(frameRange), startF = max(1, frameRange(1)); endF = min(totFrames, frameRange(2)); end
        
        nRead = endF - startF + 1;
        if startF > 1, fseek(fid, (startF-1) * h * w * 2, 'bof'); end
        
        data = reshape(fread(fid, [h * w, nRead], 'uint16'), h, w, nRead);
        fclose(fid);
        
        if ~isfield(info, 'sz'), info.sz = [h, w]; end
        info.totalFrames = totFrames;
        return;
    catch
        if exist('fid', 'var') && fid ~= -1, fclose(fid); end
    end

    % 3: Tiff
    try
        tInfo = imfinfo(filename);
        totFrames = length(tInfo);
        startF = 1; endF = totFrames;
        if ~isempty(frameRange), startF = max(1, frameRange(1)); endF = min(totFrames, frameRange(2)); end
        
        nRead = endF - startF + 1;
        f1 = imread(filename, startF);
        [h, w, c] = size(f1);
        data = zeros(h, w, c, nRead, class(f1));
        
        for i = 1:nRead
            idx = startF + i - 1;
            if c == 1, data(:,:,i) = imread(filename, idx); else, data(:,:,:,i) = imread(filename, idx); end
        end
        info.sz = [h, w];
        info.totalFrames = totFrames;
    catch
        error('Could not read SBX file: %s', filename);
    end
end
