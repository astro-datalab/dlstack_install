# To build an image
# docker build --build-arg GIT_TOKEN=<your_git_token> -t my_dlstackanator_image .
#
# To obtain a container shell from the image
# docker run --name my_dlstackanator_container --rm -it my_dlstackanator_image

FROM ubuntu:22.3

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV PATH=/data0/anaconda3/bin:$PATH

# Install necessary packages
RUN apt-get update && apt-get install -y \
    wget \
    bzip2 \
    ca-certificates \
    curl \
    git \
    build-essential \
    zlib1g-dev \
    ncurses-term \
    pkg-config \
    libhdf5-dev \
    libmysqlclient-dev \
    librdkafka-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Clone the dlstack_install repository from the specified branch
ARG GIT_TOKEN
RUN git clone -b dlstackanator https://$GIT_TOKEN@github.com/astro-datalab/dlstack_install.git /dlstack_install

# Run the dlstackanator.sh script to download and install Anaconda
WORKDIR /dlstack_install
RUN ./dlstackanator.sh -A -P /data0 -p /data0/envs -v 3.10 -r -b --verbose

# Set the working directory
WORKDIR /workspace

# Activate the Conda environment and set it as the default command
CMD ["bash", "-c", "source activate /data0/envs/py_3.10 && /bin/bash"]
