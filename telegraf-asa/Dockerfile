# Telegraf with pyATS for Cisco ASA monitoring
FROM telegraf:1.30

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    git \
    openssh-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create Python virtual environment and install pyATS
RUN python3 -m venv /opt/asa/venv && \
    /opt/asa/venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/asa/venv/bin/pip install --no-cache-dir \
    'pyats[full]' \
    --pre genie.libs.parser \
    jsonmerge

# Setup working directory
WORKDIR /opt/telegraf

# Clone ASA Telemetry Guide repository
RUN git clone https://github.com/mageru/ASA-Telemetry-Guide.git /opt/telegraf/ASA-Telemetry-Guide


# Add venv to PATH
ENV PATH="/opt/asa/venv/bin:$PATH"

# Healthcheck
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD telegraf --test --config /etc/telegraf/telegraf.conf || exit 1
