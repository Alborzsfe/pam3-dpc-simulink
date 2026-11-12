function [metrics,pairs,summary,folder]=RUN_FINAL_DPC_POINT()
% Six native simulations: frozen hysteresis reference versus observer_only.
[metrics,pairs,summary,folder]=RUN_RESEARCH_STAGE4('final_point',15);
end
