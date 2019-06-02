#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Enable overlayfs for dind if it can be tested to work.
function enable-overlay-storage() {
  local storage_dir=${1:-/var/lib/docker}

  local msg=""

  if grep -q overlay /proc/filesystems; then
    # Smoke test the overlay filesystem:

    # 1. create smoke dir in the storage dir being mounted
    local d="${storage_dir}/smoke"
    mkdir -p "${d}/upper" "${d}/lower" "${d}/work" "${d}/mount"

    # 2. try to mount an overlay fs on top of the smoke dir
    local overlay_works=1
    mount -t overlay overlay\
          -o"lowerdir=${d}/lower,upperdir=${d}/upper,workdir=${d}/work"\
          "${d}/mount" &&\
    # 3. try to write a file in the overlay mount
          echo foo > "${d}/mount/probe" || overlay_works=

    umount -f "${d}/mount" || true
    rm -rf "${d}" || true

    if [[ -n "${overlay_works}" ]]; then
      msg="Enabling overlay storage for docker-in-docker"
      python3 <(cat <<EOFEOF
import json;
strOutput = None;
daemonFile = '/etc/docker/daemon.json';
with open(daemonFile, 'r') as fptr:
    d = json.load(fptr);
    if 'storage-driver' in d:
        d['storage-driver'] = "overlay";
        strOutput = json.dumps(d, indent=4, sort_keys=True);
    # end if
# end with
if strOutput is not None:
    with open(daemonFile, 'w') as fptr:
        fptr.write(strOutput);
    # end with
# end if
EOFEOF
)
    fi
  fi

  if [[ -z "${msg}" ]]; then
    msg="WARNING: Unable to enable overlay storage for docker-in-docker"
  fi

  echo "${msg}"
}

# Ensure shared mount propagation to ensure volume mounting works for
# Kubernetes and OpenShift.
mount --make-shared /
enable-overlay-storage
