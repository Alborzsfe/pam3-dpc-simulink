classdef quality_mock_block < handle
    % Test double for callback unit checks. This class DOES NOT run Simulink.
    properties
        NumDialogPrms
        DialogPrm
        DialogPrmsTunable
        NumInputPorts
        NumOutputPorts
        InputPort
        OutputPort
        SampleTimes
        SimStateCompliance
        NumDworks
        Dwork
        callbacks = struct()
    end
    methods
        function block = quality_mock_block(cfg)
            block.DialogPrm = struct('Data',cfg);
            port = struct('Dimensions',1,'DatatypeID',0,'Complexity','Real', ...
                'DirectFeedthrough',true,'Data',0);
            block.InputPort = port; block.OutputPort = port;
            block.Dwork = struct('Name','','Dimensions',0,'DatatypeID',0, ...
                'Complexity','Real','UsedAsDiscState',false,'Data',[]);
        end
        function SetPreCompInpPortInfoToDynamic(~)
        end
        function SetPreCompOutPortInfoToDynamic(~)
        end
        function RegBlockMethod(block,name,callback)
            block.callbacks.(name) = callback;
        end
        function invoke(block,name)
            callback = block.callbacks.(name); callback(block);
        end
    end
end
