function cleanup=PAM3_SHORT_BUILD_PATHS(cfg)
% Put Stateflow/S-function build products outside a long project directory.
% With an output, restore prior cache settings on scope exit, including error.
% Without an output, retain the short paths for an interactive model preview.
if nargin<1,cfg=struct();end
buildRoot=fullfile(tempdir,'dpc4');
if isfield(cfg,'shortBuildRoot') && ~isempty(cfg.shortBuildRoot)
    buildRoot=char(cfg.shortBuildRoot);
end
cache=fullfile(buildRoot,'c');code=fullfile(buildRoot,'g');
sampleName=repmat('M',1,19);
worstExample=fullfile(cache,'slprj','_sfprj',sampleName,'_self','sfun','src', ...
    ['c1_' sampleName '.c']);
assert(numel(worstExample)<230,'PAM3Full:BuildPath', ...
    'Temporary build path is too long. Set cfg.shortBuildRoot to a short writable absolute folder.');
prior=Simulink.fileGenControl('getConfig');
oldCache=prior.CacheFolder;oldCode=prior.CodeGenFolder;
Simulink.fileGenControl('set','CacheFolder',cache,'CodeGenFolder',code,'createDir',true);
if nargout>0
    cleanup=onCleanup(@()restore_paths(oldCache,oldCode));
end
end

function restore_paths(cache,code)
try
    Simulink.fileGenControl('set','CacheFolder',cache,'CodeGenFolder',code,'createDir',true);
catch problem
    warning('PAM3Full:RestoreCache','Could not restore previous build paths: %s',problem.message);
end
end
