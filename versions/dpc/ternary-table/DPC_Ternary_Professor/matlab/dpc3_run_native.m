function [raw,info,folder] = dpc3_run_native(method,fs,cfg)
root = fileparts(fileparts(mfilename('fullpath')));
[model,info] = build_dpc3_model(method,fs,cfg);
folder = fullfile(root,'results',sprintf('%gk_%s',fs/1000,method));
if ~exist(folder,'dir'),mkdir(folder);end
fprintf('\nRunning actual converter: %s, control Fs=%g kHz, stop=%g s.\n',method,fs/1000,cfg.stop_time);
timer = tic;out = sim(model,'ReturnWorkspaceOutputs','on','SimulationMode','normal');
names = {'iabc','vabc','vdc','p','pref','q','qref','gates','binary_dp','binary_dq','sector'};
if ~strcmp(method,'conventional'),names{end+1} = 'audit';end
raw = struct();for k = 1:numel(names),raw.(names{k}) = out.get(['dpc3_log_' names{k}]);end
info.elapsed_s = toc(timer);info.simulink_executed = true;info.closed_loop_executed = true;info.runtime = version;
save(fullfile(folder,'native_simulink_logs.mat'),'raw','info','cfg','-v7');
end
