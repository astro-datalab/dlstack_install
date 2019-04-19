#!/bin/sh
#
#  DLSTACK.SH -- Install the Data Lab software using Anaconda as a base
#                system plus additional packages.

ver="4.4.0"					# Anaconda version to install
ver="5.2.0"					# Anaconda version to install
base_url="https://repo.continuum.io/archive/"	# Anaconda download repo

# ===========================================================================
# Optional installs (Note: not all of these build cleanly and should probably
# be done manually if needed).

do_astrometry_dot_net=0
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
#git clone http://github.com/noao-datalab/datalab-client.git && \
#          mv datalab-client datalab
git clone http://gitlab.noao.edu/datalab/datalab.git


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



# ------------------------------------------------------------------------
# ===================
# Anaconda Python 2.7
# ===================

export PATH=$cwd/anaconda2/bin:$path

echo ""
echo "----------------------------------------------"
echo " Installing Python2 packages ...."
echo "----------------------------------------------"

# Conda Installs
conda config --add channels conda-forge
conda config --add channels astropy
conda config --add channels https://conda.anaconda.org/als832
conda config --add channels https://conda.anaconda.org/pmuller

conda install -y numpy future cx_oracle
conda install -y astropy
conda install -y astroml
conda install -y autopep8
conda install -y numpy
conda install -y passlib
conda install -y psycopg2
conda install -y passlib
conda install -y future
conda install -y mpi4py
conda install -y nodejs
conda install -y openblas
conda install -y pyvo
conda install -y redis
conda install -y redis-py
conda install -y simplejson
conda install -y termcolor
conda install -y virtualenv
conda install -y healpy
conda install -y photutils
conda install -y tensorflow

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
pip install astrorapid==0.1.21
pip install matplotlib

if [ do_astrometry_dot_net == 1 ]; then
    ( cd astrometry.net-0.75 ; make pyinstall )
    pip install -v --no-deps --upgrade git+https://github.com/dstndstn/tractor.git
    cp -rp astrometry/libpython/astrometry anaconda3/lib/python*/site-packages/
fi


# Install the Data Lab client package
#pip install datalab
( cd datalab ; python setup.py install )


# GAVO Package installation
(cd gavoutils-$gavo_ver  ; python setup.py install)
(cd gavovot-$gavo_ver    ; python setup.py install)
(cd gavostc-$gavo_ver    ; python setup.py install)

conda clean -y -a

# ============================================================================

# ===================
# Anaconda Python 3.6
# ===================

export PATH=$cwd/anaconda3/bin:$path


echo ""
echo "----------------------------------------------"
echo " Installing Python3 packages ...."
echo "----------------------------------------------"

# Conda Installs
conda config --add channels conda-forge
conda config --add channels astropy

conda install -y numpy cx_oracle
conda install -y astropy
conda install -y astroml
conda install -y autopep8
conda install -y docker-py
conda install -y numpy
conda install -y passlib
conda install -y psycopg2
conda install -y passlib
conda install -y future
conda install -y mpi4py
conda install -y nodejs
conda install -y openblas
conda install -y pyvo
conda install -y redis
conda install -y redis-py
conda install -y simplejson
conda install -y termcolor
conda install -y virtualenv
conda install -y healpy
conda install -y photutils
conda install -y tensorflow

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
pip install astrorapid==0.1.21
pip install PyQt5
pip install matplotlib

if [ do_astrometry_dot_net == 1 ]; then
    ( cd astrometry.net-0.75 ; make pyinstall )
    pip install -v --no-deps --upgrade git+https://github.com/dstndstn/tractor.git
    cp -rp astrometry/libpython/astrometry anaconda3/lib/python*/site-packages/
fi

# Install the Data Lab client package
( cd datalab ; python setup.py install )


# GAVO Package installation
(cd gavoutils-$gavo_ver  ; python setup.py install)
(cd gavovot-$gavo_ver    ; python setup.py install)
(cd gavostc-$gavo_ver    ; python setup.py install)

conda clean -y -a

echo ""
echo ""
echo -n "End: "
/bin/date
echo ""

