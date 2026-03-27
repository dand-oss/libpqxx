# Installing libpq on Windows for libpqxx builds

## Why

libpqxx requires libpq (the PostgreSQL C client library) to build.
On Linux, `libpq-dev` is a system package. On Windows, you must install it manually.

## Steps

### 1. Download PostgreSQL zip binaries

Download the Windows x64 zip from EDB (not the installer):

https://www.enterprisedb.com/download-postgresql-binaries

Direct link for 18.3: https://sbp.enterprisedb.com/getfile.jsp?fileid=1260119

64-bit only. 32-bit is not supported.

### 2. Extract to I:\t\postgres\<version>\

```bash
mkdir -p /i/t/postgres
curl -L -o /c/Users/appsmith/pg18.zip 'https://sbp.enterprisedb.com/getfile.jsp?fileid=1260119'
unzip /c/Users/appsmith/pg18.zip -d /i/t/postgres/18.3/
rm /c/Users/appsmith/pg18.zip
```

This creates `I:\t\postgres\18.3\pgsql\` containing `include/`, `lib/`, `bin/`, etc.

Key files used by the build:
- `I:/t/postgres/18.3/pgsql/include/libpq-fe.h`
- `I:/t/postgres/18.3/pgsql/lib/libpq.lib`
- `I:/t/postgres/18.3/pgsql/bin/libpq.dll`

### 3. Build libpqxx

```bash
dev build ports --task libpqxx
```

CMake auto-discovers the PostgreSQL install by globbing `I:/t/postgres/*/pgsql`.
No environment variables need to be set.

## How it works

`cmake/config.cmake` searches for libpq in this order:

1. `PGDIR` environment variable (if set)
2. `I:/t/postgres/*/pgsql` glob (Windows only, picks latest version)
3. `ASV_PLAT_PORTS` cmake variable
4. System pkg-config (`libpq-dev` on Linux)

## Upgrading PostgreSQL

Download the new zip, extract to `I:\t\postgres\<new-version>\`, and rebuild.
The glob picks the highest version directory. Old versions can be deleted.
