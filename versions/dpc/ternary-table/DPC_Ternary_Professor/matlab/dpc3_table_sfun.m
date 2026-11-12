function dpc3_table_sfun(block)
block.NumDialogPrms = 1; c = block.DialogPrm(1).Data;
block.DialogPrmsTunable = {'Nontunable'};
block.NumInputPorts = 10; block.NumOutputPorts = 2;
block.SetPreCompInpPortInfoToDynamic(); block.SetPreCompOutPortInfoToDynamic();
widths = [1,1,1,3,3,1,1,1,1,1];
for k = 1:10
    block.InputPort(k).Dimensions = widths(k); block.InputPort(k).DatatypeID = 0;
    block.InputPort(k).Complexity = 'Real'; block.InputPort(k).DirectFeedthrough = true;
end
for k = 1:2
    block.OutputPort(k).DatatypeID = 0; block.OutputPort(k).Complexity = 'Real';
end
block.OutputPort(1).Dimensions = 6; block.OutputPort(2).Dimensions = 21;
block.SampleTimes = [c.sample_time,0]; block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('PostPropagationSetup',@post_setup);
block.RegBlockMethod('InitializeConditions',@initialize);
block.RegBlockMethod('Outputs',@outputs); block.RegBlockMethod('Update',@update);
end
function post_setup(block)
block.NumDworks = 1; block.Dwork(1).Name = 'previous_upper_legs'; block.Dwork(1).Dimensions = 3;
block.Dwork(1).DatatypeID = 0; block.Dwork(1).Complexity = 'Real'; block.Dwork(1).UsedAsDiscState = true;
end
function initialize(block)
block.Dwork(1).Data = zeros(3,1);
end
function [g,a] = calculate(block)
[g,a] = dpc3_table(block.InputPort(1).Data,block.InputPort(2).Data, ...
    block.InputPort(3).Data,block.InputPort(4).Data,block.InputPort(5).Data, ...
    block.InputPort(6).Data,block.InputPort(7).Data,block.InputPort(8).Data, ...
    block.InputPort(9).Data,block.InputPort(10).Data,block.Dwork(1).Data,block.DialogPrm(1).Data);
end
function outputs(block)
[g,a] = calculate(block); block.OutputPort(1).Data = g; block.OutputPort(2).Data = a;
end
function update(block)
[g,~] = calculate(block); block.Dwork(1).Data = g([1,3,5]);
end
