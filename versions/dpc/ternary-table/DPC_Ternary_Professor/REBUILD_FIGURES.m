dpc3_root = fileparts(mfilename('fullpath'));addpath(fullfile(dpc3_root,'matlab'));
dpc3_saved = load(fullfile(dpc3_root,'results','all_closed_loop_results.mat'),'results');
for dpc3_k = 1:size(dpc3_saved.results,1)
    if isempty(dpc3_saved.results{dpc3_k,1}) || isempty(dpc3_saved.results{dpc3_k,2})
        fprintf('Skipping incomplete frequency pair %d.\n',dpc3_k);continue;
    end
    quality_plot_pair(dpc3_saved.results{dpc3_k,1},dpc3_saved.results{dpc3_k,2},fullfile(dpc3_root,'SEND_TO_PROFESSOR'));
end
if all(~cellfun(@isempty,dpc3_saved.results(:)))
    quality_export_summary(dpc3_saved.results,fullfile(dpc3_root,'SEND_TO_PROFESSOR'));
end
