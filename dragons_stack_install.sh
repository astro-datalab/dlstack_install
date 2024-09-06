#!/bin/bash
#
#  STACK_INSTALL.SH -- Install the DRAGONS software using Anaconda as a base
#                      system plus additional packages.

export SHELL=/bin/bash


ver="2020.02"					# Anaconda Py3.7 base version
ver="2023.03"					# Anaconda Py3.10 base version
base_url="https://repo.anaconda.com/archive/"	# Anaconda download repo


function usage {
  echo "Usage:"
  echo "      $(basename $0) [options...]"
  echo ""
  echo "Options:"
  echo "   [-h|-?|--help]        Display a usage summary"
  echo "   [--debug]             Enable debug output"
  echo "   [--verbose]           Enable verbose output"
  exit
}

# =======================================================================

# ----------
# Initialize
# ----------
prefix=`pwd -L`
platform=`uname -m`
os=`uname -s`

if [ "$os" == "Linux" ]; then
    arch="Linux"
elif [ "$os" == "Darwin" ]; then
    arch="MacOSX"
else
    arch="none"
fi


# --------------------
# Process script args.
# --------------------
version=''
_debug=0
_verbose=0
root_dir='/data0'

declare -a userargs skiplist
while [ "$#" -gt 0 ]; do
    case $1 in
        -h|-\?|--help) usage;;
        --debug) _debug=1;;
        --verbose) _verbose=1;;
        *) userargs=("${userargs[@]}" "${1}");;
    esac; shift
done



# ------------------------------------------------------------------------
echo ""
echo "----------------------------------------------"
echo " Downloading base Anaconda3 $ver system ...."
echo "----------------------------------------------"
fname="Anaconda3-${ver}-${arch}-${platform}.sh"
url=${base_url}${fname}

if [ ! -f ./$fname ]; then
    curl -o $fname $url
fi
if [ ! -d $prefix/anaconda3 ]; then
    mkdir $prefix/anaconda3
fi
chmod 755 $fname
export PWD=$prefix && sh $fname -b -u -p $prefix/anaconda3

# Set the PATH to pick up the new conda install directory.
export PATH=$prefix/anaconda3/bin:$path:/bin:/usr/bin

# Download the latest PIP installer.
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
anaconda3/bin/python get-pip.py


# Update conda and install configs
#conda update -n base -c defaults -y conda
conda upgrade -n base -c defaults --override-channels -y conda

/bin/rm -f $HOME/.condarc
conda config --add channels conda-forge
#conda config --add channels astropy
conda config --set auto_activate_base false
#conda config --add channels http://ssb.stsci.edu/astroconda
conda config --add channels http://astroconda.gemini.edu/public

# ============================================================================

echo "" && echo ""
echo -n "Start: "
/bin/date
echo ""

# ====================================
# Anaconda Python 3.10 / DRAGONS 3.1
# ====================================

echo ""
echo "----------------------------------------------"
echo " Installing Python3 packages ...."
echo "----------------------------------------------"

# ===============
# Conda Installs
# ===============


# ===============
# PIP Installs
# ===============
pip install --upgrade pip

#pip install setuptools_scm
#pip install numpy
#pip install matplotlib
#pip install healpy
#pip install pandas
#pip install palpy
#pip install scipy
#pip install astropy
#pip install pytables
#pip install h5py
#pip install scikit-learn
#pip install ipython==7.12.0


# ------------------------------------------------------------------------
# Install the DRAGONS package(s)
conda create -n dragons -y python=3.10 dragons ds9

# Workaround for Dask loader bug (https://github.com/dask/dask/issues/8574)
pip install distributed==2022.01.0


# ------------------------------------------------------------------------
# Clean up
if [ ! -d downloads ]; then
    mkdir downloads
fi
mv -f Anaconda*.sh get-pip.py downloads
conda clean -y -a


# Create the local manifest file.
pip freeze >& MANIFEST

echo "" && echo ""
echo -n "End: "
/bin/date
echo ""

