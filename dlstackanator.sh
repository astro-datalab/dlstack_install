#!/bin/bash


# DLSTACK.SH  -- Installs the Data Lab software stack, using Anaconda as a base
#                system and extending functionality with additional packages.
#                It is designed to accommodate various deployment scenarios, including:
#                1. Installation on a bare-metal machine or VM, setting up
#                   JupyterHub and its kernels.
#                2. Integration within a Dockerfile for containerized environments.
#                3. Construction of the Data Lab kernel for use within the
#                   Data Lab JupyterHub on Google Cloud Platform (GCP).



set -e

# TODO not all the options are implemented. Revisit it.
usage() {
  echo "Usage:"
  echo "      $(basename $0) [options...]"
  echo ""
  echo "Options:"
  echo "   [-h|-?|--help]          Display a usage summary."
  echo "   [-A|--anaconda]         Install Anaconda."
  echo "   [-a|--active]           Print active version."
  echo "   [-b|--buildkernel]      Builds Jupyter Notebook kernel."
  echo "   [-c|--clean]            Clean up existing version before install."
  echo "   [-d|--dev]              Install the dev 'datalab' package release."
  echo "   [-e|--extensions]       Install JupyterLab extensions."
  echo "   [-f|--install_cfitio]   Install the cfitsio library."
  echo "   [-K|--kernel-dir <dir>] Set kernel-spec dir (default: /data0/kernel-specs)."
  echo "   [-k|--kernels]          Install all kernel specs in kernel-spec dir."
  echo "   [-j|--jhubserver]       Build JupyterHub server stack."
  echo "   [-m|--managers]         Install package managers only."
  echo "   [-P|--prefix <dir>]     Set the Anaconda installation prefix directory."
  echo "   [-S|--set-version <ver>]Set the active software version."
  echo "   [-s|--stable]           Use the stable 'datalab' release (default: True)."
  echo "   [-R|--root-dir <dir>]   Set root dir (default: /data0)."
  echo "   [-r|--create-env]       Create a new Conda environment."
  echo "   [--env-prefix <dir>]    Set the environment prefix directory."
  echo "   [--cbase <dir>]         Set the Conda base path."
  echo "   [--pyenv <ver>]         Set Python environment version. E.g., 3.10."
  echo "   [--dryrun]              Enable dry run mode (no changes made)."
  echo "   [--debug]               Enable debug output."
  echo "   [--verbose]             Enable verbose output."
  exit
}

log_verbose() {
    if [ "$_verbose" -eq 1 ]; then
        echo "$@"
    fi
}

# Cleanup function
cleanup_old_anaconda_install() {
    log_verbose "# ------------------------------------"
    log_verbose "Cleaning old install (dry run: $_dry_run) ..."
    if [ "$_dry_run" -eq 0 ]; then
        /bin/rm -rf ./anaconda3 ./downloads ./MANIFEST
    else
        echo "/bin/rm -rf ./anaconda3 ./downloads ./MANIFEST"
    fi
    log_verbose "Done"
    log_verbose "# ------------------------------------"
}

# Anaconda installation function
install_anaconda() {
    log_verbose ""
    log_verbose "----------------------------------------------"
    log_verbose "Downloading base Anaconda3 $ver system ...."
    log_verbose "----------------------------------------------"

    fname="Anaconda3-${ver}-${platform}-${arch}.sh"
    url="${base_url}${fname}"
    echo "fname=$fname"

    if [ "$_dry_run" -eq 0 ]; then
        if [ ! -f "./$name" ]; then
            curl -o "$fname" "$url"
        fi
        if [ ! -d "$prefix/anaconda3" ]; then
            mkdir "$prefix/anaconda3"
        fi
        chmod 755 "$fname"
        echo "export PWD=\"$prefix\" && sh \"$fname\" -b -u -p \"$prefix/anaconda3\""
        export PWD="$prefix" && sh "$fname" -b -u -p "$prefix/anaconda3"

        export PATH="$prefix/anaconda3/bin:$PATH"

        # Update conda and install configs
        conda update -n base -c defaults -y conda
        conda config --add channels conda-forge
        conda config --add channels astropy
        conda config --add channels glueviz
        conda config --add channels plotly
        conda config --add channels anaconda
    else
        log_verbose "Skipping download and installation in dry run mode."
    fi
}


# Function to check if a given path is a valid Conda environment
is_valid_conda_env() {
    local env_path="$1"

    # Check if the conda-meta directory exists in the given path
    if [[ -d "$env_path/conda-meta" ]]; then
        log_verbose "Valid Conda environment found at $env_path."
        return 0 # Success code
    else
        log_verbose "No valid Conda environment found at $env_path."
        return 1 # Error code
    fi
}

create_conda_env() {
    log_verbose "Updating conda"
    conda update -y conda
    conda install -y pip

    # Use a default prefix if env_prefix is not provided
    if [ -z "$env_prefix" ]; then
        # Default to the standard Conda envs directory if env_prefix is not specified
        env_prefix="$(conda info --base)/envs"
        log_verbose "env_prefix is not set, using default: $env_prefix"
    fi

    conda_env_dir="$env_prefix/py_${python_env_version}"

    # Ensure the directory exists
    if [ ! -d "$conda_env_dir" ]; then
        mkdir -p "$conda_env_dir"
    fi

    log_verbose "##** Create Python ${python_env_version} environment"
    log_verbose "conda create python=${python_env_version} --prefix=${conda_env_dir} -y"
    conda create python=${python_env_version} --prefix=${conda_env_dir} -y

    log_verbose "source activate \"$conda_env_dir\""
    source activate "$conda_env_dir"

    # Log the environment location after creation
    log_verbose "New conda environment created at: $conda_env_dir"
}

# Generalized function to construct a filename with the Python version appended
construct_filename_with_python_version() {
    local base_filename="$1"
    # Use the global python_version variable
    echo "${base_filename}${python_version}"
}

# TODO need to add doc on how this function works
install_packages_from_file() {
    local file_path="$1"
    # Check if the file exists
    if [ ! -f "$file_path" ]; then
        echo "Error: File not found: $file_path"
        exit 1
    fi

    log_verbose "$pip_path install --upgrade pip"
    $pip_path install --upgrade pip

    log_verbose "Processing package installation file: $file_path (dry run: $_dry_run)"

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" == \#* ]] || [[ -z "$line" ]] && continue

        log_verbose "Processing line: $line"

        # Handle special instructions (e.g., --reinstall)
        if [[ "$line" == --reinstall* ]]; then
            local packages_to_reinstall=(${line#--reinstall })
            for pkg in "${packages_to_reinstall[@]}"; do
                if [ "$_dry_run" -eq 0 ]; then
                    $pip_path uninstall --force "$pkg"
                    $pip_path install "$pkg"
                else
                    log_verbose "Dry run: Would uninstall and reinstall package $pkg"
                fi
            done
        elif [[ "$line" == conda+* ]]; then
            if [ "$_dry_run" -eq 0 ]; then
                    local python_pkg="${line#conda+}"
                    log_verbose "running: $conda_path install $python_pkg -y"
                    $conda_path install $python_pkg -y
            else
                    log_verbose "Dry run: conda path: [${conda_path}]"

                    log_verbose "Dry run: running: $conda_path install $python_pkg -y"
            fi
        elif [[ "$line" == git+* ]]; then
            if [ "$_dry_run" -eq 0 ]; then
                if [ "$do_stable" == "1" ]; then
                    # Create a temporary directory
                    local temp_dir=$(mktemp -d)
                    log_verbose "Created temporary directory $temp_dir for cloning"
                    # Extract repository URL and optional branch from the line
                    # Format: git+https://github.com/user/repo.git@branch
                    local repo_url_with_optional_branch="${line#git+}"
                    local branch_name=""
                    if [[ "$repo_url_with_optional_branch" == *@* ]]; then
                        # Extract the branch name if specified
                        branch_name="${repo_url_with_optional_branch##*@}"
                        # Remove the branch name from the URL
                        repo_url_with_optional_branch="${repo_url_with_optional_branch%@*}"
                    fi
                    # Clone the repository into the temporary directory, specifying the branch if present
                    if [ -n "$branch_name" ]; then
                        git clone -b "$branch_name" "$repo_url_with_optional_branch" "$temp_dir"
                    else
                        git clone "$repo_url_with_optional_branch" "$temp_dir"
                    fi
                    # Install from the cloned local repository
                    $pip_path install "$temp_dir"
                    # Clean up the temporary directory
                    rm -rf "$temp_dir"
                else
                    # Directly install using pip, supports URLs with branches
                    $pip_path install "$line"
                fi
            else
                log_verbose "Dry run: Would install package from Git URL $line"
            fi
        else
            if [ "$_dry_run" -eq 0 ]; then
                # Normal pip install
                $pip_path install "$line"
            else
                log_verbose "Dry run: Would install package $line"
            fi
        fi
    done < "$file_path"
}

install_cfitsio() {
    local PREFIX=$1

    if [[ -z ${PREFIX} ]]; then
        PREFIX="/usr/local"
    fi

    local cfitsio_ver="4.2.0"

    # Download, extract, configure, compile, and install CFITSIO
    set -eux
    wget https://heasarc.gsfc.nasa.gov/FTP/software/fitsio/c/cfitsio-${cfitsio_ver}.tar.gz
    tar xzvf cfitsio-${cfitsio_ver}.tar.gz
    pushd cfitsio-${cfitsio_ver}
    ./configure --prefix=${PREFIX}
    make
    make install
    popd

    # Cleanup
    rm -rf cfitsio-${cfitsio_ver} cfitsio-${cfitsio_ver}.tar.gz
}

install_gavo() {

    local temp_dir=$(mktemp -d)
    cd ${temp_dir}
    gavo_ver="2.6"
    log_verbose "Created temporary directory $temp_dir for gavo ${gavo_ver} installation"

    wget "https://soft.g-vo.org/dist/gavoutils-${gavo_ver}.tar.gz"
    wget "https://soft.g-vo.org/dist/gavostc-${gavo_ver}.tar.gz"
    wget "https://soft.g-vo.org/dist/gavovot-${gavo_ver}.tar.gz"

    tar xvf gavoutils-${gavo_ver}.tar.gz
    tar xvf gavostc-${gavo_ver}.tar.gz
    tar xvf gavovot-${gavo_ver}.tar.gz

    (cd gavoutils-$gavo_ver  ; ${python_path} setup.py install)
    rm -rf gavoutils-$gavo_ver; rm gavoutils-${gavo_ver}.tar.gz
    (cd gavovot-$gavo_ver    ; ${python_path} setup.py install)
    rm -rf gavovot-$gavo_ver ; rm gavovot-${gavo_ver}.tar.gz
    (cd gavostc-$gavo_ver    ; ${python_path} setup.py install)
    rm -rf gavostc-$gavo_ver; rm gavostc-${gavo_ver}.tar.gz

    log_verbose "Clean gavo ${temp_dir}"
    cd ..
    rm -rf "$temp_dir"
}


#TODO where does the astrometry code comes from?
install_astrometry() {
    log_verbose "----------------------------------------------"
    log_verbose " Installing astrometry.net packages ...."
    log_verbose "----------------------------------------------"
    local temp_dir=$(mktemp -d)
    cd ${temp_dir}
    ( cd astrometry.net-0.75 ; make pyinstall )
    ${pip_path} install -v --no-deps --upgrade git+https://github.com/dstndstn/tractor.git
    cp -rp astrometry/libpython/astrometry anaconda3/lib/python*/site-packages/

    log_verbose "Clean astrometry ${temp_dir}"
    cd ..
    rm -rf "$temp_dir"
}

get_env() {
    # Environment paths might change; re-capture them
    export python_path=$(which python || echo "")
    export pip_path=$(which pip || echo "")
    export conda_path=$(command -v conda || echo "")

    # Making sure to not proceed if python_path is empty
    if [ -z "$python_path" ]; then
        log_verbose "Python was not found in your system."
        exit 1
    fi

    # Deriving python_version
    export python_version=$($python_path -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")

    # We can attempt to find the root of the conda installation here again in a secure manner
    # if conda_path is not empty
    if [ -n "$conda_path" ]; then
        export conda_base_path=$($conda_path info --base 2>/dev/null || echo "")
    fi

    log_verbose "Current Environment -- Python: ${python_path} (v${python_version}), Conda: ${conda_path}, Pip: ${pip_path}"
}


# Main function
main() {
    if [[ "$do_cfitsio" == "1" ]]; then
       log_verbose "Install cfitsio"
       install_cfitsio
    fi

    if [ "$do_clean" == 1 ]; then
        cleanup_old_anaconda_install
    fi
    # if which python error then install conda?
    if [ "$do_install_anaconda" == 1 ]; then
        install_anaconda
    fi

    # export whatever conda and python env we have
    get_env

    # Use a default prefix if env_prefix is not provided
    if [ -z "$env_prefix" ]; then
        # Default to the standard Conda envs directory if env_prefix is not specified
        env_prefix="$(conda info --base)/envs"
        log_verbose "env_prefix is not set, using default: $env_prefix"
    fi

    log_verbose "env_prefix=${env_prefix} python_env_version ${python_env_version}"
    if [[ "$do_create_env" == 1 &&  -n "$python_env_version" ]]; then
        log_verbose "create_conda_env for $env_prefix and version $python_env_version"
        create_conda_env
        get_env
    fi

    if [[ -n "$env_prefix" && -n "$python_env_version" ]] &&
         { is_valid_conda_env "$env_prefix/py_${python_env_version}"; }; then
           log_verbose "source activate \"$env_prefix/py_${python_env_version}\""
           source activate "$env_prefix/py_${python_env_version}"
           # get new environment vars
           get_env
    fi

    if [ "$do_managers_only" == "1" ]; then
        local filename_base="managers_requirement_py" # Example base filename
        local packages_file
        packages_file=$(construct_filename_with_python_version "$filename_base")".txt"
        log_verbose "install_packages_from_file \"$packages_file\""
        install_packages_from_file "$packages_file"
    fi

    if [ "$do_jhubserver" == "1" ]; then
        local filename_base="jupyterHub_requirement_py" # Example base filename
        local packages_file
        packages_file=$(construct_filename_with_python_version "$filename_base")".txt"
        log_verbose "install_packages_from_file \"$packages_file\""
        install_packages_from_file "$packages_file"
    fi

    if [[ "$do_buildkernel" == "1" ]]; then
        get_env
        log_verbose "build datalab stack for python env ${python_env_version} python path ${python_path}"
        local filename_base="jupyterNotebook_kernel_requirement_py" # Example base filename
        local packages_file
        packages_file=$(construct_filename_with_python_version "$filename_base")".txt"
        log_verbose "install_packages_from_file \"$packages_file\""
        install_packages_from_file "$packages_file"
        # install datalab kernel
        log_verbose "Install kernel ${python_path} under ${conda_base_path}"
        $python_path -m ipykernel install \
        --name="python3_default" \
        --display-name="DL Py${python_env_version} (default)" --prefix=${conda_base_path}
    fi

    # gavo will always install when building a kernel or the managers
    if [[ "$do_gavo" == "1" ]] && { [[ "$do_buildkernel" == "1" ]] || [[ "$do_managers_only" == "1" ]]; }; then
       log_verbose "Install gavo"
       install_gavo
    fi
}

# Global variable indicating whether to proceed with installation

# --------------------
# Process script args.
# --------------------

# Script settings and default values
root_dir='/data0'
ver="2023.03-1"  # Anaconda version to install
arch="x86_64"    # Architecture
platform="Linux" # Platform
base_url="https://repo.anaconda.com/archive/"  # Anaconda download repo
prefix="./"      # Installation prefix
kernel_dir="${root_dir}/kernel-specs"
conda_base_path="${root_dir}/sw/anaconda3"

# Feature flags and options
do_gavo=1        # gavo always on
do_dev=0
do_install_anaconda=0
do_create_env=0
do_clean=0
do_buildkernel=0
do_stable=1
do_active=0
do_cfitsio=0
do_kernels=0
do_jhubserver=0
do_jupyterlab_extensions=0
do_managers_only=0

# Miscellaneous options
env_prefix=""
python_env_version=""
version=''
_dry_run=0
_debug=0
_verbose=0

declare -a userargs skiplist
while [ "$#" -gt 0 ]; do
    case $1 in
        -h|-\?|--help) usage;;
        -A|--anaconda) export do_install_anaconda=1;;
        -a|--active) export do_active=1;;
        -b|--buildkernel) export do_buildkernel=1;;
        -c|--clean) export do_clean=1;;
        -d|--dev) export do_dev=1;export do_stable=0;;
        -e|--extensions) export do_jupyterlab_extensions=1;;
        -f|--install_cfitsio) export do_cfitsio=1;;
        -K|--kernel-dir) shift;kernel_dir=$1;;
        -k|--kernels) export do_kernels=1;;
        -j|--jhubserver) export do_jhubserver=1;;
        -m|--managers) export do_managers_only=1;;
        -P|--prefix) shift; prefix=$1;;
        -S|--set-version) shift;version=$1;;
        -s|--stable) export do_stable=1;export do_dev=0;;
        -R|--root-dir) shift;root_dir=$1;;
        -r|--create-env) export do_create_env=1;;
        --env-prefix) shift; env_prefix=$1;;
        --cbase) shift;conda_base_path=$1;;
        --pyenv) shift;python_env_version=$1;;
        --dryrun) _dry_run=1;;
        --debug) _debug=1;;
        --verbose) _verbose=1;;
        *) userargs=("${userargs[@]}" "${1}");;
    esac; shift
done

main
