FROM osrf/ros:indigo-desktop-full

# using bash instead of sh to be able to source
ENV TERM xterm
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Load the GitHub key from a variable passed to the build script
# Do this near the beginning so we don't waste time if the key isn't available.
ARG GITHUB_KEY=local
ENV GITHUB_KEY ${GITHUB_KEY}

# Install Gazebo 7 on ROS Indigo
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -yqq \
        python-catkin-tools \
        ros-indigo-moveit \
        wget \
        && \
    echo "deb http://packages.osrfoundation.org/gazebo/ubuntu-stable `lsb_release -cs` main" > /etc/apt/sources.list.d/gazebo-stable.list && \
    wget http://packages.osrfoundation.org/gazebo.key -O - | apt-key add - && \
    apt-get update && \
    apt-get remove -y gazebo2 && \
    DEBIAN_FRONTEND=noninteractive apt-get install -yqq \
        gazebo7 \
        ros-indigo-gazebo7-ros-pkgs \
        ros-indigo-gazebo7-ros-control \
        ros-indigo-controller-manager \
        ros-indigo-ros-controllers \
        python-pip

# Create a new catkin workspace
RUN mkdir -p /workspace/src && \
    cd /workspace/ && \
    source /opt/ros/indigo/setup.bash && \
    catkin init

# Copy the files in *this* (Dockerfile-containing) package into the new workspace
COPY . /workspace/src/


# Download application-specific code, as well as gazebo7 deps?
RUN source /opt/ros/indigo/setup.bash && \
    cd /workspace/src && \
    git clone -b indigo-devel https://${GITHUB_KEY}@github.com/Kukanani/gazebo_ros_pkgs && \
    git clone https://${GITHUB_KEY}@github.com/Kukanani/stevia && \
    git clone https://github.com/shadow-robot/pysdf.git && \
    git clone -b F_add_moveit_funtionallity https://github.com/shadow-robot/gazebo2rviz.git && \
    git clone -b F_gazebo_7_docker https://github.com/shadow-robot/universal_robot.git && \
    git clone -b F#182_partial_trajectory_mod  https://github.com/shadow-robot/ros_controllers.git && \
    wget https://raw.githubusercontent.com/osrf/osrf-rosdep/master/gazebo7/00-gazebo7.list -O /etc/ros/rosdep/sources.list.d/00-gazebo7.list && \
    apt-get update && \
    rosdep update && \
    rosdep install --default-yes --all --ignore-src && \
    catkin build --cmake-args -DCMAKE_BUILD_TYPE=Release

# install nvm and node, required because of older version of node packages with trusty (which is used because of indigo)
RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.0/install.sh | bash
ENV NVM_DIR /root/.nvm
ENV NODE_VERSION 6.1.0
RUN . /root/.nvm/nvm.sh && nvm install $NODE_VERSION && nvm use $NODE_VERSION
ENV NODE_PATH $NVM_DIR/versions/node/v$NODE_VERSION/lib/node_modules
ENV PATH      $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# install gzweb
RUN curl -sL https://deb.nodesource.com/setup | bash - && \
    DEBIAN_FRONTEND=noninteractive apt-get install -yqq libjansson-dev libboost-dev imagemagick libtinyxml-dev mercurial cmake build-essential xvfb
RUN /workspace/src/setup_gzweb.sh

# Install Cloud9 IDE
RUN cd /root && \
    git clone git://github.com/c9/core.git c9sdk && \
    cd c9sdk && \
    scripts/install-sdk.sh && \
    sed -i -e 's_127.0.0.1_0.0.0.0_g' /root/c9sdk/configs/standalone.js

# Install Jupyter and data analysis packages
RUN apt-get remove -y python-pip && \
    wget https://bootstrap.pypa.io/get-pip.py && \
    python get-pip.py && \
    pip2 install --upgrade \
        packaging \
        jupyter \
        && \
    pip2 install --upgrade \
        jupyter_contrib_nbextensions \
        && \
    pip2 install --upgrade \
        tensorflow \
        keras \
        h5py \
        sklearn \
        bokeh \
        bayesian-optimization \
        pandas \
        && \
    jupyter contrib nbextension install --system --symlink && \
    mkdir -p /root/.jupyter && \
    jupyter nbextension enable toc2/main

COPY jupyter_notebook_config.py /root/.jupyter/

# cleanup
RUN rm -rf /var/lib/apt/lists/*

# setup entrypoint
COPY ./entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

# open ports for GZWeb, Jupyter notebook, and Cloud9
EXPOSE 8080 8888 8181 7681
