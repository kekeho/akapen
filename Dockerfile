FROM docker

RUN apk update
RUN apk add -y alpine-sdk

# Install Nim
RUN mkdir /download
RUN wget https://github.com/nim-lang/Nim/archive/v0.19.6.zip
RUN unzip ./v0.19.6.zip
WORKDIR /Nim-0.19.6
RUN sh build_all.sh
RUN bin/nim c koch
RUN ./koch tools
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/Nim-0.19.6/bin

# Build akapen
RUN mkdir /akapen
RUN mkdir /akapen/src
COPY akapen.nimble /akapen
COPY src /akapen/src
WORKDIR /akapen
RUN nimble update
RUN nimble install redis
RUN nimble make

CMD [ "./akapen" ]
