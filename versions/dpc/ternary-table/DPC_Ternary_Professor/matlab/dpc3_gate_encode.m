function gates = dpc3_gate_encode(legs)
legs = double(legs(:)); assert(numel(legs) == 3 && all(ismember(legs,[0,1])));
gates = reshape([legs,1-legs]',6,1); % Exact original [p1,!p1,p3,!p3,p5,!p5].
end
