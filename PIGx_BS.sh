#!/bin/bash


# PIGx BSseq Pipeline.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# #===== DEFAULT PATHS ===== #
tablesheet="test_dataset/TableSheet_test.csv"
path2configfile="./config.json"
path2programsJSON="test_dataset/PROGS.json"

#=========== PARSE PARAMETERS ============#

usage="
PIGx BSseq Pipeline.

PIGx is a data processing pipeline for raw fastq read data of
bisulfite experiments.  It produces methylation and coverage
information and can be used to produce information on differential
methylation and segmentation.

It was first developed by the Akalin group at MDC in Berlin in 2017.

Usage: $(basename "$0") [OPTION]...

Options:

  -t, --tablesheet FILE     The tablesheet containing the basic configuration information
                             for running the BSseq_pipeline.

  -p, --programs FILE       A JSON file containing the absolute paths of the required tools.

  -c, --configfile FILE     The config file used for calling the underlying snakemake process.
                             By default the file '${path2configfile}' is dynamically created
                             from tablesheet and programs file.
                             
  -C, --create-config       Force the re-creation of the config file, even if it already exists                            

  -s, --snakeparams PARAMS  Additional parameters to be passed down to snakemake, e.g.
                               --dryrun    do not execute anything
                               --forceall  re-run the whole pipeline

"

createConfig=false

# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ $# -gt 0 ]]; do
    key="$1"
    shift

    case $key in
        -t|--tablesheet)
            tablesheet="$1"
            shift
            ;;
        -c|--configfile)
            path2configfile="$1"
            shift
            ;;
        -C|--create-config)
            createConfig=true
            shift
            ;;
        -p|--programs)
            path2programsJSON="$1"
            shift
            ;;
        -s|--snakeparams)
            snakeparams="$1"
            shift
            ;;
        -h|--help)
            echo "$usage"
            exit 1
            ;;
        *)
            # unknown option
            echo "$usage"
            echo "$(basename "$0"): Error: unkown argument provided"
            exit 1
            ;;
    esac
done

# echo "${tablesheet} ${path2configfile} ${path2programsJSON} ${snakeparams}" 

#========================================================================================
#----------  CREATE CONFIG FILE:  ----------------------------------------------
 
 
warning="$(basename "$0"): Warning:

The config file ${path2configfile} already exists and is not re-generated by default.
You can savely ignore this warning, unless changes were made to either: 
    tablesheet: ${tablesheet}  
    or 
    programs: ${path2programsJSON}
    
If that is the case, please remove ${path2configfile} or use the '-C/--create-config' option,
to force the recreation of the config file.
"
  
if [ ! -f $path2configfile ]
  then
    scripts/create_configfile.py $tablesheet $path2configfile $path2programsJSON
  elif $createConfig
    then
     scripts/create_configfile.py $tablesheet $path2configfile $path2programsJSON
  else    
    echo "${warning}"
fi
 

#======================================================================================
#----------  NOW CREATE SYMBOLIC LINKS TO THE INPUTS AND REFERENCE GENOME -------------

path_OUT=$( python -c "import sys, json; print(json.load(sys.stdin)['PATHOUT'])" < $path2configfile)
path_IN=$( python -c "import sys, json; print(json.load(sys.stdin)['PATHIN'])" < $path2configfile)
path_refG=$( python -c "import sys, json; print(json.load(sys.stdin)['GENOMEPATH'])" < $path2configfile)

mkdir -p ${path_OUT}
mkdir -p ${path_OUT}"path_links"
mkdir -p ${path_OUT}"path_links/input"

# create links within the output folder that point directly to the 
# reference genome, as well as to each sample input file  
# so that it's clear where the source data came from.
# N.B. Any previously existing links will be kept in place, and no warning will be issued if this is the case. 

# link to reference genome:
ln -sn ${path_refG} ${path_OUT}"/path_links/refGenome" 2>/dev/null

# create file links:
scripts/create_file_links.py $path2configfile 


#========================================================================================
#----------  NOW START RUNNING SNAKEMAKE:  ----------------------------------------------


pathout=$( python -c "import sys, json; print(json.load(sys.stdin)['PATHOUT'])" < $path2configfile)

snakemake -s BSseq_pipeline.py --configfile $path2configfile -d $pathout $snakeparams


