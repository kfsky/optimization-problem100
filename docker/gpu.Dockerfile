# Dockerfile for gpu context
# install pytorch and xgboost, lightGBM with GPU support

FROM nvidia/cuda:10.1-cudnn8-devel-ubuntu16.04

# イメージにベンダ名、作者などのラベル情報を付与する。一般的にレイヤが増えてしまうので、まとめることを推奨する。
# Docker 1.13 以降は MAINTAINER は非推奨となり、代わりに LABEL を使用することが推奨されている
LABEL maintainer="nyker <nykergoto@gmail.com>"

# Dockerfile内で使用できる変数を指定できる。ENVではsubprocessで引き継がれるのに対して、ARGはDockerfile中で使用できる
ARG JUPYTER_PASSWORD="dolphin"
ARG USER_NAME="penguin"
ARG USER_PASSWORD="highway"

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# https://text.superbrothers.dev/200328-how-to-avoid-pid-1-problem-in-kubernetes/
ENV TINI_VERSION v0.6.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
RUN chmod +x /usr/bin/tini
ENTRYPOINT [ "/usr/bin/tini", "--" ]

RUN apt-get update && \
  apt-get install -y \
  bzip2 \ 
  ca-certificates \
  mercurial \
  subversion \
  zsh \
  sudo \
  openssh-server \
  gcc \
  g++ \
  git \
  libglib2.0-0 \
  libxext6 \
  libsm6 \
  libxrender1 \
  libatlas-base-dev \
  libboost-dev \
  libboost-system-dev \
  libboost-filesystem-dev \
  ffmpeg \
  # IO and http utility
  curl \
  wget \
  make \
  unzip \
  # favorite editor
  nano \
  # require to use zplug 
  gawk \
  # MeCab
  swig mecab libmecab-dev mecab-ipadic-utf8 \
  cmake --fix-missing &&\
  # copy macabrc to user local
  cp /etc/mecabrc /usr/local/etc/

# install peco
RUN wget -q https://github.com/peco/peco/releases/download/v0.5.3/peco_linux_amd64.tar.gz -O ~/peco.tar.gz && \
  tar -zxvf ~/peco.tar.gz && \
  cp peco_linux_amd64/peco /usr/bin && \
  rm ~/peco.tar.gz

# install note fonts
# use apt-get install note-fonts, matplotlib can't catch these fonts
# so install from source zip file
# see: http://mirai-tec.hatenablog.com/entry/2018/04/17/004343
ENV NOTO_DIR /usr/share/fonts/opentype/notosans
RUN mkdir -p ${NOTO_DIR} &&\
  wget -q https://noto-website-2.storage.googleapis.com/pkgs/NotoSansCJKjp-hinted.zip -O noto.zip &&\
  unzip ./noto.zip -d ${NOTO_DIR}/ &&\
  chmod a+r ${NOTO_DIR}/NotoSans* &&\
  rm ./noto.zip

# Add OpenCL ICD files for LightGBM
RUN mkdir -p /etc/OpenCL/vendors && \
  echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd

# clean up cache files
RUN apt-get autoremove -y && apt-get clean && \
  rm -rf /usr/local/src/*

# user をルートユーザーから切り替えます
# ユーザー名とパスワードは arg を使って切り替えることが出来ます (このファイルの先頭を参照)
RUN groupadd -g 1000 developer &&\
  useradd -g developer -G sudo -m -s /bin/bash ${USER_NAME} &&\
  echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd

USER ${USER_NAME}

# install miniconda
ENV CONDA_DIR /home/${USER_NAME}/conda
ENV PATH ${CONDA_DIR}/bin:${PATH}
RUN wget --quiet https://repo.continuum.io/miniconda/Miniconda3-4.5.12-Linux-x86_64.sh -O ~/miniconda.sh && \
  /bin/bash ~/miniconda.sh -b -p ${CONDA_DIR} && \
  rm ~/miniconda.sh

# install requirements
RUN conda update conda && \
  conda install -y \
  numpy \
  scipy \
  scikit-learn

# pytorch
RUN conda install pytorch==1.7.1 torchvision==0.8.2 torchaudio==0.7.2 cudatoolkit=10.1 -c pytorch

# install catboost
RUN conda install -c conda-forge catboost


RUN pip install xgboost \
lightgbm


# other packages
COPY docker/requirements.txt requirements.txt
RUN pip install -r requirements.txt
# enable jupyter extentions
RUN jupyter contrib nbextension install --user

# 後片付け
RUN rm -rf ~/.cache/pip &&\
  conda clean -i -t -y

# jupyter の config ファイルの作成
RUN echo "c.NotebookApp.open_browser = False\n\
c.NotebookApp.ip = '*'\n\
c.NotebookApp.token = '${JUPYTER_PASSWORD}'" | tee -a ${HOME}/.jupyter/jupyter_notebook_config.py

COPY --chown=penguin:developer docker/jupyter-custom.css /home/${USER_NAME}/.jupyter/custom/custom.css
COPY --chown=penguin:developer docker/matplotlibrc /home/${USER_NAME}/.config/matplotlib/matplotlibrc
COPY --chown=penguin:developer docker/ipython_config.py /home/${USER_NAME}/.ipython/profile_default/

RUN curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh && \
  wget https://raw.githubusercontent.com/nyk510/dotfiles/master/.zshrc -O ~/.zshrc

WORKDIR /analysis
EXPOSE 8888

CMD [ "jupyter", "notebook", "--ip=0.0.0.0", "--port=8888"]
