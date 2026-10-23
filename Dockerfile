ARG PHP_IMAGE=php:8.4.26-apache@sha256:60111400ff77bdc44fa79b4f072afe49a42abba71e0846ad496be4761dc9c11a
FROM ${PHP_IMAGE}

# Start from the official production INI. The public PoC's heap layout depends
# on zend.assertions=-1 and the other production defaults.
RUN cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

COPY php/99-lab.ini /usr/local/etc/php/conf.d/99-lab.ini
COPY apache/zz-single-worker.conf /etc/apache2/conf-enabled/zz-single-worker.conf
COPY src/ /var/www/html/

# Proof output directory. The Compose bind mount may override this at runtime.
RUN mkdir -p /out && chown www-data:www-data /out

EXPOSE 80
