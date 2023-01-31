% Adds an event to a model
% function rap = addEvent(rap,modulename,subject,run,eventname,ons,dur,parametric)
%
% modulename=name of module (e.g.,'firstlevelmodel') for which this
%   event applies
% subject=subject for whom this model applies
% run=run for which this applies
% eventname=name of the stimulus or response event
% ons=event onset times (in seconds or scans accoding to xBF.UNITS). Does not need to be sorted
% dur=event durations (in seconds or scans accoding to xBF.UNITS), either a single element (if all
%   occurrences have the same duration) or in order that corresponds to ons
% parametric = (multiple) parametric modulator with 3 fields
%   parametric(n).name = name of the modulator or 'time' (automatic temporal modulation)
%   parametric(n).P = modulator vector (one entry for each non-dummy scan) itself or empty (automatic temporal modulation)
%   parametric(n).h = polynomial expansion
%
% Examples
%  rap=addEvent(rap,'firstlevelmodel','*','*','listening',ons,dur);
%  rap=addEvent(rap,'firstlevelmodel','01','audio','listening',ons,dur,parametric);

function rap = addEvent(rap,modulename,subject,run,eventname,ons,dur,parametric)

% Regexp for number at the end of a module name, if present in format _%05d (e.g, _00001)
m1 = regexp(modulename, '_\d{5,5}$');

% Or, we could use '_*' at the end of the module name to specify all modules with that name
m2 = regexp(modulename, '_\*$');

% Or, we might specify specific modules with  '_X/X/X'
m3 = regexp(modulename, '[_/](\d+)', 'tokens');

if ~isempty(m1)
    moduleindex = str2num(modulename(m1+1:end));
    modulename = modulename(1:m1-1);

elseif ~isempty(m2)
    modulename = modulename(1:m2-1);
    moduleindex = 1:length(find(strcmp({aap.tasklist.main.module.name}, modulename)));

elseif ~isempty(m3)
    modulename = modulename(1:find(modulename=='_',1,'last')-1);
    moduleindex = cellfun(@str2num, [m3{:}]);

else
    moduleindex = 1;
end

if ~exist('parametric','var')
    parametric = [];
end

% sort the onsets, and apply same reordering to dur & parametric
[ons, ind]=sort(ons);
if numel(dur)>1
    dur=dur(ind);
end;
for p = 1:numel(parametric)
    if strcmp(parametric(p).name,'time') && isempty(parametric(p).P) % automatic temporal modulation
        parametric(p).name = 'time_toScale'; % to scale
        parametric(p).P = ons;
    else
        parametric(p).P = parametric(p).P(ind);
    end
end

% find models that corresponds and add events if they exist
for mInd = moduleindex

    % clear empty model (first call)
    if isempty(rap.tasksettings.(modulename)(mInd).model.subject), rap.tasksettings.(modulename)(mInd).model(1) = []; end

    whichmodel=[strcmp({rap.tasksettings.(modulename)(mInd).model.subject},subject)] & [strcmp({rap.tasksettings.(modulename)(mInd).model.fmrirun},run)];
    if ~any(whichmodel)
        emptymod=[];
        emptymod.subject=subject;
        emptymod.fmrirun=run;
        emptymod.event.name=eventname;
        emptymod.event.ons=ons;
        emptymod.event.dur=dur;
        emptymod.event.modulation=parametric;
        rap.tasksettings.(modulename)(mInd).model(end+1)=emptymod;
    else
        rap.tasksettings.(modulename)(mInd).model(whichmodel).event(end+1).name=eventname;
        rap.tasksettings.(modulename)(mInd).model(whichmodel).event(end).ons=ons;
        rap.tasksettings.(modulename)(mInd).model(whichmodel).event(end).dur=dur;
        rap.tasksettings.(modulename)(mInd).model(whichmodel).event(end).modulation=parametric;
    end

end
