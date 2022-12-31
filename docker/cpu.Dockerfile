FROM ubuntu:16.04

ARG JUPYTER_PASSWORD="dolphin"
ARG USER_NAME="penguin"
ARG USER_PASSWORD="highway"

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Install dependences
RUN apt-get update --fix-missing && \
  apt-get install -y \
    wget \
    bzip2 \ 
    ca-certificates \
    libglib2.0-0 \
    libxext6 \
    libsm6 \
    libxrender1 \
    git \
    mercurial \
    subversion \
    sudo \
    git \
    zsh \
    openssh-server \
    wget \
    gcc \
    g++ \
    libatlas-base-dev \
    libboost-dev \
    libboost-system-dev \
    libboost-filesystem-dev \
    curl \
    make \
    unzip \
    vim \
    ffmpeg \
    # MeCab
    swig mecab libmecab-dev mecab-ipadic-utf8 \
    cmake --fix-missing && \
  # copy macabrc to user local
  cp /etc/mecabrc /usr/local/etc/

ENV TINI_VERSION v0.6.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
RUN chmod +x /usr/bin/tini
ENTRYPOINT ["/usr/bin/tini", "--"]

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

# remove cache files
RUN apt-get autoremove -y && apt-get clean && \
  rm -rf /usr/local/src/*

# user をルートユーザーから切り替えます
# ユーザー名とパスワードは arg を使って切り替えることが出来ます (このファイルの先頭を参照)
RUN groupadd -g 1000 developer &&\
  useradd -g developer -G sudo -m -s /bin/bash ${USER_NAME} &&\
  echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd

USER ${USER_NAME}

# Install miniconda at CONDA_DIR & add path
ENV CONDA_DIR /home/${USER_NAME}/.conda
ENV PATH ${CONDA_DIR}/bin:${PATH}
RUN wget --quiet https://repo.continuum.io/miniconda/Miniconda3-4.5.12-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p ${CONDA_DIR} && \
    rm ~/miniconda.sh

RUN conda update conda --all && \
  conda install -y conda &&\
  conda install -y \
    numpy \
    scipy \
    scikit-learn \
    pytorch \
    torchvision &&\
  conda install -c conda-forge \
    lightgbm \
    xgboost \
    uwsgi \
    libiconv && \
  conda clean -i -t -y

# install additional packages
COPY docker/requirements.txt requirements.txt
RUN pip install -U pip &&\
   pip install -U -r requirements.txt &&\
   # note: conda install すると keras / tensorflow 部分でこける為, 暫定対応
   pip install tensorflow-cpu &&\
   # remove cache files
   rm -rf ~/.cache/pip

# enable jupyter extentions
RUN jupyter contrib nbextension install --user

# jupyter の config ファイルの作成
RUN echo "c.NotebookApp.open_browser = False\n\
c.NotebookApp.ip = '*'\n\
c.NotebookApp.token = '${JUPYTER_PASSWORD}'" | tee -a ${HOME}/.jupyter/jupyter_notebook_config.py


# vim key bind
# Create required directory in case (optional)
RUN mkdir -p $(jupyter --data-dir)/nbextensions && \
    cd $(jupyter --data-dir)/nbextensions && \
    git clone https://github.com/lambdalisue/jupyter-vim-binding vim_binding

COPY --chown=penguin:developer docker/jupyter-custom.css /home/${USER_NAME}/.jupyter/custom/custom.css
COPY --chown=penguin:developer docker/matplotlibrc /home/${USER_NAME}/.config/matplotlib/matplotlibrc
COPY --chown=penguin:developer docker/ipython_config.py /home/${USER_NAME}/.ipython/profile_default/

WORKDIR /analysis/
EXPOSE 8888

CMD [ "jupyter", "notebook", "--ip=0.0.0.0", "--port=8888"]
