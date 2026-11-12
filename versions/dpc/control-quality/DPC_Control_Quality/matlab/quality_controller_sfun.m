function quality_controller_sfun(block)
block.NumDialogPrms = 1;
cfg = block.DialogPrm(1).Data;
block.DialogPrmsTunable = {'Nontunable'};
block.NumInputPorts = 1; block.NumOutputPorts = 1;
block.SetPreCompInpPortInfoToDynamic(); block.SetPreCompOutPortInfoToDynamic();
block.InputPort(1).Dimensions = 1; block.InputPort(1).DatatypeID = 0;
block.InputPort(1).Complexity = 'Real'; block.InputPort(1).DirectFeedthrough = true;
block.OutputPort(1).Dimensions = 1; block.OutputPort(1).DatatypeID = 0;
block.OutputPort(1).Complexity = 'Real';
block.SampleTimes = [cfg.sample_time, 0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('PostPropagationSetup', @post_setup);
block.RegBlockMethod('InitializeConditions', @initialize);
block.RegBlockMethod('Outputs', @outputs);
block.RegBlockMethod('Update', @update);
end

function post_setup(block)
block.NumDworks = 1;
block.Dwork(1).Name = 'controller_state';
block.Dwork(1).Dimensions = numel(quality_controller_initial(block.DialogPrm(1).Data));
block.Dwork(1).DatatypeID = 0; block.Dwork(1).Complexity = 'Real';
block.Dwork(1).UsedAsDiscState = true;
end

function initialize(block)
block.Dwork(1).Data = quality_controller_initial(block.DialogPrm(1).Data);
end

function outputs(block)
[~, value] = quality_controller_step(block.Dwork(1).Data, ...
    block.InputPort(1).Data, block.DialogPrm(1).Data);
block.OutputPort(1).Data = value;
end

function update(block)
[s, ~] = quality_controller_step(block.Dwork(1).Data, ...
    block.InputPort(1).Data, block.DialogPrm(1).Data);
block.Dwork(1).Data = s;
end
