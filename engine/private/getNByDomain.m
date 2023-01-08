% Determining the number of parts to a given domain - e.g., the number of subjects at the 'subject' level
%
% It also returns the indices of those parts. For example, if there are three runs per subject (N=3, I=[1 2 3]),
% but one subject is missing the middle run (N=2, for that subject), then the indices for that subject should be [1 3]

function [N, I] = getNByDomain(rap,domain,indices)

switch domain
    case 'diffusionrun_phaseencodedirection'
        N=2;
        I=1:2;

    case {'fmrirun','meegrun','diffusionrun','specialrun'}

        switch domain
            case 'fmrirun'
                runs = rap.acqdetails.fmrirun;
                if ~isempty(indices), runnumbers = horzcat(rap.acqdetails.subjects(indices(1)).fmriseries{:}); end
            case 'diffusionrun'
                runs = rap.acqdetails.diffusionrun;
                if ~isempty(indices), runnumbers = horzcat(rap.acqdetails.subjects(indices(1)).diffusionseries{:}); end
            case 'specialrun'
                runs = rap.acqdetails.specialrun;
                if ~isempty(indices), runnumbers = horzcat(rap.acqdetails.subjects(indices(1)).specialseries{:}); end
            case 'meegrun'
                runs = rap.acqdetails.meegrun;
                if ~isempty(indices), runnumbers = horzcat(rap.acqdetails.subjects(indices(1)).meegseries{:}); end
        end

        if isempty(indices)
            N = numel(runs);
            I = 1:N;
        else
            if iscell(runnumbers)
                N = cellfun(@(x) ~isempty(x) && (isstruct(x) || iscell(x) || any(x)), runnumbers);
                I = find(N);
                N = sum(N);
            else
                N = sum(runnumbers > 0);
                I = find(runnumbers > 0);
            end
        end

        % Parse selected_runs into indices if necessary
        rap = parseSelectedruns(rap,runs);
        I = intersect(rap.acqdetails.selectedrun,I);
        N = numel(I);

    case 'subject'
        N = numel(rap.acqdetails.subject);
        I = 1:N;

    case 'study'
        N = 1;
        I = 1;
end

% Fix a 0x1 matrix behaves differently from a 0x0 matrix in a for loop
if isempty(I), I=[]; end
end
