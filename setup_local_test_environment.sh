#! /bin/sh

echo
echo "Cloning recent pi-gen for local testing of build process"
echo

rm -rf pi-gen Dockerfile build.sh build-docker.sh docker-compose.yml export-image export-noobs imagetool.sh make_rpi-imager-snipplet.py scripts stage0 stage1 stage2 stage3 stage4 stage5
git clone https://github.com/RPi-Distro/pi-gen

for i in Dockerfile build.sh build-docker.sh docker-compose.yml export-image export-noobs imagetool.sh make_rpi-imager-snipplet.py scripts stage0 stage1 stage2 stage3 stage4 stage5
do 
  echo "Moving "$i
  mv pi-gen/$i .
done