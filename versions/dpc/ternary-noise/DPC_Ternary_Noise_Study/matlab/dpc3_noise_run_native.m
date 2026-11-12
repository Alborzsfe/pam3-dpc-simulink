function [raw,info,folder] = dpc3_noise_run_native(method,fs,cfg,s,stimulus,case_folder)
folder = fullfile(case_folder,sprintf('%gk_%s',fs/1000,method));
if ~exist(folder,'dir'),mkdir(folder);end
fprintf('Running %s | seed %u | %g kHz | %s\n',s.id,stimulus.seed,fs/1000,method);
timer = tic;
try
    [model,info] = build_dpc3_model(method,fs,cfg,s,stimulus);
    close_model = onCleanup(@() close_system(model,0));
    out = sim(model,'ReturnWorkspaceOutputs','on','SimulationMode','normal');
    names = {'iabc','vabc','vdc','p','pref','q','qref','gates','binary_dp','binary_dq','sector', ...
        'noise_vabc','noise_p','noise_q','v_feedback','p_feedback','q_feedback','grid_delta'};
    if strcmp(method,'proposed'), names{end+1} = 'audit'; end
    raw = struct();
    for k = 1:numel(names),raw.(names{k}) = out.get(['dpc3_log_' names{k}]);end
    info.elapsed_s = toc(timer); info.simulink_executed = true;
    info.closed_loop_executed = true; info.runtime = version;
    % Save actual logs BEFORE any assertions or result analysis can fail.
    save(fullfile(folder,'native_simulink_logs.mat'),'raw','info','cfg','-v7');
    report = dpc3_verify_noise_logs(raw,cfg,s,stimulus);
    info.stimulus_verification = report;
    save(fullfile(folder,'stimulus_verification.mat'),'report','-v7');
catch exception
    failure = struct('case_id',s.id,'seed',stimulus.seed,'control_hz',fs, ...
        'method',method,'message',exception.message,'identifier',exception.identifier,'stack',exception.stack);
    save(fullfile(folder,'failure.mat'),'failure','cfg','-v7');
    rethrow(exception);
end
fprintf('Verified actual stimulus and truth/feedback separation for %s.\n',method);
end
