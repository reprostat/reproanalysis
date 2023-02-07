function [val, index] = getSetting(rap,settingstring,varargin)
% Obtain (data-specific) task setting while running the task
% [val, index] = getSetting(rap,settingstring);
% [val, index] = getSetting(rap,settingstring,index);
% [val, index] = getSetting(rap,settingstring,'subject',subj);
% [val, index] = getSetting(rap,settingstring,'fmrirun',[subj, run]);
    if ~isfield(rap.tasklist.currenttask,'settings')
        logging.warning('No setting is not specified.');
        val = [];
        return
    end

    % Parse setting path
    settingpath = strsplit(settingstring,'.');

    % Obtain setting
    val = rap.tasklist.currenttask.settings;
    for f = settingpath
        if isfield(val,f{1})
            val = val.(f{1});
        else
            logging.warning('Setting <%s> is not specified.',settingstring);
            val = [];
            return
        end
    end

    if nargin > 2 % index
        if numel(varargin) == 1
            index = varargin{1};
            if ischar(val)
                val = textscan(val,'%s');
                val = val{1}';
            elseif isnumeric(val) || isstruct(val)
                val = num2cell(val);
            end
        else
            switch varargin{1}
                case 'subject'
                    index = [];
                    if ~isfield(val,'subject'), logging.warning('There is no subject-specific setting.');
                    else
                        index = find(strcmp({val.subject},rap.acqdetails.subjects(varargin{2}).subjname) | strcmp({val.subject},'*'));
                    end
                    if isempty(index)
                        logging.warning('Setting <%s> for %s is not specified.',settingstring,rap.acqdetails.subjects(varargin{2}).subjname);
                        val = [];
                        return
                    end
                    if numel(index) > 1
                        logging.warning('More than 1 setting <%s> for %s is specified -> only the first will be returned.',settingstring,rap.acqdetails.subjects(varargin{2}).subjname);
                        index = index(1);
                    end
                 case {'fmrirun' 'specialrun'}
                    index = [];
                    if ~isfield(val,varargin{1}), logging.warning('There is no %s-specific setting.',varargin{1});
                    else
                        index = find((strcmp({val.subject},rap.acqdetails.subjects(varargin{2}(1)).subjname) | strcmp({val.subject},'*')) &...
                            (strcmp({val.(varargin{1})},getRunName(rap,varargin{2}(2))) | strcmp({val.(varargin{1})},'*')));
                    end
                    if isempty(index)
                        logging.warning('Setting <%s> for %s is not specified!',settingstring,getRunName(rap,varargin{2}(2)));
                        val = [];
                        return
                    end
            end
            val = num2cell(val);
        end

        try val = val{index};
        catch E
            logging.warning('%s(%d) has been requested, but only %d value(s) are defined in the current settings.\n\tThe first value (%0.9g) will be returned.', settingstring, index, numel(val),val{1});
            val = val{1};
        end
    end
end

