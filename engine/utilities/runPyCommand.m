function [s, w] = runPyCommand(rap,pycmd,condaenv,varargin)
%
% FORMAT [s, w] = runPyCommand(...,Name,Value)
%   'runFsl' - run in FSL enviromnent, assumes the 'fsl' extension (default = false)
%
% Requires
%   - conda installed and initialised
%   - separate conda setup file, which can be sourced. You can create by
%       sed '/>>> conda initialize >>>/,/<<< conda initialize <<</!d' ~/.bashrc >> $HOME/tools/config/conda_bash.sh
%   - rap.directoryconventions.condasetup MUST point to this conda setup file

% Parse
runFsl = false;
indFsl = find(strcmp(varargin,'runFsl'));
if ~isempty(indFsl)
    runFsl = varargin{indFsl+1};
    varargin(indFsl:indFsl+1) = [];
end

% Setup
condasetup = deblank(rap.directoryconventions.condasetup);
if not(isempty(condasetup))
    if ~startsWith(condasetup,'. '), condasetup = ['. ' condasetup]; end
    if ~endsWith(condasetup,';'), condasetup=[condasetup ';']; end
end

if nargin < 2, condaenv = 'base'; end
if nargin < 4, varargin = {}; end

if runFsl
    [s, w] = runFslCommand(rap,pycmd,{},'shellprefix',[condasetup 'conda activate ' condaenv ';'],varargin{:});
else
    [s, w] = shell(pycmd,'shellprefix',[condasetup 'conda activate ' condaenv ';'],varargin{:});
end

