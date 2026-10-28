package datyx.auth;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.config.inject.ConfigProperty;

/**
 * Authentication, OpenID Connect with Google first:
 * GET /api/auth/config, public, is what the apps need to sign the user in:
 * {"enabled":true,"issuer":"https://accounts.google.com","clientId":"..."}
 * (enabled false, and no client id, when OIDC_CLIENT_ID is not set);
 * GET /api/me answers who the bearer token says is calling, a 401 without
 * one once authentication is on, {"authenticated":false} while it is off.
 */
@Path("/api")
@Produces(MediaType.APPLICATION_JSON)
public class AuthResource {

    @ConfigProperty(name = AuthConfigSourceFactory.ENABLED, defaultValue = "false")
    boolean enabled;

    @ConfigProperty(name = "datyx.oidc.issuer")
    String issuer;

    @ConfigProperty(name = AuthConfigSourceFactory.CLIENT_ID)
    Optional<String> clientId;

    @Inject
    CurrentUser user;

    @GET
    @Path("/auth/config")
    public Map<String, Object> config() {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("enabled", enabled);
        map.put("issuer", issuer);
        map.put("clientId", enabled ? clientId.orElse(null) : null);
        return map;
    }

    @GET
    @Path("/me")
    public Map<String, Object> me() {
        return user.describe();
    }
}
