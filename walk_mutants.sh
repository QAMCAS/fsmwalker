#!/usr/bin/env bash
for i in mutants/*
do
    mutant=${i%.dot}
    outfile=${mutant#mutants/}
    echo $outfile
    if [ -d outputs ]; then :; else mkdir outputs; fi
    ./fsmwalker.pl ${mutant}.dot 10 1000 13579 > outputs/${outfile}.txt
done
