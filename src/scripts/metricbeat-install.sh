#!/bin/bash

# License: https://github.com/elastic/azure-marketplace/blob/master/LICENSE.txt
#

# Custom logging with time so we can easily relate running times, also log to separate file so order is guaranteed.
# The Script extension output the stdout/err buffer in intervals with duplicates.
log()
{
    echo \[$(date +%d%m%Y-%H:%M:%S)\] "$1"
    echo \[$(date +%d%m%Y-%H:%M:%S)\] "$1" >> /var/log/arm-install.log
}

log "Begin execution of Metricbeat script extension on ${HOSTNAME}"

START_TIME=$SECONDS

export DEBIAN_FRONTEND=noninteractive

help()
{
    echo "This script installs Metricbeat on Ubuntu"
    echo ""
    echo "Options:"
    echo "    -L logging cluster URL"
    echo "    -u logging username"
    echo "    -p logging user password"

    echo "    -h      view this help content"
}

#Loop through options passed
while getopts :u:p:L:h optname; do
  log "Option $optname set"
  case $optname in
    L) # logging URL
        LOGGING_URL="${OPTARG}"
        ;;
    u) # logging username
        LOGGING_USER="${OPTARG}"
        ;;
    p) # logging password
        LOGGING_PASS="${OPTARG}"
        ;;
    h) #show help
      help
      exit 2
      ;;
    \?) #unrecognized option - show help
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      help
      exit 2
      ;;
  esac
done

install_metricbeat()
{
    local PACKAGE_NAME="metricbeat-7.1.1-amd64.deb"
    log "[install_metricbeat] installing package $PACKAGE_NAME"
    local DOWNLOAD_URL="https://artifacts.elastic.co/downloads/beats/metricbeat/$PACKAGE_NAME"
    wget --retry-connrefused --waitretry=1 -q "$DOWNLOAD_URL" -O "$PACKAGE_NAME"
    sudo dpkg -i "$PACKAGE_NAME"
    log "[install_metricbeat] installed package $PACKAGE_NAME"
}

configure_metricbeat()
{
    local CONFIG="/etc/metricbeat/metricbeat.yml"
    {
        echo -e "output.elasticsearch:"
        echo -e "  hosts: ['${LOGGING_URL}']"
        echo -e "  username: ${LOGGING_USER}"
        echo -e "  password: ${LOGGING_PASS}"
    } > script.yml

    yq w -i "$CONFIG" -s script.yml
    rm script.yml
}

install_yq()
{
    wget -q https://github.com/mikefarah/yq/releases/download/2.4.0/yq_linux_amd64 -O /usr/local/bin/yq
    chmod +x /usr/local/bin/yq
}

start_service()
{
    log "[start_service] Enable and start metricbeat"
    systemctl enable metricbeat
    systemctl restart metricbeat
    log "[start_service] Metricbeat running"
}

install_yq

install_metricbeat

configure_metricbeat

start_service

ELAPSED_TIME=$(($SECONDS - $START_TIME))
PRETTY=$(printf '%dh:%dm:%ds\n' $(($ELAPSED_TIME/3600)) $(($ELAPSED_TIME%3600/60)) $(($ELAPSED_TIME%60)))

log "End execution of Metricbeat script extension on ${HOSTNAME} in ${PRETTY}"
exit 0
