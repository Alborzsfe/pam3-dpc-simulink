classdef dpc3_mock_block < handle
    % Callback unit-test double. This is NOT the Simulink runtime.
    properties
        NumDialogPrms;DialogPrm;DialogPrmsTunable;NumInputPorts;NumOutputPorts
        InputPort;OutputPort;SampleTimes;SimStateCompliance;NumDworks;Dwork
        callbacks = struct()
    end
    methods
        function b = dpc3_mock_block(cfg)
            b.DialogPrm = struct('Data',cfg);
            p = struct('Dimensions',1,'DatatypeID',0,'Complexity','Real','DirectFeedthrough',true,'Data',0);
            b.InputPort = repmat(p,1,11);b.OutputPort = repmat(p,1,2);
            b.Dwork = struct('Name','','Dimensions',0,'DatatypeID',0,'Complexity','Real','UsedAsDiscState',false,'Data',[]);
        end
        function SetPreCompInpPortInfoToDynamic(~)
        end
        function SetPreCompOutPortInfoToDynamic(~)
        end
        function RegBlockMethod(b,name,callback)
            b.callbacks.(name) = callback;
        end
        function invoke(b,name)
            callback = b.callbacks.(name);callback(b);
        end
    end
end
