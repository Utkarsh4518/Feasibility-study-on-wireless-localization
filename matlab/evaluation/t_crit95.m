function t = t_crit95(dof)
% T_CRIT95  Two-sided 95% Student-t critical value (no Statistics Toolbox).
%
% t = t_crit95(dof)
%
% Table lookup for dof = 1..30, 1.96 beyond; NaN for dof < 1.

tab = [12.706 4.303 3.182 2.776 2.571 2.447 2.365 2.306 2.262 2.228 ...
        2.201 2.179 2.160 2.145 2.131 2.120 2.110 2.101 2.093 2.086 ...
        2.080 2.074 2.069 2.064 2.060 2.056 2.052 2.048 2.045 2.042];
if dof < 1
    t = NaN;
elseif dof <= 30
    t = tab(dof);
else
    t = 1.96;
end
end
