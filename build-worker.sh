#!/bin/sh

# python3
docker build -t akapenjudge/python3:compile worker/python3/compile/
docker build -t akapenjudge/python3:run worker/python3/run/
