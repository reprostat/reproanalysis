TOOLDIR=$HOME/tools
if [[ ! -d $TOOLDIR ]]; then  mkdir $TOOLDIR; fi
mkdir $TOOLDIR/config
TEMPLATEDIR=$TOOLDIR/templates

sudo apt update
sudo apt install libtinfo5 libtinfo6 dc libxml2-utils graphviz -y
curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o $TOOLDIR/get-pip.py
python $TOOLDIR/get-pip.py --force-reinstall

# All MATLAB tools MUST be installed referred by the parameterset
source $GITHUB_WORKSPACE/.circleci/tools_urls.sh
source $GITHUB_WORKSPACE/external/toolboxes/installation_scripts/install_tools.sh $GITHUB_WORKSPACE/.circleci/$PARAMETER_XML

echo "FSL: ${LOAD_FSL}; FREESURFER: ${LOAD_FREESURFER}"

if [[ "x${LOAD_FSL}x" == "x1x" ]]; then
    source $GITHUB_WORKSPACE/external/toolboxes/installation_scripts/install_fsl.sh $TOOLDIR 6.0.7.3 0 $TOOLDIR/config/fsl_bash.sh
fi

if [[ "x${LOAD_FREESURFER}x" == "x1x" ]]; then
    source $GITHUB_WORKSPACE/external/toolboxes/installation_scripts/install_freesurfer.sh $TOOLDIR 7.4.1 centos7 "tibor.auer@gmail.com\n7061\n *Ccpi6x7PAIeQ\n FS96pPK5vW.0g" $TEMPLATEDIR
fi

echo "Free space:"
df -h