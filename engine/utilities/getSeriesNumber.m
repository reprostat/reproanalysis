function [visitNum, seriesNum] = getSeriesNumber(rap,subj,run)
    runs = rap.acqdetails.subjects(subj).(strrep(getRunType(rap),'run','series'));

    outRun = run;
    for visitNum = 1:numel(rap.acqdetails.subjects(subj).mridata)
        currRuns = runs{visitNum};
        outRun = outRun - numel(currRuns);
        if outRun < 1
            outRun = numel(currRuns) + outRun;
            break;
        end
    end

    if iscell(currRuns), seriesnum = runs{visitNum}{outRun};
    else, seriesnum = runs{visitNum}(outRun);
    end
end
