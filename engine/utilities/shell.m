% wrapper for shell call
%
function [s,w] = shell(cmd,varargin)

    global reproacache

    quiet = any(strcmp(varargin,'quiet'));
    ignoreerrors = any(strcmp(varargin,'ignoreerror'));

    % Prepare
    if isa(reproacache,'cacheClass') && reproacache.isKey('shellprefix')
        prefix = reproacache('shellprefix');
    else
        % determine active shell
        if ispc()
            prefix = '';
        else
            [~,w]=system('ps -p $$');
            w = regexp(w,'(?<= )[a-z]*$','match'); w = w{1}; % select  last word
            switch w
                case {'sh' 'bash'}
                    prefix = 'export TERM=dumb;';
                case {'csh' 'tcsh'}
                    prefix = 'setenv TERM dumb;';
                otherwise
                    logging.error('unknown shell: %s', strrep(w,'\','\\'));
            end
        end

        % cache it
        if isa(reproacache,'cacheClass'), reproacache('shellprefix') = prefix; end
    end

    % Run
    if ~quiet, logging.info('Running: %s', strrep([prefix cmd],'\','\\')); end
    [s, w]=system([prefix cmd]);

    % Special cases
    % - ensure shell-init error to be handled
    if strcmp(w, 'shell-init: error'), s = 1; end

    % - ln returns s=1 on "file exists" -- this shouldn't be treated as
    % an error when using the -f option (and aas_retrieve_intputs does)
    if contains(cmd,'ln -f') && contains(w,'File exists'); s = 0; w = ''; end

    if ~s
        %% Process output if we're in non-quiet mode
        if ~isempty(w) && ~quiet, logging.info(strrep(w,'\','\\')); end
    else
        %% Process error if we're in non-quiet mode OR if we want to stop for errors
        if ~ignoreerrors
            logging.error('***LINUX ERROR FROM SHELL %s\n***WHILE RUNNING COMMAND\n%s***WITH ENVIRONMENT VARIABLES\n%s',...
                strrep(w,'\','\\'),strrep([prefix cmd],'\','\\'),getenvall());
        elseif ~quiet
            logging.warning('***LINUX ERROR FROM SHELL %s\n***WHILE RUNNING COMMAND\n%s***WITH ENVIRONMENT VARIABLES\n%s',...
                strrep(w,'\','\\'),strrep([prefix cmd],'\','\\'),getenvall());
        end
    end

    % Rearrange output to return
    if ~isempty(w)
        l = textscan(w,'%s','delimiter',char(10)); l = l{1};

        % strip off "<shell>: errors" at start (see http://www.mathworks.com/support/solutions/data/1-18DNL.html?solution=1-18DNL)
        toRem = contains(l,'mathworks'); if any(toRem), l(toRem) = []; end

        % put the last shell error to the last
        toShow = find(contains(l,'tcsh:') | contains(l,'/bin/sh:') | contains(l,'/bin/bash:'),1,'last');
        if ~isempty(toShow), l = l([toShow+1:end toShow]); end

        w = sprintf('%s\n',l{:});
    end
end

function env = getenvall()
% Based on https://stackoverflow.com/a/20011191
    if ispc()
        %cmd = 'set "';  %HACK for hidden variables
        cmd = 'set';
    else
        cmd = 'env';
    end
    [~,w] = system(cmd);
    vars = regexp(strtrim(w), '^(.*)=(.*)$', ...
        'tokens', 'lineanchors', 'dotexceptnewline');
    vars = vertcat(vars{:});
    keys = vars(:,1);
    vals = vars(:,2);

    if ispc()
        keys = upper(keys);
    end

    env = containers.Map(keys,vals);
    env = strjoin(cellfun(@(k) sprintf('%s = %s',k,env(k)), env.keys, 'UniformOutput', false),'\n');
end
