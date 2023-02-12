% Scaling - 0: do not scale, 1: autoscale to defWIDTH, [0< <1]: autoscale to scale*defWIDTH
function rap = addReportMedia(rap,reportStore,fnMedium,scaling)

defWIDTH=1600;

if nargin < 4, scaling = 1; end;

if ~startsWith(fnMedium,rap.acqdetails.root)
    logging.error('Cannot relate file %s to directory root %s',fnMedium,rap.acqdetails.root);
end

[~, baseFn, ext] = fileparts(fnMedium);
switch ext
    case {'.png', '.jpg', '.jpeg'}
        reportStr = sprintf('<cite>%s</cite><img src',baseFn);
        repClose = '><br>';
        mediumSize = size(imread(fnMedium));
        if scaling == 1 && (mediumSize(2) <= defWIDTH), scaling = 0; end
    case {'.avi' '.mp4'}
        reportStr = '<a href';
        repClose = sprintf('>Play video: %s</a><br>',baseFn);
        scaling = 0;
    otherwise
        logging.error('Unknown format: %s',e);
end

switch scaling
    case 1
        reportStr = [reportStr '="' fnMedium '" ' sprintf('width=%d height=%d',defWIDTH,round(defWIDTH/mediumSize(2)*mediumSize(1))) repClose];
    case 0
        reportStr = [reportStr '="' fnMedium '"' repClose];
    otherwise
        reportStr = [reportStr '="' fnMedium '" ' sprintf('width=%d height=%d',round(mediumSize(2)*scaling),round(mediumSize(1)*scaling)) repClose];
end

addReport(rap,reportStore,reportStr);

rap.report.attachment{end+1} = fnMedium;

