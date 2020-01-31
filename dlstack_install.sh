#!/bin/bash
#
#  DLSTACK.SH -- Install the Data Lab software using Anaconda as a base
#                system plus additional packages.

export SHELL=/bin/bash


ver="2019.10"					# Anaconda version to install
base_url="https://repo.continuum.io/archive/"	# Anaconda download repo

# ===========================================================================
# Optional installs (Note: not all of these build cleanly and should probably
# be done manually when needed).

export do_gavo=0
export do_astrometry_dot_net=0
export do_jupyterlab_extensions=0
# ===========================================================================


function usage {
    echo "Usage:"
    echo "      $(basename $0) [options...]"
    echo ""
    echo "Options:"
    echo "    [-h|-?|--help]    Display a usage summary"
    echo "    [-c|--clean]      Clean up existing version before install"
    echo "    [-d|--dev]        Install the dev 'datalab' package release"
    echo "    [-e|--extensions] Install JupyterLab extensions"
    echo "    [-k|--kernels]    Install all kernel specs in kernel-spec dir"
    echo "    [-s|--stable]     Use the stable 'datalab' release (def: True)"
    echo "    [-K <directory>]  Set kernel-spec dir (def: /data0/kernel-specs)"
    exit

}

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
k_dir='/data0/kernel-specs'
do_kernels=0
do_clean=0
do_dev=0
do_stable=1
declare -a userargs skiplist
while [ "$#" -gt 0 ]; do
    case $1 in
        -h|-\?|--help) usage;;
        -k|--kernels) export do_kernels=1;;
        -c|--clean) export do_clean=1;;
        -d|--dev) export do_dev=1;export do_stable=0;;
        -e|--extensions) export do_jupyterlab_extensions=1;;
        -s|--stable) export do_stable=1;export do_dev=0;;
        -K|--kernel-dir) shift;k_dir=$1;;
        *) userargs=("${userargs[@]}" "${1}");;
    esac; shift
done


echo "" && echo -n "Start: "
/bin/date
echo "" && echo ""


# ====================================
# Clean up any existing installation.
# ====================================
if [ $do_clean == 1 ]; then
    echo "# ------------------------------------"
    echo -n "Cleaning old install ..... "
    /bin/rm -rf ./anaconda3 ./downloads ./get-pip.py ./MANIFEST
    echo "Done"
    echo "# ------------------------------------"
fi


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

# Download the PIP installer.
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
anaconda3/bin/python get-pip.py

# Update conda and install configs
conda update -n base -c defaults -y conda
conda config --add channels conda-forge
conda config --add channels astropy
conda config --add channels glueviz
conda config --add channels plotly
conda config --add channels https://conda.anaconda.org/als832
conda config --add channels https://conda.anaconda.org/pmuller


# ============================================================================

# ===================
# Anaconda Python 3.7
# ===================

echo ""
echo "----------------------------------------------"
echo " Installing Python3 packages ...."
echo "----------------------------------------------"

# ===============
# Conda Installs
# ===============
conda install -y \
    astor \
    astroml \
    astropy \
    astropy-helpers \
    astropy-healpix \
    astroquery \
    autopep8 \
    cx_oracle \
    docker-py \
    emcee \
    future \
    gatspy \
    glueviz=0.14 \
    healpy \
    httplib2 \
    ipympl \
    jupyterhub \
    matplotlib \
    mpi4py \
    mysqlclient \
    nodejs \
    numpy \
    openblas \
    pandas \
    passlib \
    psycopg2 \
    photutils \
    pyopengl \
    pyvo \
    simplejson \
    speclite \
    specutils \
    tensorflow \
    termcolor \
    uwsgi \
    virtualenv \
    wget


# ===============
# PIP Installs
# ===============
pip install --upgrade pip

if [ $do_stable == 1 ]; then
    pip install noaodatalab
fi
pip install astrocalc
pip install batman-package
pip install easyaccess
pip install h5py==2.9.0
pip install lmfit
pip install jampy
pip install mgefit
pip install mpdaf
pip install pafit
pip install ppxf
pip install PyQt5
pip install vorbin
pip install redis==2.10.6


# Obsolete packages, included here for documentation only
#conda install -y pyfits
#conda install -y numpy cx_oracle
#pip install easyaccess			# Not Py3 compatible
#pip install pysqlpool			# Not Py3 compatible
#pip install fitsio			# Not Py3 compatible


if [ do_astrometry_dot_net == 1 ]; then
    echo "----------------------------------------------"
    echo " Installing astrometry.net packages ...."
    echo "----------------------------------------------"
    ( cd astrometry.net-0.75 ; make pyinstall )
    pip install -v --no-deps --upgrade git+https://github.com/dstndstn/tractor.git
    cp -rp astrometry/libpython/astrometry anaconda3/lib/python*/site-packages/
fi

# GAVO Package installation
if [ $do_gavo == 1 ]; then
    echo "----------------------------------------------"
    echo " Installing GAVO packages ...."
    echo "----------------------------------------------"
    curl -O -L http://soft.g-vo.org/dist/gavoutils-latest.tar.gz
    curl -O -L http://soft.g-vo.org/dist/gavovot-latest.tar.gz
    curl -O -L http://soft.g-vo.org/dist/gavostc-latest.tar.gz

    # Unpack the GAVO packages
    gavo_ver=`tar tf gavovot-latest.tar.gz | head -1 | cut -c9-11`
    tar zxf gavovot-latest.tar.gz
    tar zxf gavostc-latest.tar.gz
    tar zxf gavoutils-latest.tar.gz

    # Patch the gavoutils/gavo/utils/ostricks.py file
    s=`cat gavoutils-${gavo_ver}/gavo/utils/ostricks.py | grep -n ^try | cut -f 1 --delim=':'`
    e=`cat gavoutils-${gavo_ver}/gavo/utils/ostricks.py | grep -n import\ HTTPSHandler | cut -f 1 --delim=':'`
    cat gavoutils-${gavo_ver}/gavo/utils/ostricks.py | \
      sed -e "${s},${e}d" -e "97ifrom urllib2 import HTTPSHandler" > /tmp/os.$$
    mv /tmp/os.$$ gavoutils-${gavo_ver}/gavo/utils/ostricks.py

    (cd gavoutils-$gavo_ver  ; python setup.py install)
    (cd gavovot-$gavo_ver    ; python setup.py install)
    (cd gavostc-$gavo_ver    ; python setup.py install)
fi


# ------------------------------------------------------------------------
echo ""
echo "----------------------------------------------"
echo " Downloading external packages ...."
echo "----------------------------------------------"

# Install the Data Lab client package and authenticator
if [ $do_dev == 1 ]; then
    git clone http://github.com/noaodatalab/datalab.git
    ( cd datalab ; python setup.py install )
fi

# Clone the Data Lab Authenticator
git clone https://github.com/noaodatalab/dlauthenticator
( cd dlauthenticator ; python setup.py install )


# ------------------------------------------------------------------------
if [ $do_jupyterlab_extensions == 1 ]; then
    echo ""
    echo "----------------------------------------------"
    echo " Installing JupyterLab packages ...."
    echo "----------------------------------------------"

    conda install -c conda-forge -y ipywidgets		# enabled automatically

    jupyter labextension install jupyterlab_bokeh

    conda install -c plotly -y jupyterlab-dash

    jupyter labextension install @jupyterlab/hub-extension

    jupyter labextension install @jupyterlab/toc
    jupyter labextension install jupyterlab-drawio
    jupyter labextension install @lckr/jupyterlab_variableinspector

    conda install -c conda-forge -y ipyleaflet

    conda install -c conda-forge -y ipytree

    conda install -c conda-forge -y ipyvolume
    jupyter labextension install @jupyter-widgets/jupyterlab-manager
    jupyter labextension install ipyvolume
    jupyter labextension install jupyter-threejs

    conda install -c conda-forge -y qgrid
    jupyter labextension install qgrid

    pip install sidecar
    jupyter labextension install @jupyter-widgets/jupyterlab-sidecar

    jupyter labextension install jupyterlab-flake8

    jupyter labextension install @jupyterlab/xkcd-extension

    conda install -c wwt -y pywwt
fi
jupyter lab build


# ------------------------------------------------------------------------
# Install third-party kernel spec files
if [ $do_kernels == 1 ]; then
    echo "----------------------------------------------"
    echo " Installing kernels ...."
    echo "----------------------------------------------"
    if [ -e ${k_dir} ]; then
        echo "Copying Kernel files .... "
        cp -rp $k_dir/* $prefix/anaconda3/share/jupyter/kernels/
    fi
fi


# ------------------------------------------------------------------------
# Clean up and save the download files
echo "----------------------------------------------"
echo " Cleaning up ...."
echo "----------------------------------------------"
if [ ! -d ./downloads ]; then
    mkdir downloads
fi
mv Anaconda*.sh *.gz datalab dlauthenticator downloads
conda clean -y -a

# Create the local manifest file.
pip freeze >& MANIFEST


echo "" && echo ""
echo -n "End: "
/bin/date
echo ""

