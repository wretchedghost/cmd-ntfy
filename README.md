# cmd-ntfy
Script that runs program and displays info, output, success or fail on command.

Uses [ntfy](https://ntfy.sh/) as the base where you will need to setup your own topic or if you self host it, you will need to point to that domain and topic.

## Important stuff
* Copy cmd-ntfy to /usr/local/bin
* Create and edit /etc/cron-notify.conf
```bash
    NTFY_SERVER="https://ntfy.<your-domain>.com" 
    NTFY_TOPIC="<your-topic>" 
    NTFY_USER=""  # optional 
    NTFY_PASS=""  # optional 
```

### Run examples:
* $ cmd-ntfy <command>
* $ cmd-ntfy rsync -av <source-dir> <dest-dir>

```bash
$ cmd-ntfy df -h
Filesystem      Size  Used Avail Use% Mounted on 
udev             32G     0   32G   0% /dev 
tmpfs           6.3G 1012K  6.3G   1% 
/run /dev/nvme0n1p3  442G  2.4G  417G   1% / 
tmpfs            32G     0   32G   0% /dev/shm 
efivarfs        256K   55K  197K  22% /sys/firmware/efi/efivars 
tmpfs           5.0M     0  5.0M   0% /run/lock 
tmpfs           1.0M     0  1.0M   0% /run/credentials/systemd-journald.service 
tmpfs            32G     0   32G   0% /tmp 
/dev/nvme0n1p1  975M  8.8M  966M   1% /boot/efi 
tmpfs           1.0M     0  1.0M   0% /run/credentials/getty@tty1.service 
tmpfs           6.3G  8.0K  6.3G   1% /run/user/0 
tank0            25T  256K   25T   1% /mnt/tank0 
tank0/enc        35T   11T   25T  31% /mnt/tank0/enc 
tmpfs           6.3G  8.0K  6.3G   1% /run/user/1000 
{"id...
```
After the "id..." is the relevant information sent to your ntfy instance.

## Installation:
```bash
# Copy to /usr/local/bin
sudo cp cmd-ntfy /usr/local/bin/cmd-ntfy
sudo chmod +x /usr/local/bin/cmd-ntfy

# Now you can use it from anywhere:
cmd-ntfy zpool status
cmd-ntfy -v apt update
cmd-ntfy --version
cmd-ntfy --help
```

## Usage Examples:
```bash
# Show version
cmd-ntfy --version

# Show help
cmd-ntfy --help

# Run commands
cmd-ntfy rsync -av /source /dest
cmd-ntfy -v zpool status
cmd-ntfy apt update
```
