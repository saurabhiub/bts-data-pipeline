#!/bin/bash

# MongoDB Installation Script for GCP VM
# SSH into your airline-mongodb instance and run this script
###gcloud compute ssh airline-mongodb

# Import the public key used by the package management system
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
   --dearmor

# Create a list file for MongoDB
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Reload local package database
sudo apt-get update

# Install MongoDB packages
sudo apt-get install -y mongodb-org

# Start MongoDB
sudo systemctl start mongod

# Enable MongoDB to start on boot
sudo systemctl enable mongod

# Configure MongoDB for remote access
#sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf
sudo sed -i 's/127.0.0.1/127.0.0.1,10.128.0.3/g' /etc/mongod.conf
sudo systemctl restart mongod

# Create firewall rule for MongoDB
sudo ufw allow 27017

echo "MongoDB installation complete!"
echo "MongoDB is now accessible on port 27017"
