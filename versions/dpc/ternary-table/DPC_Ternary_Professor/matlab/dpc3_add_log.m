function dpc3_add_log(model,name,source,ts,position)
block = [model '/Log_' name];
add_block('simulink/Sinks/To Workspace',block,'VariableName',['dpc3_log_' name], ...
    'SaveFormat','Structure With Time','SampleTime',sprintf('%.17g',ts), ...
    'MaxDataPoints','inf','Decimation','1','Position',position);
ports = get_param(block,'PortHandles');
add_line(model,source,ports.Inport(1),'autorouting','on');
end
