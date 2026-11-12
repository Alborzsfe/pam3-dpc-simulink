function [metrics,pairs,summary,folder]=RUN_BINARY_DPC_POINTS()
% Compare the four highlighted operating conditions with binary hysteresis.
[metrics,pairs,summary,folder]=RUN_RESEARCH_STAGE4('binary_points',[10 15]);
end
