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
export do_jupyerlab_extensions=1
# ===========================================================================


platform=`uname -m`
os=`uname -s`
cwd=`pwd`

if [ "$os" == "Linux" ]; then
    arch="Linux"
elif [ "$os" == "Darwin" ]; then
    arch="MacOSX"
else
    arch="none"
fi

echo ""
echo -n "Start: "
/bin/date
echo ""
echo ""


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
if [ ! -d $cwd/anaconda3 ]; then
    mkdir $cwd/anaconda3
fi
sh $fname -b -u -p $cwd/anaconda3


curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
anaconda3/bin/python get-pip.py


# ------------------------------------------------------------------------
echo ""
echo "----------------------------------------------"
echo " Downloading external packages ...."
echo "----------------------------------------------"

# Clone the Data Lab client package
git clone http://github.com/noaodatalab/datalab.git

# Clone the Data Lab Authenticator
git clone https://github.com/noaodatalab/dlauthenticator


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

export PATH=$cwd/anaconda3/bin:$path:/bin:/usr/bin

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
    docker-py \
    emcee \
    future \
    gatspy \
    glueviz=0.14 \
    healpy \
    httplib2 \
    jupyterhub \
    matplotlib \
    mpi4py \
    mysqlclient \
    nodejs \
    numpy \
    openblas \
    passlib \
    psycopg2 \
    photutils \
    pyopengl \
    pyvo \
    redis redis-py \
    simplejson \
    speclite \
    specutils \
    tensorflow \
    termcolor \
    uwsgi \
    virtualenv

# ===============
# PIP Installs
# ===============
pip install --upgrade pip

pip install astrocalc
pip install batman-package
pip install h5py==2.9.0
pip install lmfit
pip install jampy
pip install mgefit
pip install mpdaf
pip install pafit
pip install ppxf
pip install PyQt5
pip install uwsgi uwsgitop
pip install vorbin


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

# Install the Data Lab client package and authenticator
( cd datalab ; python setup.py install )
( cd dlauthenticator ; python setup.py install )


if [ $do_jupyterlab_extensions == 1 ]; then

    conda install -c conda-forge -y ipywidgets		# enabled automatically

    jupyter labextension install jupyterlab_bokeh

    conda install -c plotly -y jupyterlab-dash

    #conda install -c conda-forge -y ipysheet

    jupyter labextension install @jupyterlab/hub-extension

    jupyter labextension install @ryantam626/jupyterlab_code_formatter
    #pip install jupyterlab_code_formatter
    #jupyter serverextension enable --py jupyterlab_code_formatter
    #pip install autopep8 black YAPF lsort

    jupyter labextension install @jupyterlab/toc
    jupyter labextension install jupyterlab-drawio
    jupyter labextension install @jupyterlab/statusbar
    jupyter labextension install @lckr/jupyterlab_variableinspector

    conda install -c conda-forge -y ipyleaflet

    conda install -c conda-forge -y ipytree

    conda install -c conda-forge -y ipyvolume
    jupyter labextension install @jupyter-widgets/jupyterlab-manager
    jupyter labextension install ipyvolume
    jupyter labextension install jupyter-threejs

    conda install -c conda-forge -y qgrid
    jupyter labextension install qgrid

    #jupyter labextension install @mflevine/jupyterlab_html
    #jupyter labextension install @jupyterlab/plotly-extension

    #pip install jupyterlab_sql
    #jupyter serverextension enable jupyterlab_sql --py --sys-prefix

    pip install sidecar
    jupyter labextension install @jupyter-widgets/jupyterlab-sidecar

    jupyter labextension install jupyterlab-flake8

    jupyter labextension install @jupyterlab/xkcd-extension

    conda install -c wwt -y pywwt

    jupyter lab build
fi


# Clean up and save the download files
if [ ! -d ./downloads ]; then
    mkdir downloads
fi
mv Anaconda*.sh *.gz downloads
conda clean -y -a

# Create the local manifest file.
pip freeze >& MANIFEST


echo ""
echo ""
echo -n "End: "
/bin/date
echo ""

