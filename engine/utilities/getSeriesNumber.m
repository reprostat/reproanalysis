function [visitNum, seriesNum] = getSeriesNumber(rap,subj,varargin)
    switch numel(varargin)
        case 1
            runs = rap.acqdetails.subjects(subj).(strrep(getRunType(rap),'run','series'));
            run = varargin{1}
        case 2
            runs = rap.acqdetails.subjects(subj).(varargin{1});
            run = varargin{2};
    end


    outRun = run;
    for visitNum = 1:numel(rap.acqdetails.subjects(subj).subjid)
        currRuns = runs{visitNum};
        outRun = outRun - numel(currRuns);
        if outRun < 1
            outRun = numel(currRuns) + outRun;
            break;
        end
    end

    if iscell(currRuns), seriesNum = runs{visitNum}{outRun};
    else, seriesNum = runs{visitNum}(outRun);
    end
end
