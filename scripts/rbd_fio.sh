#!/bin/sh
set -e

IMG="rbd/rbd_fio_`hostname`.img"
IMG_SIZE=8 # GB
IMG_FEATURES=3 # layering|stripingv2
FIO_JOB="/tmp/rbd-$$.fio"
DURATION="${1:-60}" # 1 minute
IODEPTH="${2:-8}"

cleanup () {
	if rbd info "$IMG" >/dev/null 2>&1; then
		rbd rm "$IMG"
	fi
}

prepare () {
	sudo /bin/sh -c 'echo madvise > /sys/kernel/mm/transparent_hugepage/enabled'
	sudo /bin/sh -c 'echo 0 > /sys/kernel/mm/ksm/run'
	rbd create \
		--image-format 2 \
		--image-features $IMG_FEATURES \
		--size "$((IMG_SIZE*1024))" \
		"$IMG"


}

trap cleanup EXIT INT QUIT

cleanup
prepare

cat > "$FIO_JOB" <<-EOF
[global]
ioengine=rbd
rw=randwrite
bs=4k
clientname=admin
pool=${IMG%%/*}
invalidate=0
runtime=${DURATION}

[rbd0]
rbdname=${IMG##*/}
iodepth=$IODEPTH
EOF

exec \
	env \
		LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.1 \
			fio "$FIO_JOB"
