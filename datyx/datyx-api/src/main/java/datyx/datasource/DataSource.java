package datyx.datasource;

import java.time.Instant;
import java.util.List;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;
import io.quarkus.hibernate.orm.panache.PanacheEntity;
import io.quarkus.panache.common.Sort;
import jakarta.persistence.AttributeOverride;
import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.Embedded;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

/**
 * A data source on record (table data_source): where data lives and how
 * to reach it. One of three kinds so far, each with its own access
 * details, in its own embedded group of columns: a database, an S3 bucket,
 * or a filesystem folder. Secrets (a database password, an S3 secret key)
 * are stored as given and never answered back (see DataSourceResource).
 */
@Entity
@Table(name = "data_source", uniqueConstraints = @UniqueConstraint(columnNames = "name"))
public class DataSource extends PanacheEntity {

    public enum Type {
        DATABASE, S3, FILESYSTEM;

        /** JSON: "database", "s3", "filesystem". */
        @JsonValue
        public String json() {
            return name().toLowerCase();
        }

        @JsonCreator
        public static Type fromJson(String value) {
            return value == null ? null : valueOf(value.trim().toUpperCase());
        }
    }

    @Column(nullable = false, length = 100)
    public String name;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    public Type type;

    @Column(length = 500)
    public String description;

    @Column(name = "created_at", nullable = false)
    public Instant createdAt;

    /** Who added it: the email of the signed-in user, else the subject; null when authentication is off. */
    @Column(name = "created_by", length = 320)
    public String createdBy;

    @Column(name = "created_by_name", length = 200)
    public String createdByName;

    @Embedded
    @AttributeOverride(name = "engine", column = @Column(name = "db_engine", length = 40))
    @AttributeOverride(name = "host", column = @Column(name = "db_host", length = 255))
    @AttributeOverride(name = "port", column = @Column(name = "db_port"))
    @AttributeOverride(name = "database", column = @Column(name = "db_database", length = 200))
    @AttributeOverride(name = "username", column = @Column(name = "db_username", length = 200))
    @AttributeOverride(name = "password", column = @Column(name = "db_password", length = 500))
    public DatabaseAccess database;

    @Embedded
    @AttributeOverride(name = "bucket", column = @Column(name = "s3_bucket", length = 255))
    @AttributeOverride(name = "region", column = @Column(name = "s3_region", length = 40))
    @AttributeOverride(name = "endpoint", column = @Column(name = "s3_endpoint", length = 500))
    @AttributeOverride(name = "prefix", column = @Column(name = "s3_prefix", length = 1000))
    @AttributeOverride(name = "accessKeyId", column = @Column(name = "s3_access_key_id", length = 200))
    @AttributeOverride(name = "secretAccessKey", column = @Column(name = "s3_secret_access_key", length = 500))
    public S3Access s3;

    @Embedded
    @AttributeOverride(name = "path", column = @Column(name = "fs_path", length = 1000))
    public FilesystemAccess filesystem;

    /** The newest first, at most {@code limit}. */
    public static List<DataSource> newest(int limit) {
        return findAll(Sort.descending("createdAt", "id")).page(0, limit).list();
    }

    public static boolean nameTaken(String name) {
        return count("lower(name)", name.toLowerCase()) > 0;
    }

    /** A database: engine (postgresql, mysql, ...), host and port, the database, a user and its password. */
    @Embeddable
    public static class DatabaseAccess {
        public String engine;
        public String host;
        public Integer port;
        public String database;
        public String username;
        public String password;
    }

    /** An S3 bucket: the bucket and region, an endpoint for S3-compatible stores, a prefix, a key pair. */
    @Embeddable
    public static class S3Access {
        public String bucket;
        public String region;
        public String endpoint;
        public String prefix;
        public String accessKeyId;
        public String secretAccessKey;
    }

    /** A folder the API can reach. */
    @Embeddable
    public static class FilesystemAccess {
        public String path;
    }
}
