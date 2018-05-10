############
# Base image
############
FROM base/archlinux:latest AS bamboo_base

ARG GRADLE_VER=3.3
ARG CRYSTAX_NDK_VER=10.3.2
ARG ANDROID_NDK_VER=r16b
ARG BAMBOO_VER=6.4.1

ENV ANDROID_HOME /opt/android-sdk
ENV ANDROID_SDK_ROOT /opt/android-sdk
ENV CRYSTAX_NDK_ROOT /opt/crystax-ndk-${CRYSTAX_NDK_VER}
ENV NDK_ROOT /opt/android-ndk-${ANDROID_NDK_VER}

ADD ./mirrorlist /etc/pacman.d/
ADD ./locale.gen /etc/locale.gen

RUN locale-gen \
	&& useradd -m bamboo \
	&& echo -e "[multilib]\nInclude = /etc/pacman.d/mirrorlist\n[bpiotrowski]\nServer = https://pkgbuild.com/~bpiotrowski/repo" >> /etc/pacman.conf \
	&& pacman -Sy --noconfirm base-devel unzip mercurial git subversion openssh aria2 python2 python2-pip cifs-utils zip libpng12 libpng lib32-glibc lib32-gcc-libs freeimage ncurses5-compat-libs jshon \
	&& pip2 install mercurial_keyring Pillow xlrd openpyxl \
	# Intall the yaourt tool \
	&& (cp /etc/sudoers /etc/sudoers.bak;echo 'ALL ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers) \
	&& sudo -u nobody mkdir /tmp/yaourt \
	&& (cd /tmp/yaourt;curl https://aur.archlinux.org/cgit/aur.git/snapshot/package-query.tar.gz | sudo -u nobody tar xzf -;cd ./package-query;sudo -u nobody makepkg -si --noconfirm) \
	&& (cd /tmp/yaourt;curl https://aur.archlinux.org/cgit/aur.git/snapshot/yaourt.tar.gz | sudo -u nobody tar xzf -;cd ./yaourt;sudo -u nobody makepkg -si --noconfirm) \
	&& rm -rf /tmp/yaourt \
	# Install jdk \
	&& sudo -u nobody yaourt -S --noconfirm jdk8 ncurses5-compat-libs \
	&& pacman -Rcs --noconfirm yaourt package-query \
	&& cp /etc/sudoers.bak /etc/sudoers \
	&& rm -rf /var/cache/pacman/* \
	&& chown bamboo:bamboo /opt

USER bamboo

COPY android.packages /opt

RUN	mkdir /opt/android-sdk \
	&& (cd /opt/android-sdk;curl -O -L https://dl.google.com/android/repository/sdk-tools-linux-3859397.zip;unzip *.zip;rm -f *.zip)

RUN	yes | $ANDROID_SDK_ROOT/tools/bin/sdkmanager --package_file=/opt/android.packages

RUN	(cd /opt;curl -O -L https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VER}-linux-x86_64.zip;unzip *.zip;rm -f *.zip)

RUN	(cd /opt;aria2c --max-connection-per-server=10 --async-dns=false https://www.crystax.net/download/crystax-ndk-${CRYSTAX_NDK_VER}-linux-x86_64.tar.xz;tar xJfv *.tar.xz;rm -f *.tar.xz)

RUN	(cd /opt;aria2c --max-connection-per-server=10 --async-dns=false https://downloads.gradle.org/distributions/gradle-${GRADLE_VER}-bin.zip;unzip *.zip;rm -f *.zip)

ENV PATH /opt/gradle-${GRADLE_VER}/bin:/home/bamboo/buildserver/bin:$PATH
ENV BAMBOO_VERSION $BAMBOO_VER
USER root

#####################
# Bamboo Server Image
#####################
FROM bamboo_base AS bamboo_server

ENV BAMBOO_ROOT /opt/atlassian-bamboo-$BAMBOO_VERSION

ADD atlassian-bamboo-${BAMBOO_VERSION}.tar.gz /opt
ADD bamboo-init.properties /opt/atlassian-bamboo-${BAMBOO_VERSION}/atlassian-bamboo/WEB-INF/classes

RUN	(chown -R bamboo:bamboo $BAMBOO_ROOT;rm -rf $BAMBOO_ROOT/logs;ln -s /home/bamboo/bamboo-logs $BAMBOO_ROOT/logs)

VOLUME /home/bamboo

USER bamboo
EXPOSE 8085

ENTRYPOINT /opt/atlassian-bamboo-${BAMBOO_VERSION}/bin/start-bamboo.sh -fg

####################
# Bamboo Agent Image
####################
FROM bamboo_base AS bamboo_agent

ARG AGENT_URL=http://bamboo-host:8085/agentServer/

USER bamboo

COPY --from=bamboo_server /opt/atlassian-bamboo-${BAMBOO_VERSION}/atlassian-bamboo/admin/agent/bamboo-agent-${BAMBOO_VERSION}.jar /opt

VOLUME /home/bamboo

ENV BAMBOO_AGENT_URL $AGENT_URL
WORKDIR /opt
ENTRYPOINT java -Dbamboo.home=/home/bamboo/bamboo-home -jar bamboo-agent-${BAMBOO_VERSION}.jar $BAMBOO_AGENT_URL
