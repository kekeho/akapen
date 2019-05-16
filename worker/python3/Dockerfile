# Copyright (c) 2019 Kekeho (Hiroki Takemura)
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT


FROM linuxbrew/brew

RUN brew install python3 gcc

COPY ./requirements.txt /

# Install Python3
RUN pip3 install -r /requirements.txt

ENTRYPOINT [ "python3" , "-c"]