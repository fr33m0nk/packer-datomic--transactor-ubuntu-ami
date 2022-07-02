locals {
  timestamp       = regex_replace(timestamp(), "[- TZ:]", "")
  ami_name        = "ubuntu_22.04_[arch]_jdk_${var.jdk_version}_datomic_v${var.datomic_version}_datadog_v${var.datadog_agent_version}_${local.timestamp}"
  ami_description = "[arch] AMI with Ubuntu 22.04 base image, JDK ${var.jdk_version}, Datomic ver. ${var.datomic_version}, Datadog Agent ver. ${var.datadog_agent_version}"
  shell_provisioner_environment_vars = [
    "JDK_VERSION=${var.jdk_version}",
    "DATOMIC_USER=${var.datomic_account_user}",
    "DATOMIC_PASSWORD=${var.datomic_account_password}",
    "DATOMIC_VERSION=${var.datomic_version}",
    "ENABLE_DATADOG=${var.enable_datadog}",
    "DD_AGENT_MAJOR_VERSION=${var.datadog_agent_version}",
    "DD_API_KEY=${var.datadog_api_key}",
    "DD_SITE=${var.datadog_site}",
    "DATOMIC_CUSTOM_METRIC_CALLBACK_LIBRARY_URL=${var.datomic_custom_metric_callback_library_url}",
    "DATOMIC_LOGSTASH_ENCODER_LIBRARY_URL=${var.datomic_logstash_encoder_library_url}"
  ]
}

source "amazon-ebs" "ubuntu_datomic_datadog_amd64_ami" {
  access_key              = var.aws_access_key
  secret_key              = var.aws_secret_key
  ami_description         = replace(local.ami_description, "[arch]", "AMD64")
  ami_name                = replace(local.ami_name, "[arch]", "amd64")
  ami_virtualization_type = "hvm"
  instance_type           = var.instance_type_amd64
  region                  = var.aws_region
  source_ami              = data.amazon-ami.ubuntu_22_04_amd64_hvm_ebs.id
  ssh_username            = "ubuntu"

  tags = {
    BaseAMIName    = data.amazon-ami.ubuntu_22_04_amd64_hvm_ebs.name
    BaseAMIID      = data.amazon-ami.ubuntu_22_04_amd64_hvm_ebs.id
    BaseAMIOwnerID = data.amazon-ami.ubuntu_22_04_amd64_hvm_ebs.owner
    DatomicVersion = var.datomic_version
    DatadogVersion = var.datadog_agent_version
    JDKVersion     = var.jdk_version
    ImageCreatedAt = local.timestamp
    Name           = replace(local.ami_name, "[arch]", "amd64")
  }
}

source "amazon-ebs" "ubuntu_datomic_datadog_arm64_ami" {
  access_key              = var.aws_access_key
  secret_key              = var.aws_secret_key
  ami_description         = replace(local.ami_description, "[arch]", "ARM64")
  ami_name                = replace(local.ami_name, "[arch]", "arm64")
  ami_virtualization_type = "hvm"
  instance_type           = var.instance_type_arm64
  region                  = var.aws_region
  source_ami              = data.amazon-ami.ubuntu_22_04_arm64_hvm_ebs.id
  ssh_username            = "ubuntu"

  tags = {
    BaseAMIName    = data.amazon-ami.ubuntu_22_04_arm64_hvm_ebs.name
    BaseAMIID      = data.amazon-ami.ubuntu_22_04_arm64_hvm_ebs.id
    BaseAMIOwnerID = data.amazon-ami.ubuntu_22_04_arm64_hvm_ebs.owner
    DatomicVersion = var.datomic_version
    DatadogVersion = var.datadog_agent_version
    JDKVersion     = var.jdk_version
    ImageCreatedAt = local.timestamp
    Name           = replace(local.ami_name, "[arch]", "arm64")
  }
}

build {
  sources = [
    "source.amazon-ebs.ubuntu_datomic_datadog_amd64_ami"
  ]

  provisioner "file" {
    source      = "resources/datomic_transactor_logback.xml"
    destination = "/tmp/datomic_transactor_logback.xml"
  }

  provisioner "shell" {
    environment_vars = concat(local.shell_provisioner_environment_vars, ["YQ_VERSION=v4.24.2/yq_linux_amd64"])
    script           = "scripts/setup.sh"
  }
}

build {
  sources = [
    "source.amazon-ebs.ubuntu_datomic_datadog_arm64_ami"
  ]

  provisioner "file" {
    source      = "resources/datomic_transactor_logback.xml"
    destination = "/tmp/datomic_transactor_logback.xml"
  }

  provisioner "shell" {
    environment_vars = concat(local.shell_provisioner_environment_vars, ["YQ_VERSION=v4.25.2/yq_linux_arm64"])
    script           = "scripts/setup.sh"
  }
}
