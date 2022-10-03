% expand environment variables (anything with a $ prefix) in the input path x
% with their current value. This assumes bash-style expansion, where variables are
% referenced $likethis and expressions are evaluated $(like this). We also support
% historical csh-style expansion where expressions are evaluated `like this`.
%
% If x is a cell, struct or multi-row char array we recurse and return
% something of similar structure.
%
% If verbose is true, we print each expanded string to the command window.
%
% Examples:
% expandpathbyvars('/imaging/$USER/aa'); % /imaging/jc01/aa
% expandpathbyvars('$HOME/aa/$HOSTNAME'); % /home/jc01/login24
% expandpathbyvars(aap); % yes, this works
%
% 20180730 J Carlin
% 20220926 T Auer
%
% xnew = expandpathbyvars(x, [verbose=false])
function x = expandpathbyvars(x, varargin)

argParse = inputParser;
argParse.addOptional('verbose',false,@(x) islogical(x) || isnumeric(x));
argParse.parse(varargin{:});
verbose = argParse.Results.verbose;

if isstruct(x)
    for thisfn = fieldnames(x)'
        fnstr = thisfn{1};
        for n = 1:numel(x)
            x(n).(fnstr) = expandpathbyvars(x(n).(fnstr), verbose);
        end
    end
    return
end

if iscell(x)
    for cellind = 1:numel(x)
        x{cellind} = expandpathbyvars(x{cellind}, verbose);
    end
    return
end

if size(x,1) > 1
    for rowind = 1:size(x,1)
        x(rowind,:) = expandpathbyvars(x(rowind,:), verbose);
    end
    return
end

% so if we get here it's a single-row array, presumably string
% (nb this also means we ignore other type fields in e.g. struct inputs)
if ischar(x) && ~isempty(intersect(x,'$`'))
    xold = x;
    if ispc
        env = regexp(x,'(?<=\$)[a-zA-Z0-9-_\.]*','match');
        for e = env
            try, x = strrep(x,['$' e{1}], getenv(e{1}));
            catch E, logging.error('%s\n\nfailed to expand x: %s',E.message,xold);
            end
        end
    else
        [err, x] = aas_shell(['echo ' x]);
        % white space and row breaks aren't valid XML so these are errors we assume
        x = deblank(x);
        if isempty(x) || err~=0, logging.error('failed to expand x: %s',xold); end
    end
    if verbose, logging.info('expanded %s to produce %s',xold, x); end
end
