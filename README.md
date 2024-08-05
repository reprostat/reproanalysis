# Reproducible Analysis (_reproa_)

## Description

Reproducible Analysis (_reproa_) is the main pipeline system for ReproStat written primarily in OCTAVE/MATLAB.

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/reprostat/reproanalysis/tree/master.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/reprostat/reproanalysis/tree/master)

## Requirements
- [MATLAB](https://matlab.mathworks.com) or [OCTAVE](https://octave.org) - when using the OCTAVE container, it is strongly advised to pull it from the [reprostat collection](https://hub.docker.com/r/reprostat/octave)
- [SPM](https://www.fil.ion.ucl.ac.uk/spm) - when using under OCTAVE, you need to [recompile the mex-files](https://www.fil.ion.ucl.ac.uk/spm/docs/installation/octave/#compilation)

## Getting started
### 1. Obtain code
You can download _reproa_ either using `git clone` or downloading the archive of the latest [release](https://github.com/reprostat/reproanalysis/releases) or the developmental branch.

### 2. Setup
You only need to add the top-level directory, which contains `reproaSetup`, to the MATLAB/OCTAVE path. Calling `reproaSetup`, typically the first command of the user script will take care of the rest, including the user-specific configuration. You will also need to provide some extra argument if, for example, you want to access the extensions. For more info type `help reproaSetup`.

## Supported use-cases
_reproa_ is highly modular and the processing steps can be easily rearranged and combined. The list of use cases is not exhaustive and includes only the pre-specified workflows used for testing. Feel free to recombine them also taking advantage of the growing list of reproa extensions.
- Retrieval of supported datasets, including MoAEpilot (demo dataset for SPM manual, chapter 30), [OpenNEURO](https://openneuro.org) (datasets #114 and #2737 already included, and more can be added to the [dataset specification](https://github.com/reprostat/reproanalysis/blob/master/engine/datasets/datasets.json)), [MPI-LEMON](http://fcon_1000.projects.nitrc.org/indi/retro/MPI_LEMON.html)
- Preprocessing anatomical images using DARTEL
- Task-based fMRI, as descibed in SPM manual, chapter 30.
- Extended analysis of multi-run task-based fMRI using dual-echo fieldmaps, slicetiming, and DARTEL-based normalisation
- Workflow connection: Analysis of a data already preprocessed using _reproa_

## Extensions
Reproa follows as core+extension model. The extensions can be loaded upon calling _reproaSetup_. Type `help reproaSetup` for details.

**Current list of extensions**
- [fconn](https://github.com/reprostat/reproanalysis-fconn)        - functional connectivity
- [freesurfer](https://github.com/reprostat/reproanalysis-freesurfer)   - integrating FreeSurfer
- [fsl](https://github.com/reprostat/reproanalysis-fsl)           - integrating FSL and other related tools, such as ICA-AROMA

You can read about the supported use-cases of each extension in their _README.md_.
