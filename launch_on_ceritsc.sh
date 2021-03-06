#!/bin/bash

USER_DATA_FILE=user-data.yaml
CONTEXT_FILE=/tmp/ctx.$$
TEMPLATE_ID=3717

export ONE_HOST=https://cloud.metacentrum.cz
export ONE_XMLRPC=$ONE_HOST:6443/RPC2

if ! oneuser show >/dev/null 2>&1 ; then 
 echo "Authentication token for OpenNebula not found or not valid, create it using the following command"
 echo "in the directory with your X509 certificate and its private key:"
 echo
 echo  "oneuser login -v $LOGNAME --x509 --cert usercert.pem --key userkey.pem --force"
 exit 1 
fi

oneuser show >/dev/null 2>&1 || echo "neplatne"

echo "starting virtual image in OpenNebula using custom user-data from file $USER_DATA_FILE"

if [ ! -f "$USER_DATA_FILE" ] ; then
  echo "file $USER_DATA_FILE not found"
  exit 1
fi

cat >$CONTEXT_FILE <<"EOF"
CONTEXT=[
  EMAIL="$USER[EMAIL]",
  PUBLIC_IP="$NIC[IP]",
  SSH_KEY="$USER[SSH_KEY]",
  TARGET="vdb",
  TOKEN="YES",
  VM_GID="$GID",
  VM_GNAME="$GNAME",
  VM_ID="$VMID",
  VM_UID="$UID",
  VM_UNAME="$UNAME",
  USERDATA_ENCODING="base64",
EOF
echo >>$CONTEXT_FILE -n '  USER_DATA="'
base64 >>$CONTEXT_FILE -w 0 $USER_DATA_FILE
cat >>$CONTEXT_FILE <<EOF
"
]
EOF
onetemplate instantiate --verbose --name  sdi4apps-$(date '+%Y%m%d%H%M%S') -v $TEMPLATE_ID $CONTEXT_FILE
