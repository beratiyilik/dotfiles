#!/bin/bash

# prints a greeting with the provided name
function greeting() {
  echo "Hello $1"
}

# returns the current unix timestamp
function _getTimestamp(){
 local timestamp=$(date +%s)
 echo $timestamp
}

# returns the current date in YYYYMMDD format
function _getDateAsPrefix(){
  echo $(date +%Y%m%d)
}

# checks if the given path is a file
function _isFile(){
    local filePath=$1
    if [ -f ${filePath} ]; then
        echo "true"
    else
        echo "false"
    fi
}

# checks if the given path is a directory
function _isDirectory(){
    local directoryPath=$1
    if [ -d ${directoryPath} ]; then
        echo "true"
    else
        echo "false"
    fi
}

# creates a backup of given files by appending a timestamp
function _bakFile(){
  local timestamp=$(_getTimestamp)
  local arr=("$@")
  for i in "${arr[@]}"; do
    if [ -f ${i} ]; then
      echo "cp $i $i.$timestamp-bak"
      cp $i $i.$timestamp-bak
    fi
  done
}

# generates a SHA256 hash for a given file using sha256sum
function _generateSHA256() {
    if [[ -f $1 ]]; then
        sha256sum "$1" | awk '{ print $1 }'
    else
        echo "Error: File not found"
    fi
}

# generates a SHA256 hash for a given file using openssl
function _checksumSHA256() {
  openssl dgst -sha256 "$1"
}

# kills processes running on the specified ports (up to 3). Defaults to port 8080 if none provided.
function _killProcessesOnPorts() {
  local defaultPort=8080
  local ports=("$@")

  if [ ${#ports[@]} -gt 3 ]; then
    echo "Error: Too many arguments. Please provide up to 3 port numbers."
    return 1
  fi

  if [ ${#ports[@]} -eq 0 ]; then
    ports=($defaultPort)
  fi

  for portNumber in "${ports[@]}"; do
    local processIds=$(lsof -i :${portNumber} -t)
    if [ -z "${processIds}" ]; then
      echo "No process is running on port ${portNumber}"
    else
      echo "Killing processes on port ${portNumber}: ${processIds}"
      for pid in ${processIds}; do
        kill -9 ${pid}
        echo "Process ${pid} is killed"
      done
    fi
  done
}

## eof
