FROM amazoncorretto:11.0.19-alpine3.17

RUN apk update && \
  apk add py3-pip \
  git \
  maven \ 
  expat \
  libxml2-utils \
  icu-dev \
  curl \
  jq \
  --no-cache openssh \
  --no-cache bash

ENV LANG=en_US.UTF-8

RUN pip3 install --upgrade pip requests
RUN pip3 install lxml

RUN mkdir -p /collatex/collatex-tools/target/
WORKDIR /collatex/collatex-tools/target/

RUN curl https://oss.sonatype.org/service/local/repositories/releases/content/eu/interedition/collatex-tools/1.7.1/collatex-tools-1.7.1.jar -o collatex-tools-1.7.1.jar

ADD "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" skipcache
# just a trick to disable cache selectively, from next command
# https://stackoverflow.com/questions/35134713/disable-cache-for-specific-run-commands


WORKDIR /

COPY relations.txt /

RUN git clone https://github.com/seretan/tpen2tei

RUN cd tpen2tei && git checkout xmlrich_tokenization

RUN adduser -D -u 8877 unilenlac

USER unilenlac

WORKDIR /home/

COPY shell-scripts/xml2collation.sh /bin/xml2collation.sh

CMD /bin/xml2collation.sh /home /home/out/ -m
