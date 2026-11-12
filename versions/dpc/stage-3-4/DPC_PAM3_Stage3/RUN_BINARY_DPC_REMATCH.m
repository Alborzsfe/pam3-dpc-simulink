function [metrics,pairs,summary,folder]=RUN_BINARY_DPC_REMATCH()
% Retry only the four unmatched 15 mH comparisons, with the same 5% rule.
[metrics,pairs,summary,folder]=RUN_RESEARCH_STAGE4('binary_rematch',15);
end
