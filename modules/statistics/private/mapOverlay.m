function [fig, vRange] = mapOverlay(bg_img, s_img, axis, slices)
    vRange = [-Inf Inf];
    if isempty(bg_img), bg_img = fullfile(spm('Dir'),'toolbox','OldNorm','T1.nii'); end
    if isempty(axis), axis = 'axial'; end

    % Init
    cmaps = {...
        gradCreate([1 0 0],[1 1 1],64),...
        gradCreate([0 0 1],[1 1 1],64),...
        gradCreate([0 1 0],[1 1 1],64)...
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
        if iscell(s_img{i})
            [s_img{i}, cmaps{i}] = deal(s_img{i}{:});
        end
        V = spm_vol(s_img{i});
        Y = spm_read_vols(V);
        o.img(i+1) = o.img(1);
        o.img(i+1).type = 'split';
        o.img(i+1).cmap = cmaps{i};
        o.img(i+1).vol = V;
        vRange(i,:) = [min(Y(Y>0)) max(Y(:))];
        o.img(i+1).range = [1e-6 vRange(i,2)]; % ensure maximum extent
        % if ~diff(o.img(i+1).range), o.img(i+1).range = [o.img(i+1).range(1)*0.9 o.img(i+1).range(2)*1.1]; end
        o.img(i+1).outofrange = {0 64};
        o.cbar(end+1) = i+1;
    end
    paint(o);
    fig = o.figure;
end
