

DLSTACK_INSTALL -- Install the Anaconda+Packages used in Data Lab


Usage:
------
      % ./dlstack_install.sh [options...]

Options:
    [-h|-?|--help]      Display a usage summary
    [-c|--clean]        Clean up existing version before install
    [-d|--dev]          Install the dev 'datalab' package release
    [-e|--extensions]   Install JupyterLab extensions
    [-k|--kernels]      Install all kernel specs
    [-s|--stable]       Use the stable 'datalab' package release (def: Yes)
    [-K <directory>]    Set kernel-spec directory (def: /data0/kernel-specs)


Description:
------------

    This script downloads in configures a Python3 Anaconda system in the
current directory under a directory called 'anaconda3'. Additional packages
not included in the base Anaconda system (e.g. AstroPy, GAVO, etc) are also
installed via Conda or 'pip' commands as appropriate.

    The Data Lab client package is installed from the development Git
repository if the '--dev' flag is enable, otherwise the current PyPi 
version of the package is installed.

