function output = dpc_relay(error_signal, on_value, off_value, on_output, off_output)
% Relay semantics: initial OFF, strict >ON / <OFF, equality keeps state.
x = double(error_signal(:));
assert(all(isfinite(x)) && on_value > off_value);
output = zeros(size(x));
active = false;
for k = 1:numel(x)
    if x(k) > on_value
        active = true;
    elseif x(k) < off_value
        active = false;
    end
    if active
        output(k) = on_output;
    else
        output(k) = off_output;
    end
end
end
