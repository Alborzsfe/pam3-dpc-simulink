dpc3_root = fileparts(mfilename('fullpath'));addpath(fullfile(dpc3_root,'matlab'));
dpc3_saved = load(fullfile(dpc3_root,'results','noise_study_manifest.mat'),'manifest');
for dpc3_k = 1:numel(dpc3_saved.manifest)
    dpc3_entry = dpc3_saved.manifest{dpc3_k};
    dpc3_a = load(dpc3_entry.conventional.result_file,'result');
    dpc3_b = load(dpc3_entry.proposed.result_file,'result');
    dpc3_dest = fullfile(dpc3_root,'SEND_TO_PROFESSOR',sprintf('%s_seed%u',dpc3_entry.case_id,dpc3_entry.seed));
    quality_plot_pair(dpc3_a.result,dpc3_b.result,dpc3_dest);
    dpc3_noise_plot_feedback(dpc3_a.result,dpc3_b.result,dpc3_dest);
end
dpc3_noise_export_summary(dpc3_saved.manifest,fullfile(dpc3_root,'SEND_TO_PROFESSOR'));
