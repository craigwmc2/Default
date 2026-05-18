#!/bin/sh
echo "Installing dependencies..."
pip install flask requests
echo ""
echo "Starting Cookbook server..."
echo "Open Safari and go to:  http://localhost:5000"
echo ""
python app.py
