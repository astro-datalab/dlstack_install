

DLSTACK_INSTALL -- Install the Anaconda+Packages used in Data Lab

```
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
```

Description:
------------

    This script downloads in configures a Python3 Anaconda system in the
current directory under a directory called 'anaconda3'. Additional packages
not included in the base Anaconda system (e.g. AstroPy, GAVO, etc) are also
installed via Conda or 'pip' commands as appropriate.

    The Data Lab client package is installed from the development Git
repository if the '--dev' flag is enable, otherwise the current PyPi 
version of the package is installed.



Building / Configuring the Data Lab Notebook Server Software Stack
------------------------------------------------------------------


    The Data Lab notebook software stack consists of one or more Jupyter
kernels in which each kernel is defined by a self-contained Anaconda
software directory.  The process of creating a kernel software tree is
notably separate from the process of configuring the Jupyter server, in
this document we'll provide an overview of both but the primary focus
will be on creating the default Python kernel for the notebook server
and procedures for updating or reverting versions of that kernel.

Background:
-----------

    All notebook software is assumed to be located in the directory

            /data0/sw

on whichever machine is hosting the server.  Within this directory are
the conda installations defining each kernel, for example:

    /data0/sw/anaconda2         - default Data Lab Py2 kernel (obsolete)
    /data0/sw/anaconda3         - default Data Lab Py3 kernel
    /data0/sw/antares-kernel    - ANTARES notebook kernel

The /data0/sw path is always assumed to be the production software
directory, but in practice this path is a symlink to the "active" version.
In order to efficiently support multiple users**, this version is deployed
on a ramdisk typically configured to be

            /data0/sw.tmpfs

where the /data0/sw link points to this ramdisk mount point.  The /etc/fstab
creates this ramdisk at boot time using the entry:

    tmpfs   /home/data0/sw.tmpfs tmpfs   nodev,nosuid,nodiratime,size=32G 0 0

Larger disk sizes can be configured as the software stack grows.
The symlink to create the desired path is then done with just:

    % sudo ln -s /data0/sw.tmpfs /data0/sw
    % sudo chown -R datalab:datalab /data0/sw.tmpfs

Because a ramdisk is not peristent across machine reboots, data stored
there must be backed-up in some way.  As of this writing, a cron job is
used to sync the ramdisk version of the /data0/sw directory link) to a
more persistent /data0/sw.hdd directory on physical disk, this is necessary
because under the current model new packages may be added to the production
software stack and these additions must be preserved.  In the event the
production code is never expected to be modified directly (e.g. under a
versioned-release model), this backup can (and should) be disabled

For maintaining multiple versions of the software tree, the /data0/sw.hdd
can itself be a link pointing a timestamped directory containing that
version.  Thus, the production tree is always accessible as /data0/sw
on fast ramdisk, its persistent backup is always at /data0/sw.hdd, and
individual versions can be located anywhere. Given this setup, a basic
directory structure might look something like:

        /data0/sw               --> /data0/sw.tmpfs
        /data0/sw.hdd           --> /data0/sw.2020-02-01
        /data0/sw.tmpfs
        /data0/sw.2020-02-01

Switching to a new/old version of the code then requires these steps (once
automated backup scripts and active notebook servers have been paused):

    1) Create a new software tree containing all desired kernels.
    2) Switch the /data0/sw.hdd symlink to point to this new version
    3) Sync that version to the /data0/sw.tmpfs ramdisk to deploy it
       to production.


  ** Python 'import' statements search the software tree to resolve the
     requested import, for a large kernel being accessed by many users 
     simultaneously, the I/O load creates a performance bottleneck.  Using
     the software from a ramdisk rather than spinning disk greatly improves
     the performance.  However, the ramdisk is not persistent across system
     reboots and must be sync'd to the harddisk directory before the nbserver
     can be functional.  Likewise when switching versions, the /data0/sw
     symlink shouldn't just be redirected to the new version's directory
     (this would then just use the slower harddisk), rather the ramdisk
     should be sync'd to this new version directory.


Creating the Software Stack:
----------------------------

    The software stack (for the Python 3 kernel and Jupyter environment) is
created automatically using a script located in:

        http://github.com/noaodatalab/dlstack_install

where a usage summary is as follows:

    Usage:
        % dlstack_install.sh [options...]

    Options:
        [-h|-?|--help] Display a usage summary
        [-c|--clean] Clean up existing version before install
        [-d|--dev] Install the dev 'datalab' package release
        [-e|--extensions] Install JupyterLab extensions
        [-k|--kernels] Install all kernel specs in kernel-spec dir
        [-s|--stable] Use the stable 'datalab' release (def: True)
        [-K <directory>] Set kernel-spec dir (def: /data0/kernel-specs)


This script will download and unpack the necessary software for creating
the default Python 3 kernel in an 'anaconda3' subdirectory of the current
working directory.  This is normally run from the /data0/sw directory,
thus the kernel path is /data0/sw/anaconda3.  So for example, on a
new machine the steps would be (following the use of /data0/sw as the
toplevel directory, and assuming the 'datalab' user):

    % cd /data0/sw
    % git clone https://github.com/noaodatalab/dlstack_install
    % ./dlstack_install/dlstack_install.sh 

The /data0/sw/anaconda3 directory will contain the Python 3 conda tree,
this is sufficient to run the Jupyter notebook however additional kernels
would need to be installed if required.


Conda Paths:
------------

    As with all Anaconda installations, the path to the directory is edited
into various files/environments in the tree (e.g. 'bin/conda', 'bin/pip',
etc).  Because we want each version created to use /data0/sw as the path
(since this a link to the faster ramdisk), we must usually be in the /data0/sw
for the desired path to be used in the conda script files (this is a
limitation imposed by the Anaconda install script itself).  Given the 
directory structure described above, we can't simply run the script in a
new directory (e.g. /data0/sw.<yyyy-mm-dd>) and still have the desired
"/data0/sw" path.  Rather, we need to build the new version in a directory
with the desired end path.  There are two ways to accomplish this:

    1) We first change the /data0/sw link to point to the new-version
       directory and begin the build, or
    2) We build directly in the /data0/sw production directory, overwriting
       the existing conda tree.

In the first case, the new version must be copied to the /data0/sw.tmpfs
ramdisk once the /data0/sw link is reset.  In the second case, the contents
of the /data0/sw.tmpfs directory must be copied to a new versioned directory.
In both cases, the '/data0/sw.hdd' link pointing to the persistent disk
store must be reset to the point to the active version.


The ANTARES Kernel:
-------------------

    The ANTARES notebook kernel is developed, maintained and updated as
needed by the ANTARES group directly.  The current notebook server
deployments define this to be located in

        /data0/sw/antares-kernel

which is owned by the 'antares' user (uid:899, gid:899) to allow remote
updates by the ANTARES group directly..


Defining a New Notebook Kernel:
-------------------------------

    The default Python 3 software stack created by the dlstack_install
script is what's normally used to run the Jupyter notebook server itself.
Notebook kernels are defined within this tree under, e.g.

        /data0/sw/anaconda3/share/jupyter/kernels

To add a new kernel, create a subdirectory (or use an existing directory
as a template) containing a 'kernel.json' file defining the kernel.
Because the python path used by the kernel is from a complete conda
installation, all packages loaded in that conda system are available to
the kernel and *independent* of other kernels.

Because the kernel directory may be deleted, or simply isn't present when a
new version is created, the current gp02/gp12 machines contain the directory

            /data0/kernel-specs

that contain the kernel specification for each of the implemented notebook
kernels.  Simply copy these directories to the jupyter kernel directory
to make it available in the notebook server, but be sure to also install
the corresponding conda directory tree where specified in the kernel file.

To simplify this process, the dlstack_install.sh script has a '-k' option
to automatically copy all kernel files to the new anaconda3 tree, and a 
'-K' option to specify the kernel-specs directory if it differs from
the default /data0/kernel-specs.


Step-by-Step Procedures:
------------------------

  I.)  Installing the notebook software stack on a new machine:

    1) Create the /data0 root directory.  This can be an existing disk
       partition or a subdirectory of an existing partition.  It is
       recommended that at least 32GB be available for this directory.

    2) Create the /data0 directories, links and ramdisk:

        # sudo mkdir /data0/sw.tmpfs
        # sudo ln -s /data0/sw.tmpfs /data0/sw
        # sudo mkdir /data0/sw.<yyyy-mm-dd>
        # sudo ln -s /data0/sw.<yyyy-mm-dd> /data0/sw.hdd
        # sudo mount -t tmpfs -o size=32G tmpfs /data0/sw.tmpfs
        # sudo chmod 777 /data0
        # sudo chown -R datalab:datalab /data0

    3) Download the latest version of the dlstack_install script:

        % cd /data0
        % git clone https://github.com/noaodatalab/dlstack_install

    4) Execute the install script in the ramdisk directory:

        % cd /data0/sw
        % /data0/dlstack_install/dlstack_install.sh

        ....Use the '-e' flag above if you wish to install JupyterLab
            extensions

        ....additional kernel configuration should go here, e.g. copy
            the latest antares-kernel and change it ownership to 'antares',
            install kernel spec files as described above, etc.

    5) Sync this directory tree to the timestamped version directory:

        % cd /data0/sw
        % rsync -a ./ /data0/sw.<yyyy-mm-dd>/

    Since this is a new machine, we don't assume a running Jupyter server.
    That would need to be configured separately, however all the needed
    software is installed to /data0/sw/anaconda3/bin


 II.)  Updating to a newer version on the production machine:

    We assume there is an existing /data0 tree as described above.

    1) Halt any running notebook server and/or ramdisk backup processes
       (details are machine dependent)

    2) Get the latest version of the dlstack_install script

        % cd /data0/dlstack_install
        % git pull

    3) Create the new timestamp versioned directory and reset the
       harddisk symlink:

        % cd /data0
        % mkdir sw.<yyyy-mm-dd>
        % rm sw.hdd && ln -s /data0/sw.<yyyy-mm-dd> /data0/sw.hdd

    4) Install the updated version to the ramdisk:

        % cd /data0/sw
        % /data0/dlstack_install/dlstack_install.sh --clean --kernels

        ....Use the '-e' flag above if you wish to install JupyterLab
            extensions
        ....The '--clean' flag will remove the existing version
        ....The '--kernels' flag will install any kernel definition
            files in /data0/kernel-specs.
        ....This version will not touch any other kernel directories

    5) Sync this directory tree to the timestamped version directory:

        % cd /data0/sw
        % rsync -a ./ /data0/sw.<yyyy-mm-dd>/

    6) Restart the Jupyter notebook server and/or ramdisk backup processes
       (details are machine dependent)


III.)  Reverting to an older version on the production machine:

    We assume there is an existing /data0 tree as described above.

    1) Halt any running notebook server and/or ramdisk backup processes
       (details are machine dependent)

    2) Install the old version to the ramdisk:

        % cd /data0/sw.<yyyy-mm-dd>
        % rsync -a --delete /data0/sw.<yyyy-mm-dd>/ ./

    3) Reset the harddisk symlink to point to the active version

        % cd /data0
        % rm sw.hdd && ln -s /data0/sw.<yyyy-mm-dd> /data0/sw.hdd

    4) Restart the Jupyter notebook server and/or ramdisk backup processes
       (details are machine dependent)

