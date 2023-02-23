#!/bin/bash

systemctl enable --quiet --now ronin-setup.service
systemctl disable --quiet oem-boot.service
