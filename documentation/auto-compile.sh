#!/bin/bash
while inotifywait -q -r --exclude '.*___$' -e close_write,moved_to,create `pwd` ; do make pdfs; done
