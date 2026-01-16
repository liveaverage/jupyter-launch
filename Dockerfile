# Purpose: CPU-only lightweight JupyterLab with NeMo Data Designer tools
# Inputs: None (uses latest jupyter/base-notebook)
# Outputs: Smaller (<3GB) CPU-optimized image
# Assumptions: No GPU required, runs on any Docker host
# Notes: No CUDA, no JupyterLab build, extensions load dynamically
# Optimizations: Minimal unstructured deps, aggressive cleanup

FROM jupyter/base-notebook:latest

USER root

# Install minimal system dependencies (combined layer)
RUN apt-get update && \
    apt-get install -y --no-install-recommends git socat && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Python packages in stages to minimize transitive deps
# Stage 1: Core Jupyter extensions (lightweight)
RUN pip install --no-cache-dir \
    jupyterlab-nvdashboard \
    nvidia-ml-py3 \
    jupyterlab-tour \
    jupyter_kernel_gateway && \
    rm -rf /home/jovyan/.cache/pip /tmp/*

# Stage 2: Data processing (heavy - use minimal extras)
# Note: unstructured without [pdf] saves ~500MB (no poppler/tesseract/opencv)
# If PDF parsing needed, install manually: apt-get install poppler-utils tesseract-ocr
RUN pip install --no-cache-dir \
    "pydantic>=2.9.2" \
    langchain==0.3.17 \
    unstructured \
    pandas==2.2.3 \
    "rich>=13.7.1" \
    pillow && \
    rm -rf /home/jovyan/.cache/pip /tmp/*

# Stage 3: NeMo and datasets (largest deps - installed last)
RUN pip install --no-cache-dir \
    datasets \
    "nemo-microservices[data-designer]" && \
    fix-permissions /opt/conda /home/jovyan && \
    rm -rf /home/jovyan/.cache/pip /tmp/* /root/.cache

# Aggressive cleanup: Remove unnecessary files from conda/pip packages
RUN find /opt/conda -follow -type f -name '*.a' -delete && \
    find /opt/conda -follow -type f -name '*.pyc' -delete && \
    find /opt/conda -follow -type f -name '*.js.map' -delete && \
    find /opt/conda/lib/python*/site-packages/bokeh/server/static -follow -type f -name '*.js' ! -name '*.min.js' -delete 2>/dev/null || true

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
    echo '{"documentTitle": "Pyrrhus Lab"}' > /home/jovyan/.jupyter/lab/user-settings/@jupyterlab/application-extension/page-config.jupyterlab-settings && \
    mkdir -p /etc/jupyter/labconfig && \
    cp /opt/nvidia-assets/page_config.json /etc/jupyter/labconfig/page_config.json

# OpenShift-compatible permissions (minimal footprint)
RUN fix-permissions /home/jovyan /opt/conda && \
    chgrp -R 0 /home/jovyan /opt/conda && \
    chmod -R g+rwX /home/jovyan /opt/conda && \
    find /home/jovyan -type d -exec chmod g+s {} \; && \
    chmod -R 777 /home/jovyan/.jupyter

WORKDIR /home/jovyan/work
USER ${NB_USER}

ENV JUPYTER_ENABLE_LAB=yes \
    JUPYTER_PORT=8888

# Labels for CPU-only image
LABEL org.opencontainers.image.title="Pyrrhus JupyterLab CPU" \
      org.opencontainers.image.description="Lightweight CPU-only JupyterLab with NeMo Data Designer" \
      org.opencontainers.image.vendor="Pyrrhus"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["start-notebook.sh"]