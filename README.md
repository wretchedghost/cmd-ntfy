# cmd-ntfy
Script that runs program and displays info, output, success or fail on command.

## How to run
* Copy cmd-ntfy to /usr/local/bin
* Create and edit /etc/cron-notify.conf
```bash
    NTFY_SERVER="https://ntfy.<your-domain>.com" 
    NTFY_TOPIC="<your-topic>" 
    NTFY_USER=""  # optional 
    NTFY_PASS=""  # optional 
```

* Run examples:
```bash
$ cmd-ntfy <command>
or
$ cmd-ntfy rsync -av <source-dir> <dest-dir>
```

