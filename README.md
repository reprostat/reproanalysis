# Reproducible Analysis (_reproa_)

## Description

Reproducible Analysis (_reproa_) is a pipeline system for neuroimaging written primarily in OCTAVE/MATLAB. The goal is to facilitate reproducible and flexible neuroimaging analyses and allow the assessment and optimisation of the reproducibility of such analyses.

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/reprostat/reproanalysis/tree/master.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/reprostat/reproanalysis/tree/master)

## Features

### Reproducibility
- Explicit specification of dependence between steps
- Clear recording and visualisation of provenance
- Tight control of loading/unloading tools via toolbox interfaces
- High- and low-level data diagnostics
- Data integrity (checksum) is recorded and checked at every steps

### Inclusivity
- Compatible with both MATLAB and OCTAVE
- Tested on both Windows and Linux (ubuntu)
- Integration of large variety of MATLAB/OCTAVE-, Linux- and Python-based neuroimaging tools

### Efficiency
- Parallel execution on a single PC and on a cluster
- Modular design
- Core + extensions
- Interface to download data from common sources, including OpenNEURO
- Installation scripts for tools



