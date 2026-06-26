FROM httpd:2.4

LABEL description="OPE Download site (Apache autoindex) for Open Prison Education"
LABEL version="0.1"

# Serve files from /downloads instead of the default htdocs, mirroring
RUN sed -ri \
    -e 's#DocumentRoot "/usr/local/apache2/htdocs"#DocumentRoot "/downloads"#' \
    -e 's#<Directory "/usr/local/apache2/htdocs">#<Directory "/downloads">#' \
    /usr/local/apache2/conf/httpd.conf

# Enable a nicer auto-generated index. mod_autoindex is already loaded in the
# base image; these directives turn on fancy indexing for the download root.
RUN { \
      echo ''; \
      echo '<Directory "/downloads">'; \
      echo '    Options +Indexes +FollowSymLinks'; \
      echo '    AllowOverride None'; \
      echo '    Require all granted'; \
      echo '    IndexOptions FancyIndexing HTMLTable SuppressDescription NameWidth=* FoldersFirst IgnoreCase'; \
      echo '</Directory>'; \
    } >> /usr/local/apache2/conf/httpd.conf

VOLUME ["/downloads"]
EXPOSE 80
