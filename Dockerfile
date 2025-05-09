FROM ubuntu:22.04
LABEL maintainer="James Shen <jierans@sas.upenn.edu>"

SHELL ["/bin/bash", "-c"]

RUN apt-get -q update \
 && DEBIAN_FRONTEND=noninteractive apt-get -qy install --no-install-recommends \
    git curl build-essential vim libx11-dev libxpm-dev libqt5opengl5-dev ssh cmake \
    xserver-xorg-video-intel libxft-dev libxext-dev libxerces-c-dev \
    libxkbcommon-x11-dev libopengl-dev python3 python3-dev python3-numpy \
    libcurl4-gnutls-dev ca-certificates libssl-dev libffi-dev \
 && apt-get autoclean \
 && apt-get clean
# Strip ABI tag to ensure that QT libraries can be used on EL7
RUN strip --remove-section=.note.ABI-tag /usr/lib/x86_64-linux-gnu/libQt5Core.so.5
RUN useradd -ms /bin/bash ratuser

WORKDIR /

RUN git clone https://github.com/rat-pac/ratpac-setup.git
WORKDIR /ratpac-setup

RUN chown -R ratuser:ratuser /ratpac-setup
USER ratuser
RUN ./setup.sh --only chroma -j$(nproc)
RUN ./setup.sh --only root -j$(nproc)
RUN ./setup.sh --only geant4 -j$(nproc)
RUN ./setup.sh --only cry
RUN ./setup.sh --only tensorflow
RUN ./setup.sh --only nlopt
RUN ./setup.sh --only hdf5 -j$(nproc)
ENV PATH=/ratpac-setup/local/bin:$PATH
RUN sed -i '1s/^/#!\/bin\/bash\n/' /ratpac-setup/env.sh
RUN printf '\nexec "$@"\n' >> /ratpac-setup/env.sh
RUN chmod +x env.sh

ENTRYPOINT ["/ratpac-setup/env.sh"]
CMD [ "/bin/bash" ]
