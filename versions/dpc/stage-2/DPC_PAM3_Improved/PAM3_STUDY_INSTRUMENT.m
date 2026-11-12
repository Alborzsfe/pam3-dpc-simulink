function PAM3_STUDY_INSTRUMENT(model)
% Add/reuse logging sinks. Calling twice must leave exactly the same graph.
controller=[model '/MATLAB Function3'];
ports=[4 5 8 9 1 2 3];labels={'Pmeasured','Qmeasured','sp','sq','S1','S2','S3'};
% Keep new sinks outside the existing block layout, avoiding incidental
% overlap with old wires during interactive/model editing callbacks.
blocks=find_system(model,'SearchDepth',1,'Type','Block');
bottom=0;right=0;
for k=1:numel(blocks)
    name=get_param(blocks{k},'Name');
    if strncmp(name,'Study_Log_',10),continue;end
    position=get_param(blocks{k},'Position');
    bottom=max(bottom,position(4));right=max(right,position(3));
end
origin=[right+200,bottom+100];
for k=1:numel(ports)
    logport(model,controller,ports(k),labels{k},k,origin);
end
% Resolve upstream sources afresh, AFTER adding the preceding sinks.
[sourceBlock,sourcePort]=input_source(controller,3);
logport(model,sourceBlock,sourcePort,'Pref',8,origin);
for pair={'Scope4','Scope1';'I','Vdc'}
    [sourceBlock,sourcePort]=input_source([model '/' pair{1}],1);
    logport(model,sourceBlock,sourcePort,pair{2},9+strcmp(pair{2},'Vdc'),origin);
end
sensor=[model '/Study_Sensor_Noise'];
sensorPorts=[3 4 1 2 5 6];
sensorLabels={'P','Q','Vmeasured','Imeasured','NoiseV','NoiseI'};
for k=1:numel(sensorPorts)
    logport(model,sensor,sensorPorts(k),sensorLabels{k},10+k,origin);
end
[sourceBlock,sourcePort]=input_source(sensor,1);
logport(model,sourceBlock,sourcePort,'V',17,origin);
[sourceBlock,sourcePort]=input_source(controller,4);
logport(model,sourceBlock,sourcePort,'Qref',18,origin);
logport(model,controller,11,'Diagnostics',19,origin);
end
function logport(model,sourceBlock,sourcePort,label,slot,origin)
path=[model '/Study_Log_' label];
if getSimulinkBlockHandle(path)==-1
    add_block('simulink/Sinks/To Workspace',path, ...
        'Position',[origin(1),origin(2)+45*slot,origin(1)+110,origin(2)+45*slot+25]);
else
    assert(strcmp(get_param(path,'BlockType'),'ToWorkspace'), ...
        'PAM3Study:LoggerType','Reserved logger name %s belongs to another block.',path);
end
set_param(path,'VariableName',['study_' label],'SaveFormat','Structure With Time', ...
    'MaxDataPoints','inf','Decimation','1');
PAM3_STUDY_CONNECT(sourceBlock,sourcePort,path,1);
end
function [block,port]=input_source(path,index)
handles=get_param(path,'PortHandles');
line=get_param(handles.Inport(index),'Line');
assert(line~=-1,'PAM3Study:Logging','Required input is disconnected: %s.',path);
source=get_param(line,'SrcPortHandle');
while source==-1
    line=get_param(line,'LineParent');
    assert(line~=-1 && line~=0,'PAM3Study:Logging','Cannot resolve source for %s.',path);
    source=get_param(line,'SrcPortHandle');
end
block=get_param(source,'Parent');
port=get_param(source,'PortNumber');
end
