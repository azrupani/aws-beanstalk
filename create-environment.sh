#!/bin/bash

FUNCTIONS_FILE="beanstalk-bash-functions.sh"
CREATE_ENVIRONMENT=1

# Import functions and custom variables:

. ${FUNCTIONS_FILE}

if [[ ${OS} != "Linux" ]]
then
    echo "CRITICAL: Script can only be run on a Linux system, please try one of the CentOS Boxes."
    exit 1
elif [[ $(facter --plaintext node_role) != "syseng" ]]
then
    echo "CRITICAL: Script can only be run on the syseng machines."
    exit 1
elif [[ "${CHECKED_OUT_BRANCH}" != "master" ]]
then
    echo "CRITICAL: Script can only be executed when checked out to master branch"
    exit 1
else
    # Continue
    git pull origin master -qp > /dev/null
fi

echo -e "== This script asks for specified input and configures the prospective beanstalk environment ==\n"
echo -e "Please answer the following questions:\n"

#
# Notes: The order is critical, some operations require previous functions to be completed to make sure pre-requisites
# are being met and/or we have the necessary information. For Example: identifyDBDeploy function will always need to
# be executed before commitBranchToGit as we compare local changes against origin to find out which DB Deploy
# components needs to be executed
#

getBeanstalkEnvironmentName

getDatabaseSuffix
configureDatabaseName
getDatabaseUserName
configureDatabaseUserName
getDatabaseUserPassword
configureDatabaseUserPassword

#
# Choose only one from below
#
configureDockerFromExistingEnvironment
#configureDockerFromSysengOrMannual

configureReverseProxy
buildDockerReverseProxy
pushDockerReverseProxy
configureReverseProxyDockerTag

prepareRoute53Entry

identifyDBDeploy

verifyGitChanges

DBDeploy

createZip
uploadZipToS3

prepareApplicationAWS
deployEnvironmentAWSExceptRproxy
#Reverse Proxy is Deployed as part of the below function only during environment creation:
watchEnvironmentDeploymentStatusAWS

commitToGit

