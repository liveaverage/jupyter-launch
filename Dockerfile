FROM jupyter/base-notebook:latest

USER root

# Install packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    jupyterlab-nvdashboard \
    nvidia-ml-py3 \
    jupyterlab-tour \
    jupyter_kernel_gateway && \
    fix-permissions /opt/conda /home/jovyan

# Copy all assets
COPY assets/ /opt/nvidia-assets/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create directories
RUN mkdir -p /home/jovyan/.jupyter/lab/user-settings/@jupyterlab/apputils-extension && \
    mkdir -p /opt/conda/share/jupyter/lab/settings && \
    mkdir -p /etc/jupyter

# Copy configuration files
RUN cp /opt/nvidia-assets/themes.jupyterlab-settings /home/jovyan/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/themes.jupyterlab-settings && \
    cp /opt/nvidia-assets/notification.jupyterlab-settings /home/jovyan/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/notification.jupyterlab-settings && \
    cp /opt/nvidia-assets/overrides.json /opt/conda/share/jupyter/lab/settings/overrides.json && \
    cp /opt/nvidia-assets/jupyter_server_config.py /etc/jupyter/jupyter_server_config.py

# Apply NVIDIA branding using a dedicated script
COPY assets/apply-branding.sh /opt/nvidia-assets/apply-branding.sh
RUN chmod +x /opt/nvidia-assets/apply-branding.sh && \
    /opt/nvidia-assets/apply-branding.sh

# Configure JupyterLab Tour settings and application title
RUN mkdir -p /home/jovyan/.jupyter/lab/user-settings/jupyterlab-tour && \
    cp /opt/nvidia-assets/user-tours.jupyterlab-settings /home/jovyan/.jupyter/lab/user-settings/jupyterlab-tour/user-tours.jupyterlab-settings && \
    mkdir -p /home/jovyan/.jupyter/lab/user-settings/@jupyterlab/application-extension && \
    echo '{"documentTitle": "Pyrrhus Lab"}' > /home/jovyan/.jupyter/lab/user-settings/@jupyterlab/application-extension/page-config.jupyterlab-settings

# Disable default tour extensions (but keep user-tours enabled for our custom tours)
RUN jupyter labextension disable "jupyterlab-tour:notebook-tours" && \
    jupyter labextension disable "jupyterlab-tour:default-tours" && \
    mkdir -p /etc/jupyter/labconfig && \
    cp /opt/nvidia-assets/page_config.json /etc/jupyter/labconfig/page_config.json

# Fix permissions
RUN fix-permissions /home/jovyan /opt/conda && \
    chgrp -R 0 /home/jovyan /opt/conda && \
    chmod -R g+rwX /home/jovyan /opt/conda && \
    find /home/jovyan -type d -exec chmod g+s {} \; && \
    mkdir -p /home/jovyan/.jupyter && \
    chmod -R 777 /home/jovyan/.jupyter

# Set working directory
WORKDIR /home/jovyan/work

USER ${NB_USER}

ENV JUPYTER_ENABLE_LAB=yes
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["start-notebook.sh"]