function manifest = run_dpc3_noise_study(cfg,parameter_note)
root = fileparts(mfilename('fullpath')); addpath(root,fullfile(root,'matlab'));
if nargin < 1, cfg = dpc3_noise_config(); end
if nargin < 2, parameter_note = 'parameters supplied in configuration'; end
dpc3_validate_noise_config(cfg); manifest = {};
total = numel(cfg.study_cases)*numel(cfg.control_frequencies_hz)*numel(cfg.noise_seeds);
fprintf('\n%d matched comparisons, up to %d converter runs. Normal case runs first.\n',total,3*total);
for ci = 1:numel(cfg.study_cases)
    s = cfg.study_cases(ci);
    for seed = cfg.noise_seeds(:)'
        case_folder = fullfile(root,'results',sprintf('%s_seed%u',s.id,seed));
        if ~exist(case_folder,'dir'),mkdir(case_folder);end
        stimulus = dpc3_make_stimulus(cfg,s,seed);
        save(fullfile(case_folder,'shared_stimulus.mat'),'stimulus','cfg','-v7');
        for fs = cfg.control_frequencies_hz(:)'
            key = sprintf('%s_seed%u_%gk',s.id,seed,fs/1000);
            checkpoint = fullfile(case_folder,sprintf('pair_%gk.mat',fs/1000));
            figure_folder = fullfile(root,'SEND_TO_PROFESSOR',sprintf('%s_seed%u',s.id,seed));
            cfg_key = cfg; cfg_key.resume_completed = false; cfg_key.plot_visible = 'off';
            if cfg.resume_completed && exist(checkpoint,'file')
                saved = load(checkpoint,'entry');
                expected_file = fullfile(case_folder,sprintf('%gk_conventional',fs/1000),'analyzed_result.mat');
                if isequaln(saved.entry.cfg_key,cfg_key) && saved.entry.binary_limit_report.passed && ...
                        strcmp(saved.entry.conventional.result_file,expected_file) && ...
                        exist(saved.entry.conventional.result_file,'file') && exist(saved.entry.proposed.result_file,'file')
                    fprintf('Reusing verified completed pair: %s\n',key);
                    figure_file = fullfile(figure_folder,sprintf('%gk_feedback_and_dc.png',fs/1000));
                    if ~exist(figure_file,'file')
                        a = load(saved.entry.conventional.result_file,'result');
                        b = load(saved.entry.proposed.result_file,'result');
                        quality_plot_pair(a.result,b.result,figure_folder);
                        dpc3_noise_plot_feedback(a.result,b.result,figure_folder);
                        clear a b;
                    end
                    manifest{end+1} = saved.entry; %#ok<AGROW>
                    dpc3_noise_export_summary(manifest,fullfile(root,'SEND_TO_PROFESSOR'));
                    save(fullfile(root,'results','noise_study_manifest.mat'),'manifest','cfg','-v7');
                    continue;
                end
            end
            fprintf('\nComparison %d/%d: %s\n',numel(manifest)+1,total,key);
            [baseline,base_info,base_folder] = dpc3_noise_run_native('conventional',fs,cfg,s,stimulus,case_folder);
            conventional = dpc3_noise_analyze(baseline,cfg,base_info,parameter_note);
            quality_export_run(conventional,base_folder);
            [limit,~,~] = dpc3_noise_run_native('binary_limit',fs,cfg,s,stimulus,case_folder);
            proof = dpc3_verify_binary_limit(baseline,limit,cfg,fs,case_folder);
            clear baseline limit;
            [raw,info,folder] = dpc3_noise_run_native('proposed',fs,cfg,s,stimulus,case_folder);
            proposed = dpc3_noise_analyze(raw,cfg,info,parameter_note);
            proposed.binary_limit_report = proof;
            quality_export_run(proposed,folder); clear raw;
            quality_plot_pair(conventional,proposed,figure_folder);
            dpc3_noise_plot_feedback(conventional,proposed,figure_folder);
            entry = struct('key',key,'case_id',s.id,'label',s.label,'seed',seed,'control_hz',fs, ...
                'cfg_key',cfg_key,'binary_limit_report',proof,'parameter_note',parameter_note, ...
                'conventional',compact(conventional,base_folder),'proposed',compact(proposed,folder));
            save(checkpoint,'entry','-v7');
            manifest{end+1} = entry; %#ok<AGROW>
            save(fullfile(root,'results','noise_study_manifest.mat'),'manifest','cfg','-v7');
            dpc3_noise_export_summary(manifest,fullfile(root,'SEND_TO_PROFESSOR'));
            fprintf('%s | THD %.4g / %.4g %% | true P ripple RMS %.4g / %.4g W\n', ...
                key,conventional.fft{1}.thd_percent,proposed.fft{1}.thd_percent, ...
                conventional.metrics.p.ripple_rms,proposed.metrics.p.ripple_rms);
            clear conventional proposed;
        end
    end
end
save(fullfile(root,'results','noise_study_manifest.mat'),'manifest','cfg','-v7');
fprintf('\nDONE: %s\n',fullfile(root,'SEND_TO_PROFESSOR'));
end
function r = compact(result,folder)
r = rmfield(result,{'time','signals','fft_indices'});
r.result_file = fullfile(folder,'analyzed_result.mat');
end
