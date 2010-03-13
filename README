ABOUT THIS SCRIPT
=================

This bash script was designed to automate and simplify the remote backup
process of duplicity on Amazon S3.  After your script is configured, you can
easily backup, restore, verify and clean (either via cron or manually) your
data without having to remember lots of different command options and
passphrases.

Most importantly, you can easily backup the script and your gpg key in a
convenient passphrase-encrypted file.  This comes in in handy if/when your
machine ever does go belly up. 

More information about this script avaiable at:
http://damontimm.com/code/dt-s3-backup

Latest version of the code is available at:
http://github.com/thornomad/dt-s3-backup

BEFORE YOU START
================

This script requires user configuration.  Instructions are in
the file itself and should be self-explanatory.  Be sure to replace all the
*foobar* values with your real ones.  Almost every value needs to be
configured in someway.

You can use multiple copies of the script with different settings for different
backup scenarios.  It is designed to run as a cron job and will log information
to a text file (including remote file sizes, if you have s3cmd installed).  Be
sure to make the script executable (chmod +x) before you hit the gas.

REQUIREMENTS
============

* duplicity
* gpg
* Amazon S3 account
* s3cmd (optional)

COMMON USAGE EXAMPLES
=====================

* View help:
    $ dt-s3-backup.sh

* Run an incremental backup:
	$ dt-s3-backup.sh --backup

* Restore your entire backup:
	$ dt-s3-backup.sh --restore 
    You will be prompted for a restore directory

	$ dt-s3-backup.sh --restore /home/user/restore-folder
    You can also provide a restore folder on the command line.

* Restore a specific file in the backup:
    $ dt-s3-backup.sh --restore-file
    You will be prompted for a file to restore to the current directory

    $ dt-s3-backup.sh --restore-file img/mom.jpg
    Restores the file img/mom.jpg to the current directory

    $ dt-s3-backup.sh --restore-file img/mom.jpg /home/user/i-love-mom.jpg
    Restores the file img/mom.jpg to /home/user/i-love-mom.jpg

* List files in the remote archive
	$ dt-s3-backup.sh --list-current-files

* Verify the backup
    $ dt-s3-backup.sh --verify


NEXT VERSION WISH LIST
======================

* --restore-dir option
* restore files from a specific time period 


Thanks to Mario Santagiuliana for his help. 
