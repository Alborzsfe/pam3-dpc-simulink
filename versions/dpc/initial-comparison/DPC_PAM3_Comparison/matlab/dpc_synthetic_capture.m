function capture = dpc_synthetic_capture()
% Saved deterministic educational input. NEVER label this as converter data.
root = fileparts(fileparts(mfilename('fullpath')));
data = load(fullfile(root, 'data', 'comparison_fixtures.mat'));
capture = data.demo;
capture.kind = 'synthetic_educational';
end
