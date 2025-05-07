#!/bin/bash

# Jupyter Installation Script for GCP VM
sudo apt update
sudo apt install python3-pip -y
pip3 install --upgrade pip

# Optional: Create virtual environment (recommended)
sudo pip3 install virtualenv
virtualenv venv
source venv/bin/activate

# Install Jupyter and data packages
pip install jupyter pandas matplotlib seaborn pymongo google-cloud-storage

# Configure Jupyter to allow external access
jupyter notebook --generate-config
CONFIG_FILE="$HOME/.jupyter/jupyter_notebook_config.py"
sed -i "s/^#c.NotebookApp.ip =.*/c.NotebookApp.ip = '0.0.0.0'/" "$CONFIG_FILE"
sed -i "s/^#c.NotebookApp.port =.*/c.NotebookApp.port = 8888/" "$CONFIG_FILE"
sed -i "s/^#c.NotebookApp.open_browser =.*/c.NotebookApp.open_browser = False/" "$CONFIG_FILE"

# Start Jupyter
jupyter notebook