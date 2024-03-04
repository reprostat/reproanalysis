% Add a contrast to a model
%
% inputs
%
%   rap - rap structure
%
%   modulename - module(s) for which this contrast applies. Can be a
%   single module, or multiple modules identified using A regex string.
%   See examples below.
%
%   subjname - subjects for which this contrast applies. Can be a single
%   subject ID (string), a cell array of multiple subject IDs, or a wildcard
%   ("*") to apply constrast to all subjets. See examples below.
%
%   runspec - runs for which this contrast applies.
%   The following options are recognized:
%
%   "*"
%       - contrast applies to all runs defined in the model
%
%   "runs:<run name>[+<run name>[...]]"
%       - contrast applies to multiple named runs
%
%   "runs:<weight>*<run name>[|<weight>*<run name>[...]]"
%       - contrast apples to multiple runs differently weighted
%
%   "uniquebyrun"
%       - contrast is a long vector of weights applied across *all* runs
%
%   See examples below
%
%   conspec - contrast specification. Two options are recognized:
%
%   1) (numeric) vector. This will be zero padded to the number of columns
%   in each run, or to the number of columns in the design matrix
%   for "uniquebyrun"
%
%   2) string specifier in the form
%
%       <weight>*<event name>[|<weight>*<event name>...]
%
%   where "weight" is a signed string expression (e.g., +1, -1, etc)
%
%   this can optionally include main or parametric order:
%
%       <weight>*<event name>m<N>
%       <weight>*<event name>p<N>
%
%   that is:
%
%       <weight>x<event name>[<basis ('b') or modulator ('m')><number of basis/modulator function>]
%
%   for example:
%
%       '+1*ENC_DISPLb1|-1*ENC_FIXATm3')
%
%   where the number of basis/modulator functions can be, e.g.:
%
%     - "b2": 2nd order of the basis function (e.g. temporal derivative of canocical hrf) of the main event
%     - "m3": depending on the number of basis functions and the order of expansions of modulators
%         - dispersion derivative of the 1st order polynomial expansion of the first modulator
%         - 2nd order polynomial expansion of the first modulator (with hrf + temporal derivative)
%         - 3rd order polynomial expansion of the first modulator (with hrf or no convolution)
%         - 1st order polynomial expansion of the second modulator
%         - 2nd order polynomial expansion of the second modulator
%         - 1st order polynomial expansion of the third modulator
%
%   N.B.: Any combination of m<N> and p<N> in the contrast definition will be parsed; therefore, normal event names MUST NOT end with them.
%
%   Additional examples are provided below.
%
%   conname - contrast name. Must be unique within and across runs.
%
%   contype = "T" or "F"
%
% Notes
%
% 1) Call addContrast once for each contrast to be defined in the model
%
% 2) Avoid the use of spaces or special characters (~!@#$%^&*()_+}{|: etc)
%    in contrast and event names. Specifically, avoid the use of >,< and
%    * in the contrast name. Addtionally, while run and/or event names are
%    not requiredto be in uppercase, it is generally good programming practice
%    to always use uppercase for run and event names.
%
% 3) Note the standard first-level contrast module is named firstlevelcontrasts
%    (plural), not firstlevelcontrast (singular)
%
% 4) As a rule, differential contrasts should sum to zero with positive and
%    negative terms summing to 1 and -1, respectively, to avoid scaline issues.
%    See any good text on the contrasts for details.
%
% 5) F-contrast can be specified with multi-line numeric vector or cell of strings.
%
% ------------------------------------------------------------------------------------------------------------------------------------
%
% Examples
%
% Example 1: Assume the model contains two runs named RUN01 and RUN02, each with two events of interest
% called E1 and E2 defined in this order with a single basis function (e.g., "hrf") and the six motion parameters (x,y,x,r,p,j) as nuisance regressors.
%
% 1a) This call defines an omnibus contrast for E1>0 for all subjects:
%    rap = addContrast(rap, 'firstlevelcontrasts', '*', '*', [1], 'E1_G_0', 'T');
%
%   You might be warned [1] is unncecessary and can be replaced by 1:
%    rap = addContrast(rap, 'firstlevelcontrasts', '*', '*', 1, 'E1_G_0', 'T');
%
%   Note in both examples, we avoided the use of ">" in the contrast name, instead using "_G(reater)_"
%
% 1b) This call defines the differential contrast E1>E2:
%    rap = addContrast(rap, 'firstlevelcontrasts', '*', '*', [1 -1], 'E1_G_E2', 'T');
%
%   We can define this contrast for sub-01 only:
%    rap = addContrast(rap, 'firstlevelcontrasts', {'sub-01'}, '*', [1 -1], 'E1_G_E2', 'T');
%
%   We can define this contrast for sub-01 and RUN01 only
%    rap = addContrast(rap, 'firstlevelcontrasts', {'sub-01'}, 'singlerun:RUN01', [1 -1], 'E1_G_E2', 'T');
%
%   If the tasklist contains more than one instance of firstlevelcontrasts, we can define this contrast for all
%   instances using a wildcard:
%    rap = addContrast(rap, 'firstlevelcontrasts_*', {'sub-01'}, 'run:RUN01', [1 -1], 'E1_G_E2', 'T');
%
%   or, we could define this contrast only for a specific instance by including the module numerical suffix:
%    rap = addContrast(rap, 'firstlevelcontrasts_00002', {'sub-01'}, 'run:RUN01', [1 -1], 'E1_G_E2', 'T');
%   would define the contrast only for the second instance of aamod_firstlevel_contrast. Note the module suffix
%   is FIVE characters (i.e. _00001, not _0001 or _001 or _01 or _1)
%
% 1c) It's usually the easiest to define a contrast using a string specifier:
%   rap = addContrast(rap, 'firstlevelcontrasts', '*', '*', '+1*E1|-1*E2', 'E1_G_E2', 'T');
%
% 1d) We could define the differential constast E1>E2 (1a) using 'uniquebyrun':
%   cvec = [1 -1   0 0 0 0 0 0   1 -1   0 0 0 0 0 0    0 0 ];
%   rap = addContrast(rap, 'firstlevelcontrasts', '*', 'uniquebyrun', cvec, 'E1_G_E2', 'T');
%
%   Note the contrast vector must include entries for all columns of the design matrix when using 'uniquebyrun'.
%   In this case, it includes entries for the six motion parameters in each run, and two final zeros for the two constant
%   terms automatically added to the model.However, padding of the contrast vector with zeros is automatic. So we could define:
%   cvec = [1 -1   0 0 0 0 0 0   1 -1 ];
%   rap = addContrast(rap, 'firstlevelcontrasts', '*', 'uniquebyrun', cvec, 'E1_G_E2', 'T');
%
% Example 2 The usefulness of uniquebyrun becomes apparent in a rare case when the contrast contain DIFFERENT events for dufferent runs.
% Consider a model with two runs: RUN01 has events LC (listen to a Clear word) and LN (Listen to a word presented in Noise).
% RUN02 has events RC (Repeat a word presented in Clear) and RN (Repeat a word presented in Noise)
%
% 2a) We could define the contrasts LC>LN and RC>RN seperately using the single run specifier:
%   rap = addContrast(rap, 'firstlevelcontrasts', '*', 'run:RUN01', [1 -1], 'LC_G_LN', 'T');
%   rap = addContrast(rap, 'firstlevelcontrasts', '*', 'run:RUN02', [1 -1], 'RC_G_RN', 'T');
%
% 2b) However, we can't use this approach to define, say, LC>RC, because the contrast vector spans
% runs and the columns mean different things in different runs. The following is WRONG:
%   rap = addContrast(rap, 'firstlevelcontrasts', '*', '*', [1 -1], 'LC_G_RC', 'T'); *** WRONG
%
% Instead we must use uniquebyrun:
%   cvec = [1 0   0 0 0 0 0 0   -1 0    0 0 0 0 0 0    0 0 ];
%   rap = addContrast(rap, 'firstlevelcontrasts', '*', 'uniquebyrun', cvec, 'LC_G_RC', 'T');
%   cvec = [0 1   0 0 0 0 0 0   0 -1    0 0 0 0 0 0    0 0 ];
%   rap = addContrast(rap, 'firstlevelcontrasts', '*', 'uniquebyrun', cvec, 'LN_G_RN', 'T');
%
% (As before, we assume the six motion parameters are included in the model as nuisance events.)
%
% However, a better approach is to define these contrasts using a string specifier. Keep in mind that
% this approach will add all events from all runs with the specified names.
%   rap = addContrast(rap, 'firstlevelcontrasts', '*', 'uniquebyrun', '+1*LC|-1*RC', 'LC_G_RC', 'T');
%   rap = addContrast(rap, 'firstlevelcontrasts', '*', 'uniquebyrun', '+1*LN|-1*RN', 'LN_G_RN', 'T');
%
% Footnote: This is essential when including frame censoring in your workflow, because (unlike the six motion paramters)
% you don't know a priori how many nuisance events will appear in each run. As such, you would not be able to
% define a contrast spanning multiple runs using a zero-padded vector.
%
% ------------------------------------------------------------------------------------------------------------------------------------

function rap = addContrast(rap, modulename, subjname, runspec, conspec, conname, contype)

    % Regexp for number at the end of a module name, if present in format _%05d (e.g. _00001)
    m1 = regexp(modulename, '_\d{5,5}$');

    % Or, we could use '_*' at the end of the module name to specify all modules with that name
    m2 = regexp(modulename, '_\*$');

    % Or, we might specify certain modules with  '_X/X/X' (e.g. _00001/00002/00004)
    m3 = regexp(modulename, '[_/](\d+)', 'tokens');

    if ~isempty(m1)
        moduleindex = str2num(modulename(m1+1:end));
        modulename = modulename(1:m1-1);

    elseif ~isempty(m2)
        modulename = modulename(1:m2-1);
        moduleindex = 1:length(find(strcmp({rap.tasklist.main.module.name}, modulename)));

    elseif ~isempty(m3)
        modulename = modulename(1:find(modulename=='_',1,'last')-1);
        moduleindex = cellfun(@str2num, [m3{:}]);

    else
        moduleindex = 1;
    end

    run.names = {};
    run.weights = [];

    runspec = strsplit(runspec,':');
    format = runspec{1};
    switch format
        case 'runs'
            for runspec = strsplit(runspec{2},'|')
                specs = strsplit(runspec{1},'*');
                run.names = [run.names specs(end)];
                if numel(specs) == 2
                    run.weights = [run.weights str2double(specs{1})];
                else
                    run.weights = [run.weights 1];
                end
            end
        case '*'
            run.names = {rap.acqdetails.fmriruns.name};
            run.weights = ones(1,numel(run.names));
    end

    if ~iscell(subjname), subjname = {subjname}; end
    if subjname{1} == '*', subjname = {rap.acqdetails.subjects.subjname}; end

    for subj = subjname
        % check if (any of) the run(s) (of the subject) missing
        if ~isempty(run.names)
            missingRuns = setdiff(run.names,{rap.acqdetails.fmriruns.name});
            if ~isempty(missingRuns), logging.error(['missing specified runs in contrast:' sprintf(' %s',missingRuns{:})]); end
            [~, indRunInSpec] = intersect({rap.acqdetails.fmriruns.name},run.names,'stable');
            [~,subjIndRun] = getNByDomain(rap,'fmrirun',find(strcmp({rap.acqdetails.subjects.subjname},subj{1})));
            indSubjMissingRun = setdiff(indRunInSpec,subjIndRun);
            if ~isempty(indSubjMissingRun), logging.error([sprintf('missing acquired runs for subject %s in contrast:',subj{1}) sprintf(' %s',rap.acqdetails.fmriruns(indSubjMissingRun).name)]); end
        end

        % find model that corresponds and add contrast to this if it exists
        for mInd = moduleindex
            % clear empty model (first call)
            if isempty(rap.tasksettings.(modulename)(mInd).contrast(1).subject), rap.tasksettings.(modulename)(mInd).contrast(1) = []; end

            whichcontrast = strcmp({rap.tasksettings.(modulename)(mInd).contrast.subject},subj{1});
            if ~any(whichcontrast)
                % The first one is usually empty, makes for a good template in case the structure changes
                emptycon=[];
                emptycon.subject=subj{1};
                emptycon.con.format=format;
                emptycon.con.vector=conspec;
                emptycon.con.fmrirun=run;
                emptycon.con.type=contype;
                emptycon.con.name=conname;
                rap.tasksettings.(modulename)(mInd).contrast(end+1)=emptycon;
            else
                rap.tasksettings.(modulename)(mInd).contrast(whichcontrast).con(end+1).format=format;
                rap.tasksettings.(modulename)(mInd).contrast(whichcontrast).con(end).vector=conspec;
                rap.tasksettings.(modulename)(mInd).contrast(whichcontrast).con(end).fmrirun=run;
                rap.tasksettings.(modulename)(mInd).contrast(whichcontrast).con(end).type=contype;
                rap.tasksettings.(modulename)(mInd).contrast(whichcontrast).con(end).name=conname;
            end
        end
    end
 end
