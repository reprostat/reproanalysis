function varargout = evalModule(mfile,rap,command,indices)

if ~exist(spm_file(mfile,'ext','.m'),'file'), logging.error('%s doesn''t appear to be a valid m file?',funcname); end

ci = num2cell(indices);
aap = feval(mfile,rap,command,ci{:});
end
