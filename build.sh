#/bin/bash

script=`readlink -f "$0"`
cwd=`dirname "${script}"`
cd "${cwd}"
docker build -t sam80180/systemd-dind:ubuntu18.04 .
