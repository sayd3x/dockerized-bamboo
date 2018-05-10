Dockerized bamboo images (server + agent)

The scripts aimed to run your own copy of the Bamboo Server in Docker environment. It was built on top of the archlinux base image and installs tools for building Android apps.

Put downloaded version of the Bamboo Server(for instance: atlassian-bamboo-6.4.1.tar.gz) in the project directory, adjust Android SDK packages to install in the android.packages file and run "docker-compose run".
