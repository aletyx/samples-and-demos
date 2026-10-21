# Welcome page

[WelcomeScreen](../contacthub_app/lib/welcome/welcome_screen.dart) is the
app's home. Centered, at most 480 px wide:

- a speech-bubbles icon (`Icons.forum_outlined`) in the theme's primary
  color;
- **Welcome to Contact Hub**, bold;
- "Ask anything, and we get it to the right person.", muted;
- a **Say hello** button, which opens the [Hello page](hello.md);
- the build's version, `X.Y.Z` (see
  [Development environment](dev-environment.md)), small and faint, only
  when the build sets `CONTACTHUB_VERSION`.

The browser tab, the web app's manifest, and the Android, iOS and Linux
app names say **Contact Hub**.

## Known limitations

- English only.
- No sign-in.
- The app icon is Flutter's default.
