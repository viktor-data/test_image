FROM apache/airflow:2.10.4-python3.12

USER root

# Install basic utilities and dependencies
RUN apt-get update && \
    apt-get -y install git curl wget unzip libglib2.0-0 libnss3 libgconf-2-4 libfontconfig1 \
    fonts-liberation libasound2 libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 libcairo2 libcups2 \
    libgbm1 libgtk-3-0 libpango-1.0-0 libu2f-udev libvulkan1 libx11-6 libxcb1 libxcomposite1 \
    libxdamage1 libxext6 libxfixes3 libxkbcommon0 libxrandr2 xdg-utils && \
    apt-get clean

# Add Microsoft package signing key and repository
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/debian/10/prod.list > /etc/apt/sources.list.d/mssql-release.list

# Install Microsoft ODBC driver and tools
RUN apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql17 mssql-tools unixodbc-dev && \
    apt-get clean

# Add Google Chrome signing key and repository
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'

# Copy the Chrome .deb package into the Docker image and install
COPY packages/chrome_114_amd64.deb /tmp/
RUN dpkg -i /tmp/chrome_114_amd64.deb || apt-get -f install -y && \
    rm /tmp/chrome_114_amd64.deb && \
    apt-get clean

RUN chown -R airflow /opt/airflow/

# Switch back to airflow user
USER airflow

# Install Python packages
COPY requirements.txt /tmp/requirements.txt
RUN pip install --upgrade pip \
    && uv pip install --no-cache-dir -r /tmp/requirements.txt

# Install dbt into a virtual environment
RUN python -m venv dbt_venv && source dbt_venv/bin/activate \
    && uv pip install --no-cache-dir dbt-bigquery \
    && deactivate
ENV DBT_PROFILES_DIR=/opt/airflow/dags/inwave_dbt

# Set additional env vars
ENV LD_LIBRARY_PATH=/opt/microsoft/msodbcsql17/lib64:$LD_LIBRARY_PATH
ENV GOOGLE_APPLICATION_CREDENTIALS=/opt/airflow/iw-datawarehouse-cd2284bda645.json
ENV PYTHONPATH="${PYTHONPATH}:/opt/airflow/include"

# Copy Airflow configuration
COPY airflow/airflow.cfg /opt/airflow/
COPY airflow/dags/.airflowignore /opt/airflow/dags/
COPY airflow/template /opt/airflow/template

# Copy Google Application credentials
COPY iw-datawarehouse-cd2284bda645.json /opt/airflow/iw-datawarehouse-cd2284bda645.json
COPY tattoo_oauth2_desktop_client_secret_53343684005-hlrv507jks3lrepluuvrmta3ve7iuqp8.json /opt/airflow/tattoo_oauth2_desktop_client_secret_53343684005-hlrv507jks3lrepluuvrmta3ve7iuqp8.json

RUN echo "groups: $(groups airflow)" && umask 0002 && mkdir -p ~/.cache/selenium


