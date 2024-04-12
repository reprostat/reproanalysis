function [fig, vRange] = mapOverlay(bg_img, s_img, axis, slices)
    if isempty(bg_img), bg_img = fullfile(spm('Dir'),'toolbox','OldNorm','T1.nii'); end
    if isempty(axis), axis = 'axial'; end

    % Init
    resCMap = 128;
    cmaps = {...
        gradCreate([1 0 0],[1 1 1],resCMap),...
        gradCreate([0 0 1],[1 1 1],resCMap),...
        gradCreate([0 1 0],[1 1 1],resCMap)...
        };
    o = slover;
    o.transform = axis;
    o.figure = spm_figure('CreateWin','Graphics');
    o.slicedef = [...
        -90 2 90;...
        -126 2 90];
    o.slices = slices;

    % Load bg
    V = spm_vol(bg_img);
    Y = spm_read_vols(V);
    o.img = struct(...
        'vol',V,...
        'type','truecolor',...
        'cmap',gray(256),...
        'range',prctile(Y(:),[0.1 99.9]),...
        'prop',1,...
        'hold',0,... % no interpolation
        'background',nan,...
        'nancol',0 ...
        );
    o.img(1).outofrange = {1 256};
    o.cbar = [];

    for i = 1:numel(s_img)
        vRange(i,1:2) = NaN;
        if iscell(s_img{i})
            inp = s_img{i};
            s_img{i} = inp{1};
            if numel(inp) > 1 && ~isempty(inp{2}), cmaps{i} = inp{2}; end
            if numel(inp) > 2 && ~isempty(inp{3}), vRange(i,:) = inp{3}; end
        end
        V = spm_vol(s_img{i});
        Y = spm_read_vols(V);
        o.img(i+1) = o.img(1);
        o.img(i+1).type = 'split';
        o.img(i+1).cmap = cmaps{i};
        o.img(i+1).vol = V;
        if any(isnan(vRange(i,:))),
            vRange(i,:) = [1e-6 prctile(Y(:),98)]; % ensure maximum extent
        end
        % if ~diff(vRange(i,:)), vRange(i,:) = [vRange(i,1)*0.9 vRange(i,2)*1.1]; end
        o.img(i+1).range = vRange(i,:);
        o.img(i+1).outofrange = {0 resCMap};
        o.cbar(end+1) = i+1;
    end
    paint(o);
    fig = o.figure;
end
