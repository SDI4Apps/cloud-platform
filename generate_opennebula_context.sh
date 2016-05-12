#!/bin/bash
#
# Generates the part of OpenNebula template that can include user-data
#

USER_DATA_FILE=user-data-xenial.yaml
CONTEXT_FILE=/tmp/ctx.$$

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

cat $CONTEXT_FILE
