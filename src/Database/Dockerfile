FROM mcr.microsoft.com/mssql/server:2022-latest

COPY ./CompanyName.MyMeetings.Database/Scripts/CreateDatabase_Linux.sql /scripts/

ENV ACCEPT_EULA=Y
ENV SA_PASSWORD=Test@12345
ENV MSSQL_PID=Express
ENV MSSQL_TCP_PORT=1433

ADD entrypoint.sh /
ADD healthcheck.sh /

# Invoke with bash so chmod +x is not needed (chmod can fail on some Docker Desktop builds).
HEALTHCHECK --interval=5s --timeout=10s --start-period=120s --retries=24 \
  CMD /bin/bash /healthcheck.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]