#! /bin/bash
# check_md5_sums.sh
# Author: Eric L'Italien , <dev@lit-alien.com>
#
# check_md5_sums.sh is an NRPE plugin to check the integrity of a file,
# or a group of files.
#     Copyright (C) 2016  Eric L'Italien
#
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
#
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# ########################################################################
#
#

# variables
  version=0.1
# listdir to store list files
  listdir='/usr/local/nagios/etc/check_md5_sums'
# md5list is the default list file to check for individual files
  listfile="${listdir}/md5list"

# Nagios Exit Codes
  OK=0
  WARNING=1
  CRITICAL=2
  UNKNOWN=3


function nagios_exit {
  # Exit, Nagios style.
  echo $2
  exit $1
}



function show_usage {
	echo ''
  echo 'Usage:'
  echo '     check_md5_sums.sh [-f filename][-l list_file][-u]'
  echo '     check_md5_sums.sh -a -f filename [-l list_file]'
	echo ' check_md5_sums.sh tests md5sums of one or more files,'
  echo ' and returns Nagios exit codes as follows:'
  echo ' For the specified file or if the entire list passes: OK'
  echo ' If the file or member of the list does not match: WARNING'
  echo ' If the file or member of the list are missing: CRITICAL'
  echo ' In case of various errors or bad input: UNKNOWN'

  echo ''
  echo '  -f, --file filename'
  echo '        The name of the file to check.'
  echo '  -l, --list list_filename'
  echo '        The name of a listfile; to be used for checking'
  echo '        an entire list, or a single file in a custom list.'
  echo '  -a, --add-file'
  echo '        Used to add a file, the "--file filename" argument'
  echo '        is required.  If used with "--list" argument hash'
  echo '        will be added to the specified list.'
  echo '  -u, --update'
  echo '        With the --update argument WARNING or CRITICAL will'
  echo '        be returned, then the hash(es) that did not match '
  echo '        will updated with the new values.'

  exit
}

# process arguments
while [ "$1" != "" ]; do
    case $1 in
        -f | --file )           shift
                                filename=$1
                                ;;
        -l | --list )    	      shift
				                        listfile=$1
                                ;;
	      -a | --add-file	)	      add_file=1
				                        ;;
	      -u | --update )		      auto_update=1
				                        ;;
        -h | --help )           show_usage
                                exit
                                ;;
        -V | --version )        echo "Version: ${version}"
                                exit
                                ;;
        * )                     show_usage
                                exit
    esac
    shift
done

function check_file {
  # Checks an individual file. A mismatch returns WARNING, if the
  # file is missing CRITICAL will be returned from the validate function.
  # If auto_update is specified, the list file will be updated with they
  # new md5 sum.

    result=$(/usr/bin/md5sum $filename)
    if [[ -z $result ]]; then
      nagios_exit $UNKNOWN "UNKNOWN: No md5sum returned for $filename."
    fi
    if ! [[ $(grep $result $listfile) ]]; then
      if [[ $auto_update ]]; then
        update_file $filename
        update_text=" $listfile has been updated."
      fi
      nagios_exit $WARNING "WARNING: $filename does not match the \
      existing md5sum.$update_text"
    else
      nagios_exit $OK "OK: $filename matches the existing md5sum."
    fi
}

function check_list {
  # Check an entire list for matches.  If one or more files fails,
  # iterate through the failed files, if they exist, return a
  # WARNING Message, if the file no longer exists return CRITICAL.
  # If the auto_update option is selected update_file is called.

    listresult=$(/usr/bin/md5sum -c $listfile 2>/dev/null | grep ": FAILED")
    if [[ -z $listresult ]]; then
      nagios_exit $OK "OK: All files in $listfile match."
    else
      exitmessage="$listfile had one or more mismatches."
      exitcode=1
      for lr in ${listresult} ; do
        if ! [[ $lr =~ FAILED|open|or|read ]]; then
          if ! [[ -e ${lr//:} ]]; then
            exitcode=2
            exitmessage="${exitmessage} CRITICAL: ${lr} does not exist."
          else
            exitmessage="${exitmessage} WARNING: ${lr} does not match."
          fi
          if [[ $auto_update ]]; then
            update_file $lr
            exitmessage="${exitmessage} ${listfile} has been updated."
          fi
        fi
      done
      nagios_exit $exitcode "${exitmessage}"
    fi
}



function update_file {
  # Updates the list file. This is called with a file name
  # as an argument. A backup of the current list is saved,
  # and the specified file is then corrected, by first removing
  # the old line, and then adding the current version.

  oldfile="${listfile}_$(date +%Y%m%d_%H%M%S%N)"
  mv $listfile $oldfile
  grep -v $1 $oldfile >> $listfile
  /usr/bin/md5sum "$1" >> $listfile 2>/dev/null
}

function validate {
    # confirm the existence of any files supplied
    if [[ -z $listfile ]]; then
      listfile="$($listdir)md5list"
    fi

    if ! [[ -e $listfile ]]; then
      nagios_exit $UNKNOWN "UNKNOWN: $listfile does not exist."
    fi

    if ! [[ -z $filename ]] && ! [[ -e $filename ]]; then
        nagios_exit $CRITICAL "CRITICAL: $filename does not exist."
    fi

    if [[ $add_file ]] && [[ -z $filename ]]; then
        show_usage
    fi
}

validate
if ! [[ -z $filename ]]; then
  if [[ $add_file ]]; then
    /usr/bin/md5sum $filename >> $listfile 2>/dev/null
    nagios_exit $OK "$filename added to $listfile."
  else
    check_file
  fi
else
  check_list
fi
