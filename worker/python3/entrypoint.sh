#!/bin/sh
if [ ${1} = "build" ]; then
    echo $2 > "/bin_cache/${3}"
elif [ ${1} = "run" ]; then
    python3 /bin_cache/${2}
fi
