#!/bin/bash
R CMD Rserve --no-save --RS-conf Rserve.conf
ls -l $0
echo running  bash
touch /tmp/ttt
tail -f /tmp/ttt
