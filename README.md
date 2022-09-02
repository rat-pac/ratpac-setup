# Ratpac Installation Script
This script simplifies the install process for rat-pac by building the
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
./ratpacSetup.sh
```
Individually components can be selected, or excluded
```bash
# Include only specific programs
./ratpacSetup.sh --only cmake root geant4 sibyl cry tensorflow ratpac
# Install all but excluded programs, e.g:
./ratpacSetup.sh --skip cmake
```
Additional options are available, including passing make commands
```bash
# For linux, tensorflow can either use the cpu(default) or gpu
./ratpacSetup.sh --only tensorflow --gpu
# For mac, a separate tensorflow is available
./ratpacSetup.sh --only tensorflow --mac
# Pass number of processors to make, and even keep downloaded files for debugging
./ratpacSetup.sh -j8 --noclean
```

## Usage 
Once installation is complete there will be a new directory structure from where
`ratpacSetup.sh` is run with a complete `./local` directory that contains all
of the header files, libraries, and executables, and an environment variable to
source before running
```bash
# Before running rat or installing new versions.
source ratpacSetup/env.sh
```
