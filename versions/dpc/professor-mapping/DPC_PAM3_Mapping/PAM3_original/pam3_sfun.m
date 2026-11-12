function pam3_sfun(block)
% Level-2 MATLAB S-Function; one sample per discrete tick, independent DWork.
block.NumDialogPrms = 1;
cfg = block.DialogPrm(1).Data;
pam3_validate_config(cfg);
block.DialogPrmsTunable = {'Nontunable'};
block.NumInputPorts = 2; block.NumOutputPorts = 1;
block.SetPreCompInpPortInfoToDynamic();
block.SetPreCompOutPortInfoToDynamic();
for k = 1:2
    block.InputPort(k).Dimensions = 1;
    block.InputPort(k).DatatypeID = 0;
    block.InputPort(k).Complexity = 'Real';
    block.InputPort(k).DirectFeedthrough = true;
end
block.OutputPort(1).Dimensions = 18;
block.OutputPort(1).DatatypeID = 0;
block.OutputPort(1).Complexity = 'Real';
block.SampleTimes = [cfg.sample_time, 0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('PostPropagationSetup', @post_setup);
block.RegBlockMethod('InitializeConditions', @initialize);
block.RegBlockMethod('Outputs', @outputs);
block.RegBlockMethod('Update', @update);
end

function post_setup(block)
L = pam3_layout();
block.NumDworks = 1;
block.Dwork(1).Name = 'receiver_state';
block.Dwork(1).Dimensions = L.size;
block.Dwork(1).DatatypeID = 0;
block.Dwork(1).Complexity = 'Real';
block.Dwork(1).UsedAsDiscState = true;
end

function initialize(block)
block.Dwork(1).Data = pam3_initial_state(block.DialogPrm(1).Data);
end

function outputs(block)
% Do not mutate states in Outputs: Simulink may call it more than once.
[~, y] = pam3_step(block.Dwork(1).Data, block.InputPort(1).Data, ...
    block.InputPort(2).Data, block.DialogPrm(1).Data);
block.OutputPort(1).Data = y;
end

function update(block)
[s, ~] = pam3_step(block.Dwork(1).Data, block.InputPort(1).Data, ...
    block.InputPort(2).Data, block.DialogPrm(1).Data);
block.Dwork(1).Data = s;
end
