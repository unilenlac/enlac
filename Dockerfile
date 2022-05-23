FROM ubuntu:18.04
RUN apt-get update && \
  apt-get upgrade -y && \
  apt-get install -q -y openjdk-8-jdk python3-pip git maven expat libxml2-utils libicu-dev curl jq
#libicu-dev: uconv

ENV LANG=en_US.UTF-8

RUN pip3 install --upgrade pip requests
RUN pip3 install lxml

#RUN cd / && git clone https://github.com/interedition/collatex.git

#RUN cd collatex && mvn -Dmaven.test.skip=true package

RUN mkdir -p /collatex/collatex-tools/target/

COPY collatex-tools-1.8-SNAPSHOT.jar /collatex/collatex-tools/target/

ADD "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" skipcache
# just a trick to disable cache selectively, from next command
# https://stackoverflow.com/questions/35134713/disable-cache-for-specific-run-commands

COPY relations.txt /

RUN git clone https://github.com/seretan/tpen2tei

RUN cd tpen2tei && git checkout xmlrich_tokenization

#RUN useradd -u 8877 unilenlac

#USER unilenlac

WORKDIR /home/

COPY shell-scripts/xml2collation.sh /bin/xml2collation.sh

CMD /bin/xml2collation.sh /home /home/out/ -m
