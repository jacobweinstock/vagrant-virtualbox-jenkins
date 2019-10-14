#!/usr/bin/env bash

LOG_FILE=/var/log/setup.log

echo -e "update docker perms for jenkins..."
usermod -aG docker jenkins
usermod -aG root jenkins
echo -e "done."

echo "updating jenkins..."
sed -i '/^JAVA_ARGS=/ s/"$/ -Djenkins.install.runSetupWizard=false"/' /etc/default/jenkins
mkdir -p /var/lib/jenkins/init.groovy.d/
chown jenkins:jenkins /var/lib/jenkins/init.groovy.d
touch /var/lib/jenkins/init.groovy.d/init.groovy
chown jenkins:jenkins /var/lib/jenkins/init.groovy.d/init.groovy
user=$(yq r /tmp/local/config.yaml 'jenkins_admin_username')
password=$(yq r /tmp/local/config.yaml 'jenkins_admin_password')
echo -e "#!groovy

import hudson.security.*
import hudson.security.csrf.*
import jenkins.model.*
import jenkins.security.s2m.AdminWhitelistRule
import org.jenkinsci.plugins.*
import org.jenkinsci.plugins.saml.*


def jenkins = Jenkins.getInstance()
jenkins.getInjector().getInstance(AdminWhitelistRule.class).setMasterKillSwitch(false)

def realm = new HudsonPrivateSecurityRealm(false)
jenkins.setSecurityRealm(realm)

def strategy = new hudson.security.FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
jenkins.setAuthorizationStrategy(strategy)
jenkins.save()

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount('$user', '$password')
Jenkins.instance.setSecurityRealm(hudsonRealm)
def strategy1 = new FullControlOnceLoggedInAuthorizationStrategy()
strategy1.setAllowAnonymousRead(false)
Jenkins.instance.setAuthorizationStrategy(strategy1)
Jenkins.instance.save()

" > /var/lib/jenkins/init.groovy.d/init.groovy
echo -e "done."

echo "restarting jenkins..."
systemctl restart jenkins
echo -e "done."

echo -e "installing plugins..." | tee -a $LOG_FILE
for plugin in $(yq r /tmp/local/config.yaml 'plugins'); do

    NEXT_WAIT_TIME=0
    until java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin install-plugin $plugin >> $LOG_FILE 2>&1 || [ $NEXT_WAIT_TIME -eq 5 ]; do
    sleep $(( NEXT_WAIT_TIME++ ))
    done

done
echo -e "done." | tee -a $LOG_FILE
systemctl restart jenkins

echo -e "loading pipeline job..." | tee -a $LOG_FILE
app_name=$(yq r /tmp/local/config.yaml 'job_name')
cp -a /tmp/local/job.xml /tmp/job.xml
sed -i "s;<remote>/src/app</remote>;<remote>/src/$app_name</remote>;" /tmp/job.xml 
NEXT_WAIT_TIME=0
until java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin create-job ${app_name} < /tmp/job.xml >> $LOG_FILE 2>&1 || [ $NEXT_WAIT_TIME -eq 5 ]; do
    sleep $(( NEXT_WAIT_TIME++ ))
done
echo -e "done." | tee -a $LOG_FILE

echo -e "scan multibranch pipeline now for ${app_name}..." | tee -a $LOG_FILE
# this does a "scan multibranch pipeline now" but doesn't allow any builds to run

NEXT_WAIT_TIME=0
until java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin who-am-i >> $LOG_FILE 2>&1 || [ $NEXT_WAIT_TIME -eq 3 ]; do
    sleep $(( NEXT_WAIT_TIME++ ))
done
curl -s http://localhost:8080/git/notifyCommit?url=/src/${app_name} >> $LOG_FILE 2>&1
java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin quiet-down
sleep 3
java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin clear-queue
java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin cancel-quiet-down

echo -e "done." | tee -a $LOG_FILE
