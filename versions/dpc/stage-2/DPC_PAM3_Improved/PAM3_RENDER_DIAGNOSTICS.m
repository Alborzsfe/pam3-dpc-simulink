function code=PAM3_RENDER_DIAGNOSTICS(code,template,method,cfg)
% Append a read-only 14-element diagnostic output; retain the first 10 ports.
scale=1;
if strcmp(method,'baseline') && isfield(cfg,'baselineBandScale')
    scale=cfg.baselineBandScale;
end
validateattributes(scale,{'numeric'},{'scalar','real','finite','positive'});
code=strrep(code,'sp,sq,sec]','sp,sq,sec,diagnostics]');
for name={'hP_in','hQ_in','hP_out','hQ_out'}
    if contains(name{1},'_in'),value=.01*scale;else,value=.005*scale;end
    code=regexprep(code,[name{1} '\s*=\s*0\.0(?:10|05);'], ...
        sprintf('%s = %.17g;',name{1},value),'once');
end
setup=['studyWeightP=0;studyWeightQ=0;studySigmaP=0;studySigmaQ=0;' newline];
if strcmp(template,'predictive')
    code=strrep(code,'[observerState,Pctrl,Qctrl]=pam3_power_predict', ...
        '[observerState,Pctrl,Qctrl,studyWeightP,studyWeightQ]=pam3_power_predict');
    setup=['studySigmaP=sqrt(max(0,observerState(6)));' newline ...
        'studySigmaQ=sqrt(max(0,observerState(7)));' newline];
elseif strcmp(template,'fast')
    code=strrep(code,'[powerStateP,sp] = pam3_power_step', ...
        '[powerStateP,sp,hP_in,hP_out] = pam3_power_step');
    code=strrep(code,'[powerStateQ,sq] = pam3_power_step', ...
        '[powerStateQ,sq,hQ_in,hQ_out] = pam3_power_step');
    setup=[setup 'studySigmaP=sqrt(max(0,powerStateP(6)));' newline ...
        'studySigmaQ=sqrt(max(0,powerStateQ(6)));' newline];
end
% e_used = e_raw - centerShift. All four effective raw-error boundaries
% for an axis are centerShift + [+hEnter,+hExit,-hExit,-hEnter].
diagnostic=[setup ...
    'diagnostics=[(Pref-P)/Pbase;(Qref-Q)/Qbase;eP_pu;eQ_pu;' ...
    'hP_in;hP_out;hQ_in;hQ_out;(Pctrl-P)/Pbase;(Qctrl-Q)/Qbase;' ...
    'studyWeightP;studyWeightQ;studySigmaP;studySigmaQ];' newline];
anchor='valid_old = true;';
assert(contains(code,anchor),'PAM3Study:Diagnostics','Missing controller end anchor.');
code=strrep(code,anchor,[anchor newline diagnostic]);
end
