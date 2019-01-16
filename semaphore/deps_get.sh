#!/bin/bash
# retry setup if it fails
n=0
until [ $n -ge 3 ]; do
    mix do deps.get, deps.compile && exit 0
    n=$[$n+1]
    sleep 3
done
exit 1
