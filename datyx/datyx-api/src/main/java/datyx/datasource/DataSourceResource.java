package datyx.datasource;

import java.net.URI;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import datyx.auth.CurrentUser;
import datyx.datasource.DataSource.Type;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

/**
 * The data sources on record, the first entity of datyx:
 * GET /api/datasources?limit=100 lists them, newest first;
 * GET /api/datasources/{id} answers one;
 * POST /api/datasources adds one and answers 201 with it and a Location;
 * DELETE /api/datasources/{id} removes one (204).
 * A body names the source, its type (database, s3, filesystem) and the
 * access details of that type, under a key of the same name:
 * {"name":"warehouse","type":"database","description":"...",
 *  "database":{"engine":"postgresql","host":"db","port":5432,"database":"dw","username":"u","password":"p"}}
 * {"name":"lake","type":"s3","s3":{"bucket":"b","region":"eu-west-1","endpoint":null,"prefix":"raw/","accessKeyId":"...","secretAccessKey":"..."}}
 * {"name":"exports","type":"filesystem","filesystem":{"path":"/data/exports"}}
 * Missing or mismatched details are a 400, a name already taken a 409.
 * Answers carry the details without their secrets: passwordSet and
 * secretAccessKeySet say whether one was given. Every call needs a
 * signed-in user once authentication is on; who added a source is kept
 * as createdBy (email) and createdByName.
 */
@Path("/api/datasources")
@Produces(MediaType.APPLICATION_JSON)
public class DataSourceResource {

    @Inject
    CurrentUser user;

    @GET
    public List<Map<String, Object>> list(@QueryParam("limit") @DefaultValue("100") int limit) {
        return DataSource.newest(Math.clamp(limit, 1, 1000)).stream().map(DataSourceResource::view).toList();
    }

    @GET
    @Path("/{id}")
    public Response get(@PathParam("id") long id) {
        DataSource source = DataSource.findById(id);
        return source == null ? notFound(id) : Response.ok(view(source)).build();
    }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @Transactional
    public Response create(@Valid NewDataSource body) {
        String problem = body.problem();
        if (problem != null) {
            return Response.status(Response.Status.BAD_REQUEST).entity(Map.of("error", problem)).build();
        }
        String name = body.name().strip();
        if (DataSource.nameTaken(name)) {
            return Response.status(Response.Status.CONFLICT)
                .entity(Map.of("error", "a data source named '" + name + "' already exists")).build();
        }
        DataSource source = new DataSource();
        source.name = name;
        source.type = body.type();
        source.description = blankToNull(body.description());
        source.createdAt = Instant.now();
        source.createdBy = user.id();
        source.createdByName = user.name();
        switch (body.type()) {
            case DATABASE -> source.database = body.database().toEntity();
            case S3 -> source.s3 = body.s3().toEntity();
            case FILESYSTEM -> source.filesystem = body.filesystem().toEntity();
        }
        source.persist();
        return Response.created(URI.create("/api/datasources/" + source.id)).entity(view(source)).build();
    }

    @DELETE
    @Path("/{id}")
    @Transactional
    public Response delete(@PathParam("id") long id) {
        DataSource source = DataSource.findById(id);
        if (source == null) {
            return notFound(id);
        }
        source.delete();
        return Response.noContent().build();
    }

    private static Response notFound(long id) {
        return Response.status(Response.Status.NOT_FOUND)
            .entity(Map.of("error", "no data source with id " + id)).build();
    }

    /** The JSON of a source: its fields and the details of its type, secrets replaced by whether they are set. */
    static Map<String, Object> view(DataSource source) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", source.id);
        map.put("name", source.name);
        map.put("type", source.type.json());
        map.put("description", source.description);
        map.put("createdAt", source.createdAt.toString());
        map.put("createdBy", source.createdBy);
        map.put("createdByName", source.createdByName);
        switch (source.type) {
            case DATABASE -> {
                Map<String, Object> d = new LinkedHashMap<>();
                d.put("engine", source.database.engine);
                d.put("host", source.database.host);
                d.put("port", source.database.port);
                d.put("database", source.database.database);
                d.put("username", source.database.username);
                d.put("passwordSet", source.database.password != null);
                map.put("database", d);
            }
            case S3 -> {
                Map<String, Object> d = new LinkedHashMap<>();
                d.put("bucket", source.s3.bucket);
                d.put("region", source.s3.region);
                d.put("endpoint", source.s3.endpoint);
                d.put("prefix", source.s3.prefix);
                d.put("accessKeyId", source.s3.accessKeyId);
                d.put("secretAccessKeySet", source.s3.secretAccessKey != null);
                map.put("s3", d);
            }
            case FILESYSTEM -> map.put("filesystem", Map.of("path", source.filesystem.path));
        }
        return map;
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.strip();
    }

    /** POST's body. The details of the named type are required, the others must be absent. */
    public record NewDataSource(
            @NotBlank @Size(max = 100) String name,
            @NotNull Type type,
            @Size(max = 500) String description,
            @Valid DatabaseDetails database,
            @Valid S3Details s3,
            @Valid FilesystemDetails filesystem) {

        /** What is wrong with the body beyond the field constraints, or null. */
        String problem() {
            int given = (database != null ? 1 : 0) + (s3 != null ? 1 : 0) + (filesystem != null ? 1 : 0);
            String expected = type.json();
            boolean present = switch (type) {
                case DATABASE -> database != null;
                case S3 -> s3 != null;
                case FILESYSTEM -> filesystem != null;
            };
            if (!present) {
                return "a " + expected + " data source needs its '" + expected + "' details";
            }
            if (given > 1) {
                return "a " + expected + " data source takes only its '" + expected + "' details";
            }
            return null;
        }
    }

    public record DatabaseDetails(
            @NotBlank @Size(max = 40) String engine,
            @NotBlank @Size(max = 255) String host,
            @NotNull @Min(1) @Max(65535) Integer port,
            @NotBlank @Size(max = 200) String database,
            @Size(max = 200) String username,
            @Size(max = 500) String password) {

        DataSource.DatabaseAccess toEntity() {
            DataSource.DatabaseAccess access = new DataSource.DatabaseAccess();
            access.engine = engine.strip().toLowerCase();
            access.host = host.strip();
            access.port = port;
            access.database = database.strip();
            access.username = blankToNull(username);
            access.password = password == null || password.isEmpty() ? null : password;
            return access;
        }
    }

    public record S3Details(
            @NotBlank @Size(max = 255) String bucket,
            @Size(max = 40) String region,
            @Size(max = 500) String endpoint,
            @Size(max = 1000) String prefix,
            @Size(max = 200) String accessKeyId,
            @Size(max = 500) String secretAccessKey) {

        DataSource.S3Access toEntity() {
            DataSource.S3Access access = new DataSource.S3Access();
            access.bucket = bucket.strip();
            access.region = blankToNull(region);
            access.endpoint = blankToNull(endpoint);
            access.prefix = blankToNull(prefix);
            access.accessKeyId = blankToNull(accessKeyId);
            access.secretAccessKey = secretAccessKey == null || secretAccessKey.isEmpty() ? null : secretAccessKey;
            return access;
        }
    }

    public record FilesystemDetails(@NotBlank @Size(max = 1000) String path) {

        DataSource.FilesystemAccess toEntity() {
            DataSource.FilesystemAccess access = new DataSource.FilesystemAccess();
            access.path = path.strip();
            return access;
        }
    }
}
