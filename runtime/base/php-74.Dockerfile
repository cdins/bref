# The container we build here contains everything needed to compile PHP + PHP.
#
# It can be used as a base to compile extra extensions.

# PHP Build
# https://github.com/php/php-src/releases
# Needs:
#   - zlib
#   - libxml2
#   - openssl
#   - readline
#   - sodium

FROM bref/tmp/step-1/build-environment as build-environment


###############################################################################
# Oniguruma
# This library is not packaged in PHP since PHP 7.4.
# See https://github.com/php/php-src/blob/43dc7da8e3719d3e89bd8ec15ebb13f997bbbaa9/UPGRADING#L578-L581
# We do not install the system version because I didn't manage to make it work...
# Ideally we shouldn't compile it ourselves.
# https://github.com/kkos/oniguruma/releases
# Needed by:
#   - php mbstring
ENV VERSION_ONIG=6.9.8
ENV ONIG_BUILD_DIR=${BUILD_DIR}/oniguruma
RUN set -xe; \
    mkdir -p ${ONIG_BUILD_DIR}; \
    curl -Ls https://github.com/kkos/oniguruma/releases/download/v${VERSION_ONIG}/onig-${VERSION_ONIG}.tar.gz \
    | tar xzC ${ONIG_BUILD_DIR} --strip-components=1
WORKDIR  ${ONIG_BUILD_DIR}/
RUN set -xe; \
    ./configure --prefix=${INSTALL_DIR}; \
    make -j $(nproc); \
    make install


ENV VERSION_PHP=7.4.33


ENV PHP_BUILD_DIR=${BUILD_DIR}/php
RUN set -xe; \
    mkdir -p ${PHP_BUILD_DIR}; \
    # Download and upack the source code
    # --location will follow redirects
    # --silent will hide the progress, but also the errors: we restore error messages with --show-error
    # --fail makes sure that curl returns an error instead of fetching the 404 page
    curl --location --silent --show-error --fail https://www.php.net/get/php-${VERSION_PHP}.tar.gz/from/this/mirror \
  | tar xzC ${PHP_BUILD_DIR} --strip-components=1
# Move into the unpackaged code directory
WORKDIR  ${PHP_BUILD_DIR}/

# Configure the build
# -fstack-protector-strong : Be paranoid about stack overflows
# -fpic : Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# -fpie : Support Address Space Layout Randomization (see -fpic)
# -O3 : Optimize for fastest binaries possible.
# -I : Add the path to the list of directories to be searched for header files during preprocessing.
# --enable-option-checking=fatal: make sure invalid --configure-flags are fatal errors instead of just warnings
# --enable-ftp: because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
# --enable-mbstring: because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
# --with-zlib and --with-zlib-dir: See https://stackoverflow.com/a/42978649/245552
# --with-pear: necessary for `pecl` to work (to install PHP extensions)
#
RUN set -xe \
 && ./buildconf --force \
 && CFLAGS="-fstack-protector-strong -fpic -fpie -O3 -I${INSTALL_DIR}/include -I/usr/include -ffunction-sections -fdata-sections" \
    CPPFLAGS="-fstack-protector-strong -fpic -fpie -O3 -I${INSTALL_DIR}/include -I/usr/include -ffunction-sections -fdata-sections" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib -Wl,-O1 -Wl,--strip-all -Wl,--hash-style=both -pie" \
    ./configure \
        --build=x86_64-pc-linux-gnu \
        --prefix=${INSTALL_DIR} \
        --enable-option-checking=fatal \
        --enable-sockets \
        --with-config-file-path=${INSTALL_DIR}/etc/php \
        --with-config-file-scan-dir=${INSTALL_DIR}/etc/php/conf.d:/var/task/php/conf.d \
        --enable-fpm \
        --disable-cgi \
        --enable-cli \
        --disable-phpdbg \
        --disable-phpdbg-webhelper \
        --with-sodium \
        --with-readline \
        --with-openssl \
        --with-zlib=${INSTALL_DIR} \
        --with-zlib-dir=${INSTALL_DIR} \
        --with-curl \
        --enable-exif \
        --enable-ftp \
        --with-gettext \
        --enable-mbstring \
        --with-pdo-mysql=shared,mysqlnd \
        --with-mysqli \
        --enable-pcntl \
        --with-zip \
        --enable-bcmath \
        --with-pdo-pgsql=shared,${INSTALL_DIR} \
        --enable-intl=shared \
        --enable-soap \
        --with-xsl=${INSTALL_DIR} \
        --with-pear
RUN make -j $(nproc)
# Run `make install` and override PEAR's PHAR URL because pear.php.net is down
RUN set -xe; \
 make install PEAR_INSTALLER_URL='https://github.com/pear/pearweb_phars/raw/master/install-pear-nozlib.phar'; \
 { find ${INSTALL_DIR}/bin ${INSTALL_DIR}/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; }; \
 make clean; \
 cp php.ini-production ${INSTALL_DIR}/etc/php/php.ini

# Symlink all our binaries into /opt/bin so that Lambda sees them in the path.
RUN mkdir -p /opt/bin \
    && cd /opt/bin \
    && ln -s ../bref/bin/* . \
    && ln -s ../bref/sbin/* .

# Install extensions
# We can install extensions manually or using `pecl`
RUN pecl install APCu

###############################################################
# NewRelic agent
ARG NEW_RELIC_AGENT_VERSION=9.18.1.303
ARG NEW_RELIC_LICENSE_KEY=485399637409f4456a3f66db12c8377c50fa3549
ARG NEW_RELIC_APPNAME='QuotingPortal'
ARG NEW_RELIC_DAEMON_ADDRESS=portal-newrelic.clariondoor.com:31339

RUN curl -L "https://download.newrelic.com/php_agent/archive/${NEW_RELIC_AGENT_VERSION}/newrelic-php5-${NEW_RELIC_AGENT_VERSION}-linux.tar.gz" | tar -C /tmp -zx \
 && export NR_INSTALL_USE_CP_NOT_LN=1 \
 && export NR_INSTALL_SILENT=1 \
 && export NR_INSTALL_DAEMONPATH=${INSTALL_DIR}/bin/newrelic-daemon \
 && /tmp/newrelic-php5-*/newrelic-install install \
 && rm -rf /tmp/newrelic-php5-* /tmp/nrinstall*

RUN echo extension = "newrelic.so" >> ${INSTALL_DIR}/etc/php/php.ini && \
    echo newrelic.appname = "${NEW_RELIC_APPNAME}" >> ${INSTALL_DIR}/etc/php/php.ini && \
    echo newrelic.license = "${NEW_RELIC_LICENSE_KEY}" >> ${INSTALL_DIR}/etc/php/php.ini && \
    echo newrelic.logfile = "/dev/stderr" >> ${INSTALL_DIR}/etc/php/php.ini && \
    echo newrelic.loglevel = "error" >> ${INSTALL_DIR}/etc/php/php.ini && \
    echo newrelic.daemon.dont_launch = "3" >> ${INSTALL_DIR}/etc/php/php.ini

RUN mkdir -p ${INSTALL_DIR}/etc/newrelic && \
  echo "loglevel=error" > ${INSTALL_DIR}/etc/newrelic/newrelic.cfg && \
  echo "logfile=/dev/stderr" >> ${INSTALL_DIR}/etc/newrelic/newrelic.cfg && \
  echo "wait_for_port=0" >> ${INSTALL_DIR}/etc/newrelic/newrelic.cfg

# Run the next step in the previous environment because the `clean.sh` script needs `find`,
# which isn't installed by default
FROM build-environment as build-environment-cleaned
# Remove extra files to make the layers as slim as possible
COPY clean.sh /tmp/clean.sh
RUN /tmp/clean.sh && rm /tmp/clean.sh


# Now we start back from a clean image.
# We get rid of everything that is unnecessary (build tools, source code, and anything else
# that might have created intermediate layers for docker) by copying online the /opt directory.
FROM public.ecr.aws/lambda/provided:al2
ENV PATH="/opt/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/bref/lib64:/opt/bref/lib"

# Copy everything we built above into the same dir on the base AmazonLinux container.
COPY --from=build-environment-cleaned /opt /opt

# Set the workdir to the same directory as in AWS Lambda
WORKDIR /var/task
