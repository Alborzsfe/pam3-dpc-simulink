function report = validate_callback_contract()
% Callback/integration unit check with a test double; NOT native Simulink.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'patent_core'),fullfile(root,'validation'));
fixtures = load(fullfile(root,'data','quality_fixtures.mat'));
selected = [7,8,17,18,27,28,37,38]; checked = 0;
for k = selected
    item = fixtures.cases{k}; cfg = quality_config(); cfg.proposed_variant = strtrim(item.variant);
    controller = quality_controller_config(cfg,1/item.fs,1,-1);
    input = quality_fixture_input(item.errors,controller.sample_time);
    assert(isa(input,'double') && isequal(size(input),[numel(item.errors),2]));
    assert(isequal(input(:,2),double(item.errors(:))));
    assert(isequal(input(:,1),(0:numel(item.errors)-1)'*controller.sample_time));
    block = quality_mock_block(controller);
    quality_controller_sfun(block);
    block.invoke('PostPropagationSetup'); block.invoke('InitializeConditions');
    assert(isequal(block.SampleTimes,[controller.sample_time,0]));
    observed = zeros(numel(item.errors),1);
    for j = 1:numel(item.errors)
        block.InputPort.Data = input(j,2); before = block.Dwork.Data;
        block.invoke('Outputs'); first = block.OutputPort.Data;
        block.invoke('Outputs');
        assert(isequal(before,block.Dwork.Data) && first == block.OutputPort.Data, ...
            'Outputs must not advance the controller state.');
        observed(j) = first;
        block.invoke('Update');
        assert(numel(block.Dwork.Data) == block.Dwork.Dimensions);
    end
    assert(isequal(observed,double(item.expected(:))),'Callback golden mismatch, fixture %d.',k);
    checked = checked+numel(observed);
end
report = struct('passed',true,'cases',numel(selected),'samples',checked, ...
    'input_format','two-column double array','simulink_executed',false, ...
    'test_double_used',true,'runtime',version);
fprintf('PASS callback contract with test double: %d fixtures, %d samples. NOT native Simulink.\n', ...
    report.cases,report.samples);
end
