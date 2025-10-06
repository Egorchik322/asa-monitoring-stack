FROM telegraf:1.30
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client sshpass python3-venv python3-pip ca-certificates jq curl \
 && rm -rf /var/lib/apt/lists/*
# Создаём виртуальное окружение и ставим зависимости pyATS/Genie/Unicon
RUN python3 -m venv /opt/asa/venv && . /opt/asa/venv/bin/activate \
 && pip install --upgrade pip setuptools wheel \
 && pip install pyats genie unicon genie.libs.parser jsonmerge
WORKDIR /opt/telegraf/ASA-Telemetry-Guide/telegraf/scripts
