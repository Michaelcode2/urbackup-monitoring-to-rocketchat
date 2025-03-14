# UrBackup Monitor

A Python script that monitors UrBackup backup directories and alerts via RocketChat when backups are missing or outdated.

## Description

This script scans an UrBackup server's backup directory to identify clients that haven't been backed up within a specified timeframe. It checks for ZIP backup files and can send alerts to RocketChat when it detects missing or outdated backups.

## Features

- Scans UrBackup backup directories for ZIP backup files
- Identifies clients missing recent backups
- Supports various backup filename formats
- Sends formatted alerts to RocketChat
- Configurable backup age threshold
- Excludes system directories automatically

## Prerequisites

- Python 3.6 or higher
- Access to UrBackup backup directory
- RocketChat webhook URL (if using alerts)

## Required Python Packages

``` bash
pip install requests
```

## Configuration

Edit the following variables in the script:

```python
BACKUP_ROOT_DIR = "/mnt/backup/urbackup/" # Your UrBackup backup directory
ROCKETCHAT_WEBHOOK = "https://your-rocketchat-server/hooks/XXX" # Your webhook URL
DAYS_THRESHOLD = 3 # Number of days to consider a backup as outdated
```

## Usage

1. Make the script executable:

```bash
chmod +x scanner.sh
```

2. Run the script:

```bash
./scanner.sh
```

## Output Example

The script will output results to both console and RocketChat (if configured):

```
Found 2 clients missing recent zip backups:
Client1: Last backup on 2024-01-15 10:30
Client2: No matching backup zip files found
```

RocketChat alert format:

```
⚠️ UrBackup Alert: 2 clients missing zip backups for 3+ days!
Client1: Last backup on 2024-01-15 10:30
Client2: No matching backup zip files found
```

## Error Handling

- Handles missing or inaccessible directories
- Skips system directories (clients, urbackup, .hashes)
- Reports errors to console
- Can be configured to send error notifications to RocketChat

