#!/bin/bash

# Since system dependencies, especially on clusters, are a pain
# Lets just pre-install everything (except GCC for now).

# Todo:
# --help, -h

exec > >(tee -i install.log)
exec 2>&1

function install(){
  gitdir="git@github.com:eosdemonstrator/ratpac-two.git"
  help $@
  procuse=$(getnproc $@)
  # End testing
  export CC=$(command -v gcc)
  export CXX=$(command -v g++)

  # Versioning
  root_branch="v6-28-00-patches"
  root_branch="latest-stable"
  root_branch="v6-28-04"
  
  # Check requirements; Git && GCC
  if ! [ -x "$(command -v gcc)" ]; then
    echo "gcc not installed"
    exit 1
  fi
  if ! [ -x "$(command -v git)" ]; then
    echo "git not installed"
    exit 1
  fi

  outfile="env.sh"
  prefix=$(pwd -P)/local
  mkdir -p $prefix/bin
  export PATH=$prefix/bin:$PATH
  export LD_LIBRARY_PATH=$prefix/lib:$LD_LIBRARY_PATH
  printf "export PATH=$prefix/bin:\$PATH\n" > $outfile
  printf "export LD_LIBRARY_PATH=$prefix/lib:\$LD_LIBRARY_PATH\n" >> $outfile
  printf "export CC=$CC\n" >> $outfile
  printf "export CXX=$CXX\n" >> $outfile

  ## Tensorflow options
  enable_gpu=false
  enable_mac=false
  
  skipping=false
  skip_cmake=false
  skip_root=false
  skip_geant=false
  skip_ratpac=false
  skip_cry=false
  skip_tflow=false
  skip_chroma=false
  for element in $@;
  do
    if [ "$skipping" = true ]
    then
      if [ $element == "cmake" ]
      then
        skip_cmake=true
      fi
      if [ $element == "root" ]
      then
        skip_root=true
      fi
      if [ $element == "geant4" ]
      then
        skip_geant=true
      fi
      if [ $element == "ratpac" ]
      then
        skip_ratpac=true
      fi
      if [ $element == "cry" ]
      then
        skip_cry=true
      fi
      if [ $element == "tensorflow" ]
      then
        skip_tflow=true
      fi
      if [ $element == "chroma" ]
      then
        skip_chroma=true
      fi
    fi
    if [ $element == "--skip" ]
    then
      skipping=true;
    fi
  done
  
  cleanup=true
  boolOnly=false
  for element in $@;
  do
    if [ "$boolOnly" = true ]
    then
      if [ $element == "cmake" ]
      then
        skip_cmake=false
      fi
      if [ $element == "root" ]
      then
        skip_root=false
      fi
      if [ $element == "geant4" ]
      then
        skip_geant=false
      fi
      if [ $element == "ratpac" ]
      then
        skip_ratpac=false
      fi
      if [ $element == "cry" ]
      then
        skip_cry=false
      fi
      if [ $element == "tensorflow" ]
      then
        skip_tflow=false
      fi
      if [ $element == "chroma" ]
      then
        skip_chroma=false
      fi
    fi
    if [ $element == "--only" ]
    then
      # Only will overwrite the skipping rules
      boolOnly=true
      skip_cmake=true
      skip_root=true
      skip_geant=true
      skip_ratpac=true
      skip_cry=true
      skip_tflow=true
      skip_chroma=true
    fi
    if [ $element == "--noclean" ]
    then
      cleanup=false
    fi
    if [ $element == "--gpu" ]
    then
      enable_gpu=true
    fi
    if [ $element == "--mac" ]
    then
      enable_mac=true
    fi
  done
  
  
  # Install cmake
  if ! [ "$skip_cmake" = true ]
  then
    git clone https://github.com/Kitware/CMake.git --single-branch --branch v3.22.0 cmake_src
    mkdir -p cmake_build
    cd cmake_build
    ../cmake_src/bootstrap --prefix=../local \
      && make -j$procuse \
      && make install
    cd ../
    # Check if cmake was successful, if so clean-up, otherwise exit
    if test -f $prefix/bin/cmake
    then
      printf "Cmake install successful\n"
    else
      printf "Cmake install failed ... check logs\n"
      exit 1
    fi
    if [ "$cleanup" = true ]
    then
      rm -rf cmake_src cmake_build
    fi
  fi
  
  # Install root
  if ! [ "$skip_root" = true ]
  then
    git clone https://github.com/root-project/root.git --single-branch --branch $root_branch root_src
    mkdir -p root_build
    cd root_build
    cmake -DCMAKE_INSTALL_PREFIX=$prefix -DCMAKE_CXX_STANDARD=20 -D xrootd=OFF -D roofit=OFF -D minuit2=ON\
        ../root_src \
      && make -j$procuse \
      && make install
    cd ../
    # Check if root was successful, if so clean-up, otherwise exit
    if test -f $prefix/bin/root
    then
      printf "Root install successful\n"
    else
      printf "Root install failed ... check logs\n"
      exit 1
    fi
    if [ "$cleanup" = true ]
    then
      rm -rf root_src root_build
    fi
  fi
  
  # Install Geant4
  if ! [ "$skip_geant" = true ]
  then
    git clone https://github.com/geant4/geant4.git --single-branch --branch geant4-11.0-release geant_src
    mkdir -p geant_build
    cd geant_build
    cmake -DCMAKE_INSTALL_PREFIX=$prefix ../geant_src -DGEANT4_BUILD_EXPAT=OFF \
      -DGEANT4_BUILD_MULTITHREADED=OFF -DGEANT4_USE_QT=ON -DGEANT4_INSTALL_DATA=ON \
      -DGEANT4_INSTALL_DATA_TIMEOUT=15000 -DGEANT4_USE_GDML=ON \
      && make -j$procuse \
      && make install
    cd ../
    # Check if g4 was successful, if so clean-up, otherwise exit
    if test -f $prefix/bin/geant4-config
    then
      printf "G4 install successful\n"
    else
      printf "G4 install failed ... check logs\n"
      exit 1
    fi
    if [ "$cleanup" = true ]
    then
      rm -rf geant_src geant_build
    fi
  fi

  # Install CRY for cosmogenics
  if ! [ "$skip_cry" = true ]
  then
    curl https://nuclear.llnl.gov/simulation/cry_v1.7.tar.gz --output cry.tar.gz
    tar xzvf cry.tar.gz
    cd cry_v1.7
    # Lets hack things up a bit to get a shared library
    sed -i 's/$//' src/Makefile
    sed -i '25 i \\t$(CXX) -shared $(OBJ) -o ../lib/libCRY.so' src/Makefile
    sed -i 's/\-Wall/\-Wall \-fPIC/g' src/Makefile
    make -j1 # Race condition using multiple threads
    mkdir -p $prefix/data/cry
    mv data/* $prefix/data/cry
    # "Make install"
    mv lib/libCRY.so $prefix/lib
    mkdir -p $prefix/include/cry
    cp src/*.h $prefix/include/cry
    cd ../
    if [ "$cleanup" = true ]
    then
      rm -r cry_v1.7 cry.tar.gz
    fi
  fi

  # Tensorflow
  if ! [ "$skip_tflow" = true ]
  then
    # CPU only or GPU support, listen for the --gpu command? Also if macos?
    linuxGPU="https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-gpu-linux-x86_64-2.9.1.tar.gz"
    linuxCPU="https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-cpu-linux-x86_64-2.9.1.tar.gz"
    macCPU="https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-cpu-darwin-x86_64-2.9.1.tar.gz"

    tfurl=$linuxCPU #Default
    if [ "$enable_gpu" = true ]
    then
      tfurl=$linuxGPU
    fi
    if [ "$enable_mac" = true ]
    then
      tfurl=$macCPU
    fi
    curl $tfurl --output tensorflow.tar.gz
    tar -C $prefix -xzf tensorflow.tar.gz

    git clone git@github.com:serizba/cppflow.git
    cp -r cppflow/include/cppflow $prefix/include
    rm -rf tensorflow.tar.gz cppflow
  fi

  if ! [ "$skip_chroma" = true ]
  then
    # Geant4-Pybind and such: need to wrap with chroma install
    virtualenv pyrat
    source pyrat/bin/activate
    git clone --recursive https://github.com/HaarigerHarald/geant4_pybind
    pip install ./geant4_pybind
    pushd geant4_pybind/pybind11
    cmake -DCMAKE_INSTALL_PREFIX=$prefix . -Bbuild
    cmake --build build --target install
    pip install .
    popd
  fi

  # Install rat-pac
  if ! [ "$skip_ratpac" = true ]
  then
    source $prefix/bin/thisroot.sh
    source $prefix/bin/geant4.sh
    rm -rf ratpac
    git clone $gitdir ratpac
    cd ratpac
    make -j$procuse && source ./ratpac.sh
    # Check if ratpac was successful, if so clean-up, otherwise exit
    if test -f build/bin/rat
    then
      printf "Ratpac install successful\n"
    else
      printf "Ratpac install failed ... check logs\n"
      exit 1
    fi
    cd ../
  fi

  if [[ -f "$prefix/lib/libCRY.so" ]];
  then
    printf "export CRYLIB=$prefix/lib\n" >> $outfile
    printf "export CRYINCLUDE=$prefix/include/cry\n" >> $outfile
    printf "export CRYDATA=$prefix/data/cry\n" >> $outfile
  fi
  printf "pushd $prefix/bin 2>&1 >/dev/null\nsource thisroot.sh\nsource geant4.sh\npopd 2>&1 >/dev/null\n" >> $outfile
  printf "if [ -f \"$prefix/../ratpac/ratpac.sh\" ]; then\nsource $prefix/../ratpac/ratpac.sh\nfi\n" >> $outfile
  printf "if [ -f \"$prefix/../pyrat/bin/activate\" ]; then\nsource $prefix/../pyrat/bin/activate\nfi\n" >> $outfile
}

function help()
{
  for element in $@
  do
    if [[ $element =~ "-h" ]];
    then
      printf "Ratpac Dependency Installer -- in progress\n"
      exit 0
    fi
  done
}

function getnproc()
{
  local nproc=1
  for element in $@
  do
    if [[ $element =~ "-j" ]];
    then
      nproc=$(echo $element | sed -e 's/-j//g')
    fi
  done
  echo $nproc
}

function command_exists()
{
  if (command -v $1 > /dev/null )
  then
    true
  else
    false
  fi
}

function check_deps()
{
  bool=true
  # Before trying to install anything, confirm a list of dependencies
  echo "Checking list of dependencies ..."
  cmds=(gcc openssl curl)
  for c in ${cmds[@]}
  do
    if command_exists $c
    then
      printf "%-30s%-20s\n" $c "Installed"
    else
      printf "%-30s%-20s\n" $c "NOT AVAILABLE"
      bool=false
    fi
  done
  # Check libraries with ldd
  echo "Checking for libraries ..."
  libraries=(libX11 libXpm libXft libffi libXext libQt libOpenGL)
  for lb in ${libraries[@]}
  do
    if check_lib $lb
    then
      printf "%-30s%-20s\n" $lb "Installed"
    else
      printf "%-30s%-20s\n" $lb "NOT AVAILABLE"
      bool=false
    fi
  done
  echo "Dependencies look to be in check"

  $bool
}

function check_lib()
{
  if (ldconfig -p | grep -q $1)
  then
    true
  else
    false
  fi
}

function skip_check()
{
  bool=false
  for elem in $@
  do
    if [[ $elem = "--skip-checks" ]];
    then
      printf "Skipping dependency checker\n"
      bool=true
    fi
  done
  $bool
}

if skip_check $@
then
  install $@
else
  if check_deps
  then
    install $@
  else
    printf "\033[31mPlease install system dependencies as indicated above.\033[0m\n"
    printf "\033[31mYou can skip these checks by passing the --skip-checks flag.\033[0m\n"
  fi
fi
