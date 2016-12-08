# cloud-platform
cloud-init description for newly launched VMs

This repository contains config file for cloud-init that converts plain Ubuntu LTS to SDI4Apps platform.

See the following sections to see how to launch it on various clouds:
* [Amazon AWS](#amazon-aws)
* [CERIT-SC](#cerit-sc-opennebula)
* [Google CE](#google-computing-engine)

## Amazon AWS

In the **Step 3**  of [Launch Wizard](https://eu-west-1.console.aws.amazon.com/ec2/v2/home?region=eu-west-1#LaunchInstanceWizard:),
when launching Ubuntu 16.04, click on **Advanced Details**, then in the section **User Data** click **As file** and upload the file user-data-xenial.yaml.


## CERIT-SC OpenNebula

Log into [OpenNebula web interface](https://cloud.metacentrum.cz/). Instantiate the template 3717 "SDI4Apps platform 16.04 Xenial".

It can be also submitted from command line.  Download the files user-data-xenial.yaml, authenticate, then run  *launch_on_ceritsc.sh*.

### Setup for CERIT-SC OpenNebula Command Line

Install package **opennebula-tools** from [repository](http://docs.opennebula.org/4.14/design_and_installation/quick_starts/qs_ubuntu_kvm.html#install-the-repo). On a Ubuntu 14.04 box, do the following:
```
sudo su -
wget -q -O- http://downloads.opennebula.org/repo/Ubuntu/repo.key | apt-key add -
echo "deb http://downloads.opennebula.org/repo/4.14/Ubuntu/14.04/ stable opennebula" > /etc/apt/sources.list.d/opennebula.list
apt-get update
apt-get install opennebula-tools
/usr/share/one/install_gems
exit
```

Then you have to set up authentication. You will need an X509 digital certificate from an IGTF-approved certification authority
 imported in your browser for that.
* register your digital certificate at [Perun account management](https://perun.metacentrum.cz/perun-identity-consolidator-krb/)
* export that certificate and its private key from your browser into a file, named e.g. *mycreds.p12*
* create an OpenNebula access token from the certificate using the following commands:
```
# extracts the public certificate into file usercert.pem
openssl pkcs12 -in mycreds.p12 -out usercert.pem -clcerts -nokeys 
# extract the private key userkey.pem
openssl pkcs12 -in mycreds.p12 -out userkey.pem -nocerts -nodes  
# generates Opennebula access token
oneuser login -v $LOGNAME --x509 --cert usercert.pem --key userkey.pem --force
```
* add the following at the end of your *~/.bashrc* file:
```
#env vars for OpenNebula tools
export ONE_HOST=https://cloud.metacentrum.cz
export ONE_XMLRPC=$ONE_HOST:6443/RPC2
```

## Google Computing Engine

Must be submitted from command line. 

Download the files user-data-xenial.yaml and launch_on_google_ce.sh, run the script.

### Setup for Google Computing Engine

Install Google Cloud tools from [repository](https://cloud.google.com/sdk/#debubu). On a Ubuntu 14.04 box, do the following:
```
sudo su -
export CLOUD_SDK_REPO=cloud-sdk-`lsb_release -c -s`
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list
apt-get update 
apt-get install google-cloud-sdk
exit
gcloud init
```
Set up authentication by running the following command:
```
gcloud auth login
```
