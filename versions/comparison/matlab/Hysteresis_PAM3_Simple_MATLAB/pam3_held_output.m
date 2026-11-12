function [held, decoded, valid] = pam3_held_output(adc, cfg)
% Use the ORIGINAL final symbol output, including its processing delay.
% Symbols arrive only on valid events. Hold each one until the next event.
decoded = pam3_decode(adc, cfg);
n = numel(adc);
valid = decoded.trace(1:n, 1) ~= 0;
held = zeros(n, 1);
previous = 0;
for k = 1:n
    if valid(k)
        previous = decoded.trace(k, 2);
    end
    held(k) = previous;
end
% Do not place symbols at decoded.points: these are past acquisition indices,
% not the later causal availability times. Tail-flush rows are not measured.
end
