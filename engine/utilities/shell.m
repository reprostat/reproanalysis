% wrapper for shell call
%
function [s,w] = shell(cmd,varargin)

    argParse = inputParser;
    argParse.addParameter('quiet',false,@(x) islogical(x) || isnumeric(x));
    argParse.addParameter('ignoreerror',false,@(x) islogical(x) || isnumeric(x));
    argParse.addParameter('shellprefix','',@ischar);
    argParse.addParameter('environment',{},@iscell);

    argParse.parse(varargin{:});

    global reproacache

    quiet = argParse.Results.quiet;
    ignoreerror = argParse.Results.ignoreerror;
    ENV = argParse.Results.environment;

    % Prepare
    if isa(reproacache,'cacheClass') && reproacache.isKey('shellprefix')
        sh = reproacache('shell');
        prefix = reproacache('shellprefix');
    else
        % determine active shell (based on https://uk.mathworks.com/help/matlab/ref/system.html#btnr3fv-1)
        if ispc()
            sh = '';
            prefix = '';
        else
            sh = '';
            if isa(reproacache,'cacheClass') && reproacache.isKey('shell'), sh = reproacache('shell'); end
            if isempty(sh), sh = getenv('MATLAB_SHELL'); end
            if isempty(sh), sh = getenv('SHELL'); end
            if isempty(sh), sh = '/bin/sh'; end
            sh = regexp(sh,['(?<=\' filesep ')[^\' filesep ']*$'],'match','once');
            switch sh
                case {'sh' 'bash'}
                    prefix = 'export TERM=dumb;';
                case {'csh' 'tcsh'}
                    prefix = 'setenv TERM dumb;';
                otherwise
                    logging.error('unknown shell: %s', strrep(sh,'\','\\'));
            end
        end

        % cache it
        if isa(reproacache,'cacheClass')
            if ~reproacache.isKey('shell') || isempty(reproacache('shell')), reproacache('shell') = sh; end
            reproacache('shellprefix') = prefix;
        end
    end

    % Environment
    if ~isempty(ENV)
        % Special cases
        for e = 1:size(ENV,1)
            switch ENV{e,1}
                case 'PATH'
                    [~,pthSys] = system('echo $PATH'); pthSys = strsplit(pthSys,pathsep);
                    for pth = strsplit(ENV{e,2},pathsep)
                        pthSys(strcmp(pth,pthSys)) = [];
                        pthSys = [pth pthSys];
                    end
                    ENV{e,2} = strjoin(pthSys,pathsep);
            end
        end
        if startsWith(prefix,'export')
            for e = 1:size(ENV,1)
                cmd = [sprintf('export %s=%s;',ENV{e,1},ENV{e,2}) cmd];
            end
        elseif startsWith(prefix,'setenv')
            for e = 1:size(ENV,1)
                cmd = [sprintf('setenv %s %s;',ENV{e,1},ENV{e,2}) cmd];
            end
        end
    end

    % Run
    if ~quiet, logging.info('shell:%s', strrep([prefix argParse.Results.shellprefix cmd],'\','\\')); end
    if isempty(sh), [s, w] = system([prefix argParse.Results.shellprefix cmd]);
    else, [s, w] = system([sh ' -c "' strrep([prefix argParse.Results.shellprefix cmd],'"','\"') '"']);
    end

    % Special cases
    % - ensure shell-init error to be handled
    if strcmp(w, 'shell-init: error'), s = 1; end

    % - ln returns s=1 on "file exists" -- this shouldn't be treated as
    % an error when using the -f option (and aas_retrieve_intputs does)
    if lookFor(cmd,'ln -f') && lookFor(w,'File exists'); s = 0; w = ''; end

    if ~s
        %% Process output if we're in non-quiet mode
        if ~isempty(w) && ~quiet, logging.info(strreps(w,{'\' '%'},{'\\' '%%'})); end
    else
        %% Process error if we're in non-quiet mode OR if we want to stop for errors
        if ~ignoreerror
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
        toRem = lookFor(l,'mathworks'); if any(toRem), l(toRem) = []; end

        % put the last shell error to the last
        toShow = find(lookFor(l,'tcsh:') | lookFor(l,'/bin/sh:') | lookFor(l,'/bin/bash:'),1,'last');
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
