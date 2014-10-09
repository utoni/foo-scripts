#!/bin/bash

nvidia-smi | grep -oE '[0-9]{2,3}C'
