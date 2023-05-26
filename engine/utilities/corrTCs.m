function h = corrTCs(TCs, TCNames)
    corrTC = corrcoef(TCs, 'rows', 'pairwise');

    % Keep only upper triagonal
    trigon = ~logical(tril(ones(size(corrTC))));
    corrTC(~trigon) = 0;

    % Significance
    dfTC = sum(~isnan(TCs));
    dfTC = min(repmat(dfTC', [1 numel(dfTC)]), repmat(dfTC, [numel(dfTC) 1]));
    tTC = corrTC ./ sqrt((1-corrTC.^2) ./ (dfTC-2));
    pTC = (1 - tcdf(abs(tTC), dfTC-2)) * sum(trigon(:)); % Bonferroni-corrected
    corrTC(pTC>0.05) = 0;

    % Shared variance
    sharedVar = sign(corrTC).*corrTC.^2;
    MsharedVar = mean(abs(sharedVar(sharedVar>0)));

    % Plot
    h = figure;
    set(h, 'Position', [0 0 1200 700])
    imagesc(sharedVar);
    set(gca, 'Xtick', 1:size(corrTC,2), 'Ytick', 1:size(corrTC,1), ...
        'Xticklabel', TCNames, 'XTickLabelRotation', 90,  'Yticklabel', TCNames)
    caxis([-1 1]);
    cmap = jet(128); cmap(64,:) = [1 1 1]; cmap(65,:) = [1 1 1];
    colormap(cmap);
    colorbar;
    title(sprintf('Variance shared by variables. Mean: %0.2f %%', MsharedVar*100))
end
