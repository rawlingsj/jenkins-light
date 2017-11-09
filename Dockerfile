FROM centos:centos7

RUN yum install -y git tar zip unzip java-1.8.0-openjdk java-1.8.0-openjdk.i686 java-1.8.0-openjdk-devel java-1.8.0-openjdk-devel.i686
COPY jenkins.war /usr/lib/jenkins/jenkins.war
COPY run.sh /usr/lib/jenkins/run.sh
RUN chmod +x /usr/lib/jenkins/run.sh

CMD /usr/lib/jenkins/run.sh
