function report = validate_dpc3_math()
root = fileparts(mfilename('fullpath')); addpath(fullfile(root,'matlab'));
d = load(fullfile(root,'data','dpc3_golden.mat')); cfg = dpc3_config(); dpc3_validate_config(cfg);
ch = dpc3_channel_config(cfg,50e-6,1,-1,true);c = dpc3_table_config(cfg,50e-6,ch,ch);
% The startup failure in the old adapter must be impossible here.
assert(dpc3_classifier(0,3,1,ch) == 1 && dpc3_classifier(0,-3,0,ch) == -1);
assert(dpc3_classifier(1,0,1,ch) == 0 && dpc3_classifier(-1,0,0,ch) == 0);
for bp = 0:1
    for bq = 0:1
        for sector = 1:12
            assert(isequal(dpc3_original_table(bp,bq,sector), ...
                squeeze(d.source_table(bp+1,bq+1,sector,:))));
        end
    end
end
max_prediction_error = 0;changed_zero_entries = 0;
for k = 1:size(d.table_inputs,1)
    x = d.table_inputs(k,:); c.sample_time = x(18); c.R = x(19);
    [g,a,ids] = dpc3_table(x(1),x(2),x(3),x(4:6),x(7:9),x(10),x(11),x(12), ...
        x(13),x(14),x(15:17),c);
    assert(isequal(g',d.gates(k,:)),'DPC3:Golden','Table gate mismatch in case %d.',k);
    assert(isequal(ids',d.audit(k,13:21)),'DPC3:NineRows','Nine-row mapping mismatch in case %d.',k);
    assert(max(abs(a'-d.audit(k,:))./max(1,abs(d.audit(k,:)))) < 1e-8);
    [pred,~,~] = dpc3_predict(x(4:6),x(7:9),x(10),c);
    prediction_error = max(abs([pred(1,:),pred(2,:)]-d.predictions(k,:)));
    max_prediction_error = max(max_prediction_error,prediction_error);
    assert(prediction_error < 1e-8,'DPC3:Prediction','Independent ABC quadrature mismatch.');
    assert(all(g([1,3,5])+g([2,4,6]) == 1));
    if x(1) == 0 || x(2) == 0
        original = dpc3_gate_encode(dpc3_original_table(x(13),x(14),x(3)));
        changed_zero_entries = changed_zero_entries+double(~isequal(g,original));
        assert(a(10) <= a(11)+1e-10*max(1,a(11)),'DPC3:Guard','Predicted tracking guard violated.');
    end
end
assert(changed_zero_entries > 0,'DPC3:Collapsed','Zero cases silently collapsed to the original binary path.');
samples = 0;
for n = 1:numel(d.native)
    item = d.native{n}; p = 0; q = 0; previous = zeros(3,1); binary = [0,0];
    channel = dpc3_channel_config(cfg,1/item.fs,1,-1,true);
    table = dpc3_table_config(cfg,1/item.fs,channel,channel);
    for k = 1:size(item.input,1)
        x = item.input(k,:);
        % Independently recompute native binary Relay bits, INCLUDING equality.
        for channel_index = 1:2
            if x(channel_index) >= 1
                binary(channel_index) = 1;
            elseif x(channel_index) <= -1
                binary(channel_index) = 0;
            end
        end
        assert(isequal(binary,double(item.binary(k,:))),'DPC3:RelayReference', ...
            'Binary reference mismatch at sample %d.',k);
        bp = binary(1); bq = binary(2);
        p = dpc3_classifier(p,x(1),bp,channel);q = dpc3_classifier(q,x(2),bq,channel);
        assert(isequal([p,q],item.states(k,:)));
        [g,~] = dpc3_table(p,q,x(3),x(4:6),x(7:9),x(10),x(11),x(12),bp,bq,previous,table);
        assert(isequal(g',item.proposed_gates(k,:))); previous = g([1,3,5]);
        [limit,~] = dpc3_table(2*bp-1,2*bq-1,x(3),x(4:6),x(7:9),x(10),x(11),x(12), ...
            bp,bq,previous,table);
        assert(isequal(limit',item.original_gates(k,:)),'DPC3:BinaryLimit','Binary limit differs.');
        samples = samples+1;
    end
end
% Known 50% THD (RMS harmonics 3 and 4, fundamental 10); same metrics as prior package.
t = (0:39999)'*5e-6; w = 2*pi*50*t;
r = quality_fft(7+sqrt(2)*(10*sin(w)+3*sin(3*w)+4*sin(5*w)),5e-6,50,50);
assert(abs(r.thd_percent-50) < 1e-9);
r = quality_ripple([1,3,1,3]); assert(r.mean == 2 && r.peak_to_peak == 2 && r.ripple_rms == 1);
% Same-rate clock checks must retain actual values and reject real shifts.
log.time = (0:999)'*50e-6;log.signals.values = reshape(1:2000,1000,2);
v = dpc3_log_samples(log,50e-6,1000,2,'test'); assert(isequal(v,log.signals.values));
% Harmless floating clock representation differences must not shift samples.
query = (0:999)'/20000;
v = quality_log_to_grid(log,query,'uniform roundoff');assert(isequal(v,log.signals.values));
query = log.time(1:end-1)+25e-6;
v = quality_log_to_grid(log,query,'between samples');assert(isequal(v,log.signals.values(1:end-1,:)));
report = struct('passed',true,'table_contexts',size(d.table_inputs,1), ...
    'stream_samples',samples,'source_binary_entries',48,'changed_zero_contexts',changed_zero_entries, ...
    'max_independent_prediction_error_W_var',max_prediction_error,'simulink_executed',false,'runtime',version);
save(fullfile(root,'validation','numerical_report.mat'),'report','-v7');
fprintf('PASS DPC3 numerical: %d table contexts, %d stream samples; all 9 pairs, binary limit, ABC prediction and metrics.\n', ...
    report.table_contexts,report.stream_samples);
end
