function quality_export_run(result, folder)
save(fullfile(folder, 'analyzed_result.mat'), 'result', '-v7');
% Classic powergui FFT accepts a structure with time. No timeseries conversion needed.
fft_current.time = result.time;
fft_current.signals.values = result.signals.iabc;
fft_current.signals.dimensions = 3;
cfg = result.cfg;
save(fullfile(folder, 'powergui_current.mat'), 'fft_current', 'cfg', '-v7');
rows = result.fft{1}.orders;
for phase = 1:3
    rows = [rows, result.fft{phase}.harmonic_rms]; %#ok<AGROW>
end
file = fopen(fullfile(folder, 'harmonic_rms_A.csv'), 'w');
assert(file >= 0); close_file = onCleanup(@() fclose(file));
fprintf(file, 'harmonic_order,phase_a_A_rms,phase_b_A_rms,phase_c_A_rms\n');
fprintf(file, '%d,%.12g,%.12g,%.12g\n', rows');
end
