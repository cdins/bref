ARG PHP_VERSION
FROM bref/build-php-$PHP_VERSION as build_extensions

# Re-expose the arg again inside this "FROM" block
ARG PHP_VERSION

RUN if [[ "$PHP_VERSION" != 7* ]]; then pecl install xdebug; fi
RUN if [[ "$PHP_VERSION" == 7* ]]; then pecl install xdebug-3.1.6; fi
RUN cp $(php -r "echo ini_get('extension_dir');")/xdebug.so /tmp

RUN version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
    && curl -A "Docker" -o /tmp/blackfire.so -L -s "https://packages.blackfire.io/binaries/blackfire-php/1.55.0/blackfire-php-linux_amd64-php-"$version".so" ;

FROM bref/php-${PHP_VERSION}-fpm as build_dev

USER root
COPY --from=build_extensions /tmp/*.so /tmp/
RUN cp /tmp/*.so $(php -r "echo ini_get('extension_dir');")

FROM bref/php-${PHP_VERSION}-fpm

COPY --from=build_dev  /opt /opt
# Override the config so that PHP-FPM listens on port 9000
COPY php-fpm.conf /opt/bref/etc/php-fpm.conf
COPY bootstrap /opt/bref/bin/bootstrap
