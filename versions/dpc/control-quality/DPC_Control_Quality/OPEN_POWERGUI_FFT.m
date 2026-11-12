% Optional independent visual check in the classic powergui FFT Analysis tool.
quality_root = fileparts(mfilename('fullpath'));
quality_files = dir(fullfile(quality_root, 'results', '*', 'powergui_current.mat'));
assert(~isempty(quality_files), 'Run START_CONTROL_QUALITY first.');
for quality_k = 1:numel(quality_files)
    quality_loaded = load(fullfile(quality_files(quality_k).folder, quality_files(quality_k).name));
    [~, quality_name] = fileparts(quality_files(quality_k).folder);
    quality_name = matlab.lang.makeValidName(['FFT_' quality_name]);
    assignin('base', quality_name, quality_loaded.fft_current);
    quality_fft_cfg = quality_loaded.cfg;
    fprintf('Loaded %s: phase 1; f1=%g Hz; start=%g s; %d cycles; THD max=%g Hz.\n', ...
        quality_name,quality_fft_cfg.line_frequency,quality_fft_cfg.fft_start, ...
        quality_fft_cfg.fft_cycles,quality_fft_cfg.max_harmonic*quality_fft_cfg.line_frequency);
end
if exist('power_fftscope', 'file')
    power_fftscope;
else
    fprintf('Open the generated model, double-click powergui, then FFT Analysis.\n');
end
