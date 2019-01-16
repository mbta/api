#!/bin/bash
set -e
if [ ! -f $VIRTUAL_ENV/bin/activate ]; then
    . aws/bin/activate
fi

./build.sh
eb deploy --staged $*
