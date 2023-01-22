function fg = realignPlot(mv)
% mv can be
%   an array (strvcat or cell) of file names of movement parameters
%   a cell array of matrices containing the parameters

%% Threshold for excessive movement
QA_TRANSL = 2;
QA_ROT = 8;

%% Input
if ischar(mv), mv = cellstr(mv); end

movePars0 = [];
for s = 1:numel(mv)
    if isstr(mv{s}), mv{s} = load(deblank(mv{s})); end
    movePars0 = [movePars0; mv{s}];
end

%% Data
% Movements
% - relative to the first
movePars = movePars0 - repmat(movePars0(1,:),[size(movePars0,1) 1]);

% - convert to degrees
movePars(:,4:6) = movePars(:,4:6)/pi*180;

mvmean = mean(movePars);
mvmax = max(movePars);
mvstd = std(movePars);

DmovePars = movePars(:,1:3);
RmovePars = movePars(:,4:6);

% - framewise displacement
FD = [0;sum(abs(diff(movePars0 * diag([1 1 1 50 50 50]))),2)];

%% Plot
fg = spm_figure('CreateWin','Graphics');

% - translation over time series
ax = axes('Position',[0.1 0.65 0.8 0.2],'Parent',fg,'XGrid','on','YGrid','on');
plot(DmovePars,'Parent',ax); hold on;
plot(1:size(DmovePars,1),-QA_TRANSL*ones(1,size(DmovePars,1)),'k','Parent',ax)
plot(1:size(DmovePars,1),QA_TRANSL*ones(1,size(DmovePars,1)),'k','Parent',ax)
set(get(ax,'Title'),'String','Displacement (mm) [x: blue; y: green; z:red]','FontSize',16,'FontWeight','Bold');
set(get(ax,'Xlabel'),'String','image');
set(get(ax,'Ylabel'),'String','mm');
YL = get(ax,'YLim');
ylim([min(-(QA_TRANSL+0.5),YL(1)) max((QA_TRANSL+0.5),YL(2))]);

% - rotation over time series
ax = axes('Position',[0.1 0.35 0.8 0.2],'Parent',fg,'XGrid','on','YGrid','on');
plot(RmovePars,'Parent',ax); hold on;
plot(1:size(RmovePars,1),-QA_ROT*ones(1,size(RmovePars,1)),'k','Parent',ax)
plot(1:size(RmovePars,1),QA_ROT*ones(1,size(RmovePars,1)),'k','Parent',ax)
set(get(ax,'Title'),'String','Rotation (deg) [r: blue; p: green; j:red]','FontSize',16,'FontWeight','Bold');
set(get(ax,'Xlabel'),'String','image');
set(get(ax,'Ylabel'),'String','degrees');
YL = get(ax,'YLim');
ylim([min(-(QA_ROT+0.5),YL(1)) max((QA_ROT+0.5),YL(2))]);

% - framewise displacement
ax = axes('Position',[0.1 0.05 0.8 0.2],'Parent',fg,'XGrid','on','YGrid','on');
% scale rotation to translation based on the ratio of thresholds (see above)
plot(FD,'Parent',ax); hold on;
plot(1:size(FD,1),-QA_TRANSL*ones(1,size(FD,1)),'k','Parent',ax)
plot(1:size(FD,1),QA_TRANSL*ones(1,size(FD,1)),'k','Parent',ax)
set(get(ax,'Title'),'String','Framewise displacement (a.u.)','FontSize',16,'FontWeight','Bold');
set(get(ax,'Xlabel'),'String','image');
set(get(ax,'Ylabel'),'String','a.u. (mm + scaled degrees)');
YL = get(ax,'YLim');
ylim([min(-(QA_TRANSL+0.5),YL(1)) max((QA_TRANSL+0.5),YL(2))]);
