% Recreate figures from completed native runs without rerunning the converter.
quality_root = fileparts(mfilename('fullpath'));
addpath(fullfile(quality_root,'matlab'));
quality_cfg = quality_config();
quality_methods = {'conventional','proposed'};
quality_results = cell(numel(quality_cfg.control_frequencies_hz),2);
for quality_frequency = 1:numel(quality_cfg.control_frequencies_hz)
    for quality_method = 1:2
        quality_folder = fullfile(quality_root,'results',sprintf('%gk_%s', ...
            quality_cfg.control_frequencies_hz(quality_frequency)/1000,quality_methods{quality_method}));
        quality_data = load(fullfile(quality_folder,'analyzed_result.mat'),'result');
        quality_results{quality_frequency,quality_method} = quality_data.result;
    end
    quality_plot_pair(quality_results{quality_frequency,1},quality_results{quality_frequency,2}, ...
        fullfile(quality_root,'SEND_TO_PROFESSOR'));
end
quality_export_summary(quality_results,fullfile(quality_root,'SEND_TO_PROFESSOR'));
