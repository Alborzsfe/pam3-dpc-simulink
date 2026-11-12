function pam3_packer_sfun(block)
block.NumDialogPrms = 1;
cfg = block.DialogPrm(1).Data;
block.DialogPrmsTunable = {'Nontunable'};
block.NumInputPorts = 3; block.NumOutputPorts = 1;
block.SetPreCompInpPortInfoToDynamic();
block.SetPreCompOutPortInfoToDynamic();
for k = 1:3
    block.InputPort(k).Dimensions = 18;
    if k == 3
        block.InputPort(k).Dimensions = 1;
    end
    block.InputPort(k).DatatypeID = 0;
    block.InputPort(k).Complexity = 'Real';
    block.InputPort(k).DirectFeedthrough = true;
end
block.OutputPort(1).Dimensions = 34;
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
block.NumDworks = 1;
block.Dwork(1).Name = 'packet_state';
block.Dwork(1).Dimensions = 70;
block.Dwork(1).DatatypeID = 0;
block.Dwork(1).Complexity = 'Real';
block.Dwork(1).UsedAsDiscState = true;
end

function initialize(block)
block.Dwork(1).Data = zeros(70, 1);
end

function outputs(block)
[~, y] = pam3_packer_step(block.Dwork(1).Data, block.InputPort(1).Data, ...
    block.InputPort(2).Data, block.InputPort(3).Data);
block.OutputPort(1).Data = y;
end

function update(block)
[s, ~] = pam3_packer_step(block.Dwork(1).Data, block.InputPort(1).Data, ...
    block.InputPort(2).Data, block.InputPort(3).Data);
block.Dwork(1).Data = s;
end
