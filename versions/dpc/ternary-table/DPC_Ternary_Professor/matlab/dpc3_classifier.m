function state = dpc3_classifier(previous,error_value,binary_reference,c)
assert(ismember(previous,[-1,0,1]) && isfinite(error_value));
assert(ismember(binary_reference,[0,1]));
if ~c.zero_enabled
    state = 2*binary_reference-1; % Exact binary limit through the NEW table.
    return;
end
x = error_value-c.center;
% Outer comparisons match the source Relay's STRICT switching convention.
if x > c.outer
    state = 1;
elseif x < -c.outer
    state = -1;
elseif previous == 1 && x > c.inner
    state = 1;
elseif previous == -1 && x < -c.inner
    state = -1;
else
    state = 0;
end
end
