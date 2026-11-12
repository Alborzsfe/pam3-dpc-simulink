function dpc3_classifier_sfun(block)
block.NumDialogPrms = 1; c = block.DialogPrm(1).Data;
block.DialogPrmsTunable = {'Nontunable'};
block.NumInputPorts = 2; block.NumOutputPorts = 1;
block.SetPreCompInpPortInfoToDynamic(); block.SetPreCompOutPortInfoToDynamic();
for k = 1:2
    block.InputPort(k).Dimensions = 1; block.InputPort(k).DatatypeID = 0;
    block.InputPort(k).Complexity = 'Real'; block.InputPort(k).DirectFeedthrough = true;
end
block.OutputPort(1).Dimensions = 1; block.OutputPort(1).DatatypeID = 0;
block.OutputPort(1).Complexity = 'Real'; block.SampleTimes = [c.sample_time,0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('PostPropagationSetup',@post_setup);
block.RegBlockMethod('InitializeConditions',@initialize);
block.RegBlockMethod('Outputs',@outputs); block.RegBlockMethod('Update',@update);
end
function post_setup(block)
block.NumDworks = 1; block.Dwork(1).Name = 'ternary_state'; block.Dwork(1).Dimensions = 1;
block.Dwork(1).DatatypeID = 0; block.Dwork(1).Complexity = 'Real'; block.Dwork(1).UsedAsDiscState = true;
end
function initialize(block)
block.Dwork(1).Data = 0;
end
function outputs(block)
block.OutputPort(1).Data = dpc3_classifier(block.Dwork(1).Data, ...
    block.InputPort(1).Data,block.InputPort(2).Data,block.DialogPrm(1).Data);
end
function update(block)
block.Dwork(1).Data = dpc3_classifier(block.Dwork(1).Data, ...
    block.InputPort(1).Data,block.InputPort(2).Data,block.DialogPrm(1).Data);
end
