#!/bin/bash

# Wait for Packer builder to be ready
sleep 10

# Helper function for decorating echo commands
# param $1 is the text to echo
# param $2 is optional command to execute after echoing text
# example:
# with 1 param: `echo_helper "test"`
# with 2 params: `echo_helper "test" "pwd"`
echo_helper() {
    echo -e "\n\n#################################################\n\n"
    echo -e "$1"
    if [[ ! -z $2 ]]
      then
        echo -e "\n"
        eval "$2"
    fi
    echo -e "\n\n#################################################\n\n"
}

# Update Ubuntu 22.04 repositories
echo_helper "Updating Ubuntu 22.04 repositories"
sudo apt-get update -y

# Install system libraries and utilities
echo_helper "Installing system libraries and utilities for noninteractive mode"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q dialog apt-utils software-properties-common python3-pip build-essential libssl-dev libffi-dev python3-dev

# Update Ubuntu 22.04 distribution
echo_helper "Updating Ubuntu 22.04 distribution"
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -q

# Install general purpose utilities
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q curl wget unzip jq
sudo wget https://github.com/mikefarah/yq/releases/download/"$YQ_VERSION" -O /usr/bin/yq && sudo chmod +x /usr/bin/yq

# Install JDK LTS
echo_helper "Installing JDK $JDK_VERSION LTS"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q openjdk-"$JDK_VERSION"-jdk
echo_helper "JDK version" "java -version"

# Create Datomic User group
sudo groupadd datomic
# Associate Datomic user group with Ubuntu user
sudo usermod -a -G datomic ubuntu

# Make setup directory for storing all the setup artifacts
echo_helper "Making /tmp/setup_artifacts directory for storing all the setup related artifacts"
mkdir -p /tmp/setup_artifacts/datomic
mkdir -p /tmp/setup_artifacts/datadog_agent

# Download Datomic
echo_helper "CD in /tmp/setup_artifacts/datomic"
cd /tmp/setup_artifacts/datomic || return

echo_helper "Downloading Datomic distribution with version $DATOMIC_VERSION"
wget --http-user="$DATOMIC_USER" --http-password="$DATOMIC_PASSWORD" "https://my.datomic.com/repo/com/datomic/datomic-pro/$DATOMIC_VERSION/datomic-pro-$DATOMIC_VERSION.zip" -O "datomic-pro-$DATOMIC_VERSION.zip"
unzip "datomic-pro-$DATOMIC_VERSION.zip"

# Download custom_metric_callback_library in "$DATOMIC_VERSION"/lib/
if [ -z "$DATOMIC_CUSTOM_METRIC_CALLBACK_LIBRARY_URL" ]
  then
    curl "$DATOMIC_CUSTOM_METRIC_CALLBACK_LIBRARY_URL" -o datomic-pro-"$DATOMIC_VERSION"/lib/custom-datomic-metric-callback.jar
fi

# Download datomic_logstash_encoder_library in "$DATOMIC_VERSION"/lib/
if [ -z "$DATOMIC_LOGSTASH_ENCODER_LIBRARY_URL"]
  then
    curl "$DATOMIC_LOGSTASH_ENCODER_LIBRARY_URL" -o datomic-pro-"$DATOMIC_VERSION"/lib/logstash-logback-encoder.jar
fi

echo_helper "Moving Datomic distribution to /opt/datomic_pro"
sudo mv datomic-pro-"$DATOMIC_VERSION" /opt/datomic_pro
sudo cp /tmp/datomic_transactor_logback.xml /opt/datomic_pro/bin/logback.xml
sudo chown -R ubuntu:datomic /opt/datomic_pro

if [ "$ENABLE_DATADOG" -eq true ]
  then
    # Download Datadog agent
    echo_helper "CD in /tmp/setup_artifacts/datadog_agent"
    cd /tmp/setup_artifacts/datadog_agent || return

    echo_helper "Downloading DataDog agent installer with version: $DD_AGENT_MAJOR_VERSION"
    wget "https://s3.amazonaws.com/dd-agent/scripts/install_script.sh" -O "install_script.sh"

    echo_helper "Installing DataDog Agent"
    chmod +x ./install_script.sh
    DD_AGENT_MAJOR_VERSION=$DD_AGENT_MAJOR_VERSION DD_API_KEY=$DD_API_KEY DD_SITE=$DD_SITE DD_INSTALL_ONLY=true DEBIAN_FRONTEND=noninteractive ./install_script.sh

    echo_helper "Creating JMX configuration"
    sudo mv /etc/datadog-agent/conf.d/jmx.d/conf.yaml.example /etc/datadog-agent/conf.d/jmx.d/conf.yaml
    sudo sed -i 's/# \(host.*\)/\1/' /etc/datadog-agent/conf.d/jmx.d/conf.yaml

    echo_helper "Configuring log exports to Datadog"
    touch conf.yaml
    yq -i '
      .logs[0].type = "file" |
      .logs[0].path = "/opt/datomic_pro/log/transactor.log" |
      .logs[0].service = "datomic_transactor" |
      .logs[0].source = "java" |
      .logs[0].sourcecategory = "sourcecode"
    ' conf.yaml

    echo_helper "Enabling log exports to Datadog"
    sudo mkdir /etc/datadog-agent/conf.d/java.d
    sudo cp conf.yaml /etc/datadog-agent/conf.d/java.d/
    sudo sed -i 's/# \(logs_enabled.*\)/\1/' /etc/datadog-agent/datadog.yaml
    sudo yq -i '.logs_enabled = true' /etc/datadog-agent/datadog.yaml
    sudo chown -R dd-agent:dd-agent /etc/datadog-agent
fi

echo_helper "Cleaning up /tmp"
rm -rf /tmp/setup_artifacts/datomic
rm -rf /tmp/setup_artifacts/datadog_agent

sleep 5
echo_helper "Script completed!!"
