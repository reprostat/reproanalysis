function rap = addReport(rap,varargin)
    if ~isfield(rap,'report')
        return
    end

    reportStore = varargin{1};
    reportStr = varargin{2};

    % Subject
    if startsWith(reportStore,'sub')
        subj = str2double(regexp(reportStore,'(?<=sub)[0-9]*','match'));

        if ~isfield(rap.report,reportStore)
            % Initialise subject report
            rap.report.(reportStore).fname = fullfile(rap.report.subjDir,[rap.report.fbase '_sub-' rap.acqdetails.subjects(subj).subjname '.html']);
            rap = addReport(rap,'sub0',...
                sprintf('<a href="%s" target=_top>%s</a><br>',...
                rap.report.(reportStore).fname,...
                ['Subject: ' rap.acqdetails.subjects(subj).subjname]));
            rap = addReport(rap,reportStore,['HEAD=Subject: ' rap.acqdetails.subjects(subj).subjname]);
        end
    end

    if isempty(reportStr) % Clear HTML
        rap.report.(reportStore).fid = fopen(rap.report.(reportStore).fname,'w');

    elseif startsWith(reportStr, 'HEAD=') % Initialise HTML
        rap = addReport(rap,reportStore,'');
        reportStr = strrep(reportStr,'HEAD=','');

        % calculate path sublevels
        nSubDir = sum(strrep(spm_file(rap.report.(reportStore).fname,'path'),spm_file(rap.report.main.fname,'path'),'')==filesep);
        nSubDir = reshape(char(arrayfun(@(x) '../',1:nSubDir,'UniformOutput',false))',1,[]);

        fprintf(rap.report.(reportStore).fid,'<!DOCTYPE html>\n');
        fprintf(rap.report.(reportStore).fid,'<html>\n');
        fprintf(rap.report.(reportStore).fid,'<head><link rel="stylesheet" href="%s%s"></head>\n',nSubDir,rap.report.style);
        if strcmp(reportStore, 'main'), fprintf(rap.report.(reportStore).fid,'<meta charset="utf-8">\n'); end
        fprintf(rap.report.(reportStore).fid,'<body>\n');

        % Dependencies for provenance graph
        if strcmp(reportStore, 'main')
            fprintf(rap.report.(reportStore).fid,'<script src="https://d3js.org/d3.v5.min.js"></script>\n');
            fprintf(rap.report.(reportStore).fid,'<script src="https://unpkg.com/@hpcc-js/wasm@0.3.11/dist/index.min.js"></script>\n');
            fprintf(rap.report.(reportStore).fid,'<script src="https://unpkg.com/d3-graphviz@3.0.5/build/d3-graphviz.js"></script>\n');
        end

        fprintf(rap.report.(reportStore).fid,'<table border=0>\n');
        fprintf(rap.report.(reportStore).fid,'<td align=center width=100%%>\n');
        fprintf(rap.report.(reportStore).fid,'%s\n',['<tr><td align=center><font size=+3><b>' reportStr '</b></font></tr>']);
        fprintf(rap.report.(reportStore).fid,'</table>\n');
        fprintf(rap.report.(reportStore).fid,'<a href="%s" target=_top>Main</a> &nbsp;-&nbsp;',rap.report.main.fname);
        fprintf(rap.report.(reportStore).fid,'<a href="%s" target=_top>Subject list</a> &nbsp;-&nbsp;',rap.report.sub0.fname);

        % Summaries
        for s = 1:size(rap.report.summaries,1)-1
            fprintf(rap.report.(reportStore).fid,'<a href="%s" target=_top>%s</a> &nbsp;-&nbsp;',rap.report.(rap.report.summaries{s,1}).fname,rap.report.summaries{s,2});
        end
        fprintf(rap.report.(reportStore).fid,'<a href="%s" target=_top>%s</a>',rap.report.(rap.report.summaries{s+1,1}).fname,rap.report.summaries{s+1,2});

        fprintf(rap.report.(reportStore).fid,'\n<hr class="rounded">\n');

        % Provenance graph
        if strcmp(reportStore, 'main')
            fprintf(rap.report.(reportStore).fid,'<h2>Workflow</h2>\n');
            fprintf(rap.report.(reportStore).fid,'<div id="workflow"></div>\n');
            fprintf(rap.report.(reportStore).fid,'<script>\n');
            fprintf(rap.report.(reportStore).fid,'d3.select("#workflow").graphviz()\n');
            fprintf(rap.report.(reportStore).fid,'.renderDot(''digraph {''\n');

            % read dot data
            dotfid = fopen(spm_file(rap.report.(reportStore).fname,'filename','rap_prov.dot'));
            lines = {};
            while ~feof(dotfid), lines{end+1} = fgetl(dotfid); end
            fclose(dotfid);
            lines([1 end]) = '';

            % write dot data to html
            for l = lines, fprintf(rap.report.(reportStore).fid,['    +''' l{1}(2:end) '''\n']); end

            fprintf(rap.report.(reportStore).fid,'    +''}'');\n');
            fprintf(rap.report.(reportStore).fid,'</script>\n');
        end
        fprintf(rap.report.(reportStore).fid,'<table border=0>\n');

    elseif strcmp(reportStr, 'EOF') % Close HTML
        fprintf(rap.report.(reportStore).fid,'</table>\n');
        fprintf(rap.report.(reportStore).fid,'\n<hr class="rounded">\n');
        fprintf(rap.report.(reportStore).fid,'</body>\n');
        fprintf(rap.report.(reportStore).fid,'</html>\n');
        rap.report.(reportStore).fid = fclose(rap.report.(reportStore).fid);

    else
        fprintf(rap.report.(reportStore).fid,'%s\n',reportStr);
        %     strcat(rap.report.(reportStore).text,sprintf('%s\n',reportStr));
    end
end
