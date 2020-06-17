#!/bin/bash

files=$(find $1 -maxdepth 1 -mmin +$2 -type f -print -exec rm {} + | wc -l)
echo $files
