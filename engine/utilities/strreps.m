function str = strreps(str, old, new)
for i = 1:numel(old)
    str = strrep(str, old{i}, new{i});
end
