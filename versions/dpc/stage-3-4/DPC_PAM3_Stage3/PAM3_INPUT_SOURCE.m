function [block,port]=PAM3_INPUT_SOURCE(path,index)
% Resolve an input's source through branch parents without cached handles.
handles=get_param(path,'PortHandles');
line=get_param(handles.Inport(index),'Line');
assert(line~=-1,'PAM3Study:Source','Disconnected input: %s.',path);
source=get_param(line,'SrcPortHandle');
while source==-1
    line=get_param(line,'LineParent');
    assert(line~=-1 && line~=0,'PAM3Study:Source','Cannot resolve %s.',path);
    source=get_param(line,'SrcPortHandle');
end
block=get_param(source,'Parent');port=get_param(source,'PortNumber');
end
