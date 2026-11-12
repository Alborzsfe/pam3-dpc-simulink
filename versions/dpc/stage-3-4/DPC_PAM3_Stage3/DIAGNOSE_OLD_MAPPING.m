function T=DIAGNOSE_OLD_MAPPING()
% Run the original receiver itself in MATLAB; no Simulink is required.
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'original_receiver'));
cfg=pam3_config();
inputs={.02*ones(100,1),-.02*ones(100,1), ...
 [zeros(10,1);repmat([.015;.0154],50,1)], ...
 [zeros(10,1);.02;.015*ones(50,1)]};
names={'constant_positive_start','constant_negative_start','positive_small_ripple','falling_still_positive'};
rows=cell(4,1);
for c=1:4
 x=inputs{c};s=pam3_initial_state(cfg);held=0;old=0;rawMismatch=0;finalMismatch=0;first=-1;
 for j=1:numel(x)
  e=x(j);adc=min(255,max(0,floor(117.5+2250*e+.5)));
  [s,y]=pam3_step(s,adc,1,cfg);
  if old==0
   if e>=.01,ref=1;elseif e<=-.01,ref=-1;else,ref=0;end
  elseif old==1
   if e<=-.01,ref=-1;elseif e<=.005,ref=0;else,ref=1;end
  else
   if e>=.01,ref=1;elseif e>=-.005,ref=0;else,ref=-1;end
  end
  old=ref;
  if y(1),held=y(2);if first==-1,first=j-1;end;end
  rawMismatch=rawMismatch+(y(5)~=ref);finalMismatch=finalMismatch+(held~=ref);
 end
 rows{c}=struct('Case',string(names{c}),'Samples',numel(x), ...
  'RawMismatchTicks',rawMismatch,'FinalMismatchTicks',finalMismatch,'FirstValidTickZeroBased',first);
end
T=struct2table(vertcat(rows{:}));disp(T);
folder=fullfile(root,'results');if ~isfolder(folder),mkdir(folder);end
writetable(T,fullfile(folder,'old_mapping_logic_tests.csv'));
end
