function model = OPEN_DPC_PAM3()
% Rebuild with native Simulink API; compile before presenting the model.
root = fileparts(mfilename('fullpath'));
assignin('base','Ts_DPC',1/40000);
assignin('base','e',50);
% Load uniquely named COPIES. The professor's DPC_Three_Level may remain open.
source = fullfile(root,'DPC_Three_Level.slx');
load_comparison_copy(source, root, 'DPC_PAM3_Baseline');
model = 'DPC_PAM3_Mapped';
load_comparison_copy(source, root, model);
chart = find(sfroot,'-isa','Stateflow.EMChart', ...
    'Path',[model '/MATLAB Function3']);
assert(numel(chart)==1,'DPCMapping:Chart','Expected one controller chart.');
chart.Script = fileread(fullfile(root,'controller_pam3.m'));
set_param(model,'SimulationCommand','update');
save_system(model);
open_system(model);
open_system([model '/MATLAB Function3']);
fprintf('PAM3 model compiled. Run RUN_DPC_PAM3_COMPARE for numerical comparison.\n');
end

function load_comparison_copy(source, root, name)
destination = fullfile(root,[name '.slx']);
if bdIsLoaded(name)
    loadedPath = get_param(name,'FileName');
    if ispc, samePath = strcmpi(loadedPath,destination);
    else, samePath = strcmp(loadedPath,destination); end
    if ~samePath
        error('DPCMapping:OtherCopyOpen', ...
            ['A comparison model named %s is open from another folder: %s. ' ...
             'Save any edits, close that comparison model, and retry. ' ...
             'The professor''s DPC_Three_Level can remain open.'],name,loadedPath);
    end
    return;
end
% Reuse an existing comparison file; never overwrite or close a loaded model.
if ~isfile(destination)
    [ok,message] = copyfile(source,destination);
    assert(ok,'DPCMapping:Copy','Cannot create comparison copy: %s',message);
end
load_system(destination);
end
