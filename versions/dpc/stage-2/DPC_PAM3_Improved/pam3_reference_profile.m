function [p,q]=pam3_reference_profile(t,stepTime,pBefore,pAfter,qBefore,qAfter)
% Explicit independent setpoints; no coupling to the outer voltage PI.
if t<stepTime,p=pBefore;q=qBefore;else,p=pAfter;q=qAfter;end
end
