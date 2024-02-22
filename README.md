# Reproducible Analysis (_reproa_)

## Description

Reproducible Analysis (_reproa_) is the main pipeline system for ReproStat written primarily in OCTAVE/MATLAB.

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/reprostat/reproanalysis/tree/master.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/reprostat/reproanalysis/tree/master)

## Requirements
- [MATLAB](https://matlab.mathworks.com) or [OCTAVE](https://octave.org)
- [SPM](https://www.fil.ion.ucl.ac.uk/spm) - when using under OCTAVE, you need to [recompile the mex-files](https://www.fil.ion.ucl.ac.uk/spm/docs/installation/octave/#compilation)

## Supported use-cases
_reproa_ is highly modular and the processing steps can be easily rearranged and combined. The list of use cases is not exhaustive and includes only the pre-specified workflows used for testing. Feel free to recombine them also taking advantage of the growing list of reproa extensions.
- Retrieval of supported datasets, including MoAEpilot (demo dataset for SPM manual, chapter 30), [OpenNEURO](https://openneuro.org) (datasets #114 and #2737 already included, and more can be added to the [dataset specification](https://github.com/reprostat/reproanalysis/blob/master/engine/datasets/datasets.json)), [MPI-LEMON](http://fcon_1000.projects.nitrc.org/indi/retro/MPI_LEMON.html)
- Preprocessing anatomical images using DARTEL
- Task-based fMRI, as descibed in SPM manual, chapter 30.
- Workflow connection: Analysis of a data already preprocessed using _reproa_
