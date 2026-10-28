package datyx;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.CoreMatchers.nullValue;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

/** Without OIDC_CLIENT_ID authentication is off: every path is open and nobody is signed in. */
@QuarkusTest
class AuthOffTest {

    @Test
    void reportsAuthenticationOff() {
        given()
            .when().get("/api/auth/config")
            .then()
            .statusCode(200)
            .body("enabled", is(false))
            .body("issuer", is("https://accounts.google.com"))
            .body("clientId", nullValue());
    }

    @Test
    void nobodyIsSignedIn() {
        given()
            .when().get("/api/me")
            .then()
            .statusCode(200)
            .body("authenticated", is(false));
    }
}
