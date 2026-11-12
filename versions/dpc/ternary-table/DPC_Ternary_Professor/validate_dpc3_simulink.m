function report = validate_dpc3_simulink()
% Real Simulink bench against independent fixtures and the ORIGINAL chart.
root = fileparts(mfilename('fullpath'));addpath(fullfile(root,'matlab'));
d = load(fullfile(root,'data','dpc3_golden.mat'));cfg = dpc3_config();
reference = dpc3_copy_source('DPC3_native_reference',root);
cleanup_reference = onCleanup(@() close_system(reference,0));
model = 'DPC3_native_preflight';
if bdIsLoaded(model)
    assert(strcmp(get_param(model,'Dirty'),'off'),'Save/close unsaved preflight first.');close_system(model,0);
end
new_system(model);cleanup = onCleanup(@() close_system(model,0));
ws = get_param(model,'ModelWorkspace');
initial = d.native{1}; assign_case(ws,initial,cfg,'proposed');
add_block('simulink/Sources/From Workspace',[model '/Input'], ...
    'VariableName','dpc3_input_array','SampleTime','dpc3_ts','Interpolate','off', ...
    'OutputAfterFinalValue','Holding final value');
add_block('simulink/Signal Routing/Demux',[model '/Fields'],'Outputs','[1 1 1 3 3 1 1 1]');
add_line(model,'Input/1','Fields/1');fields = get_param([model '/Fields'],'PortHandles');
for k = 1:2
    name = sprintf('Original_relay_%d',k);
    add_block('simulink/Discontinuities/Relay',[model '/' name], ...
        'OnSwitchValue','1','OffSwitchValue','-1','OnOutputValue','1','OffOutputValue','0', ...
        'SampleTime','dpc3_ts');
    p = get_param([model '/' name],'PortHandles');add_line(model,fields.Outport(k),p.Inport(1));
    target = [model sprintf('/Ternary_%d',k)];
    add_block('built-in/M-S-Function',target,'FunctionName','dpc3_classifier_sfun','Parameters','dpc3_channel');
    pp = get_param(target,'PortHandles');add_line(model,fields.Outport(k),pp.Inport(1));
    add_line(model,p.Outport(1),pp.Inport(2));
    dpc3_add_log(model,sprintf('binary%d',k),p.Outport(1),1/initial.fs,[800,k*70,1000,k*70+40]);
    % Use expression sample time so the second Fs case updates all log rates.
    set_param([model sprintf('/Log_binary%d',k)],'SampleTime','dpc3_ts');
    dpc3_add_log(model,sprintf('state%d',k),pp.Outport(1),1/initial.fs,[800,200+k*70,1000,240+k*70]);
    set_param([model sprintf('/Log_state%d',k)],'SampleTime','dpc3_ts');
end
add_block([reference '/Subsystem1/ Pulses'],[model '/Original_source_table']);
original = get_param([model '/Original_source_table'],'PortHandles');
for k = 1:2
    pp = get_param([model sprintf('/Original_relay_%d',k)],'PortHandles');
    add_line(model,pp.Outport(1),original.Inport(k));
end
add_line(model,fields.Outport(3),original.Inport(3));
% Reproduce the original gate order and complement conversion with native blocks.
add_block('simulink/Signal Routing/Mux',[model '/Original_gates'],'Inputs','6');
mux = get_param([model '/Original_gates'],'PortHandles');
for k = 1:3
    negate = [model sprintf('/Complement_%d',k)];convert = [model sprintf('/Double_%d',k)];
    add_block('simulink/Logic and Bit Operations/Logical Operator',negate,'Operator','NOT');
    add_block('simulink/Signal Attributes/Data Type Conversion',convert,'OutDataTypeStr','double');
    np = get_param(negate,'PortHandles');cp = get_param(convert,'PortHandles');
    add_line(model,original.Outport(k),mux.Inport(2*k-1));add_line(model,original.Outport(k),np.Inport(1));
    add_line(model,np.Outport(1),cp.Inport(1));add_line(model,cp.Outport(1),mux.Inport(2*k));
end
add_block('built-in/M-S-Function',[model '/New_nine_state_table'], ...
    'FunctionName','dpc3_table_sfun','Parameters','dpc3_table_cfg');
table = get_param([model '/New_nine_state_table'],'PortHandles');
for k = 1:2
    pp = get_param([model sprintf('/Ternary_%d',k)],'PortHandles');add_line(model,pp.Outport(1),table.Inport(k));
end
for k = 3:8, add_line(model,fields.Outport(k),table.Inport(k)); end
for k = 1:2
    pp = get_param([model sprintf('/Original_relay_%d',k)],'PortHandles');add_line(model,pp.Outport(1),table.Inport(k+8));
end
add_block('simulink/Sources/Constant',[model '/Enable'],'Value','dpc3_enable');
add_block('simulink/Signal Routing/Switch',[model '/Select'],'Criteria','u2 > Threshold','Threshold','0.5');
sw = get_param([model '/Select'],'PortHandles');enable = get_param([model '/Enable'],'PortHandles');
add_line(model,table.Outport(1),sw.Inport(1));add_line(model,enable.Outport(1),sw.Inport(2));
add_line(model,mux.Outport(1),sw.Inport(3));
ports = [mux.Outport(1),sw.Outport(1),table.Outport(2)]; names = {'original','selected','audit'};
for k = 1:3
    dpc3_add_log(model,names{k},ports(k),1/initial.fs,[1100,70*k,1320,70*k+40]);
    set_param([model '/Log_' names{k}],'SampleTime','dpc3_ts');
end
dpc3_add_log(model,'input',fields.Outport(1),1/initial.fs,[1100,400,1320,440]);
set_param([model '/Log_input'],'SampleTime','dpc3_ts');
dpc3_add_log(model,'input_q',fields.Outport(2),1/initial.fs,[1100,450,1320,490]);
set_param([model '/Log_input_q'],'SampleTime','dpc3_ts');
set_param(model,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','dpc3_ts', ...
    'StartTime','0','ReturnWorkspaceOutputs','on','SaveTime','off','SaveOutput','off');
modes = {'proposed','binary_limit','bypass'};cases = 0;samples = 0;
for n = 1:numel(d.native)
    item = d.native{n};count = size(item.input,1);dt = 1/item.fs;
    for m = 1:numel(modes)
        mode = modes{m};assign_case(ws,item,cfg,mode);
        set_param(model,'StopTime',sprintf('%.17g',(count-1)*dt));
        out = [];
        try
            out = sim(model,'ReturnWorkspaceOutputs','on','SimulationMode','normal');
            input = dpc3_log_samples(out.get('dpc3_log_input'),dt,count,1,'input');
            assert(isequal(input,item.input(:,1)),'DPC3:NativeInput','Native loaded input differs.');
            input_q = dpc3_log_samples(out.get('dpc3_log_input_q'),dt,count,1,'input Q');
            assert(isequal(input_q,item.input(:,2)),'DPC3:NativeInput','Native loaded Q input differs.');
            for k = 1:2
                observed = dpc3_log_samples(out.get(sprintf('dpc3_log_binary%d',k)),dt,count,1,'binary');
                expected = double(item.binary(:,k));
                mismatch = find(observed ~= expected,1,'first');
                if ~isempty(mismatch)
                    error('DPC3:NativeRelay', ...
                        ['Relay %d differs: Fs=%.0f, mode=%s, sample=%d, t=%.17g, ' ...
                         'input=%.17g, actual=%.17g, expected=%.17g.'], ...
                        k,item.fs,mode,mismatch,(mismatch-1)*dt,item.input(mismatch,k), ...
                        observed(mismatch),expected(mismatch));
                end
                observed = dpc3_log_samples(out.get(sprintf('dpc3_log_state%d',k)),dt,count,1,'state');
                expected = item.states(:,k);if strcmp(mode,'binary_limit'),expected = 2*item.binary(:,k)-1;end
                assert(isequal(observed,expected),'DPC3:NativeState','Native ternary state differs.');
            end
            original_g = dpc3_log_samples(out.get('dpc3_log_original'),dt,count,6,'original gates');
            selected_g = dpc3_log_samples(out.get('dpc3_log_selected'),dt,count,6,'selected gates');
            assert(isequal(original_g,item.original_gates),'DPC3:SourceTable','Copied SOURCE table differs from golden.');
            expected = item.proposed_gates;if ~strcmp(mode,'proposed'),expected = item.original_gates;end
            assert(isequal(selected_g,expected),'DPC3:NativeGates','New selected gates differ: %s.',mode);
            audit = dpc3_log_samples(out.get('dpc3_log_audit'),dt,count,21,'audit');
            if strcmp(mode,'proposed')
                assert(isequal(audit(:,1:5),item.audit(:,1:5)));
                assert(isequal(audit(:,12:21),item.audit(:,12:21)));
            end
        catch exception
            failure = struct('mode',mode,'item',item,'message',exception.message,'identifier',exception.identifier);
            if ~isempty(out), failure.output = out; end
            save(fullfile(root,'validation','native_preflight_failure.mat'),'failure','-v7');
            rethrow(exception);
        end
        cases = cases+1;samples = samples+count;
    end
end
report = struct('passed',true,'simulink_executed',true,'converter_executed',false, ...
    'cases',cases,'samples',samples,'native_original_chart_used',true,'runtime',version);
save(fullfile(root,'validation','native_preflight_report.mat'),'report','-v7');
fprintf('PASS actual Simulink DPC3: %d cases, %d samples; original chart, ternary states, 9-row table, binary limit and bypass.\n',cases,samples);
end
function assign_case(ws,item,cfg,mode)
dt = 1/item.fs; count = size(item.input,1);
ch = dpc3_channel_config(cfg,dt,1,-1,~strcmp(mode,'binary_limit'));
assignin(ws,'dpc3_ts',dt);assignin(ws,'dpc3_input_array',[(0:count-1)'*dt,item.input]);
assignin(ws,'dpc3_channel',ch);assignin(ws,'dpc3_table_cfg',dpc3_table_config(cfg,dt,ch,ch));
assignin(ws,'dpc3_enable',double(~strcmp(mode,'bypass')));
end
