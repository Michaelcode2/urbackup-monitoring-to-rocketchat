#!/usr/bin/env python3
import os
import re
import time
import datetime
from pathlib import Path
import json
import requests
from typing import List, Dict, Tuple

class UrBackupMonitor:
    def __init__(self, backup_root_dir: str, days_threshold: int = 3):
        """
        Initialize the UrBackup monitor.
        
        Args:
            backup_root_dir: Root directory where UrBackup stores backups
            days_threshold: Number of days to check for missing backups
        """
        self.backup_root_dir = Path(backup_root_dir)
        self.days_threshold = days_threshold
        self.current_time = time.time()
        self.threshold_time = self.current_time - (days_threshold * 86400)
        # Pattern for zip files with format like 2025-03-08_01-10-Retail.zip
        self.backup_pattern = re.compile(r'\d{4}-\d{2}-\d{2}[_-]\d{2}[:-]?\d{2}.*\.zip$')
        
    def get_client_directories(self) -> List[Path]:
        """Get all client directories from the backup root."""
        if not self.backup_root_dir.exists():
            raise FileNotFoundError(f"Backup directory {self.backup_root_dir} does not exist")
        
        return [d for d in self.backup_root_dir.iterdir() if d.is_dir()]
    
    def parse_backup_date(self, filename: str) -> float:
        """Extract timestamp from backup filename."""
        # Match patterns like 2025-03-08_01-10-Retail.zip or 2025-03-08-010510
        date_pattern = r'(\d{4}-\d{2}-\d{2})[_-](\d{2})[:-]?(\d{2})'
        match = re.search(date_pattern, filename)
        
        if match:
            date_str = match.group(1)
            hour_str = match.group(2)
            min_str = match.group(3)
            
            # Parse the date string to a timestamp
            try:
                dt = datetime.datetime.strptime(f"{date_str} {hour_str}:{min_str}", "%Y-%m-%d %H:%M")
                return dt.timestamp()
            except ValueError:
                return 0
        
        return 0  # Return 0 if no date pattern found
    
    def check_directory_for_recent_backups(self, directory: Path) -> Tuple[bool, float]:
        """
        Check if a directory has any backup zip files newer than the threshold.
        Recursively checks the '~current' subdirectory for better performance.
        Skips system directories ('clients', 'urbackup', '.hashes').
        
        Returns:
            Tuple of (has_recent_backup, most_recent_timestamp)
        """
        most_recent = 0
        has_recent = False
        
        # Only check the ~current directory
        current_dir = directory / "current"
        if not current_dir.exists() or not current_dir.is_dir():
            return has_recent, most_recent
            
        # Recursively check files in the ~current directory
        for file in current_dir.rglob('*'):
            # Skip if the current item's name is in the excluded list
            if file.name.lower() in ['clients', 'urbackup', '.hashes']:
                continue
                
            if not file.is_file():
                continue
                
            # Only check files that match our backup zip pattern
            if not file.name.lower().endswith('.zip') or not self.backup_pattern.match(file.name):
                continue
            
            # Try to get file modification time first
            try:
                file_mtime = file.stat().st_mtime
            except (FileNotFoundError, PermissionError):
                continue
            
            # Also try to parse date from filename
            name_time = self.parse_backup_date(file.name)
            
            # Use the more recent of the two timestamps
            file_time = max(file_mtime, name_time)
            
            if file_time > most_recent:
                most_recent = file_time
                
            if file_time > self.threshold_time:
                has_recent = True
        
        return has_recent, most_recent
    
    def get_clients_missing_backups(self) -> Dict[str, float]:
        """
        Get a dictionary of clients missing recent backups.
        
        Returns:
            Dict mapping client names to their most recent backup timestamp
        """
        clients_missing_backups = {}
        
        for client_dir in self.get_client_directories():
            if client_dir.name.lower() in ['clients', 'urbackup', 'urbackup_tmp_files']:
                continue
            client_name = client_dir.name
            has_recent, most_recent = self.check_directory_for_recent_backups(client_dir)
            
            if not has_recent:
                clients_missing_backups[client_name] = most_recent
        
        return clients_missing_backups
    
    def send_rocketchat_alert(self, webhook_url: str, clients_missing_backups: Dict[str, float]):
        """Send alert to RocketChat about clients missing backups."""
        if not clients_missing_backups:
            return  # No missing backups, no alert needed
        
        # Format the message
        message = f"⚠️ **UrBackup Alert**: {len(clients_missing_backups)} clients missing zip backups for {self.days_threshold}+ days!\n\n"
        
        for client, timestamp in clients_missing_backups.items():
            if timestamp > 0:
                last_backup = datetime.datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M')
                message += f"- **{client}**: Last backup on {last_backup}\n"
            else:
                message += f"- **{client}**: No matching backup zip files found\n"
        
        # Send to RocketChat
        payload = {"text": message}
        try:
            response = requests.post(webhook_url, json=payload)
            response.raise_for_status()
            print(f"Alert sent to RocketChat: Status {response.status_code}")
        except requests.exceptions.RequestException as e:
            print(f"Failed to send alert to RocketChat: {e}")

# Example usage
if __name__ == "__main__":
    # Configuration
    BACKUP_ROOT_DIR = "/mnt/backup/urbackup/"  # Replace with your UrBackup backup directory
    ROCKETCHAT_WEBHOOK = "https://your-rocketchat-server/hooks/XXX"
    DAYS_THRESHOLD = 3
    
    # Run the check
    try:
        monitor = UrBackupMonitor(BACKUP_ROOT_DIR, DAYS_THRESHOLD)
        missing_backups = monitor.get_clients_missing_backups()
        
        if missing_backups:
            print(f"Found {len(missing_backups)} clients missing recent zip backups:")
            for client, timestamp in missing_backups.items():
                if timestamp > 0:
                    date_str = datetime.datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M')
                    print(f"- {client}: Last backup on {date_str}")
                else:
                    print(f"- {client}: No matching backup zip files found")
            
            # Send notification to RocketChat
            monitor.send_rocketchat_alert(ROCKETCHAT_WEBHOOK, missing_backups)
        else:
            print("All clients have recent zip backups.")
    
    except Exception as e:
        print(f"Error running UrBackup monitor: {e}")
        # Optionally send error notification to RocketChat