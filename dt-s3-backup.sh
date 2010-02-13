#!/bin/bash
# 
# Copyright (c) 2008-2010 Damon Timm.  
# Copyright (c) 2010 Mario Santagiuliana.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

# ---------------------------------------------------------------------------- #

# AUTHORS:

# Damon Timm <damontimm@gmail.com> <http://blog.damontimm.com> 
# Mario Santagiuliana <mario@marionline.it> <http://www.marionline.it>

# VERSION 4 NOTE (02/12/2010):

# **Code is still being tested - if you want the last stable version, please
# download verion 0.3!**

# ABOUT THIS SCRIPT:
#
# This bash script was designed to automate and simplify the remote backup
# process using duplicity and Amazon S3.  Hopefully, after the script is
# configured, you can easily backup, restore, verify and clean without having
# to remember lots of different command options.
#
# Furthermore, you can even automate the process of saving your script and the
# gpg key for your backups in a single password-protected file -- this way, you
# know you have everything you need for a restore, in case your machine goes
# down.
#
# You can run the script from cron with no command-line options (all options
# set in the script itself); however, you can also run it outside of the cron
# with some variables for more control.

# OPTIONS:
#
# --full: forces a full backup (instead of waiting specified number of days)
# --verify: verifies the backup (no cleanup is run) 
# --restore: restores the backup to the directory specified in the script 
# --restore-to-dir [path]: restores the backup to the specified path 
# --restore-file [file]: restore a specific file 
# --backup-this-script: let's you backup the script and secret key to the 
#                       current working directory 
# --test: This was a non-duplicity scripting test: check logfile  
# --display-config: display directory variables configs in this script 
# --help: display help

# MORE INFORMATION:
#
# http://damontimm.com/code/dt-s3-backup

# ---------------------------------------------------------------------------- #

# AMAZON S3 INFORMATION
export AWS_ACCESS_KEY_ID="foobar_aws_key_id"
export AWS_SECRET_ACCESS_KEY="foobar_aws_access_key"

# GPG PASSPHRASE & GPG KEY (Automatic/Cron Usage)
# If you aren't running this from a cron, comment this line out
# and duplicity should prompt you for your password.
export PASSPHRASE="foobar_gpg_passphrase"
GPG_KEY="foobar_gpg_key"

# The ROOT of your backup (where you want the backup to start);
# This can be / or somwhere else -- I use /home/ because all the 
# directories start with /home/ that I want to backup.
ROOT="/home/"

# BACKUP DESTINATION INFORMATION
# In my case, I use Amazon S3 use this - so I made up a unique
# bucket name (you don't have to have one created, it will do it
# for you).  If you don't want to use Amazon S3, you can backup 
# to a file or any of duplicity's supported outputs.
#
# NOTE: You do need to keep the "s3+http://<your location>/" format;
# even though duplicity supports "s3://<your location>/" this script
# needs to read the former.
DEST="file:///home/foobar_user_name/new-backup-test/"
#DEST="s3+http://backup-bucket/backup-folder/"

# RESTORE FOLDER
# Being ready to restore is important to me, so I have this script
# setup to easily be able to restore a backup by adding the 
# "--restore" flag.  Indicate where you want the fili to restore to
# here so you're ready to go.
RESTORE="/home/foobar_user_name/restore-backup-01"

# INCLUDE LIST OF DIRECTORIES
# Here is a list of directories to include; if you want to include 
# everything that is in root, you could leave this list empty, I think.
#INCLIST=( "/home/*/Documents" \ 
#    	  "/home/*/Projects" \
#	      "/home/*/logs" \
#	      "/home/www/mysql-backups" \
#        ) 

INCLIST=( "/home/foobar_user_name/Documents/Prose/" ) # small dir for testing

# EXCLUDE LIST OF DIRECTORIES
# Even though I am being specific about what I want to include, 
# there is still a lot of stuff I don't need.           
EXCLIST=( "/home/*/Trash" \
	      "/home/*/Projects/Completed" \
	      "/**.DS_Store" "/**Icon?" "/**.AppleDouble" \ 
           ) 

# STATIC BACKUP OPTIONS
# Here you can define the static backup options that you want to run with
# duplicity.  I use both the full-if-older-than option plus the
# --s3-use-new-style option (for European buckets).  Be sure to separate your
# options with appropriate spacing.
STATIC_OPTIONS="--full-if-older-than 14D --s3-use-new-style"

# FULL BACKUP & REMOVE OLDER THAN SETTINGS
# Because duplicity will continue to add to each backup as you go,
# it will eventually create a very large set of files.  Also, incremental 
# backups leave room for problems in the chain, so doing a "full"
# backup every so often isn't not a bad idea.
#
# I set the default to do a full backup every 14 days and to remove all
# all files over 31 days old.  This should leave me at least two full
# backups available at any time, as well as a month's worth of incremental
# data.
#CLEAN_UP_TYPE="remove-older-than"
#CLEAN_UP_VARIABLE="31D"

# If you would rather keep a certain (n) number of full backups (rather 
# than removing the files based on their age), uncomment the following
# two lines and select the number of full backups you want to keep.
CLEAN_UP_TYPE="remove-all-but-n-full"
CLEAN_UP_VARIABLE="2"

# LOGFILE INFORMATION DIRECTORY
# Provide directory for logfile, ownership of logfile, and verbosity level.
# I run this script as root, but save the log files under my user name -- 
# just makes it easier for me to read them and delete them as needed. 

# LOGDIR="/dev/null"
LOGDIR="/home/foobar_user_name/logs/test2/"
LOG_FILE="duplicity-`date +%Y-%m-%d-%M`.txt"
LOG_FILE_OWNER="foobar_user_name:foobar_user_name"
VERBOSITY="-v3"

# END OF USER EDITS











##############################################################
# Script Happens Below This Line - Shouldn't Require Editing # 
##############################################################
LOGFILE="${LOGDIR}${LOG_FILE}"
DUPLICITY="$(which duplicity)"
S3CMD="$(which s3cmd)"

NO_S3CMD="WARNING: s3cmd is not installed, remote file \
size information unavailable."
NO_S3CMD_CFG="WARNING: s3cmd is not configured, run 's3cmd --configure' \
in order to retrieve remote file size information. Remote file \
size information unavailable."

if [ ! -x "$DUPLICITY" ]; then
  echo "ERROR: duplicity not installed, that's gotta happen first!" >&2
  exit 1
elif  [ `echo ${DEST} | cut -c 1,2` = "s3" ]; then
  if [ ! -x "$S3CMD" ]; then
    echo $NO_S3CMD; S3CMD_AVAIL=false
  elif [ ! -f "${HOME}/.s3cfg" ]; then
    echo $NO_S3CMD_CFG; S3CMD_AVAIL=false
  else
    S3CMD_AVAIL=true
  fi
fi

if [ ! -d ${LOGDIR} ]; then
  echo "Attempting to create log directory ${LOGDIR} ..."
  if ! mkdir -p ${LOGDIR}; then
    echo "Log directory ${LOGDIR} could not be created by this user: ${USER}"
    echo "Aborting..."
    exit 1
  else
    echo "Directory ${LOGDIR} successfully created."
  fi
elif [ ! -w ${LOGDIR} ]; then
  echo "Log directory ${LOGDIR} is not writeable by this user: ${USER}"
  echo "Aborting..."
  exit 1
fi

get_source_file_size() 
{
  echo "---------[ Source File Size Information ]---------" >> ${LOGFILE}

  for exclude in ${EXCLIST[@]}; do
    DUEXCLIST="${DUEXCLIST}${exclude}\n"
  done
  
  for include in ${INCLIST[@]}
    do
      echo -e $DUEXCLIST | \
      du -hs --exclude-from="-" ${include} | \
      awk '{ print $2"\t"$1 }' \
      >> ${LOGFILE}
  done
}

get_remote_file_size() 
{
  echo "------[ Destination File Size Information ]------" >> ${LOGFILE}
  if [ `echo ${DEST} | cut -c 1,2` = "fi" ]; then
    TMPDEST=`echo ${DEST} | cut -c 6-` 
    SIZE=`du -hs ${TMPDEST} | awk '{print $1}'`	
  elif [ `echo ${DEST} | cut -c 1,2` = "s3" ] &&  $S3CMD_AVAIL ; then
      TMPDEST=$(echo ${DEST} | cut -c 11-)
      SIZE=`s3cmd du -H s3://${TMPDEST} | awk '{print $1}'`
  else
      SIZE="s3cmd not installed."
  fi
  echo "Current Remote Backup File Size: ${SIZE}" >> ${LOGFILE}
}

include_exclude()
{
  for include in ${INCLIST[@]}
    do
      TMP=" --include="$include
      INCLUDE=$INCLUDE$TMP
  done
  for exclude in ${EXCLIST[@]}
      do
      TMP=" --exclude "$exclude
      EXCLUDE=$EXCLUDE$TMP
    done  
    EXCLUDEROOT="--exclude=**"
}

duplicity_cleanup() 
{
  echo "-----------[ Duplicity Cleanup ]-----------" >> ${LOGFILE}
  ${DUPLICITY} ${CLEAN_UP_TYPE} ${CLEAN_UP_VARIABLE} --force \
	    --encrypt-key=${GPG_KEY} \
	    --sign-key=${GPG_KEY} \
	    ${DEST} >> ${LOGFILE}
  echo >> ${LOGFILE}    
}

duplicity_backup()
{
  ${DUPLICITY} ${OPTION} ${VERBOSITY} ${STATIC_OPTIONS} \
  --encrypt-key=${GPG_KEY} \
  --sign-key=${GPG_KEY} \
  ${EXCLUDE} \
  ${INCLUDE} \
  ${EXCLUDEROOT} \
  ${ROOT} ${DEST} \
  >> ${LOGFILE}
}

get_file_sizes() 
{
  get_source_file_size
  get_remote_file_size

  sed -i '/-------------------------------------------------/d' ${LOGFILE}
  chown ${LOG_FILE_OWNER} ${LOGFILE}
}

backup_this_script()
{
  if [ `echo ${0} | cut -c 1` = "." ]; then
    SCRIPTFILE=$(echo ${0} | cut -c 2-)
    SCRIPTPATH=$(pwd)${SCRIPTFILE}
  else
    SCRIPTPATH=$(which ${0})
  fi
  TMPDIR=DT-S3-Backup-`date +%Y-%m-%d`
  TMPFILENAME=${TMPDIR}.tar.gpg
  
  echo "You are backing up: "
  echo "      1. ${SCRIPTPATH}"
  echo "      2. GPG Secret Key: $GPG_KEY"
  echo "Backup will be saved: `pwd`/${TMPFILENAME}"
  echo
  echo ">> Are you sure you want to do that ('yes' to continue)?"
  read ANSWER
  if [ "$ANSWER" != "yes" ]; then
    echo "You said << ${ANSWER} >> so I am exiting now."
    exit 1
  fi

  mkdir -p ${TMPDIR} 
  cp $SCRIPTPATH ${TMPDIR}/ 
  gpg -a --export-secret-keys ${GPG_KEY} > ${TMPDIR}/s3-secret.key.txt
  echo
  echo "Encrypting tarball, choose a password you'll remember..."
  tar c ${TMPDIR} | gpg -aco ${TMPFILENAME}
  rm -Rf ${TMPDIR}
  echo 
  echo ">> To restore files, run the following (remember your password!)"
  echo "gpg -d ${TMPFILENAME} | tar x"
}

check_variables ()
{
  if [[ ${ROOT} = "" || ${DEST} = "" || ${INCLIST} = "" || ${RESTORE} = "" ]]; then
    echo "Check your configuration variables ROOT or DEST or INCLIST or RESTORE not defined."
    echo -e "Check your configuration variables ROOT or DEST or INCLIST or RESTORE not defined.\n--------    END    --------" >> ${LOGFILE}
    exit 1
  fi
}	# ----------  end of function check_variables  ----------

echo -e "--------    START DT-S3-BACKUP SCRIPT    --------\n" >> ${LOGFILE}
if [ "$1" = "--backup-this-script" ]; then
  backup_this_script
  exit
elif [ "$1" = "--full" ]; then
  check_variables
  OPTION="full"
  include_exclude
  duplicity_backup
  duplicity_cleanup
  get_file_sizes
  
elif [ "$1" = "--verify" ]; then
  check_variables
  OLDROOT=${ROOT}
  ROOT=${DEST}
  DEST=${OLDROOT}
  OPTION="verify"
  
  echo "-------[ Verifying Source & Destination ]-------" >> ${LOGFILE}
  include_exclude
  duplicity_backup
  echo >> ${LOGFILE}
  #restore previous condition
  OLDROOT=${ROOT}
  ROOT=${DEST}
  DEST=${OLDROOT}
  get_file_sizes  

elif [ "$1" = "--restore" ]; then
  check_variables
  ROOT=$DEST
  DEST=$RESTORE
  OPTION="restore"

  if [ "$2" != "yes" ]; then
    echo ">> You will restore to ${DEST} from ${ROOT}."
    echo ">> You can override this question by executing '--restore yes' next time"
    echo "Are you sure you want to do that ('yes' to continue)?"
    read ANSWER
    if [ "$ANSWER" != "yes" ]; then
      echo "You said << ${ANSWER} >> so I am exiting now."
      echo -e "--------    END    --------\n" >> ${LOGFILE}
      exit 1
    fi
    echo "Restoring now ..."
  fi
  duplicity_backup

elif [ "$1" = "--restore-to-dir" ]; then
  check_variables
  ROOT=$DEST
  OPTION="restore"

  if [[ ! "$2" ]]; then
    echo "Please provide a path destination (eg. /home/user/restore-dir):"
    read -e NEWDESTINATION
    DEST=$NEWDESTINATION
    echo ">> You will restore to ${DEST} from ${ROOT}."
    echo ">> You can override this question by executing '--restore-to-dir [directory_destination]' next time"
    echo "Are you sure you want to do that ('yes' to continue)?"
    read ANSWER
    if [ "$ANSWER" != "yes" ]; then
      echo "You said << ${ANSWER} >> so I am exiting now."
      echo -e "--------    END    --------\n" >> ${LOGFILE}
      exit 1
    fi
    echo "Restoring now ..."
  else
    DEST=$2
  fi
  duplicity_backup

elif [ "$1" = "--restore-file" ]; then
  check_variables
  ROOT=$DEST
  INCLUDE=
  EXCLUDE=
  EXLUDEROOT=
  OPTION=

  if [[ ! "$2" ]]; then
    echo "Please provide file to restore (eg. Mail/article):"
    read -e FILE_TO_RESTORE
    FILE_TO_RESTORE=$FILE_TO_RESTORE
    DEST=$FILE_TO_RESTORE
    echo ">> You will restore your $FILE_TO_RESTORE to ${DEST} from ${ROOT}."
    echo ">> You can override this question by executing '--restore-file [file]' next time"
    echo "Are you sure you want to do that ('yes' to continue)?"
    read ANSWER
    if [ "$ANSWER" != "yes" ]; then
      echo "You said << ${ANSWER} >> so I am exiting now."
      echo -e "--------    END    --------\n" >> ${LOGFILE}
      exit 1
    fi
    echo "Restoring now ..."
  else
    FILE_TO_RESTORE=$2
  fi
  #use INCLUDE variable without create another one
  INCLUDE="--file-to-restore ${FILE_TO_RESTORE}"
  DEST=$FILE_TO_RESTORE
  duplicity_backup

elif [ "$1" = "--test" ]; then
  echo "This was a non-duplicity scripting test: check logfile for file sizes."
  get_file_sizes
elif [ "$1" = "--help" ]; then
  echo "  Usage: 
        `basename $0` [options]
  
  Options:
    --full: forces a full backup (instead of waiting specified number of days)
    --verify: verifies the backup (no cleanup is run)
    --restore: restores the backup to the directory specified in the script
    --restore-to-dir [path]: restores the backup to specified path
    --restore-file [file]: restore a specific file

    --backup-this-script: let's you backup the script and secret key to the current working directory

    --test: This was a non-duplicity scripting test: check logfile for file sizes.
    --display-config: display directory variables configs in this script
    --help: display this help
    "
elif [ "$1" = "--display-config" ]; then
  echo "Directory variables are:
    DEST (backup destination) = ${DEST}
    RESTORE (restore destination) = ${RESTORE}
    INCLIST (directory that will be backup) = ${INCLIST}
    EXCLIST (directory that will not be backup) = ${EXCLIST}
    ROOT (root directory) = ${ROOT}
  "
else
  check_variables
  include_exclude
  duplicity_backup
  duplicity_cleanup
  get_file_sizes
fi
echo -e "--------    END    --------\n" >> ${LOGFILE}

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset PASSPHRASE

# EOF
