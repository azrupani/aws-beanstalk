#!/bin/bash

#
# This script is used to push updates out to all components except the public Reverse Proxy (Changing that requires a
# full environment creation)
#

FUNCTIONS_FILE="beanstalk-bash-functions.sh"
MODIFY_ENVIRONMENT=1

# Import functions and custom variables:

. ${FUNCTIONS_FILE}

BEANSTALK_ENVIRONMENT="${CHECKED_OUT_BRANCH}"
UNIQUE_VERSION_ID="${BEANSTALK_ENVIRONMENT}-${EPOCH_TIME}"

if [[ ${OS} != "Linux" ]]
then
    echo "CRITICAL: Script can only be run on a Linux system, please try one of the CentOS Boxes."
    exit 1
elif [[ $(facter --plaintext node_role) != "syseng" ]]
then
    echo "CRITICAL: Script can only be run on the syseng machines."
    exit 1
elif [[ "${CHECKED_OUT_BRANCH}" == "master" ]]
then
    echo "CRITICAL: Script can only be executed when NOT checked out to master to modify an existing environment"
    exit 1
else
    # Continue
    git pull origin ${CHECKED_OUT_BRANCH} -qp > /dev/null
fi

echo -e "== This script asks for specified input and modifies the ${BEANSTALK_ENVIRONMENT} beanstalk environment ==\n"
echo -e "Please answer the following questions:\n"

#
# Notes: The order is critical, some operations require previous functions to be completed to make sure pre-requisites
# are being met and/or we have the necessary information. For Example: identifyDBDeploy function will always need to
# be executed before commitBranchToGit as we compare local changes against origin to find out which DB Deploy
# components needs to be executed
#

configureDockerFromSysengOrMannual
#configureDockerFromExistingEnvironment
getDBInfo

identifyDBDeploy
verifyBranchGitChanges

DBDeploy

createZip
uploadZipToS3

prepareApplicationAWS
modifyEnvironmentAWS

watchEnvironmentDeploymentStatusAWS

commitBranchToGit

