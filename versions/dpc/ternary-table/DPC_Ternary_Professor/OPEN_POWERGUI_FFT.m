dpc3_root = fileparts(mfilename('fullpath'));
dpc3_files = dir(fullfile(dpc3_root,'results','*','powergui_current.mat'));
assert(~isempty(dpc3_files),'Run START_DPC_TERNARY first.');
for dpc3_k = 1:numel(dpc3_files)
    dpc3_loaded = load(fullfile(dpc3_files(dpc3_k).folder,dpc3_files(dpc3_k).name));
    [~,dpc3_name] = fileparts(dpc3_files(dpc3_k).folder);
    dpc3_name = matlab.lang.makeValidName(['FFT_' dpc3_name]);
    assignin('base',dpc3_name,dpc3_loaded.fft_current);dpc3_c = dpc3_loaded.cfg;
    fprintf('%s: f1=%g Hz; start=%g s; cycles=%d; THD max=%g Hz; select phase 1.\n', ...
        dpc3_name,dpc3_c.line_frequency,dpc3_c.fft_start,dpc3_c.fft_cycles,dpc3_c.max_harmonic*dpc3_c.line_frequency);
end
if exist('power_fftscope','file'),power_fftscope;end
