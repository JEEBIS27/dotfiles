#!/bin/bash

# rclone-gdrive.service hash: {{ include "dot_config/systemd/user/rclone-gdrive.service" | sha256sum }}
# rclone-onedrive.service hash: {{ include "dot_config/systemd/user/rclone-onedrive.service" | sha256sum }}
echo "Enabling linger for user..."
sudo loginctl enable-linger "$USER"

echo "Reloading systemd user services..."
systemctl --user daemon-reload

systemctl --user enable --now rclone-gdrive.service
systemctl --user enable --now rclone-onedrive.service
