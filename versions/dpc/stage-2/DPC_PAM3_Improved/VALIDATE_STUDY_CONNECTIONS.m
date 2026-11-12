function VALIDATE_STUDY_CONNECTIONS()
% Native Simulink regression: repeat connections and repair a wrong logger
% branch while retaining the ordinary consumers on BOTH source signals.
[~,suffix]=fileparts(tempname);model=['pam3_wire_' suffix];
new_system(model);cleanup=onCleanup(@()close_system(model,0)); %#ok<NASGU>
add_block('simulink/Sources/Constant',[model '/SignalA']);
add_block('simulink/Sources/Constant',[model '/SignalB']);
add_block('simulink/Sinks/Terminator',[model '/ConsumerA']);
add_block('simulink/Sinks/Terminator',[model '/ConsumerB']);
add_block('simulink/Sinks/To Workspace',[model '/Study_Log_P']);
PAM3_STUDY_CONNECT([model '/SignalA'],1,[model '/ConsumerA'],1);
PAM3_STUDY_CONNECT([model '/SignalB'],1,[model '/ConsumerB'],1);
% Initial logging and an identical second request.
PAM3_STUDY_CONNECT([model '/SignalA'],1,[model '/Study_Log_P'],1);
PAM3_STUDY_CONNECT([model '/SignalA'],1,[model '/Study_Log_P'],1);
% Simulate a logger retained from a previous partial run with wrong wiring.
PAM3_STUDY_CONNECT([model '/SignalB'],1,[model '/Study_Log_P'],1);
PAM3_STUDY_CONNECT([model '/SignalA'],1,[model '/Study_Log_P'],1);
% Repeating instrumentation must never delete an ordinary signal consumer.
assert_source([model '/ConsumerA'],[model '/SignalA']);
assert_source([model '/ConsumerB'],[model '/SignalB']);
assert_source([model '/Study_Log_P'],[model '/SignalA']);
fprintf('PASS: logging connections are repeatable; both original branches preserved.\n');
end
function assert_source(destination,expected)
h=get_param(destination,'PortHandles');line=get_param(h.Inport(1),'Line');
assert(line~=-1,'PAM3Study:WireTest','Consumer was disconnected.');
source=get_param(line,'SrcPortHandle');
while source==-1
    line=get_param(line,'LineParent');
    assert(line~=-1 && line~=0,'PAM3Study:WireTest','Source is missing.');
    source=get_param(line,'SrcPortHandle');
end
assert(strcmp(get_param(source,'Parent'),expected),'PAM3Study:WireTest','Wrong source.');
end
