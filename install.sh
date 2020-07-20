#!/bin/bash

cd /workspace/<user>/input

cat $1 | while read line;
do
	echo $line
	fastq-dump --split-files $line
done
