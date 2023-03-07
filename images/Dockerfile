FROM mambaorg/micromamba:1.2.0

COPY --chown=$MAMBA_USER:$MAMBA_USER images/environment.yml /tmp/environment.yml

RUN micromamba install --verbose -n base --file /tmp/environment.yml && \
    micromamba clean --all --yes

COPY --chown=$MAMBA_USER:$MAMBA_USER jobs /home/$MAMBA_USER/jobs
WORKDIR /home/$MAMBA_USER
