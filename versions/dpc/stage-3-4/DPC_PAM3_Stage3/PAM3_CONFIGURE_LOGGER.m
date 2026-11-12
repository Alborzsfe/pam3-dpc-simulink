function PAM3_CONFIGURE_LOGGER(path,variableName,Ts)
% A sink-only sampling clock: does not change the controller or plant rates.
validateattributes(Ts,{'numeric'},{'scalar','real','finite','positive'});
set_param(path,'VariableName',variableName,'SaveFormat','Structure With Time', ...
    'MaxDataPoints','inf','Decimation','1','SampleTime',num2str(Ts,17));
end
