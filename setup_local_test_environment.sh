#! /bin/sh

set -e

rm -rf pi-gen

git clone https://github.com/RPi-Distro/pi-gen
cd pi-gen
git switch arm64
cd ..

echo
echo "Copying setup for use"
echo

cp config ./pi-gen
cp -r stage* ./pi-gen

echo 'To build the image, run:'
echo
echo '  docker rm -v pigen_work ; ./pi-gen/build-docker.sh'
echo
