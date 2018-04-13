############
# Base image
############
FROM base/archlinux:latest AS bamboo_base

ENV BAMBOO_VER 6.4.1
ENV CRYSTAX_NDK_VER 10.3.2
ENV ANDROID_NDK_VER r16b

ENV ANDROID_SDK_ROOT /opt/android-sdk
ENV CRYSTAX_NDK_ROOT /opt/crystax-ndk-${CRYSTAX_NDK_VER}
ENV NDK_ROOT /opt/android-ndk-${ANDROID_NDK_VER}

ADD ./mirrorlist /etc/pacman.d/

RUN useradd -m bamboo \
	&& pacman -Sy --noconfirm base-devel unzip mercurial git subversion \
	# Intall the yaourt tool \
	&& (cp /etc/sudoers /etc/sudoers.bak;echo 'ALL ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers) \
	&& sudo -u nobody mkdir /tmp/yaourt \
	&& (cd /tmp/yaourt;curl https://aur.archlinux.org/cgit/aur.git/snapshot/package-query.tar.gz | sudo -u nobody tar xzf -;cd ./package-query;sudo -u nobody makepkg -si --noconfirm) \
	&& (cd /tmp/yaourt;curl https://aur.archlinux.org/cgit/aur.git/snapshot/yaourt.tar.gz | sudo -u nobody tar xzf -;cd ./yaourt;sudo -u nobody makepkg -si --noconfirm) \
	&& rm -rf /tmp/yaourt \
	# Install jdk \
	&& sudo -u nobody yaourt -S --noconfirm jdk8 \
	&& pacman -Rcs --noconfirm yaourt package-query \
	&& cp /etc/sudoers.bak /etc/sudoers \
	&& rm -rf /var/cache/pacman/*

COPY android.packages /opt

RUN mkdir /opt/android-sdk \
	#&& (cd /opt/android-sdk;curl -O -L https://dl.google.com/android/repository/sdk-tools-linux-3859397.zip;unzip *.zip;rm -f *.zip) \
	#&& (cd /opt;curl -O -L https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VER}-linux-x86_64.zip;unzip *.zip;rm -f *.zip) \
	#&& curl -O -L https://www.crystax.net/download/crystax-ndk-${CRYSTAX_NDK_VER}-linux-x86_64.tar.xz | tar xzf - -C /opt \
	#&& yes | $ANDROID_SDK_ROOT/tools/bin/sdkmanager --package_file=/opt/android.packages \
	&& chown -R bamboo:bamboo /opt/*

#####################
# Bamboo Server Image
#####################
FROM bamboo_base AS bamboo_server

ENV BAMBOO_ROOT /opt/atlassian-bamboo-$BAMBOO_VER

ADD atlassian-bamboo-6.4.1.tar.gz /opt
ADD bamboo-init.properties /opt/atlassian-bamboo-6.4.1/atlassian-bamboo/WEB-INF/classes

RUN (chown -R bamboo:bamboo $BAMBOO_ROOT;rm -rf $BAMBOO_ROOT/logs;ln -s /home/bamboo/bamboo-logs $BAMBOO_ROOT/logs)

VOLUME /home/bamboo

USER bamboo
EXPOSE 8085

ENTRYPOINT /opt/atlassian-bamboo-${BAMBOO_VER}/bin/start-bamboo.sh -fg

####################
# Bamboo Agent Image
####################
FROM bamboo_base AS bamboo_agent

ARG AGENT_URL=http://bamboo-host:8085/agentServer/

COPY --from=bamboo_server /opt/atlassian-bamboo-${BAMBOO_VER}/atlassian-bamboo/admin/agent/bamboo-agent-${BAMBOO_VER}.jar /opt

USER bamboo

VOLUME /home/bamboo

WORKDIR /opt
ENTRYPOINT java -Dbamboo.home=/home/bamboo/bamboo-home -jar bamboo-agent-${BAMBOO_VER}.jar $AGENT_URL
