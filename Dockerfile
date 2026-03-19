FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY Kalendr.Shared/Kalendr.Shared.csproj Kalendr.Shared/
COPY Kalendr.API/Kalendr.API.csproj Kalendr.API/
RUN dotnet restore Kalendr.API/Kalendr.API.csproj

COPY Kalendr.Shared/ Kalendr.Shared/
COPY Kalendr.API/ Kalendr.API/
RUN dotnet publish Kalendr.API/Kalendr.API.csproj -c Release -o /app

FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app .
ENTRYPOINT ["dotnet", "Kalendr.API.dll"]
