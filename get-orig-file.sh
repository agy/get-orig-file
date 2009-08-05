#!/bin/bash

set -e
set -u

FILE=${1:-""}

case $( uname -m ) in
    i686|i386)
        arch="i386"
        ;;
    x86_64)
        arch="amd64"
        ;;
    *)
        # There are more but I don't care.
        exit 1
        ;;
esac

if [ -e ${FILE} ]; then
    FILE=$( readlink -f ${FILE} )
    if [ ! -f ${FILE} ]; then
        echo "Not a file: ${FILE}" >&2
        exit 1
    fi
    echo "Finding package for ${FILE}"
    dpkg -S ${FILE} | \
        awk -F: '{ print $1 }' | \
        COLUMNS=200 xargs dpkg -l | \
        awk ' $1 ~ /^ii/ { print $2 " " $3 }' | \
        while read pkg ver; do 
            echo "Downloading package: ${pkg}"
            t=$( mktemp -d /tmp/XXXXXXX ) && \
            mkdir -p ${t}/partial && \
            apt-get -qq -o Dir::Cache::archives=${t} -o Debug::NoLocking=true -dy --reinstall install ${pkg}=${ver} && \
            if [ -f /var/cache/apt/archives/${pkg}_${ver}_${arch}.deb ]; then
                pkg="/var/cache/apt/archives/${pkg}_${ver}_${arch}.deb"
            elif [ -f /var/cache/apt/archives/${pkg}_${ver}_all.deb ]; then
                pkg="/var/cache/apt/archives/${pkg}_${ver}_all.deb"
            else
                echo "Cannot find downloaded package" >&2
                exit 1
            fi && \
            echo "Extracting package." && \
            dpkg -x ${pkg} ${t} && \
            echo "File is here: ${t}/${FILE}"
        done || \
        echo "Cannot find package for file: ${FILE}" >&2 && \
        exit 1
else
    echo "Cannot find file.  Check your path and try again." >&2
    exit 1
fi
