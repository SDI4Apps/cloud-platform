# cloud-platform
cloud-init description for newly launched VMs

This repository contains config file for cloud-init that converts plain Ubuntu 14.04 LTS to SDI4Apps platform.

## CERIT-SC cloud (OpenNebula)

Must be submitted from command line. Install package **opennebula-tools** from [repository](http://docs.opennebula.org/4.10/design_and_installation/quick_starts/qs_ubuntu_kvm.html#install-the-repo).

Download the files user-data.yaml and launch_on_ceritsc.sh, run the script.

## Amazon AWS

In the **Step 3**  of [Launch Wizard](https://eu-west-1.console.aws.amazon.com/ec2/v2/home?region=eu-west-1#LaunchInstanceWizard:),
click on **Advanced Details**, then in the section **User Data** click **As file** and upload the file user-data.yaml.