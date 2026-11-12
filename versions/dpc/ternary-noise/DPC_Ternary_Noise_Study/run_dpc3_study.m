function results = run_dpc3_study(cfg,parameter_note)
root = fileparts(mfilename('fullpath'));addpath(root,fullfile(root,'matlab'));
if nargin < 1,cfg = dpc3_config();end
if nargin < 2,parameter_note = 'e supplied explicitly in dpc3_config';end
dpc3_validate_config(cfg);results = cell(numel(cfg.control_frequencies_hz),2);
for k = 1:numel(cfg.control_frequencies_hz)
    fs = cfg.control_frequencies_hz(k);
    [raw,info,folder] = dpc3_run_native('conventional',fs,cfg);
    baseline = raw;
    result = quality_analyze_run(raw,cfg,info,parameter_note);
    quality_export_run(result,folder);results{k,1} = result;
    [limit,~,~] = dpc3_run_native('binary_limit',fs,cfg);
    proof = dpc3_verify_binary_limit(baseline,limit,cfg,fs);
    clear baseline limit raw;
    [raw,info,folder] = dpc3_run_native('proposed',fs,cfg);
    result = quality_analyze_run(raw,cfg,info,parameter_note);
    result.binary_limit_report = proof;
    n = round(cfg.stop_time*fs)+1;
    audit = dpc3_log_samples(raw.audit,1/fs,n,21,'full converter audit');
    result.ternary_audit_columns = {'sp','sq','sector','row','vector_id','P','Q','dP_pred', ...
        'dQ_pred','J','J_original','guard','row1','row2','row3','row4','row5','row6','row7','row8','row9'};
    result.ternary_audit = audit;
    result.zero_fraction_p = mean(audit(:,1) == 0);result.zero_fraction_q = mean(audit(:,2) == 0);
    result.guard_fraction = mean(audit(:,12));
    quality_export_run(result,folder);results{k,2} = result;
    save(fullfile(root,'results','all_closed_loop_results.mat'),'results','cfg','-v7');
    quality_plot_pair(results{k,1},results{k,2},fullfile(root,'SEND_TO_PROFESSOR'));
    fprintf('Completed %g kHz: THD phase-a conventional %.4g%% / proposed %.4g%%.\n', ...
        fs/1000,results{k,1}.fft{1}.thd_percent,results{k,2}.fft{1}.thd_percent);
    clear raw;
end
quality_export_summary(results,fullfile(root,'SEND_TO_PROFESSOR'));
fprintf('\nDONE. Genuine converter figures: %s\n',fullfile(root,'SEND_TO_PROFESSOR'));
end
