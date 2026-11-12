function code=PAM3_RENDER_FULL_FEATURES(code,cfg)
% Resolve a fixed-size parameter vector and append the single shared kernel.
f=pam3_full_feature_config();
if isfield(cfg,'fullFeatures'),f=cfg.fullFeatures;end
p=PAM3_FULL_FEATURE_VECTOR(f);
assert(contains(code,'__FULL_CFG__'),'PAM3Full:Template','Missing full-feature configuration token.');
literal=['[' sprintf('%.17g;',p) ']'];
code=strrep(code,'__FULL_CFG__',literal);
root=fileparts(mfilename('fullpath'));
code=[code newline fileread(fullfile(root,'pam3_feature_step.m'))];
end
