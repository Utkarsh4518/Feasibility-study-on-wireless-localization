function [cfg, changed] = sync_anchors_with_model(cfg)
% SYNC_ANCHORS_WITH_MODEL  Make cfg.anchor_pos agree with the Simulink model.
%
% [cfg, changed] = sync_anchors_with_model(cfg)
%
% The measurements (RSS, AoA, RTT) in a Simulink run are generated from the
% anchor positions stored in the model's Constant blocks "Anchor k_X" and
% "Anchor k_Y". If the analysis assumes different anchors, AoA and RTT
% positioning are silently wrong (metre-level errors). This reads the model
% values and overrides cfg.anchor_pos, warning if they differed.
%
% The model must already be loaded (load_system). If a block cannot be read,
% cfg is returned unchanged with a warning.

changed = false;
K = size(cfg.anchor_pos, 1);
pos = nan(K, 2);
axes_ = {'X', 'Y'};
for k = 1:K
    for a = 1:2
        blkName = sprintf('Anchor %d_%s', k, axes_{a});
        try
            blk = find_system(cfg.modelName, 'SearchDepth', 3, ...
                'BlockType', 'Constant', 'Name', blkName);
            if isempty(blk)
                continue;
            end
            v = str2double(get_param(blk{1}, 'Value'));
            if isnan(v)
                v = double(slResolve(get_param(blk{1}, 'Value'), blk{1}));
            end
            pos(k, a) = v;
        catch
            % leave NaN -> handled below
        end
    end
end

if any(isnan(pos(:)))
    warning('localization:anchors', ...
        ['Could not read all anchor positions from model "%s"; keeping cfg.anchor_pos. ' ...
         'Check that cfg.anchor_pos matches the Constant blocks "Anchor k_X/Y".'], cfg.modelName);
    return;
end

if ~isequal(size(pos), size(cfg.anchor_pos)) || any(abs(pos(:) - cfg.anchor_pos(:)) > 1e-9)
    warning('localization:anchors', ...
        'cfg.anchor_pos differs from the anchors in model "%s"; using the model values:\n%s', ...
        cfg.modelName, mat2str(pos));
    cfg.anchor_pos = pos;
    cfg.anchor_layout = 'model';
    changed = true;
end
end
