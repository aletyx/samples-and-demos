# Data sources

The first entity of datyx: where data lives and how to reach it. Users
add and remove them; nothing reads them yet (connecting to them, and
registering them in OpenMetadata, comes next). Code in
`datyx-api/src/main/java/datyx/datasource/`.

## The entity

`DataSource` (table `data_source`): `id`, `name` (up to 100 characters,
required, unique whatever its case: a unique index on `lower(name)`,
made by the Flyway migration), `type` (`database`, `s3` or
`filesystem`; stored as `DATABASE`, `S3`, `FILESYSTEM`), `description`
(up to 500), `createdAt`, `createdBy` (the email of the signed-in user,
else the token's subject; null while authentication is off) and
`createdByName`; then the access details of its type, one embedded group
of columns each, the others null:

- A **database**: `engine` (postgresql, mysql, ...; lower-cased), `host`,
  `port` (1 to 65535), `database`, `username`, `password`. Columns `db_*`.
- An **S3 bucket**: `bucket`, `region`, `endpoint` (S3-compatible stores
  only), `prefix`, `accessKeyId`, `secretAccessKey`. Columns `s3_*`.
- A **filesystem** folder: `path`. Column `fs_path`.

Secrets (`password`, `secretAccessKey`) are stored as given and never
answered back: answers carry `passwordSet` and `secretAccessKeySet`
instead.

## Endpoints

All under `/api/datasources`, and all wanting a signed-in user once
authentication is on ([auth.md](auth.md)):

- `GET /api/datasources?limit=100` lists them, newest first (`limit`
  between 1 and 1000).
- `GET /api/datasources/{id}` answers one; 404 when there is none.
- `POST /api/datasources` adds one and answers 201 with it and a
  `Location`. The body names the source, its type and the details of that
  type under a key of the same name:
  `{"name":"warehouse","type":"database","description":"...","database":{"engine":"postgresql","host":"db","port":5432,"database":"dw","username":"u","password":"p"}}`,
  `{"name":"lake","type":"s3","s3":{"bucket":"b","region":"eu-west-1","prefix":"raw/","accessKeyId":"...","secretAccessKey":"..."}}`,
  `{"name":"exports","type":"filesystem","filesystem":{"path":"/data/exports"}}`.
  Field constraints (Hibernate Validator) and details missing for the
  type, or given for another type, are a 400 with `{"error":"..."}`; a
  name already taken is a 409: the row is flushed in the call, and the
  index's refusal (SQLSTATE 23505) is answered, so a race has one winner.
- `DELETE /api/datasources/{id}` removes one (204; 404 when there is none).

An answer: the entity's fields, the type as its JSON name, and the
details of its type, without secrets:
`{"id":1,"name":"warehouse","type":"database","description":null,"createdAt":"...","createdBy":"alice@example.com","createdByName":"Alice","database":{"engine":"postgresql","host":"db","port":5432,"database":"dw","username":"u","passwordSet":true}}`.

`GET /api/status` counts them as `dataSources`.

## Known limitations

- Secrets are stored in clear in PostgreSQL; encrypting them at rest
  comes before anything shared uses this.
- No update: remove and add again.
- Nothing connects to a source yet, and OpenMetadata knows nothing of them.
