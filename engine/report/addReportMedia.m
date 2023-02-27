% Scaling - 0: do not scale, 1: autoscale to defWIDTH, [0< <1]: autoscale to scale*defWIDTH
function rap = addReportMedia(rap,reportStore,fnAll,varargin)

    defWIDTH=1600;

    argParse = inputParser;
    argParse.addParameter('scaling',1,@isnumeric);
    argParse.addParameter('displayFileName',1,@(x) isnumeric(x) | islogical(x));
    argParse.parse(varargin{:});
    scaling = argParse.Results.scaling;

    fnAll = cellstr(fnAll);
    nImg = numel(fnAll) - sum(endsWith(fnAll,{'.avi' '.mp4'}));

    if nImg > 1, addReport(rap,reportStore,'<table><tr>'); end

    for fnMedium = reshape(fnAll,1,[])
        if isempty(fnMedium{1}) || ~exist(fnMedium{1},'file')
            logging.warning('Cannot find file %s',fnMedium{1});
        end
        if ~startsWith(fnMedium{1},rap.acqdetails.root)
            logging.warning('Cannot relate file %s to directory root %s',fnMedium{1},rap.acqdetails.root);
        end

        [~, baseFn, ext] = fileparts(fnMedium{1});
        if ~argParse.Results.displayFileName, baseFn = ''; end
        switch ext
            case {'.png', '.jpg', '.jpeg'}
                reportStr = sprintf('<cite>%s</cite><img src',baseFn);
                repClose = '><br>';
                mediumSize = size(imread(fnMedium{1}));
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
                reportStr = [reportStr '="' fnMedium{1} '" ' sprintf('width=%d height=%d',defWIDTH,round(defWIDTH/mediumSize(2)*mediumSize(1))) repClose];
            case 0
                reportStr = [reportStr '="' fnMedium{1} '"' repClose];
            otherwise
                scaling = argParse.Results.scaling*defWIDTH/mediumSize(2);
                reportStr = [reportStr '="' fnMedium{1} '" ' sprintf('width=%d height=%d',round(mediumSize(2)*scaling),round(mediumSize(1)*scaling)) repClose];
        end

        % Video MUST belong to the previous image -> no new table item
        if nImg > 1 && ~startsWith(reportStr,'<a href'), reportStr = ['<td>' reportStr '</td>']; end
        addReport(rap,reportStore,reportStr);

        rap.report.attachment(end+1) = fnMedium;
    end

    if nImg > 1, addReport(rap,reportStore,'</tr></table>'); end
 end
