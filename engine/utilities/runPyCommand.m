function [s, w] = runPyCommand(rap,pycmd,condaenv,varargin)
% Requires
%   - conda installed and initialised
%   - separate conda setup file, which can be sourced. You can create by
%       sed '/>>> conda initialize >>>/,/<<< conda initialize <<</!d' ~/.bashrc >> $HOME/tools/config/conda_bash.sh
%   - rap.directoryconventions.condasetup MUST point to this conda setup file


% Setup
condasetup = deblank(rap.directoryconventions.condasetup);
if not(isempty(condasetup))
    if ~startsWith(condasetup,'. '), condasetup = ['. ' condasetup]; end
    if ~endsWith(condasetup,';'), condasetup=[condasetup ';']; end
end

if nargin < 2, condaenv = 'base'; end
if nargin < 4, varargin = {}; end

[s, w] = shell(pycmd,'shellprefix',[condasetup 'conda activate ' condaenv ';'],varargin{:});
