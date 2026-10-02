function cfg = set_anchor_layout(cfg, name)
% SET_ANCHOR_LAYOUT  Switch cfg to a named anchor layout (see anchor_layouts).
%
% cfg = set_anchor_layout(cfg, 'four_corners')

cfg.anchor_layout = name;
cfg.anchor_pos = anchor_layouts(name);
end
