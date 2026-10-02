function sig = getSignalIfExists(out, name)
% GETSIGNALIFEXISTS  Safely fetch a signal from Simulink Dataset logsout.
%
% sig = getSignalIfExists(out, name)
%
% Inputs:
%   out  - Simulink simulation output struct (must have .logsout)
%   name - char array: element name in logsout
%
% Output:
%   sig  - Signal element, or [] if not found / logsout missing

sig = [];
try
    if isprop(out, 'logsout') && ~isempty(out.logsout)
        sig = getElement(out.logsout, name);
    end
catch
    sig = [];
end
end
