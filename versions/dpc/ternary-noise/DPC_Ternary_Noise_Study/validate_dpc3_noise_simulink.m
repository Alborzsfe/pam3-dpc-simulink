function report = validate_dpc3_noise_simulink()
% Native compilation and execution of the new measured-power S-function port.
root = fileparts(mfilename('fullpath'));addpath(fullfile(root,'matlab'));
d = load(fullfile(root,'data','dpc3_noise_golden.mat'));cfg = dpc3_config();
model = 'DPCN_native_noisy_table';
if bdIsLoaded(model)
    assert(strcmp(get_param(model,'Dirty'),'off'),'Save/close the unsaved noisy preflight first.');
    close_system(model,0);
end
new_system(model);close_model = onCleanup(@() close_system(model,0));
ws = get_param(model,'ModelWorkspace');
assign_case(ws,d.native{1},cfg);
add_block('simulink/Sources/From Workspace',[model '/Input'], ...
    'VariableName','dpcn_input','SampleTime','dpcn_ts','Interpolate','off', ...
    'OutputAfterFinalValue','Holding final value');
add_block('simulink/Signal Routing/Demux',[model '/Fields'],'Outputs','[1 1 1 3 3 1 1 1 1 1 2]');
add_line(model,'Input/1','Fields/1');
add_block('built-in/M-S-Function',[model '/Noisy_power_table'], ...
    'FunctionName','dpc3_table_sfun','Parameters','dpcn_cfg');
fp = get_param([model '/Fields'],'PortHandles');tp = get_param([model '/Noisy_power_table'],'PortHandles');
for k = 1:11,add_line(model,fp.Outport(k),tp.Inport(k));end
dpc3_add_log(model,'gates',tp.Outport(1),1/d.native{1}.fs,[700,100,900,140]);
dpc3_add_log(model,'audit',tp.Outport(2),1/d.native{1}.fs,[700,200,900,240]);
set_param([model '/Log_gates'],'SampleTime','dpcn_ts');set_param([model '/Log_audit'],'SampleTime','dpcn_ts');
set_param(model,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','dpcn_ts', ...
    'ReturnWorkspaceOutputs','on','SaveTime','off','SaveOutput','off','SignalLogging','off');
total = 0;out = [];
try
    for n = 1:numel(d.native)
        item = d.native{n};assign_case(ws,item,cfg);count = size(item.input,1);
        set_param(model,'StopTime',sprintf('%.17g',(count-1)/item.fs));
        out = sim(model,'ReturnWorkspaceOutputs','on');
        gates = dpc3_log_samples(out.get('dpc3_log_gates'),1/item.fs,count,6,'noisy native gates');
        audit = dpc3_log_samples(out.get('dpc3_log_audit'),1/item.fs,count,21,'noisy native audit');
        assert(isequal(gates,item.gates),'DPC3:NativeNoisyGates','Native measured-power table differs from independent oracle.');
        assert(max(max(abs(audit-item.audit)./max(1,abs(item.audit)))) < 1e-8);
        total = total+count;
    end
catch exception
    failure = struct('message',exception.message,'identifier',exception.identifier,'item',item,'output',out);
    save(fullfile(root,'validation','native_noise_preflight_failure.mat'),'failure','-v7');
    rethrow(exception);
end
report = struct('passed',true,'simulink_executed',true,'samples',total,'runtime',version);
save(fullfile(root,'validation','native_noise_preflight.mat'),'report','-v7');
fprintf('PASS actual Simulink noisy-table preflight: %d samples / both control rates.\n',total);
end
function assign_case(ws,item,cfg)
ts = 1/item.fs;ch = dpc3_channel_config(cfg,ts,1,-1,true);
tc = dpc3_table_config(cfg,ts,ch,ch);tc.measured_power_input = true;
assignin(ws,'dpcn_ts',ts);assignin(ws,'dpcn_cfg',tc);
assignin(ws,'dpcn_input',[(0:size(item.input,1)-1)'*ts,item.input]);
end
