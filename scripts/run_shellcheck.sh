#!/bin/bash

if [ -z "$1" ]; then
    exec shellcheck *ipv6
fi

exec shellcheck "${@}"
