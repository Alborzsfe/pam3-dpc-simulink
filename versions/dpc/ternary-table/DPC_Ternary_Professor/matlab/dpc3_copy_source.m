function model = dpc3_copy_source(name,root)
% Isolated model names avoid resolving a different already-open source model.
if bdIsLoaded(name)
    assert(strcmp(get_param(name,'Dirty'),'off'),'DPC3:Unsaved','Save/close unsaved model %s first.',name);
    close_system(name,0);
end
folder = fullfile(root,'models'); if ~exist(folder,'dir'), mkdir(folder); end
file = fullfile(folder,[name '.slx']);
copyfile(fullfile(root,'source_model','DPC_POWER_RAHMAN_original.slx'),file,'f');
load_system(file); model = name;
end
