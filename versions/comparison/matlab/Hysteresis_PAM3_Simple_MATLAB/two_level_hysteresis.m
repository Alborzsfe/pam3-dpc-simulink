function y = two_level_hysteresis(x, on_point, off_point, initial)
% Explicit discrete two-level hysteresis; no filtering or tuning in this block.
assert(on_point > off_point && any(initial == [-1, 1]));
x = double(x(:));
assert(all(isfinite(x)));
y = zeros(size(x));
previous = initial;
for k = 1:numel(x)
    if x(k) >= on_point
        previous = 1;
    elseif x(k) <= off_point
        previous = -1;
    end
    y(k) = previous;
end
end
