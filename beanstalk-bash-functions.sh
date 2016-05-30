if [[ -z ${FUNCTIONS_FILE} ]]
then
	echo "CRITICAL: Naughty, Naughty - this script is not meant to be called on its own, but instead must either be called by one of the other scripts to either provision or modify environment"
	exit 1
fi

if [[ -z ${AWS_ACCESS_KEY_ID} ]] || [[ -z ${AWS_SECRET_ACCESS_KEY} ]]
then
	echo "CRITICAL: AWS Authentication Variables AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY not set, please export them before continuing"
	exit 1
fi

OS=$(uname -s)
DOCKER_REGISTRY="<ADDME>:5000"
SYSENG_DB_HOST="<ADDME>"
SYSENG_DB_NAME="<ADDME>"
SYSENG_APPREG_TABLE_NAME="<ADDME>"
SYSENG_BUILDINFO_TABLE_NAME="<ADDME>"
SYSENG_DB_USERNAME="<ADDME>"
SYSENG_DB_PASSWORD="<ADDME>"
TARGET_DB="<ADDME>"
AF_URL="https://<ADDME>"
DB_COMPONENTS="<ADDME>"
DB_DEPLOY_WORKDIR="db-deploy"
RPROXY_DOCKER_WORKDIR="<APP-PREFIX>-rproxy-docker"
RPROXY_APP_NAME=${RPROXY_DOCKER_WORKDIR%-*}
EPOCH_TIME=$(date +%s)
BEANSTALK_ARTEFACTS_DIR="beanstalk-artefacts"
S3_BUCKET_NAME="${BEANSTALK_ARTEFACTS_DIR}"
ROUTE53_JSON_FILENAME="route53-config.json"
CHECKED_OUT_BRANCH="$(git status | head -n1 | awk '{print $NF}')"
RUNNING_PATH=$(pwd)
BEANSTALK_ARTEFACTS_HOME="${RUNNING_PATH}/beanstalk-artefacts/"
AWS_SOLUTION_STACK='64bit Amazon Linux 2016.03 v2.1.1 running Multi-container Docker 1.9.1 (Generic)'
RED="tput setaf 1"
GREEN="tput setaf 2"
YELLOW="tput setaf 3"
GREY="tput setaf 7"
COLOR_RESET="tput sgr0"
LOG_START="$(${GREEN})###"
LOG_END="###$(${COLOR_RESET}) "
COMMON_CONTAINERS=(<ADDME>)

function getBeanstalkEnvironmentName {
let BEANSTALK_ENV_UNIQUENESS=1
while [[ ${BEANSTALK_ENV_UNIQUENESS} -ne 0 ]]
do
	read -p "${LOG_START} Specify a unique beanstalk environment name: ${LOG_END}" BEANSTALK_ENVIRONMENT
	EXISTING_BRANCH_COUNT=$(git branch -a | grep -wc "${BEANSTALK_ENVIRONMENT}")
	if [[ ${EXISTING_BRANCH_COUNT} = 0 ]]
	then
		let BEANSTALK_ENV_UNIQUENESS=0
		UNIQUE_VERSION_ID="${BEANSTALK_ENVIRONMENT}-${EPOCH_TIME}"
	else
		let BEANSTALK_ENV_UNIQUENESS=1
	fi
done
git checkout -qb ${BEANSTALK_ENVIRONMENT}
echo ""
}

function getDatabaseSuffix {
while [[ -z ${DATABASE_SUFFIX} ]]
do
	read -p "${LOG_START} Specify a Database Suffix: (Press Enter to accept 'test') ${LOG_END}" DATABASE_SUFFIX
	if [[ -z ${DATABASE_SUFFIX} ]]
	then
		DATABASE_SUFFIX="test"
	fi
	# <APP-PREFIX>_minions_*, <APP-PREFIX>api_coin_*, <APP-PREFIX>api_projects_*, <APP-PREFIX>api_requests_*, <APP-PREFIX>api_stores_*, <ADDME>_*, <ADDME>_upload_*
	# (This replaces * with Suffix specified)
done

DB_URL="jdbc:mysql://${TARGET_DB}/<ADDME>_${DATABASE_SUFFIX}"
COIN_DB_URL="jdbc:mysql://${TARGET_DB}/<APP-PREFIX>api_coin_${DATABASE_SUFFIX}"
UPLOAD_DB_URL="jdbc:mysql://${TARGET_DB}/<ADDME>_upload_${DATABASE_SUFFIX}"
MIGRATION_DB_URL="${DB_URL}"

export DB_URL COIN_DB_URL UPLOAD_DB_URL MIGRATION_DB_URL

if [[ ${CREATE_ENVIRONMENT} -eq 1 ]]
then
	echo ""
fi
}

function configureDatabaseName {
# For databases starting with '<ADDME>_' prefix
for DATABASE_PREFIX in <ADDME>_
do
	echo -e "Configuring Docker Images to use: ${DATABASE_PREFIX}${DATABASE_SUFFIX}"
	for DOCKERRUN_FILE in `find -type f -name "Dockerrun.aws.json"`
	do
		sed -i "s/\(${DATABASE_PREFIX}\)\(.*_\)\?.*\(\"\)/\1\2${DATABASE_SUFFIX}\3/g" ${DOCKERRUN_FILE}
	done
done

# There's only just echo for the below as it gets covered in the above global <ADDME>_ prefix
echo -e "Configuring Docker Images to use: <ADDME>_upload_${DATABASE_SUFFIX}"

for DATABASE_PREFIX in <APP-PREFIX>_minions_ <APP-PREFIX>api_coin_ <APP-PREFIX>api_projects_ <APP-PREFIX>api_requests_ <APP-PREFIX>api_stores_
do
	echo -e "Configuring Docker Images to use: ${DATABASE_PREFIX}${DATABASE_SUFFIX}"
	for DOCKERRUN_FILE in `find -type f -name "Dockerrun.aws.json"`
	do
		sed -i "s/\(${DATABASE_PREFIX}\)\(.*\)\(\"\)/\1${DATABASE_SUFFIX}\3/g" ${DOCKERRUN_FILE}
	done
done

echo ""
}

function getDatabaseUserName {
while [[ -z ${DB_USERNAME} ]]
do
	read -p "${LOG_START} Specify a Database Username: (Press Enter to accept '<ADDME>test') ${LOG_END}" DB_USERNAME
	if [[ -z ${DB_USERNAME} ]]
	then
		DB_USERNAME="<ADDME>test"
	fi
done

MIGRATION_DB_USERNAME=${DB_USERNAME}
COIN_DB_USERNAME=${DB_USERNAME}
UPLOAD_DB_USERNAME=${DB_USERNAME}
export DB_USERNAME MIGRATION_DB_USERNAME COIN_DB_USERNAME UPLOAD_DB_USERNAME

if [[ ${CREATE_ENVIRONMENT} -eq 1 ]]
then
	echo ""
fi
}

function configureDatabaseUserName {
for DOCKERRUN_FILE in `find -type f -name "Dockerrun.aws.json"`
do
	sed -i "/DB_USERNAME/{n;s/\(: \"\).*\(\"\)/\1${DB_USERNAME}\2/;}" ${DOCKERRUN_FILE}
done
}

function getDatabaseUserPassword {
while [[ -z ${DB_PASSWORD} ]]
do
	read -p "${LOG_START} Specify a Database Password: (Press Enter to accept current Test DB Password) ${LOG_END}" DB_PASSWORD
	if [[ -z ${DB_PASSWORD} ]]
	then
		DB_PASSWORD="<ADDME>"
	fi
done

MIGRATION_DB_PASSWORD=${DB_PASSWORD}
COIN_DB_PASSWORD=${DB_PASSWORD}
UPLOAD_DB_PASSWORD=${DB_PASSWORD}
export DB_PASSWORD MIGRATION_DB_PASSWORD COIN_DB_PASSWORD UPLOAD_DB_PASSWORD

if [[ ${CREATE_ENVIRONMENT} -eq 1 ]]
then
	echo ""
fi
}

function configureDatabaseUserPassword {
for DOCKERRUN_FILE in `find -type f -name "Dockerrun.aws.json"`
do
	sed -i "/DB_PASSWORD/{n;s/\(: \"\).*\(\"\)/\1${DB_PASSWORD}\2/;}" ${DOCKERRUN_FILE}
done
}

function getDBInfo {

#
# Below to Export Variables which will then be used when running the DB Migrations:
#

DB_USERNAME=$(jq -r '.containerDefinitions[] | select(.name == "api_common") | .environment[] | select(.name == "COMMON_DB_USERNAME") | .value' ${BEANSTALK_ARTEFACTS_DIR}/<APP-PREFIX>-app/Dockerrun.aws.json)
DB_PASSWORD=$(jq -r '.containerDefinitions[] | select(.name == "api_common") | .environment[] | select(.name == "COMMON_DB_PASSWORD") | .value' ${BEANSTALK_ARTEFACTS_DIR}/<APP-PREFIX>-app/Dockerrun.aws.json)
DATABASE_SUFFIX=$(jq -r '.containerDefinitions[] | select(.name == "api_common") | .environment[] | select(.name == "COMMON_DB_URL") | .value' ${BEANSTALK_ARTEFACTS_DIR}/<APP-PREFIX>-app/Dockerrun.aws.json | sed 's/\(.*\)\/\(.*\)_\(.*\)/\3/g')
TARGET_DB=$(jq -r '.containerDefinitions[] | select(.name == "api_common") | .environment[] | select(.name == "COMMON_DB_URL") | .value' ${BEANSTALK_ARTEFACTS_DIR}/<APP-PREFIX>-app/Dockerrun.aws.json | sed 's/\(.*\/\/\)\(.*\)\(\/.*\)/\2/g')

#
# Call below functions to have these VARs exported
#

getDatabaseSuffix
getDatabaseUserName
getDatabaseUserPassword

}

function configureDockerEnvironment {
	# This Function requires first parameter to be in the following format, example: api_stores:7d0649ad87d7c5698ea0fac78542ecd00bede8fa
	CONTAINER_STRING="$1"
	CONTAINER_NAME=${CONTAINER_STRING%%:*}
	CONTAINER_VERSION=${CONTAINER_STRING##*:}

	echo ${CONTAINER_STRING}

	for DOCKERRUN_FILE in `find -type f -name "Dockerrun.aws.json"`
	do
		sed -i "s/\(${CONTAINER_NAME}\):\(.*\)\(\",\)/\1:${CONTAINER_VERSION}\3/g" ${DOCKERRUN_FILE}
	done
}

function configureDockerFromSysengOrMannual {
until [[ ${CONFIGURE_OPTION} -eq 1 ]] || [[ ${CONFIGURE_OPTION} -eq 2 ]]
do
	read -p "${LOG_START} Configure Docker Environment - Valid Options: 1) for selecting the latest deployable build 2) for selecting own container versions ${LOG_END}" CONFIGURE_OPTION
	if [[ ${CONFIGURE_OPTION} -eq 1 ]]
	then
		echo -e "\nSetting the configuration to the following container versions: \n"
		for CONTAINER_NAME in $(mysql -sN -h ${SYSENG_DB_HOST} -u ${SYSENG_DB_USERNAME} -p"${SYSENG_DB_PASSWORD}" -D ${SYSENG_DB_NAME} -e "select appreg_TITLE from ${SYSENG_APPREG_TABLE_NAME};")
		do
			CONTAINER_VERSION=$(mysql -sN -h ${SYSENG_DB_HOST} -u ${SYSENG_DB_USERNAME} -p"${SYSENG_DB_PASSWORD}" -D ${SYSENG_DB_NAME} -e "SELECT cibuildreg_GIT_COMMIT FROM ${SYSENG_BUILDINFO_TABLE_NAME} WHERE cibuildreg_DOCKER_IMAGE = 1 AND cibuildreg_TITLE = '${CONTAINER_NAME}' ORDER BY cibuildreg_DT_CREATED DESC LIMIT 1;")
		done
	elif [[ ${CONFIGURE_OPTION} -eq 2 ]]
	then
		echo -e "\nPlease provide the following input: \n"
		for CONTAINER_NAME in $(mysql -sN -h ${SYSENG_DB_HOST} -u ${SYSENG_DB_USERNAME} -p"${SYSENG_DB_PASSWORD}" -D ${SYSENG_DB_NAME} -e "select appreg_TITLE from ${SYSENG_APPREG_TABLE_NAME};")
		do
			if [[ ${CONTAINER_NAME} =~ (api_projects|api_requests|api_stores|ui_web) ]]
			then
				continue
			fi
			read -p "Please provide git commit string for ${CONTAINER_NAME}: " CONTAINER_VERSION
			if [[ ${CONTAINER_NAME} == "api_common" ]]
			then
				for COMMON_APP in "${COMMON_CONTAINERS[@]}"
				do
					CONTAINER_STRING="${COMMON_APP}:${CONTAINER_VERSION}"
					configureDockerEnvironment "${CONTAINER_STRING}"
					unset CONTAINER_STRING
				done
				unset CONTAINER_NAME CONTAINER_VERSION
			else
				CONTAINER_STRING="${CONTAINER_NAME}:${CONTAINER_VERSION}"
				configureDockerEnvironment "${CONTAINER_STRING}"
				unset CONTAINER_STRING CONTAINER_NAME CONTAINER_VERSION
			fi
		done
	fi
done
}

function configureDockerFromExistingEnvironment {
while [[ -z ${SITE_INDEX} ]]
do
	read -p "${LOG_START} Specify the frontend environment the version to configure beanstalk environment with: (Valid options: dev/test/show) ${LOG_END}" ENVIRONMENT
	case $ENVIRONMENT in
		test)
			SITE_INDEX=2
		;;
		dev)
			SITE_INDEX=1
		;;
		show)
			SITE_INDEX=1
		;;
	esac
done

#
# Now SSH into one of task, img and app machines of the selected environment
#

DOCKER_HOSTS=( "syds${SITE_INDEX}${ENVIRONMENT}app01" "syds${SITE_INDEX}${ENVIRONMENT}task01" "syds${SITE_INDEX}${ENVIRONMENT}img01")

echo -e "\nSetting the configuration to the following container versions:\n"

for SSH_HOST in ${DOCKER_HOSTS[@]}
do
    for CONTAINER_STRING in `ssh ${SSH_HOST} 'sudo docker ps --format "{{.Image}}"' | sed 's/.*\///g'`
	do
		configureDockerEnvironment "${CONTAINER_STRING}"
		unset CONTAINER_STRING
	done
done
echo ""
}

function configureReverseProxy {
	echo -e "${LOG_START} Configuring Reverse Proxy URLs for the New Environment within ${RPROXY_APP_NAME} Docker Container ${LOG_END}\n"
	sed -i "s/\(http:\/\/<APP-PREFIX>-app\).*\\(\..*.elasticbeanstalk.com.*\)/\1-${BEANSTALK_ENVIRONMENT}\2/g" ${RPROXY_DOCKER_WORKDIR}/sites-available/*
	sed -i "s/\(http:\/\/<APP-PREFIX>-minions\).*\\(\..*.elasticbeanstalk.com.*\)/\1-${BEANSTALK_ENVIRONMENT}\2/g" ${RPROXY_DOCKER_WORKDIR}/sites-available/*
}

function buildDockerReverseProxy {
	echo -e "${LOG_START} Building New Publically Exposed Reverse Proxy Docker Container ${LOG_END}\n"
	sudo docker build --label ImageType="<APP-PREFIX>-rp" -t ${DOCKER_REGISTRY}/syseng/<APP-PREFIX>-rp:${UNIQUE_VERSION_ID} ${RPROXY_DOCKER_WORKDIR}/.
	echo "" 
}

function pushDockerReverseProxy {
	echo -e "${LOG_START} Pushing New Reverse Proxy Docker Container (<APP-PREFIX>-rp:${UNIQUE_VERSION_ID}) to Docker Registgry ${LOG_END}\n"
	sudo docker push ${DOCKER_REGISTRY}/syseng/<APP-PREFIX>-rp:${UNIQUE_VERSION_ID}
	
	#
	# Also delete the image locally
	#

	echo -e "\n${LOG_START} Deleting Images Locally ${LOG_END}\n"

	for DOCKER_IMAGE_ID in `sudo docker images --filter "LABEL=ImageType=<APP-PREFIX>-rp" --format "{{.ID}}"`
	do
		sudo docker rmi ${DOCKER_IMAGE_ID}
	done
	echo ""
}

function configureReverseProxyDockerTag {
	echo -e "${LOG_START} Configuring our environment ${BEANSTALK_ENVIRONMENT} to use Docker Image: (<APP-PREFIX>-rp:${UNIQUE_VERSION_ID}) for Reverse Proxy Layer ${LOG_END}"
	for DOCKERRUN_FILE in `find -type f -name "Dockerrun.aws.json"`
    do
        sed -i "s/\(<APP-PREFIX>-rp:\)\(.*\)\(\",\)/\1${UNIQUE_VERSION_ID}\3/g" ${DOCKERRUN_FILE}
    done
	echo ""
}

function prepareRoute53Entry {
echo -e "${LOG_START} Preparing new Route53 Entry ###\n"

# Modify Comment
sed -i "s/\(\"Comment\": \"\)\(.*\)\(\",\)/\1Adding Route53 Entry for environment ${BEANSTALK_ENVIRONMENT} for ${UNIQUE_VERSION_ID} on $(date -d @${EPOCH_TIME})\3/g" ${RUNNING_PATH}/${ROUTE53_JSON_FILENAME}

# Specify Name
sed -i "s/\(\"Name\": \"\)\(.*\)\(\",\)/\1beanstalk-ui-${UNIQUE_VERSION_ID}.<ADDME>.com.\3/g" ${RUNNING_PATH}/${ROUTE53_JSON_FILENAME}

# Specify Value
PUBLIC_ENDPOINT="${RPROXY_APP_NAME}-${BEANSTALK_ENVIRONMENT}.ap-southeast-2.elasticbeanstalk.com." 
sed -i "s/\(\"Value\": \"\)\(.*\)\(\"\)/\1${PUBLIC_ENDPOINT}\3/g" ${RUNNING_PATH}/${ROUTE53_JSON_FILENAME}
}

function DBDeploy {
if [[ ${#DB_DEPLOY_COMPONENTS[@]} -eq 0 ]]
then
	echo -e "${LOG_START} No DB Migrations need to be deployed ${LOG_END}\n"
else
	rm -rf ${DB_DEPLOY_WORKDIR}/*
	echo -e "${LOG_START} Deploying DB Migrations ${LOG_END}\n"
	for COMPONENT in "${DB_DEPLOY_COMPONENTS[@]}"
	do
		COMPONENT_NAME=${COMPONENT%%:*}
    	COMPONENT_VERSION=${COMPONENT##*:}
		
		if [[ ${COMPONENT_NAME} == "api_common" ]]
		then
			DB_DEPLOY_NAME="db_migrations"
			AF_REPO_NAME="SysEng"
			FILE_TYPE="tgz"
		else
			DB_DEPLOY_NAME="${COMPONENT_NAME}"
			AF_REPO_NAME="release"
			FILE_TYPE="jar"
		fi
	
		#
		# Debugging
		#
		
		#echo "${DB_DEPLOY_NAME}:${COMPONENT_VERSION} needs to be migrated"
	
		#
		# Downloading Artefacts from Artifactory
		#

		DOWNLOAD_FILENAME="${DB_DEPLOY_NAME}_${COMPONENT_VERSION}.${FILE_TYPE}"
		curl -s ${AF_URL}/${AF_REPO_NAME}/${DB_DEPLOY_NAME}/${DOWNLOAD_FILENAME} -o ${DB_DEPLOY_WORKDIR}/${DOWNLOAD_FILENAME}
	
		if [[ ${FILE_TYPE} == "tgz" ]]
		then
			tar xzf ${DB_DEPLOY_WORKDIR}/${DOWNLOAD_FILENAME} -C ${DB_DEPLOY_WORKDIR}
			if [[ $? -eq 0 ]]
			then
				JAR_FILE=$(find ${DB_DEPLOY_WORKDIR}/${DB_DEPLOY_NAME} -type f -name "*.jar")
				CONFIG_FILE=$(find ${DB_DEPLOY_WORKDIR}/${DB_DEPLOY_NAME} -type f -name "db-migrations-config.yml")
				EXECUTION="java -jar ${JAR_FILE} db migrate ${CONFIG_FILE}"
				echo -e "${LOG_START} Executing: ${EXECUTION} ${LOG_END}\n"
				${EXECUTION}
				if [[ $? -ne 0 ]]
				then
					echo "CRITICAL: Execution of ${JAR_FILE} failed. Aborting deployment!"
					rm -rf ${DB_DEPLOY_WORKDIR}/*
					exit 1
				else
					java -jar ${JAR_FILE} db status ${CONFIG_FILE}
				fi
			else
				echo "CRITICAL: Extraction of ${DOWNLOAD_FILENAME} failed. Aborting deployment!"
				scriptExitGraceful
			fi
		elif [[ ${FILE_TYPE} == "jar" ]]
		then
				JAR_FILE=$(find ${DB_DEPLOY_WORKDIR} -maxdepth 1 -type f -name "${DB_DEPLOY_NAME}*.jar")
				case ${DB_DEPLOY_NAME} in
				"api_coin")
					echo ""
					EXECUTION="java -jar ${JAR_FILE} db migrate"
					echo -e "${LOG_START} Executing: ${EXECUTION} ${LOG_END}\n"
					${EXECUTION}
					if [[ $? -ne 0 ]]
					then
						echo "CRITICAL: Execution of ${JAR_FILE} failed. Aborting deployment!"
						scriptExitGraceful
					fi
				;;
				"minions")
					echo ""
					EXECUTION="java -jar ${JAR_FILE} db-update"
					echo -e "${LOG_START} Executing: ${EXECUTION} ${LOG_END}\n"
					${EXECUTION}
					if [[ $? -ne 0 ]]
					then
						echo "CRITICAL: Execution of ${JAR_FILE} failed. Aborting deployment!"
						scriptExitGraceful
					fi
				;;
				*)
					echo -e "I Don't Know how to deal with ${DB_DEPLOY_NAME}, please configure appropriately. Aborting!!!"
					scriptExitGraceful
				;;
				esac
		fi

	done
fi
echo ""
}

function identifyDBDeploy {
DB_DEPLOY_COMPONENTS=()

if [[ ${CREATE_ENVIRONMENT} -eq 1 ]]
then
	DIFF_BRANCH="origin/master"
else
	DIFF_BRANCH="origin/${CHECKED_OUT_BRANCH}"
fi

#
# Identify Which of the DB Deploy components need to run based on the changes
#

for COMPONENT in $(git diff ${DIFF_BRANCH} | grep "${DOCKER_REGISTRY}" | grep '^+' | grep -iwE "${DB_COMPONENTS}" | sed 's/.*\///g;s/",$//g')
do
	DB_DEPLOY_COMPONENTS+=("${COMPONENT}")
done
}

function scriptExitGraceful {
CHECKED_OUT_BRANCH="$(git status | head -n1 | awk '{print $NF}')"
cp $0 /tmp
git checkout -q master
if [[ ${CHECKED_OUT_BRANCH} != "master" ]]
then
	git branch -D ${CHECKED_OUT_BRANCH}
fi
git reset -q --hard
mv /tmp/$0 .
exit 1
}
function verifyGitChanges {
read -p "${LOG_START} Press Enter to verify local git changes ${LOG_END}" RUBBISH
git diff origin/master | less

until [[ ${RESPONSE} =~ [yn] ]]
do
	if [[ ${RESPONSE} == "n" ]]
	then
		scriptExitGraceful
	elif [[ ${RESPONSE} == "y" ]]
	then
		break
	fi
	echo ""
	read -p "${LOG_START} Continue Deployment (y/n)? ${LOG_END}" RESPONSE
done
echo ""
}

function verifyBranchGitChanges {
read -p "${LOG_START} Press Enter to verify local git changes ${LOG_END}" RUBBISH
git diff | less
sleep 0.3
APPS_NEEDING_REDEPLOY=()
for CHANGED_APP in $(git diff --numstat | grep Dockerrun.aws | awk '{print $NF}' | awk -F '/' '{print $2}')
do
	APPS_NEEDING_REDEPLOY+=("${CHANGED_APP}")
done
echo ""
}

function commitToGit {
while [[ -z ${ANSWER} ]]
do
	echo -e "${LOG_START} Changes will be commited to ${BEANSTALK_ENVIRONMENT} branch on $(git config -l | grep remote.origin.url | sed 's/.*://g'), MUST answer 'y' if deployment was successful - are you sure you want to continue (y/n)? ${LOG_END}"
	read ANSWER
	if [[ ${ANSWER} =~ [Yy] ]]
	then
		git add ${RUNNING_PATH}/*
		git commit -am "Configuring Beanstalk Environment \"${BEANSTALK_ENVIRONMENT}\" to inherit from \"${ENVIRONMENT}\" on $(date)"
		git push origin ${BEANSTALK_ENVIRONMENT}
	elif [[ ${ANSWER} =~ [Nn] ]]
	then
		scriptExitGraceful
	fi
done
echo ""
}

function commitBranchToGit {
while [[ -z ${ANSWER} ]]
do
	echo -e "${LOG_START} Changes will be commited to ${BEANSTALK_ENVIRONMENT} branch on $(git config -l | grep remote.origin.url | sed 's/.*://g'), MUST answer 'y' if modification was successful - are you sure you want to continue (y/n)? ${LOG_END}"
	read ANSWER
	if [[ ${ANSWER} =~ [Yy] ]]
	then
		git add ${RUNNING_PATH}/*
		git commit -am "Modifying Beanstalk Environment \"${BEANSTALK_ENVIRONMENT}\" on $(date)"
		git push origin ${BEANSTALK_ENVIRONMENT}
	elif [[ ${ANSWER} =~ [Nn] ]]
	then
		scriptExitGraceful
	fi
done
echo ""
}

function createZip {
echo -e "${LOG_START} Creating Beanstalk Aretefacts Zip Files ${LOG_END}"
find . -type f -name "*.zip" -delete
cd ${BEANSTALK_ARTEFACTS_HOME}
for APPLICATION in `find * -type d -iname "<APP-PREFIX>-*"`
do
	if [[ ${CREATE_ENVIRONMENT} -eq 1 ]] || [[ ${APP_NAME} != "${RPROXY_APP_NAME}" ]]
	then
		cd ${APPLICATION}
		zip -q ${APPLICATION}_${UNIQUE_VERSION_ID}.zip -r * .[^.]*
		cd ${BEANSTALK_ARTEFACTS_HOME}
	fi
done
echo ""
}

function uploadZipToS3 {
cd ${BEANSTALK_ARTEFACTS_HOME}
echo -e "${LOG_START} Uploading Artefacts Zip files to S3 ${LOG_END}\n"

for APPLICATION in `find * -type d -iname "<APP-PREFIX>-*"`
do
	if [[ ${CREATE_ENVIRONMENT} -eq 1 ]] || [[ ${APP_NAME} != "${RPROXY_APP_NAME}" ]]
	then
		cd ${APPLICATION}
		aws s3 cp ${APPLICATION}_${UNIQUE_VERSION_ID}.zip s3://${S3_BUCKET_NAME}/${APPLICATION}_${UNIQUE_VERSION_ID}.zip
		cd ${BEANSTALK_ARTEFACTS_HOME}
	fi
done

cd ${RUNNING_PATH}
echo ""
}

function prepareEachApplicationInAWS {
APP_NAME="$1"
if [[ ${CREATE_ENVIRONMENT} -eq 1 ]] || [[ ${APP_NAME} != "${RPROXY_APP_NAME}" ]]
then
	echo -e "${LOG_START} Preparing New ${APP_NAME} Application Version in AWS Beanstalk ${LOG_END}\n"
	aws elasticbeanstalk create-application-version --application-name "${APP_NAME}" --version-label "${UNIQUE_VERSION_ID}" --description "Version \"${UNIQUE_VERSION_ID}\" created for ${BEANSTALK_ENVIRONMENT} environment on $(date -d @${EPOCH_TIME})" --source-bundle S3Bucket="${S3_BUCKET_NAME}",S3Key="${APP_NAME}_${UNIQUE_VERSION_ID}.zip" --process --auto-create-application > /dev/null
	until [[ ${STATUS} == "PROCESSED" ]]
	do
		STATUS=$(aws elasticbeanstalk describe-application-versions | jq -r ".ApplicationVersions[] | select (.ApplicationName == \"${APP_NAME}\" and .VersionLabel == \"${UNIQUE_VERSION_ID}\") | .Status")
		echo "Application Version Provisioning status is: ${STATUS}"
	done
	unset STATUS
	echo ""
fi
}

function prepareApplicationAWS {
cd ${BEANSTALK_ARTEFACTS_HOME}
for APPLICATION in `find * -type d -iname "<APP-PREFIX>-*"`
do
	prepareEachApplicationInAWS "${APPLICATION}"
done
cd ${RUNNING_PATH}
}

function modifyEachEnvironmentAWS {
APP_NAME="$1"
BEANSTALK_APP_ENV_NAME="${APP_NAME}-${BEANSTALK_ENVIRONMENT}"
echo -e "${LOG_START} Provisioning new application version (${UNIQUE_VERSION_ID}) to \"${BEANSTALK_ENVIRONMENT}\" environment for \"${APP_NAME}\" application in AWS Beanstalk ${LOG_END}"
aws elasticbeanstalk update-environment --application-name ${APP_NAME} --environment-name ${BEANSTALK_APP_ENV_NAME} --version-label "${UNIQUE_VERSION_ID}" --solution-stack-name "${AWS_SOLUTION_STACK}" > /dev/null
echo ""
}

function modifyEnvironmentAWS {
for APPLICATION in "${APPS_NEEDING_REDEPLOY[@]}"
do
	modifyEachEnvironmentAWS "${APPLICATION}"
done
}

function deployEachEnvironmentAWS {
APP_NAME="$1"
echo -e "${LOG_START} Provisioning new application version (${UNIQUE_VERSION_ID}) to \"${BEANSTALK_ENVIRONMENT}\" environment for \"${APP_NAME}\" application in AWS Beanstalk ${LOG_END}"
BEANSTALK_APP_ENV_NAME="${APP_NAME}-${BEANSTALK_ENVIRONMENT}"
aws elasticbeanstalk create-environment --application-name ${APP_NAME} --environment-name ${BEANSTALK_APP_ENV_NAME} --cname-prefix "${BEANSTALK_APP_ENV_NAME}" --version-label "${UNIQUE_VERSION_ID}" --solution-stack-name "${AWS_SOLUTION_STACK}" > /dev/null
echo ""
}

function deployEnvironmentAWSExceptRproxy {
cd ${BEANSTALK_ARTEFACTS_HOME}
for APPLICATION in `find * -type d -iname "<APP-PREFIX>-*" -and -not -iname "${RPROXY_APP_NAME}"`
do
	deployEachEnvironmentAWS "${APPLICATION}"
done
cd ${RUNNING_PATH}
}

function deployEnvironmentAWSRproxy {
echo -e "\n"
APPLICATION="${RPROXY_APP_NAME}"
deployEachEnvironmentAWS "${APPLICATION}"
}

function watchEnvironmentDeploymentStatusAWS {
echo -e "${LOG_START} Watch Provisioning Status in AWS (Update is provided roughly every 30 seconds) ${LOG_END}"
cd ${BEANSTALK_ARTEFACTS_HOME}
APPLICATION_COUNT=$(find * -type d -iname "<APP-PREFIX>-*" | wc -l)
while true
do
	unset GOOD_APPS
	let LOOPCOUNT=LOOPCOUNT+1
	if [[ ${LOOPCOUNT} -eq 10 ]] && [[ ${CREATE_ENVIRONMENT} -eq 1 ]]
	then
		# Approximately after 10*30 seconds  - 5 minutes (deploy the reverse proxy) as it depends on other components
		# to be deployed successfully and available. This can be changed in the future to query the health status
		# instead of waiting for a fixed amount of time
		deployEnvironmentAWSRproxy
	fi
	echo -e "\nDeployment Status as at: $(date):\n"
	for APPLICATION in `find * -type d -iname "<APP-PREFIX>-*"`
	do
		unset STATUS HEALTH
		BEANSTALK_APP_ENV_NAME="${APPLICATION}-${BEANSTALK_ENVIRONMENT}"
		
		#STATUS=$(aws elasticbeanstalk describe-environments --environment-name "${BEANSTALK_APP_ENV_NAME}" | jq -r ".Environments[] | select (.ApplicationName == \"${APPLICATION}\" and .VersionLabel == \"${UNIQUE_VERSION_ID}\" and .Status != \"Terminated\") | .Status")
		#HEALTH=$(aws elasticbeanstalk describe-environments --environment-name "${BEANSTALK_APP_ENV_NAME}" | jq -r ".Environments[] | select (.ApplicationName == \"${APPLICATION}\" and .VersionLabel == \"${UNIQUE_VERSION_ID}\" and .Status != \"Terminated\") | .Health")

		STATUS=$(aws elasticbeanstalk describe-environments --environment-name "${BEANSTALK_APP_ENV_NAME}" | jq -r ".Environments[] | select (.ApplicationName == \"${APPLICATION}\" and .Status != \"Terminated\") | .Status")
		HEALTH=$(aws elasticbeanstalk describe-environments --environment-name "${BEANSTALK_APP_ENV_NAME}" | jq -r ".Environments[] | select (.ApplicationName == \"${APPLICATION}\" and .Status != \"Terminated\") | .Health")
		
		if [[ -z ${STATUS} ]]
		hen
			STATUS="Processing"
		fi

		if [[ -z ${HEALTH} ]]
		then
			HEALTH="Not Available"
		fi

		case $HEALTH in
			"Green")
				HEALTH_STRING="$(${GREEN})${HEALTH}$(${COLOR_RESET})"
			;;
			"Yellow")
				HEALTH_STRING="$(${YELLOW})${HEALTH}$(${COLOR_RESET})"
			;;
			"Red")
				HEALTH_STRING="$(${RED})${HEALTH}$(${COLOR_RESET})"
			;;
			*)
				HEALTH_STRING="$(${GREY})${HEALTH}$(${COLOR_RESET})"	
			;;
		esac
		if [[ ${CREATE_ENVIRONMENT} -eq 1 ]]
		then
			echo -e "Deployment status for ${APPLICATION} of Environment-Version ${UNIQUE_VERSION_ID} is: ${STATUS} and Health is: ${HEALTH_STRING}"
		else
			echo -e "Deployment status for ${APPLICATION} is: ${STATUS} and Health is: ${HEALTH_STRING}"
		fi

		if [[ ${STATUS} == "Ready" && ${HEALTH} == "Green" ]]
		then
			let GOOD_APPS=GOOD_APPS+1
		fi

		if [[ ${LOOPCOUNT} -eq 40 ]]
		then
			echo -e "\nDeployment Aborted/Failed.\n"
			scriptExitGraceful
		fi

		if [[ ${GOOD_APPS} -eq ${APPLICATION_COUNT} ]]
		then
			echo -e "\n-----------------\n\n${LOG_START} Deployment Successfully Completed Final Environment Configuration ${LOG_END}\n"
			if [[ ${CREATE_ENVIRONMENT} -eq 1 ]]
			then
				echo -e "Configuring the following DNS Name:"
				echo -e "beanstalk-ui-${UNIQUE_VERSION_ID}.<ADDME>.com. IN CNAME ${PUBLIC_ENDPOINT}\n"
				aws route53 change-resource-record-sets --hosted-zone-id Z1NZATSON28YZY --change-batch file://${RUNNING_PATH}/${ROUTE53_JSON_FILENAME} > /dev/null
				if [[ $? -eq 0 ]]
				then
					echo -e "Application can be accessed from: https://beanstalk-ui-${UNIQUE_VERSION_ID}.<ADDME>.com - give a couple of minutes for the DNS changes to propagate.\n"
					break 2
				fi
			else
				echo -e "Updated application stack accessible via the same URL as before.\n"
				break 2
			fi
		fi
	done
	sleep 30
done
}

