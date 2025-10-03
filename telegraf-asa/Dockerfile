FROM telegraf:1.30

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv git openssh-client curl \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/asa/venv && \
    /opt/asa/venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/asa/venv/bin/pip install --no-cache-dir 'pyats[full]' \
    --pre genie.libs.parser jsonschema

WORKDIR /opt/telegraf
RUN git clone https://github.com/mageru/ASA-Telemetry-Guide.git /opt/telegraf/ASA-Telemetry-Guide

ENTRYPOINT ["/entrypoint.sh"]
CMD ["telegraf"]
