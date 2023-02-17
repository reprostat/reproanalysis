function out = contains(str,pttrn,varargin)

    argParse = inputParser;
    argParse.addParameter('regularExpression',false,@islogical);
    argParse.parse(varargin{:});

    if ~ischar(pttrn) % MATLAB's advanced pattern
        out = false;
        return;
    end

    if ~argParse.Results.regularExpression
        pttrn = ['.*' strrep(pttrn,'\','\\') '.*'];
    end

    switch class(str)
        case 'char'
            out = ~isempty(regexp(str,pttrn, 'once'));
        case 'cell'
            out = cellfun(@(p) ~isempty(regexp(p,pttrn, 'once')), str);
    end

end
