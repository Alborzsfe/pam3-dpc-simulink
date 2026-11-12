function PAM3_STUDY_CONNECT(sourceBlock,sourcePort,destinationBlock,destinationPort)
% Connect stable block/port identities, reusing the correct existing branch.
% Only a connection to the explicitly requested destination can be replaced.
parent=get_param(sourceBlock,'Parent');
assert(strcmp(parent,get_param(destinationBlock,'Parent')), ...
    'PAM3Study:Hierarchy','Source and destination must share a parent.');
sourceRef=[sourceBlock(numel(parent)+2:end) '/' num2str(sourcePort)];
destinationRef=[destinationBlock(numel(parent)+2:end) '/' num2str(destinationPort)];
% Resolve handles after any block creation/configuration; never cache handles
% across structural mutations of MATLAB Function block interfaces.
source=get_param(sourceBlock,'PortHandles');
destination=get_param(destinationBlock,'PortHandles');
expected=source.Outport(sourcePort);
inport=destination.Inport(destinationPort);
line=get_param(inport,'Line');
if line~=-1
    existing=line_source(line);
    if existing==expected,return;end
    % Query from the DESTINATION: this handle identifies only its leaf
    % branch, so other consumers of either source signal remain connected.
    % Also handles a dangling branch retained after a failed editing pass.
    lines=get_param(destinationBlock,'LineHandles');
    delete_line(lines.Inport(destinationPort));
end
try
    add_line(parent,sourceRef,destinationRef,'autorouting','on');
catch problem
    % Some editing callbacks can complete a branch before reporting a
    % duplicate request. Accept it only after checking the exact source.
    destination=get_param(destinationBlock,'PortHandles');
    line=get_param(destination.Inport(destinationPort),'Line');
    source=get_param(sourceBlock,'PortHandles');
    if line==-1 || line_source(line)~=source.Outport(sourcePort)
        rethrow(problem);
    end
end
source=get_param(sourceBlock,'PortHandles');
destination=get_param(destinationBlock,'PortHandles');
line=get_param(destination.Inport(destinationPort),'Line');
assert(line~=-1 && line_source(line)==source.Outport(sourcePort), ...
    'PAM3Study:Connection','Wrong logging connection: %s -> %s.',sourceRef,destinationRef);
end
function source=line_source(line)
source=get_param(line,'SrcPortHandle');
while source==-1
    parent=get_param(line,'LineParent');
    if parent==-1 || parent==0,return;end
    line=parent;source=get_param(line,'SrcPortHandle');
end
end
