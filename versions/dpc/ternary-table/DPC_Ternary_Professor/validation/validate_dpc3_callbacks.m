function report = validate_dpc3_callbacks()
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'validation'));
d = load(fullfile(root,'data','dpc3_golden.mat'));cfg = dpc3_config();samples = 0;
for n = 1:numel(d.native)
    item = d.native{n};
    for enabled = [false,true]
        c = dpc3_channel_config(cfg,1/item.fs,1,-1,enabled);
        p = dpc3_mock_block(c);q = dpc3_mock_block(c);
        t = dpc3_mock_block(dpc3_table_config(cfg,1/item.fs,c,c));
        dpc3_classifier_sfun(p);dpc3_classifier_sfun(q);dpc3_table_sfun(t);
        for b = {p,q,t}
            b{1}.invoke('PostPropagationSetup');b{1}.invoke('InitializeConditions');
            assert(isequal(b{1}.SampleTimes,[1/item.fs,0]));
        end
        for k = 1:size(item.input,1)
            x = item.input(k,:);
            p.InputPort(1).Data = x(1);p.InputPort(2).Data = item.binary(k,1);
            q.InputPort(1).Data = x(2);q.InputPort(2).Data = item.binary(k,2);
            for b = {p,q}
                before = b{1}.Dwork.Data;b{1}.invoke('Outputs');value = b{1}.OutputPort(1).Data;
                b{1}.invoke('Outputs');assert(isequal(before,b{1}.Dwork.Data));
                assert(isequal(value,b{1}.OutputPort(1).Data));
            end
            states = [p.OutputPort(1).Data,q.OutputPort(1).Data];
            expected = item.states(k,:);if ~enabled,expected = 2*item.binary(k,:)-1;end
            assert(isequal(states,expected));
            inputs = {states(1),states(2),x(3),x(4:6)',x(7:9)',x(10),x(11),x(12), ...
                item.binary(k,1),item.binary(k,2)};
            for j = 1:10,t.InputPort(j).Data = inputs{j};end
            before = t.Dwork.Data;t.invoke('Outputs');g = t.OutputPort(1).Data;
            t.invoke('Outputs');assert(isequal(before,t.Dwork.Data) && isequal(g,t.OutputPort(1).Data));
            expected = item.proposed_gates(k,:);if ~enabled,expected = item.original_gates(k,:);end
            assert(isequal(g',expected));
            p.invoke('Update');q.invoke('Update');t.invoke('Update');
            assert(isequal(t.Dwork.Data,g([1,3,5])));
            samples = samples+1;
        end
    end
end
report = struct('passed',true,'samples',samples,'simulink_executed',false,'test_double_used',true,'runtime',version);
save(fullfile(root,'validation','callback_report.mat'),'report','-v7');
fprintf('PASS callback test double: %d sample steps; repeated Outputs pure; Update state and golden gates match. NOT Simulink.\n',samples);
end
