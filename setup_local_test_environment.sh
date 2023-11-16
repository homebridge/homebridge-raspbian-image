#! /bin/sh

echo
echo "Cleaning up previous pi-gen clone"
echo

rm -rf pi-gen Dockerfile build.sh build-docker.sh docker-compose.yml export-image export-noobs imagetool.sh scripts stage0 stage1 stage2 stage3 stage4 stage5
echo
echo "Cloning recent pi-gen arm64 branch for local testing of build process"
echo

git clone https://github.com/RPi-Distro/pi-gen
cd pi-gen
git switch arm64
cd ..

echo
echo "Moving clone for use"
echo

for i in Dockerfile build.sh build-docker.sh docker-compose.yml export-image export-noobs imagetool.sh scripts stage0 stage1 stage2 stage3 stage4 stage5
do 
  echo "Moving "$i
  mv pi-gen/$i .
done
