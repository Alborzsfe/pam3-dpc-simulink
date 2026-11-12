function coverage=SMOKE_TEST_STAGE4_LOGGING()
% Three tiny native Simulink runs: constant and signed Q reference logs.
% No converter, powerlib, or performance claims. Uses the production sink
% configuration and actual reference-profile function before the long study.
root=fileparts(mfilename('fullpath'));addpath(root);VALIDATE_PAM3_LOGGING();
assert(exist('new_system','file')~=0 || exist('new_system','builtin')~=0, ...
    'PAM3Study:Simulink','MATLAB with Simulink is required.');
[~,suffix]=fileparts(tempname);model=PAM3_SHORT_MODEL_NAME(['logtest_' suffix]);
buildCleanup=PAM3_SHORT_BUILD_PATHS(struct()); %#ok<NASGU>
new_system(model);cleanup=onCleanup(@()close_system(model,0)); %#ok<NASGU>
cfg=struct('Ts',1/40000,'stopTime',.012);stepTime=.006;
set_param(model,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
    'FixedStep',num2str(cfg.Ts,17),'StartTime','0', ...
    'StopTime',num2str(cfg.stopTime,17),'ReturnWorkspaceOutputs','on', ...
    'SignalLogging','off','SaveTime','off','SaveOutput','off','SaveState','off');
add_block('simulink/Sources/Digital Clock',[model '/Clock'], ...
    'SampleTime',num2str(cfg.Ts,17));
source=[model '/Reference'];
add_block('simulink/User-Defined Functions/MATLAB Function',source);
for key={'Pref','Qref'}
    sink=[model '/Log_' key{1}];add_block('simulink/Sinks/To Workspace',sink);
    PAM3_CONFIGURE_LOGGER(sink,['study_' key{1}],cfg.Ts);
end
PAM3_STUDY_CONNECT([model '/Clock'],1,source,1);
rows=cell(3,1);amplitudes=[0 80 -80];
for k=1:3
    chart=find(sfroot,'-isa','Stateflow.EMChart','Path',source);
    code=sprintf(['function [p,q]=fcn(t)\n' ...
        '[p,q]=pam3_reference_profile(t,%.17g,400,400,0,%.17g);\nend\n'], ...
        stepTime,amplitudes(k));
    chart.Script=[code fileread(fullfile(root,'pam3_reference_profile.m'))];
    chart.ChartUpdate='INHERITED';
    PAM3_STUDY_CONNECT(source,1,[model '/Log_Pref'],1);
    PAM3_STUDY_CONNECT(source,2,[model '/Log_Qref'],1);
    out=sim(model,'ReturnWorkspaceOutputs','on');
    [horizon,completion]=PAM3_COMPLETION_HORIZON(out.SimulationMetadata,cfg);
    raw=struct('Pref',out.get('study_Pref'),'Qref',out.get('study_Qref'));
    [raw,c]=PAM3_LOG_COVERAGE(raw,cfg,horizon);
    c.CompletionTimeSource=repmat(string(completion.TimeSource),height(c),1);
    c.ReportedStopTime_s=repmat(completion.ReportedStopTime_s,height(c),1);
    t=((0:round(cfg.stopTime/cfg.Ts)-1)'+.5)*cfg.Ts;
    assert(all(PAM3_SAMPLE(raw.Pref,t)==400));
    assert(isequal(PAM3_SAMPLE(raw.Qref,t),amplitudes(k)*(t>=stepTime)));
    c.Qafter_var=repmat(amplitudes(k),height(c),1);rows{k}=c;
end
coverage=vertcat(rows{:});disp(coverage);
fprintf('PASS: three native short logging runs; complete constant and +/-80 var reference profiles.\n');
end
