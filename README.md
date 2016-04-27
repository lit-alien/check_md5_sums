# check_md5_sums
NRPE Plugin to perform an integrity check on files, or groups of files.


Purpose: 
  Other plugins exist to check file md5sums, I wanted the ability to
  easily test against multiple groups of files, or test individual files.  

List files should keep the standard format used by /usr/bin/md5sum:

    d2c8f3221cb65200dc2a456f53c4deff  /path/to/file
    292e15f60807284414d94c0db108e495  /path/to/other/file


Installation:
 Copy check_md5_sums.sh to your plugins directory.
 
 Create the command in nrpe.cfg:
 
    command[check_md5_sums]=/usr/local/nagios/plugins/check_md5_sums.sh
    
  Restart nrpe services:
  
    service xinetd restart
    
 Create the service in Nagios:
 
    define service {
        host_name                       hostname
        service_description             check_md5_sums
        check_command                   check_nrpe!check_md5_sums!-a '-f /path/to/file'
        initial_state                   o
        max_check_attempts              1
        check_interval                  720
        retry_interval                  1
        check_period                    24x7
        notification_interval           720
        first_notification_delay        0
        notification_period             24x7
        notification_options            w,c,u,
        register                        1
        }
        
  
