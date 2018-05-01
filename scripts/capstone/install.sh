#!/bin/bash -e
PROJECT_DIR=$(realpath $(dirname $BASH_SOURCE)/../../)
. $PROJECT_DIR/scripts/common.sh

echo "CAPSTONE_HOME:" $CAPSTONE_HOME

pushd $TOOLCHAINS_HOME > /dev/null
wget https://github.com/aquynh/capstone/archive/3.0.5-rc2.zip
unzip 3.0.5-rc2.zip
rm -f 3.0.5-rc2.zip
popd

pushd $CAPSTONE_HOME > /dev/null

./make.sh
sudo ./make.sh install
cd bindings/python
sudo ./setup.py install
popd>/dev/null

CAP_VER=`python2 -c "import capstone;print(capstone.__version__)"`
echo "[*] Installed capstone: $CAP_VER"
