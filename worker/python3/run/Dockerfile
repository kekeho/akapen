# Copyright (c) 2019 Kekeho (Hiroki Takemura)
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

FROM python:3.7.3-slim-stretch

COPY ./requirements.txt /

# Install lib
RUN pip3 install -r /requirements.txt

CMD [ "python3", "/main.py" ]