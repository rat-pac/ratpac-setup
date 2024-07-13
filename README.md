# Ratpac Installation Script
[![Build Docker Image](https://github.com/rat-pac/ratpac-setup/actions/workflows/build-docker-image.yml/badge.svg)](https://github.com/rat-pac/ratpac-setup/actions/workflows/build-docker-image.yml)

This script simplifies the install process for ratpac-two by building the
requirements locally and setting up the appropriate environment variables.

## Dependencies
- gcc/g++ 8.0+
- c++17
- openssl
- curl, git (used for fetching installation binaries)
- libX11, libXpm, libXft, libffi, libXext, libQt, libOpenGL

## Packages
Feel free to skip any of the packages already installed on the system that
you do not wish to reinstall, though do note you will have to properly link
them in that case (ROOT / Geant-4).

- CMake v3.22.0+
- ICU4C 74.2
- Xerces-C 3.2.5
- Python 3.x.x
- Root 6.25+
- Geant-4 11.0
- CRY 1.7
- Tensorflow 2.9.1
- Rat-pac

## Installation
The installation script can be used to install each component individually or
all at once. To install everything run:
```bash
./setup.sh
```
Individually components can be selected, or excluded
```bash
# Include only specific programs
./setup.sh --only cmake root geant4 sibyl cry tensorflow ratpac
# Install all but excluded programs, e.g:
./setup.sh --skip cmake
```
Additional options are available, including passing make commands
```bash
# For linux, tensorflow can either use the cpu(default) or gpu
./setup.sh --only tensorflow --gpu
# Pass number of processors to make, and even keep downloaded files for debugging
./setup.sh -j8 --noclean
# For complete information run
./setup.sh -h
```

### MacOS
Installation is possible on MacOS using the flag `--mac`. If using Apple 
Silicon (ARM64 architecture), one will also need the flag `--arm64`. The 
installation *assumes a zsh shell* for macs.

The MacOS installation is similar to the Linux installation, but uses dynamic
libraries rather than shared libraries. Some CMakeLists.txt files (including
ratpac's) are adjusted for the mac installation. Please be aware of this if 
developing code and committing changes to CMakeLists.txt. Ideally, we will 
remove these CMakeLists.txt edits in the future.

On Apple Silicon, the installation of ROOT can sometimes run into issues with the
error message `read jobs pipe: Resource temporarily unavailable.`. There doesn't
seem to be a consistent permanent solution to this, but if you run the 
`make && make install` command again within the `root_build` directory (maybe 
more than once), the build should finish. Then continue with the installation
with setup.sh and skipping cmake, icu, xerces and root.

Mac installation tested on Apple M1 Pro with Sonoma 14.5. 

## Usage 
Once installation is complete there will be a new directory structure from where
`setup.sh` is run with a complete `./local` directory that contains all
of the header files, libraries, and executables, and an environment variable to
source before running
```bash
# Before running rat or installing new versions.
source env.sh
```
