#!/usr/bin/env bash

# Since system dependencies, especially on clusters, are a pain
# Lets just pre-install everything (except GCC for now).

exec > >(tee -i install.log)
exec 2>&1

handle_error() {
    echo "*** An error occurred during the $1"
    echo "*** The error occurred on line $2 of setup.sh"
    exit 1
}

function install(){
    trap 'handle_error "setup" $LINENO' ERR
    ## Array of installables
    declare -a install_options=("cmake" "root" "geant4" "chroma" "cry" "tensorflow" "torch" "ratpac" "nlopt" "xerces" "hdf5")
    declare -A install_selection
    for element in "${install_options[@]}"
    do
        install_selection[$element]=true
    done
    # help message
    help "$@"

    ## run options
    enable_gpu=false
    enable_mac=false
    enable_arm64=false  # for arm64 architectures (e.g. mac with silicon chip)
    cleanup=true
    boolOnly=false
    prefix=$(pwd -P)/local
    # Versioning
    root_branch="v6-28-00-patches"
    root_branch_mac="v6-34-00-patches"
    geant_branch="v11.1.2"
    #geant_branch="v11.3.2"
    ratpac_repository="https://github.com/rat-pac/ratpac-two.git"

    for element in "$@"
    do
        if [ "$skipping" = true ]
        then
            # Check if element in install_options
            for option in "${install_options[@]}"
            do
                [[ "${option}" =~ ${element} ]] && install_selection[$element]=false
            done
        fi
        if [ "$element" == "--skip" ]
        then
            skipping=true;
        fi
    done
    
    for element in "$@"
    do
        if [ "$boolOnly" = true ]
        then
            for option in "${install_options[@]}"
            do
                [[  "${option}" =~ ${element} ]] && install_selection[$element]=true
            done
        fi
        if [ "$element" == "--only" ]
        then
            # Only will overwrite the skipping rules
            boolOnly=true
            # Set all to false
            for el in "${install_options[@]}"
            do
                install_selection[$el]=false
            done
        fi
        if [ "$element" == "--noclean" ]
        then
            cleanup=false
        fi
        if [ "$element" == "--gpu" ]
        then
            enable_gpu=true
        fi
        if [ "$element" == "--mac" ]
        then
            enable_mac=true
        fi
        if [ "$element" == "--arm64" ]
        then
            enable_arm64=true
        fi
    done
    procuse=$(getnproc "$@")
    # global options dictionary
    declare -A options=(["procuse"]=$procuse ["prefix"]=$prefix ["root_branch"]=$root_branch \
        ["geant_branch"]=$geant_branch ["enable_gpu"]=$enable_gpu ["enable_mac"]=$enable_mac \
        ["ratpac_repository"]=$ratpac_repository ["cleanup"]=$cleanup ["enable_arm64"]=$enable_arm64 \
        ["root_branch_mac"]=$root_branch_mac)

    # check dependencies unless skipped
    if ! skip_check "$@"
    then
        if ! check_deps
        then
            printf "\033[31mPlease install system dependencies as indicated above.\033[0m\n"
            printf "\033[31mYou can skip these checks by passing the --skip-checks flag.\033[0m\n"
            exit 1
        fi
    fi

    # End testing
    # Check requirements; Git && GCC
    if ! [ -x "$(command -v gcc)" ]; then
        echo "gcc not installed"
        exit 1
    fi
    if ! [ -x "$(command -v git)" ]; then
        echo "git not installed"
        exit 1
    fi
    CC=$(command -v gcc)
    export CC
    CXX=$(command -v g++)
    export CXX

    outfile="${prefix}/../env.sh"
    mkdir -p "${prefix}"/bin
    export PATH=$prefix/bin:$PATH
    export LD_LIBRARY_PATH=$prefix/lib:$LD_LIBRARY_PATH
    export DYLD_LIBRARY_PATH=$prefix/lib:$DYLD_LIBRARY_PATH
    printf 'export PATH=%s/bin:$PATH\n' "$prefix" > $outfile
    printf 'export LD_LIBRARY_PATH=%s/lib:$LD_LIBRARY_PATH\n' "$prefix" >> $outfile
    printf 'export DYLD_LIBRARY_PATH=%s/lib:$DYLD_LIBRARY_PATH\n' "$prefix" >> $outfile
    printf 'export CC=%s\n' "$CC" >> $outfile
    printf 'export CXX=%s\n' "$CXX" >> $outfile

    if [ "${install_selection[cmake]}" = true ]
    then
        install_cmake
    fi

    if [ "${install_selection[xerces]}" = true ]
    then
        install_xerces
    fi

    if [ "${install_selection[root]}" = true ]
    then
        install_root
    fi

    if [ "${install_selection[geant4]}" = true ]
    then
        install_geant4
    fi

    if [ "${install_selection[cry]}" = true ]
    then
        install_cry
    fi

    if [ "${install_selection[tensorflow]}" = true ]
    then
        if [ "${options[enable_arm64]}" = true ]
        then
            echo "Tensorflow C does not support arm64. Skipping..."
            echo "WARNING: Tensorflow will not be included in the installation"
        else
            install_tensorflow
        fi
    fi

    if [ "${install_selection[torch]}" = true ]
    then
        install_torch
    fi

    if [ "${install_selection[nlopt]}" = true ]
    then
        install_nlopt
    fi

    if [ "${install_selection[chroma]}" = true ]
    then
        install_chroma
    fi

    if [ "${install_selection[ratpac]}" = true ]
    then
        install_ratpac
    fi
    if test -f "$prefix"/lib/libCRY.so
    then
        printf 'export CRYLIB=%s/lib\n' "$prefix" >> $outfile
        printf 'export CRYINCLUDE=%s/include/cry\n' "$prefix" >> $outfile
        printf 'export CRYDATA=%s/data/cry\n' "$prefix" >> $outfile
    fi
    printf 'pushd %s/bin 2>&1 >/dev/null\nsource thisroot.sh\nsource geant4.sh\npopd 2>&1 >/dev/null\n' "$prefix" >> $outfile
    printf 'if [ -f "%s/../ratpac/ratpac.sh" ]; then\nsource %s/../ratpac/ratpac.sh\nfi\n' "$prefix" "$prefix" >> $outfile
    printf 'if [ -f "%s/../pyrat/bin/activate" ]; then\nsource %s/../pyrat/bin/activate\nfi\n' "$prefix" "$prefix" >> $outfile
    echo "Done"

    if [ "${install_selection[hdf5]}" = true ]
    then
      install_hdf5
    fi
}

function help()
{
    declare -A help_options=(["only"]="Only install the following packages" \
        ["skip"]="Skip the following packages" \
        ["gpu"]="Enable GPU support for tensorflow" \
        ["mac"]="Enable Mac support" \
        ["arm64"]="Enable arm64 architecure support" \
        ["noclean"]="Do not clean up after install")
    for element in "$@"
    do
        if [[ $element =~ "-h" ]];
        then
            printf "\nAvailable Packages\n"
            # Print out the install options as comma separated list
            printf "%s, " "${install_options[@]}"
            printf "\n\nOptions\n"
            for key in "${!help_options[@]}"
            do
                printf "%-20s%-20s\n" "--$key" "${help_options[$key]}"
            done
            exit 0
        fi
    done
}

function getnproc()
{
    local nproc=1
    for element in "$@"
    do
        if [[ $element =~ "-j" ]];
        then
            nproc=${element/-j/}
        fi
    done
    echo "$nproc"
}

function command_exists()
{
    if (command -v "$1" > /dev/null )
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
    for c in "${cmds[@]}"
    do
        if command_exists "$c"
        then
            printf "%-30s%-20s\n" "$c" "Installed"
        else
            printf "%-30s%-20s\n" "$c" "NOT AVAILABLE"
            bool=false
        fi
    done
    # Check libraries with ldd if not using macOS
    libraries=(libX11 libXpm libXft libffi libXext libQt libOpenGL)
    if [ "${options[enable_mac]}" = true ]
    then
        echo "MacOS install. Required libaries will not be checked."
        echo "Please ensure " "${libraries[@]}" "are installed on your system."
    else
        echo "Checking for libraries ..."
        for lb in "${libraries[@]}"
        do
            if check_lib "$lb"
            then
                printf "%-30s%-20s\n" "$lb" "Installed"
            else
                printf "%-30s%-20s\n" "$lb" "NOT AVAILABLE"
                bool=false
            fi
        done
        echo "Dependencies look to be in check"
    fi

    $bool
}

function check_lib()
{
    if (ldconfig -p | grep -q "$1")
    then
        true
    else
        false
    fi
}

function skip_check()
{
    bool=false
    for elem in "$@"
    do
        if [[ $elem = "--skip-checks" ]];
        then
            printf "Skipping dependency checker\n"
            bool=true
        fi
    done
    $bool
}

## Installation commands
function install_cmake()
{
    trap 'handle_error "cmake install" $LINENO' ERR
    echo "Installing cmake..."
    git clone https://github.com/Kitware/CMake.git --single-branch --branch v3.22.0 cmake_src
    mkdir -p cmake_build
    cd cmake_build || exit 1
    ../cmake_src/bootstrap --prefix=../local --parallel="${options[procuse]}"
    echo make -j"${options[procuse]}"
    make -j"${options[procuse]}"
    make install
    cd ../
    # Check if cmake was successful, if so clean-up, otherwise exit
    if test -f "${options[prefix]}"/bin/cmake
    then
        printf "CMake install successful\n"
    else
        printf "CMake install failed ... check logs\n"
        exit 1
    fi
    if [ "${options[cleanup]}" = true ]
    then
        rm -rf cmake_src cmake_build
    fi
    
}

function install_xerces()
{
    trap 'handle_error "xerces install" $LINENO' ERR
    echo "Installing xerces..."
    wget https://archive.apache.org/dist/xerces/c/3/sources/xerces-c-3.2.5.tar.gz
    tar xzf xerces-c-3.2.5.tar.gz
    cd xerces-c-3.2.5 || exit 1
    mkdir -p build
    cd build || exit 1
    #cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="${options[prefix]}" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release  -DICU_ROOT="${options[prefix]}" .. \
    cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="${options[prefix]}" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -Dtranscoder=iconv .. \
        && make -j"${options[procuse]}" \
        && make install
    cd ../..
    # Check if build was successful, if so clean-up, otherwise exit
    if test -d "${options[prefix]}"/include/xercesc
    then
        printf "Xerces install successful\n"
    else
        printf "Xerces install failed ... check logs\n"
        exit 1
    fi
    if [ "${options[cleanup]}" = true ]
    then
        rm -rf xerces-c-3.2.5.tar.gz xerces-c-3.2.5
    fi
}

function install_root()
{
    trap 'handle_error "root install" $LINENO' ERR
    echo "Installing ROOT..."
    if ${options[enable_mac]}
    then    
        git clone https://github.com/root-project/root.git --depth 1 --single-branch --branch "${options[root_branch_mac]}" root_src
    else
        git clone https://github.com/root-project/root.git --depth 1 --single-branch --branch "${options[root_branch]}" root_src
    fi
    mkdir -p root_build
    cd root_build || exit 1
    GLEW=""
    MINUIT="ON"
    if ${options[enable_mac]}
    then    
        GLEW="-D builtin_glew=ON"
        MINUIT="OFF"
    fi
    cmake -DCMAKE_INSTALL_PREFIX="${options[prefix]}" -D xrootd=OFF -D roofit=OFF -D minuit2="${MINUIT}" -D CMAKE_CXX_STANDARD=17 "${GLEW}"\
            ../root_src \
        && make -j"${options[procuse]}" \
        && make install
    cd ../
    # Check if root was successful, if so clean-up, otherwise exit
    if test -f "${options[prefix]}"/bin/root
    then
        printf "Root install successful\n"
    else
        printf "Root install failed ... check logs\n"
        exit 1
    fi
    if [ "${options[cleanup]}" = true ]
    then
        rm -rf root_src root_build
    fi
}

function install_geant4()
{
    trap 'handle_error "geant4 install" $LINENO' ERR
    echo "Installing Geant4..."
    git clone https://github.com/geant4/geant4.git --depth 1 --single-branch --branch "${options[geant_branch]}" geant_src
    mkdir -p geant_build
    cd geant_build || exit 1
    LIBSUFFIX="so"
    if [ "${options[enable_mac]}" = true ]
    then
        LIBSUFFIX="dylib"
    fi
    cmake -DCMAKE_INSTALL_PREFIX="${options[prefix]}" -DCMAKE_INSTALL_LIBDIR=lib \
        ../geant_src -DGEANT4_BUILD_EXPAT=OFF \
        -DGEANT4_BUILD_MULTITHREADED=OFF -DGEANT4_USE_QT=ON -DGEANT4_INSTALL_DATA=ON \
        -DGEANT4_BUILD_TLS_MODEL=global-dynamic \
        -DGEANT4_INSTALL_DATA_TIMEOUT=15000 -DGEANT4_USE_GDML=ON \
        -DXercesC_INCLUDE_DIR="${options[prefix]}"/include -DXercesC_LIBRARY_RELEASE="${options[prefix]}"/lib/libxerces-c."${LIBSUFFIX}" 
    make -j"${options[procuse]}" \
        && make install
    cd ../
    # Check if g4 was successful, if so clean-up, otherwise exit
    if test -f "${options[prefix]}"/bin/geant4-config
    then
        printf "G4 install successful\n"
    else
        printf "G4 install failed ... check logs\n"
        exit 1
    fi
    if [ "${options[cleanup]}" = true ]
    then
        rm -rf geant_src geant_build
    fi
}

function install_cry()
{
    trap 'handle_error "CRY install" $LINENO' ERR
    echo "Installing CRY..."
    # Install CRY for cosmogenics
    curl https://nuclear.llnl.gov/simulation/cry_v1.7.tar.gz --output cry.tar.gz
    tar xzvf cry.tar.gz
    cd cry_v1.7 || exit 1
    # Lets hack things up a bit to get a shared library
    # macs have a different format for sed
    if [ "${options[enable_mac]}" = true ]
    then
        sed -i '' 's/\r$//' src/Makefile
        sed -i '' '25i\
	$(CXX) -shared $(OBJ) -o ../lib/libCRY.so' src/Makefile
        sed -i '' 's/\-Wall/\-Wall \-fPIC/g' src/Makefile
    else
        sed -i 's/\r$//' src/Makefile
        sed -i '25 i \\t$(CXX) -shared $(OBJ) -o ../lib/libCRY.so' src/Makefile
        sed -i 's/\-Wall/\-Wall \-fPIC/g' src/Makefile
    fi
    LD_LIBRARY_PATH="${options[prefix]}"/../cry_v1.7/lib:"$LD_LIBRARY_PATH"
    make -j1 # Race condition using multiple threads
    mkdir -p "${options[prefix]}"/data/cry
    mv data/* "${options[prefix]}"/data/cry
    # "Make install"
    mv lib/libCRY.so "${options[prefix]}"/lib
    mkdir -p "${options[prefix]}"/include/cry
    cp src/*.h "${options[prefix]}"/include/cry
    cd ../
    if test -f "${options[prefix]}"/lib/libCRY.so
    then
        printf "CRY install successful\n"
    else
        printf "CRY install failed ... check logs\n"
        exit 1
    fi
    if [ "${options[cleanup]}" = true ]
    then
        rm -r cry_v1.7 cry.tar.gz
    fi
}

function install_tensorflow()
{
    trap 'handle_error "tensorflow install" $LINENO' ERR
    echo "Installing Tensorflow..."
    # Tensorflow: https://www.tensorflow.org/install/lang_c
    # CPU only or GPU support, listen for the --gpu command? Also if macos?
    # Updated 2021-08-10
    linuxGPU="https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-gpu-linux-x86_64-2.14.0.tar.gz"
    linuxCPU="https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-cpu-linux-x86_64-2.14.0.tar.gz"
    macCPU="https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-cpu-darwin-x86_64-2.14.0.tar.gz"

    tfurl=$linuxCPU #Default
    if [ "${options[enable_gpu]}" = true ]
    then
        tfurl=$linuxGPU
    fi
    if [ "${options[enable_mac]}" = true ]
    then
        tfurl=$macCPU
    fi
    curl $tfurl --output tensorflow.tar.gz
    tar -C "${options[prefix]}" -xzf tensorflow.tar.gz

    git clone https://github.com/serizba/cppflow.git
    cp -r cppflow/include/cppflow "${options[prefix]}"/include
    if test -d "${options[prefix]}"/include/tensorflow && test -d "${options[prefix]}"/include/cppflow
    then
        printf "Tensorflow install successful\n"
    else
        printf "Tensorflow install failed ... check logs\n"
        exit 1
    fi
    if [ "${options[cleanup]}" = true ]
    then
        rm -rf tensorflow.tar.gz cppflow
    fi
}

function install_torch()
{
    trap 'handle_error "torch install" $LINENO' ERR
    echo "Installing torch..."
    # PyTorch library found at pytorch.org/get-started/locally
    # Use the GUI there to reveal the specific links
    # Updated 2021-08-10
    linuxCPU="https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-2.0.1%2Bcpu.zip"
    linuxGPU="https://download.pytorch.org/libtorch/cu118/libtorch-cxx11-abi-shared-with-deps-2.0.1%2Bcu118.zip"
    macCPU="https://download.pytorch.org/libtorch/cpu/libtorch-macos-2.0.1.zip"

    tfurl=$linuxCPU #Default
    if [ "${options[enable_gpu]}" = true ]
    then
        tfurl=$linuxGPU
    fi
    if [ "${options[enable_mac]}" = true ]
    then
        tfurl=$macCPU
    fi

    curl $tfurl --output torch.zip
    unzip torch.zip -d torch
    cp -r torch/libtorch/* "${options[prefix]}"
    if test -d "${options[prefix]}"/include/torch
    then
        printf "Torch install successful\n"
    else
        printf "Torch install failed ... check logs\n"
        exit 1
    fi
    if [ "${options[cleanup]}" = true ]
    then
        rm -rf torch.zip torch
    fi
}

function install_ratpac()
{
    # FIXME: need a solution to remove requirement to edit ratpac files with sed for mac installs 
    trap 'handle_error "ratpac install" $LINENO' ERR
    echo "Installing ratpac..."
    # Install rat-pac
    source "${options[prefix]}"/bin/thisroot.sh
    source "${options[prefix]}"/bin/geant4.sh
    if [[ -f "${options[prefix]}"/lib/libCRY.so ]];
    then
        export CRYLIB="${options[prefix]}"/lib
        export CRYINCLUDE="${options[prefix]}"/include/cry
        export CRYDATA="${options[prefix]}"/data/cry
    fi
    rm -rf ratpac
    git clone "${options[ratpac_repository]}" ratpac
    cd ratpac || exit 1
    if [ "${options[enable_arm64]}" = true ]
    then
        sed -i '' 's/x86_64/arm64/g' CMakeLists.txt
    fi
    if [ "${options[enable_mac]}" = true ]
    then
        sed -i '' 's/.*Wno-terminate.*//g' CMakeLists.txt
        sed -i '' 's/\.so/.dylib/g' config/RatpacConfig.cmake.in
        sed -i '' "36 i\\
set(CMAKE_LIBRARY_PATH \${CMAKE_LIBRARY_PATH} ${options[prefix]}/lib)\\
include_directories(${options[prefix]}/include)" CMakeLists.txt
        sed -i '' '11 i\
#include <RAT/Processor.hh>' src/core/include/RAT/ProcAllocator.hh
    fi
    # avoid using default Makefile as it lacks portability for different OSs
    # make -j"${options[procuse]}" && source ./ratpac.sh
    mkdir -p build
    cd build || exit 1
    LIBSUFFIX="so"
    if [ "${options[enable_mac]}" = true ]
    then
        LIBSUFFIX="dylib"
    fi
    cmake -DXercesC_INCLUDE_DIR="${options[prefix]}"/include -DXercesC_LIBRARY_RELEASE="${options[prefix]}"/lib/libxerces-c."${LIBSUFFIX}" -DCMAKE_INSTALL_PREFIX=../install ..
    make && make install && cd .. && source ./ratpac.sh
    # Check if ratpac was successful, otherwise exit
    if test -f install/bin/rat
    then
        printf "Ratpac install successful\n"
    else
        printf "Ratpac install failed ... check logs\n"
        exit 1
    fi
    cd ..
}

function install_chroma()
{
    trap 'handle_error "chroma install" $LINENO' ERR
    echo "Installing chroma..."
    # Geant-4 pybind, special chroma branch
    #virtualenv pyrat
    #source pyrat/bin/activate
    #git clone --recursive https://github.com/MorganAskins/geant4_pybind --single-branch --branch chroma
    ##git clone --recursive https://github.com/HaarigerHarald/geant4_pybind
    #pip install ./geant4_pybind
    #rm -rf geant4_pybind
    ##pushd geant4_pybind/pybind11
    ##cmake -DCMAKE_INSTALL_PREFIX=${options[prefix]} . -Bbuild
    ##cmake --build build --target install
    ##pip install .
    ##popd

    ## For now, just install zeromq
    git clone --depth 1 -b v4.3.5 https://github.com/zeromq/libzmq.git libzmq_src
    mkdir -p libzmq_build
    pushd libzmq_build || exit 1
    cmake -DCMAKE_INSTALL_PREFIX="${options[prefix]}" -DCMAKE_INSTALL_LIBDIR=lib ../libzmq_src
    make -j"${options[procuse]}" install
    popd || exit 1

    if test -f "${options[prefix]}"/lib/libzmq.a
    then
        printf "Chroma install successful\n"
    else
        printf "Chroma install failed ... check logs\n"
        exit 1
    fi
    if [ "${options[cleanup]}" = true ]
    then
        rm -rf libzmq_src libzmq_build
    fi

}

function install_hdf5()
{
    git clone --depth=1 -b hdf5_1.14.4.3 https://github.com/HDFGroup/hdf5.git hdf5_src
    pushd hdf5_src
    ./configure  --prefix=${options[prefix]} --enable-cxx=yes
    make -j${options[procuse]} install
    popd
    rm -rf hdf5_src
    
    # Now install HighFive
    git clone --depth 1 -b v2.9.0 https://github.com/BlueBrain/HighFive.git HighFive-src
    cmake -DHIGHFIVE_EXAMPLES=Off \
      -DHIGHFIVE_USE_BOOST=Off \
      -DHIGHFIVE_UNIT_TESTS=Off \
      -DCMAKE_INSTALL_PREFIX=${options[prefix]} \
      -B HighFive-src/build \
      HighFive-src

    cmake --build HighFive-src/build
    cmake --install HighFive-src/build
    rm -rf HighFive-src
}

function install_nlopt()
{
    trap 'handle_error "nlopt install" $LINENO' ERR
    echo "Installing nlopt..."
    git clone https://github.com/stevengj/nlopt.git
    pushd nlopt || exit 1
    cmake -DCMAKE_INSTALL_PREFIX="${options[prefix]}" -DCMAKE_INSTALL_LIBDIR=lib . -Bbuild
    cmake --build build --target install
    popd || exit 1
    if test -f "${options[prefix]}"/include/nlopt.h
    then
        printf "Nlopt install successful\n"
    else
        printf "Nlopt install failed ... check logs\n"
        exit 1
    fi
    if [ "${options[cleanup]}" = true ]
    then
        rm -rf nlopt
    fi
}


## Main function
install "$@"
