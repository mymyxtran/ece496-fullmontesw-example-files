#!/bin/bash

# ONLY RUN THE FOLLOWING TWO COMMANDS TO INSTAL DOCKER THE 
# FIRST TIME YOU SETUP THE EC2 INSTANCE
# The real FullMonteWeb uses the aws_setup script instead of just this command
# you should only use this script for testing purposes, not production

# curl -fsSL https://get.docker.com -o get-docker.sh
# sudo sh get-docker.sh

# By default we pull from the 'master' branch but if you want to pull from 
# another branch simple change the 'TAG' variable below to the branch name
TAG=master

REGISTRY=registry.gitlab.com

# Gets the FullMonteSW container image for user mode (not developer mode)
IMG=-run

MIDDLE=fullmonte/fullmontesw/fullmonte$IMG

IMAGE=$REGISTRY/$MIDDLE:$TAG

###############################################################################
## NVIDIA-DOCKER
# The following installs the nvidia-docker2 utility which allows the Docker
# image to access the host's GPU. The following commands are taken from the
# NVIDIA docker github (https://github.com/NVIDIA/nvidia-docker) and are
# specific to Ubuntu. If you have a different HOST OS then the commands in this
# section must be changed (again, see https://github.com/NVIDIA/nvidia-docker).
# YOU CAN IGNORE THIS BLOCK IF YOU ARE NOT USING CUDA ACCELERATION

# only bother doing this if you enabled CUDA (CUDA=true above)
if $1; then
	# checking if nvidia-docker2 is already installed, if it is skip this part
    if !hash nvidia-docker 2>/dev/null; then
        # If you have nvidia-docker 1.0 installed: we need to remove it and all existing GPU containers
        docker volume ls -q -f driver=nvidia-docker | xargs -r -I{} -n1 docker ps -q -a -f volume={} | xargs -r docker rm -f
        sudo apt-get purge -y nvidia-docker

        # Add the package repositories
        curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | \
            sudo apt-key add -
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
            sudo tee /etc/apt/sources.list.d/nvidia-docker.list
        sudo apt-get update

        # Install nvidia-docker2 and reload the Docker daemon configuration
        sudo apt-get install -y nvidia-docker2
        sudo pkill -SIGHUP dockerd
    fi
fi
###############################################################################


# The local path to be mounted to /sims in the container
# Both your regular OS and the docker container will be able to see this folder
# Default  location is ~/docker/sims; Comment (#) and edit the following two lines if you do not want to create this default folder
HOME_DIR=$PWD
mkdir -p $HOME_DIR

# Pull the Docker image
docker login -u $3 $REGISTRY -p $4
docker pull $IMAGE

# Run Docker image
# --rm: Delete container on finish
# -t:   Provide terminal (we aren't using this setting with automated scripts)
# -i:   Interactive (we aren't using this setting with automated scripts)
# -e:   Set environment variable DISPLAY
# -v:   Mount host path into container <host-path>:<container path>
# --privileged: Allow container access to system sockets (for X)
# --runtime=nvidia: Uses the NVIDIA runtime to allow access to the hosts GPU

# build the docker command string
NVIDIA_RUNTIME_STR=""
if $1; then
    NVIDIA_RUNTIME_STR="--runtime=nvidia"
fi

# make the script to start a simulation executable
chmod +x ./docker.sh

# make the tcl script executable
chmod +x ./$2

# If you'd like to run the FullMonteSW container manually as in the original setup file,
# enter this into your instance terminal:
# docker run --rm -it -v $PWD:/sims -v /tmp/.X11-unix/X0:/tmp/.X11-unix/X0 --privileged -e DISPLAY=:0 --ipc=host registry.gitlab.com/fullmonte/fullmontesw/fullmonte-run

# create and start a FullMonteSW container and run docker.sh with your tcl script
DOCKER_COMMAND="docker run --rm -v $HOME_DIR:/sims -v /tmp/.X11-unix/X0:/tmp/.X11-unix/X0 --privileged -e DISPLAY=:0 --ipc=host $NVIDIA_RUNTIME_STR $IMAGE bash ./sims/docker.sh ./$2"

# run the docker command
eval $DOCKER_COMMAND
