FROM openjdk:7-alpine

ENV ZEPPELIN_VERSION 0.7.1

RUN apk add --update curl bash \
    && curl -L http://ftp.jaist.ac.jp/pub/apache/zeppelin/zeppelin-$ZEPPELIN_VERSION/zeppelin-$ZEPPELIN_VERSION-bin-all.tgz | tar xz \
    && ln -sf /zeppelin-$ZEPPELIN_VERSION-bin-all /zeppelin \
    && rm -fr /var/cache/apk/*

WORKDIR /zeppelin
EXPOSE 8080

CMD ["bin/zeppelin-daemon.sh", "start"]
