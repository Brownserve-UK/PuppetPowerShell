# https://hub.docker.com/_/microsoft-windows-servercore
ARG VARIANT="ltsc2022"
FROM mcr.microsoft.com/windows/servercore:${VARIANT}

# As we're only using this for testing purposes this should be fine
USER ContainerAdministrator

RUN powershell -Command \
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

RUN choco install powershell-core -y

CMD ["pwsh.exe"]
