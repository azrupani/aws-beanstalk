#
# Reverse Proxy Image
#

FROM registry.<ADDME>:5000/syseng/nginx:latest

MAINTAINER SysEng <admin@<ADDME>.com>

ADD sites-available/ /etc/nginx/sites-available/
ADD nginx.conf /etc/nginx/nginx.conf

RUN for i in `ls -1 /etc/nginx/sites-available`; do ln -s ../sites-available/${i} /etc/nginx/sites-enabled/${i}; done

CMD [ "/usr/sbin/nginx", "-c", "/etc/nginx/nginx.conf" ]

EXPOSE 80

# EOF
