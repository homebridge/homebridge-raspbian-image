#! /bin/sh

echo
echo "Cloning recent pi-gen for local testing of build process"
echo

rm -rf pi-gen Dockerfile build.sh export-noobs stage1 stage5 depends imagetool.sh stage2 docker-compose.yml scripts stage3 build-docker.sh export-image stage0 stage4
git clone https://github.com/RPi-Distro/pi-gen

for i in Dockerfile build.sh export-noobs stage1 stage5 depends imagetool.sh stage2 docker-compose.yml scripts stage3 build-docker.sh export-image stage0 stage4
do 
  echo "Moving "$i
  mv pi-gen/$i .
done