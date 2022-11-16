#!/bin/bash
#
#  DLSTACK.SH -- Install the Data Lab software using Anaconda as a base
#                system plus additional packages.

export SHELL=/bin/bash


#ver="2020.07"					# Anaconda version to install
ver="2021.05"					# Anaconda version to install
#ver="2022.05"					# Anaconda version to install
base_url="https://repo.anaconda.com/archive/"	# Anaconda download repo

# ===========================================================================
# Optional installs (Note: not all of these build cleanly and should probably
# be done manually when needed).

export do_gavo=1
export do_astrometry_dot_net=0
export do_jupyterlab_extensions=0
# ===========================================================================


function usage {
  echo "Usage:"
  echo "      $(basename $0) [options...]"
  echo ""
  echo "Options:"
  echo "   [-h|-?|--help]        Display a usage summary"
  echo "   [-a|--active]         Print active version"
  echo "   [-c|--clean]          Clean up existing version before install"
  echo "   [-d|--dev]            Install the dev 'datalab' package release"
  echo "   [-e|--extensions]     Install JupyterLab extensions"
  echo "   [-k|--kernels]        Install all kernel specs in kernel-spec dir"
  echo "   [-s|--stable]         Use the stable 'datalab' release (def: True)"
  echo " "
  echo "   [-K <directory>]      Set kernel-spec dir (def: /data0/kernel-specs)"
  echo "   [--kernel-dir <dir>]  Set kernel-spec dir (def: /data0/kernel-specs)"
  echo "   [-R <directory>]      Set root dir (def: /data0)"
  echo "   [--root-dir <dir>]    Set root dir (def: /data0)"
  echo "   [-S <ver>]            Set the active software version"
  echo "   [--set-version <ver>] Set the active software version"
  echo " "
  echo "   [--debug]             Enable debug output"
  echo "   [--verbose]           Enable verbose output"
  exit
}

function check_jupyter_running {
  if [ `ps -efw | grep anaconda3/bin/jupyter | wc -l` -gt 1 ]; then
    echo " "
    echo "ERROR:  Detected a running Jupyter instance.  Please"
    echo "        shut down the Jupyter server before continuing."
    echo " "
    exit 1
  fi
}

function remind_jupyter_restart {
  if [ `ps -efw | grep anaconda3/bin/jupyter | wc -l` -eq 1 ]; then
    echo " "
    echo "WARNING: Remember to restart Jupyter server in order"
    echo "         for changes to take effect."
    echo " "
  fi
}

function verify_disk_structure {
  nerr=0
  if [ ! -e ${root_dir}"/sw" ]; then
    echo "ERROR:  Directory ${root_dir}/sw does no exist"
    nerr=nerr+1
  fi
  if [ ! -e ${root_dir}"/sw.hdd" ]; then
    echo "ERROR:  Directory ${root_dir}/sw.hdd does no exist"
    nerr=nerr+1
    exit
  fi
  if [ ! -e ${root_dir}"/sw.tmpfs" ]; then
    echo "ERROR:  Directory ${root_dir}/sw.tmpfs does no exist"
    nerr=nerr+1
  fi

  if [ $nerr -gt 0 ]; then
    exit
  fi
}

function verify_active_version {
  echo -n "Validating /data0/sw is $1 ... "
  diff -rq --no-dereference ${root_dir}"/sw/" ${1}/ &> /dev/null
  if [ $? == 0 ]; then
    echo "OK"
  else
    echo "ERROR: ${root_dir}/sw and $1 differ"
    exit
  fi
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
do_dev=0
do_clean=0
do_stable=1
do_active=0
do_kernels=0
do_managers_only=0
root_dir='/data0'
kernel_dir='/data0/kernel-specs'

declare -a userargs skiplist
while [ "$#" -gt 0 ]; do
    case $1 in
        -h|-\?|--help) usage;;
        -a|--active) export do_active=1;;
        -c|--clean) export do_clean=1;;
        -d|--dev) export do_dev=1;export do_stable=0;;
        -e|--extensions) export do_jupyterlab_extensions=1;;
        -k|--kernels) export do_kernels=1;;
        -m|--managers) export do_managers_only=1;;
        -s|--stable) export do_stable=1;export do_dev=0;;
        -K|--kernel-dir) shift;kernel_dir=$1;;
        -R|--root-dir) shift;root_dir=$1;;
        -S|--set-version) shift;version=$1;;
        --debug) _debug=1;;
        --verbose) _verbose=1;;
        *) userargs=("${userargs[@]}" "${1}");;
    esac; shift
done



# =========================================
# See if we're printing the active version.
# =========================================

if [ $do_active == 1 ]; then

  if [ $_debug == 1 ]; then echo "    Root directory: "${root_dir}; fi

  # First check that we have the canonical directory structure
  # we expect for this script.
  verify_disk_structure

  if [[ -L ${root_dir}"/sw.hdd" ]]; then
    aver=`readlink -f ${root_dir}"/sw.hdd"`
    echo "Active-version directory: "$aver
  else
    aver=`readlink -f ${root_dir}"/sw"`
    echo "Active-version directory: "$aver
  fi

  # Verify that the active version is the same as ${root_dir}/sw
  verify_active_version $aver

  if [ $_verbose == 1 ]; then
    if [[ -L /data0/sw ]]; then
        echo "    /data0/sw link -> "`readlink -f /data0/sw`
    else
        echo "    /data0/sw is a directory"
    fi

    if [[ -L /data0/sw.hdd ]]; then
        echo "    /data0/sw.hdd link -> "`readlink -f /data0/sw.hdd`
    else
        echo "    /data0/sw.hdd is a directory"
    fi

    if [[ -L /data0/sw.tmpfs ]]; then
        echo "    /data0/sw.tmpfs link -> "`readlink -f /data0/sw.tmpfs`
    elif [[ -d /data0/sw.tmpfs ]]; then
        echo "    /data0/sw.tmpfs is a directory"
    else
        echo "    /data0/sw.tmpfs is does not exist"
    fi
  fi
  exit
fi


# ========================================
# See if we're resetting the version only.
# ========================================

if [ "$version" != "" ]; then

    if [ `dirname $version` == '.' ]; then
        vpath=${root_dir}"/"${version}
    else
        vpath=${version}
    fi
    echo "Resetting to version:  "$vpath

    if [ -e ${vpath} ]; then
        # If we're resetting the version in some way, be sure the Jupyter
        # server has been shut down first.
        check_jupyter_running

        if [ $_verbose == 1 ]; then
            echo -n "  Syncing files to active dir ... "
        fi
        cd ${root_dir}"/sw" && rsync -a --delete ${vpath}/ ./
        if [ $_verbose == 1 ]; then
            echo    "done"
        fi

        if [ -e ${root_dir}"/sw.hdd" ]; then
          if [[ -L ${root_dir}"/sw.hdd" ]]; then
            if [ $_verbose == 1 ]; then
                echo -n "  Resetting sw.hdd link ... "
            fi
            
            cd $root_dir && rm sw.hdd && ln -s ${vpath} ${root_dir}"/sw.hdd"
            if [ $_verbose == 1 ]; then
                echo    "done"
            fi
          fi
        fi

        remind_jupyter_restart
    else
        echo "ERROR: No such version directory: "${vpath}
    fi
    exit
fi



# ====================================
# Clean up any existing installation.
# ====================================
if [ $do_clean == 1 ]; then
    echo "# ------------------------------------"
    echo -n "Cleaning old install ..... "
    #/bin/rm -rf ./anaconda3 ./downloads ./get-pip.py ./MANIFEST
    /bin/rm -rf ./anaconda3 ./downloads ./MANIFEST
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

# Download the latest PIP installer.
#curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
#anaconda3/bin/python get-pip.py

# Update conda and install configs
conda update -n base -c defaults -y conda
conda config --add channels conda-forge
conda config --add channels astropy
conda config --add channels glueviz
conda config --add channels plotly
conda config --add channels anaconda
conda config --add channels https://conda.anaconda.org/als832
conda config --add channels https://conda.anaconda.org/pmuller


# ============================================================================

echo "" && echo ""
echo -n "Start: "
/bin/date
echo ""

# ===================
# Anaconda Python 3.8
# ===================

echo ""
echo "----------------------------------------------"
echo " Installing Python3 packages ...."
echo "----------------------------------------------"

# ===============
# Conda Installs
# ===============
#conda install -y --freeze-installed  uwsgi
if [ do_managers_only == 0 ]; then
    conda install -y --freeze-installed  nodejs=12.4.0
    conda install -y --freeze-installed  tensorflow openblas mysqlclient
    conda install -y --freeze-installed  mpi4py
fi


# ===============
# PIP Installs
# ===============
pip install --upgrade pip

pip install flask
pip install flask_cors

pip install astropy
pip install astropy-helpers
pip install astropy-healpix
pip install astroquery
pip install astrocalc
pip install healpy
pip install httplib2
pip install numpy
pip install pathlib
pip install psycopg2
pip install pycurl-requests
pip install pyvo
pip install pandas
pip install rebound
pip install redis
pip install Shapely==1.8.1.post1
pip install simplejson

if [ do_managers_only == 0 ]; then
    pip install astor
    pip install astroml
    pip install astroplan
    pip install autopep8
    pip install batman-package
    pip install docker-py
    pip install emcee
    pip install "fitsio==1.1.5"
    pip install future
    pip install gatspy
    pip install ginga
    pip install "glueviz==0.14"
    pip install h5py==2.10.0
    pip install ipympl
    pip install ipython==7.12.0
    pip install jampy
    pip install jupyterhub==1.4.2
    pip install jupyterlab==3.1.11
    pip install jupyter-nbextensions-configurator
    pip install lmfit
    pip install matplotlib
    pip install mgefit
    pip install mpdaf
    pip install nbresuse
    if [ $do_stable == 1 ]; then
        #pip install astro-datalab
        git clone http://github.com/astro-datalab/datalab.git
        ( cd datalab ; python setup.py install )

        #pip install fits2db
        git clone http://github.com/astro-datalab/fits2db
        ( cd fits2db ; python setup.py install )
    else
        pip install git+https://github.com/astro-datalab/datalab
        pip install git+https://github.com/astro-datalab/fits2db
    fi
    pip install pafit
    pip install passlib
    pip install ppxf
    pip install photutils
    #pip install git+https://github.com/desihub/prospect.git@1.2.0
    pip install pyopengl
    pip install rebound
    pip install sparclclient==1.0.0
    pip install speclite
    pip install specutils
    pip install termcolor
    pip install virtualenv
    pip install vorbin
    pip install wget

    pip uninstall --force spyder            # for dependency resolution below
    pip uninstall --force pyqt5 pyqtwebengine
    pip install spyder
    pip install pyqt5 pyqtwebengine
fi


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
    git clone http://github.com/astro-datalab/datalab.git
    ( cd datalab ; python setup.py install )
fi

# Clone the Data Lab Authenticator
git clone https://github.com/astro-datalab/dlauthenticator
( cd dlauthenticator ; python setup.py install )

# Install the PROSPECT viewer
git clone -q https://github.com/desihub/prospect.git
( cd prospect ; \
    git checkout -q 87479dbcdf1ed4720fb6eeb74eba571432fabe41 ; \
    python setup.py install )


# ------------------------------------------------------------------------
# Recent Anaconda packages require a re-install of jupyterhub ...
conda install -y jupyterhub
#pip install jupyterhub --force-reinstall

# ------------------------------------------------------------------------
if [ $do_jupyterlab_extensions == 1 ]; then
    echo ""
    echo "----------------------------------------------"
    echo " Installing JupyterLab packages ...."
    echo "----------------------------------------------"

    #conda install -c conda-forge -y ipywidgets		# enabled automatically
    pip install ipywidgets				# enabled automatically?

    jupyter labextension install @jupyterlab/hub-extension

    #conda install -c plotly -y jupyterlab-dash
    pip install jupyterlab-dash

    #jupyter labextension install @jupyterlab/toc
    #jupyter labextension install jupyterlab-drawio
    #jupyter labextension install @lckr/jupyterlab_variableinspector

    #conda install -c conda-forge -y ipyleaflet
    #conda install -c conda-forge -y ipytree
    #conda install -c conda-forge -y ipyvolume
    pip install ipyleaflet
    pip install ipytree
    pip install ipyvolume

    #conda install -c conda-forge -y qgrid
    pip install qgrid
    jupyter labextension install qgrid

    pip install sidecar
    jupyter labextension install @jupyter-widgets/jupyterlab-sidecar

    #jupyter labextension install @jupyterlab/xkcd-extension
    #jupyter labextension install @jupyter-widgets/jupyterlab-manager
    #jupyter labextension install jupyterlab_bokeh	# wrong version

#    jupyter labextension install @lckr/jupyterlab_variableinspector
    jupyter labextension install jupyter-threejs		# build fail
    jupyter labextension install jupyterlab-flake8
    jupyter labextension install ipyvolume			# build fail

    #conda install -c wwt -y pywwt
    pip install pywwt

    jupyter serverextension nbextens_configurator enable --user
fi
jupyter lab build


# ------------------------------------------------------------------------
# Install third-party kernel spec files
if [ $do_kernels == 1 ]; then
    echo "----------------------------------------------"
    echo " Installing kernels ...."
    echo "----------------------------------------------"
    if [ -e ${kernel_dir} ]; then
        echo "Copying Kernel files .... "
        cp -rp $kernel_dir/* $prefix/anaconda3/share/jupyter/kernels/
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
if [ $do_dev == 1 ]; then
    mv datalab downloads
fi
#mv Anaconda*.sh *.gz gavo* get-pip.py dlauthenticator downloads
mv Anaconda*.sh *.gz gavo* dlauthenticator downloads
conda clean -y -a

# Create the local manifest file.
pip freeze >& MANIFEST


echo "" && echo ""
echo -n "End: "
/bin/date
echo ""
