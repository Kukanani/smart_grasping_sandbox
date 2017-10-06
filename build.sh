#!/bin/bash
sudo docker build . -t stevia --build-arg GITHUB_KEY=${GITHUB_KEY}