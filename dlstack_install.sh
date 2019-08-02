#!/bin/sh
#
#  DLSTACK.SH -- Install the Data Lab software using Anaconda as a base
#                system plus additional packages.

ver="2019.03"					# Anaconda version to install
ver="2019.03"					# Anaconda version to install
base_url="https://repo.continuum.io/archive/"	# Anaconda download repo

# ===========================================================================
# Optional installs (Note: not all of these build cleanly and should probably
# be done manually if needed).

do_astrometry_dot_net=0
do_jupyerlab_extensions=0
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
echo " Downloading base Anaconda2 $ver system ...."
echo "----------------------------------------------"
fname="Anaconda2-${ver}-${arch}-${platform}.sh"
url=${base_url}${fname}

if [ ! -f ./$fname ]; then
    curl -o $fname $url
fi
if [ ! -d $cwd/anaconda2 ]; then
    mkdir $cwd/anaconda2
fi
sh $fname -b -u -p $cwd/anaconda2



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



# ------------------------------------------------------------------------
echo ""
echo "----------------------------------------------"
echo " Downloading external packages ...."
echo "----------------------------------------------"
curl -O -L http://soft.g-vo.org/dist/gavoutils-latest.tar.gz
curl -O -L http://soft.g-vo.org/dist/gavovot-latest.tar.gz
curl -O -L http://soft.g-vo.org/dist/gavostc-latest.tar.gz

# Clone the Data Lab client package
git clone http://github.com/noaodatalab/datalab.git

# Unpack the GAVO packages
gavo_ver=`tar tf gavovot-latest.tar.gz | head -1 | cut -c9-11`
tar zxf gavovot-latest.tar.gz
tar zxf gavostc-latest.tar.gz
tar zxf gavoutils-latest.tar.gz

# Patch the gavoutils/gavo/utils/ostricks.py file
s=`cat gavoutils-1.2/gavo/utils/ostricks.py | grep -n ^try | cut -f 1 --delim=':'`
e=`cat gavoutils-1.2/gavo/utils/ostricks.py | grep -n import\ HTTPSHandler | cut -f 1 --delim=':'`
cat gavoutils-${gavo_ver}/gavo/utils/ostricks.py | \
      sed -e "${s},${e}d" -e "97ifrom urllib2 import HTTPSHandler" > /tmp/os.$$
mv /tmp/os.$$ gavoutils-${gavo_ver}/gavo/utils/ostricks.py


# Pre-install the astroplan module to workaround old PyPi package
git clone https://github.com/astropy/astroplan


# Download and unpack the astrometry.net package
if [ do_astrometry_dot_net == 1 ]; then
    curl -O -L https://github.com/dstndstn/astrometry.net/releases/download/0.75/astrometry.net-0.75.tar.gz
    tar zxf astrometry.net-0.75.tar.gz
    ( cd astrometry.net-0.75 ; make pyinstall )
    pip install -v --no-deps --upgrade git+https://github.com/dstndstn/tractor.git
    cp -rp astrometry/libpython/astrometry anaconda2/lib/python*/site-packages/
fi



# Save the download files
if [ ! -d ./downloads ]; then
    mkdir downloads
fi
mv Anaconda*.sh *.gz downloads


# Conda Install Configs
conda config --add channels conda-forge
conda config --add channels astropy
conda config --add channels https://conda.anaconda.org/als832
conda config --add channels https://conda.anaconda.org/pmuller



# ------------------------------------------------------------------------
# ===================
# Anaconda Python 2.7
# ===================

export PATH=$cwd/anaconda2/bin:$path:/usr/bin

echo ""
echo "----------------------------------------------"
echo " Installing Python2 packages ...."
echo "----------------------------------------------"


conda install -y numpy future cx_oracle
conda install -y -c conda-forge astor
conda install -y -c conda-forge pyopengl
conda install -y astropy astroml autopep8 numpy passlib psycopg2 passlib future mpi4py nodejs openblas pyvo redis redis-py simplejson termcolor virtualenv healpy photutils tensorflow

conda install -y mysql-python		# Py2 only
conda install -y mysqlclient
conda install -y -c astropy photutils

conda install -y pyfits			# not available Py3
conda install -y uwsgi
conda install -c glueviz -y glueviz=0.14


# PIP Installs
pip install --upgrade pip

pip install astrocalc
pip install astropy-helpers
pip install astropy-healpix
pip install docker-py
pip install easyaccess
pip install httplib2
pip install pysqlpool
pip install uwsgi uwsgitop
pip install xmltodict
pip install fitsio
pip install astrorapid
pip install matplotlib
pip install batman
pip install gatspy

if [ do_astrometry_dot_net == 1 ]; then
    ( cd astrometry.net-0.75 ; make pyinstall )
    pip install -v --no-deps --upgrade git+https://github.com/dstndstn/tractor.git
    cp -rp astrometry/libpython/astrometry anaconda3/lib/python*/site-packages/
fi

# GAVO Package installation
(cd gavoutils-$gavo_ver  ; python setup.py install)
(cd gavovot-$gavo_ver    ; python setup.py install)
(cd gavostc-$gavo_ver    ; python setup.py install)

# Install the Data Lab client package
( cd datalab ; python setup.py install )

#( cd astroplan ; python setup.py install )
#( cd antares ; python setup.py install )

conda clean -y -a


# ============================================================================

# ===================
# Anaconda Python 3.7
# ===================

export PATH=$cwd/anaconda3/bin:$path:/usr/bin

echo ""
echo "----------------------------------------------"
echo " Installing Python3 packages ...."
echo "----------------------------------------------"


conda install -y numpy cx_oracle
conda install -y -c conda-forge astor
conda install -y -c conda-forge pyopengl
conda install -y astropy astroml autopep8 docker-py numpy passlib psycopg2 passlib future mpi4py nodejs openblas pyvo redis redis-py simplejson termcolor virtualenv healpy photutils tensorflow

#conda install -y pyfits
conda install -y uwsgi
conda install -c glueviz -y glueviz=0.14
conda install -y mysqlclient

# PIP Installs
pip install --upgrade pip

pip install astrocalc
pip install astropy-helpers
pip install astropy-healpix
#pip install easyaccess			# Not Py3 compatible
pip install httplib2
pip install jupyterhub
#pip install pysqlpool			# Not Py3 compatible
pip install uwsgi uwsgitop
#pip install fitsio			# Not Py3 compatible

pip install mgefit
pip install jampy
pip install vorbin
pip install ppxf
pip install pafit

pip install mpdaf
pip install astrorapid
pip install PyQt5
pip install matplotlib
pip install batman
pip install gatspy
pip install lmfit
pip install h5py==2.9.0

if [ do_astrometry_dot_net == 1 ]; then
    ( cd astrometry.net-0.75 ; make pyinstall )
    pip install -v --no-deps --upgrade git+https://github.com/dstndstn/tractor.git
    cp -rp astrometry/libpython/astrometry anaconda3/lib/python*/site-packages/
fi

# GAVO Package installation
(cd gavoutils-$gavo_ver  ; python setup.py install)
(cd gavovot-$gavo_ver    ; python setup.py install)
(cd gavostc-$gavo_ver    ; python setup.py install)

# Install the Data Lab client package
( cd datalab ; python setup.py install )

#( cd astroplan ; python setup.py install )
#( cd antares ; python setup.py install )

if [ do_jupyterlab_extensions == 1 ]; then

    conda install -c conda-forge -y ipywidgets

    jupyter labextension install jupyterlab_bokeh

    conda install -c plotly -y jupyterlab-dash

    conda install -c conda-forge -y ipysheet

    jupyter labextension install @oriolmirosa/jupyterlab_materialdarker

    jupyter labextension install @jupyterlab/theme-dark-extension

    pip install jupyterlab-discovery

    pip install pylantern
    pip list | grep lantern
    jupyter labextension install pylantern

    pip install scriptedforms

    jupyter labextension install @jupyterlab/hub-extension

    jupyter labextension install @ryantam626/jupyterlab_code_formatter
    pip install jupyterlab_code_formatter
    jupyter serverextension enable --py jupyterlab_code_formatter
    pip install autopep8 black YAPF lsort

    jupyter labextension install @jupyterlab/toc
    jupyter labextension install jupyterlab-drawio
    jupyter labextension install @jupyterlab/celltags
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

    jupyter labextension install @mflevine/jupyterlab_html

    jupyter labextension install @jupyterlab/plotly-extension

    pip install jupyterlab_sql
    jupyter serverextension enable jupyterlab_sql --py --sys-prefix
    jupyter lab build

    pip install sidecar
    jupyter labextension install @jupyter-widgets/jupyterlab-sidecar

    jupyter labextension install jupyterlab-flake8

    jupyter labextension install @jupyterlab/xkcd-extension

    conda install -c wwt -y pywwt
fi

conda clean -y -a

echo ""
echo ""
echo -n "End: "
/bin/date
echo ""

