# Copyright (c) 2019 Kekeho (Hiroki Takemura)
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

FROM python:3.7.3-slim-stretch

COPY ./requirements.txt /

# Install Python3
RUN pip3 install -r /requirements.txt

COPY ./entrypoint.sh /
ENTRYPOINT [ "./entrypoint.sh" ]
