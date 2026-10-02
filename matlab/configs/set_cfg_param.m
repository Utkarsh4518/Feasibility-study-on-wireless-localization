function cfg = set_cfg_param(cfg, param, value)
% SET_CFG_PARAM  Set a (possibly nested) config field from a dotted path.
%
% cfg = set_cfg_param(cfg, 'noise_scale.aoa', 2)
% cfg = set_cfg_param(cfg, 'anchor_layout', 'triangle')   % also updates anchor_pos
%
% Errors if the path does not exist, so a typo cannot silently sweep nothing.

if strcmp(param, 'anchor_layout')
    cfg = set_anchor_layout(cfg, value);
    return;
end
parts = strsplit(param, '.');
node = cfg;
for i = 1:numel(parts)
    if ~isstruct(node) || ~isfield(node, parts{i})
        error('localization:config', 'Config has no field "%s".', param);
    end
    node = node.(parts{i});
end
cfg = setfield(cfg, parts{:}, value); %#ok<SFLD>
end
