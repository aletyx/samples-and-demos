# Request log

Requests that shaped the specification, oldest first. Each entry summarizes
what was asked and what changed. See [README.md](README.md) for the current
spec.

## 2026-10-13

1. **Create the Mortgage Hub app, following Presence's project structure,
   with only a welcome page.** Added the Flutter app (`mortgagehub_app`:
   web, Android, iOS, Linux) with a [welcome page](welcome.md) in the
   Gruvbox [theme](theme.md); devbox, process-compose (the web server and
   the health monitor), the build scripts, the Makefile, versioning and
   the dev container ([Development environment](dev-environment.md));
   this specification, CLAUDE.md and AGENTS.md. Presence's backend, cloud
   and deploy parts weren't copied.
2. **Use port 8880 for the web app.** The dev server
   (`FLUTTER_WEB_PORT`), its readiness probe, the health check and the dev
   container's forwarded port now default to 8880 instead of 8080, so it
   runs beside Presence's dev server.
3. **Add a button to request a mortgage proposal, with the details a US
   quote needs.** Researched what a US lender needs (Regulation Z's
   application and Loan Estimate, the agencies' pricing factors,
   Regulation B's limits on what may be asked). Added the
   [proposal request](proposal-request.md): the welcome page's button, a
   form in three sections (the loan, the property, the borrower) with its
   validation, and a summary with the loan amount, LTV and DTI. It asks
   for no SSN, so it stays a quote request, not an application.
4. **Replace Flutter's default favicon with one for the app.** Drew the
   [app icon](app-icon.md), a yellow house with a dollar sign on the
   Gruvbox background, as SVG masters, and generated the favicon, the web
   icons and the Android and iOS icons from them with
   `flutter_launcher_icons`, as Presence does.
5. **Add a "Fill random" button that fills the proposal form with random
   data, using a good Dart faker.** Added the `faker` package and
   [Fill random](proposal-request.md#fill-random) to the form's app bar:
   random, valid requests with fake contact details (example.com emails,
   555-01xx phones).
6. **Integrate with aityx.ai; for now, only check the integration works.**
   Saved the key to `.env` as `AITYX_API_KEY` (git-ignored, mode 600),
   documented it and `AITYX_URL` in `.env.example`, and added
   [scripts/aityx-check.sh](../scripts/aityx-check.sh), which runs the
   docs' example on System One. See [aityx.ai](aityx.md). The check hasn't
   run yet: which API host the stage key belongs to is unconfirmed.
7. **Check with aityx whether the proposal is valid and processable under
   current US mortgage rules, in a new section of the requested proposal.**
   Researched the current rules (Fannie Mae's Eligibility Matrix of August
   2026, the 2026 FHFA and FHA loan limits, FHA, VA and USDA eligibility,
   DTI limits) and wrote them as an aityx decision model. Added the API
   (`mortgagehub_api`, a Dart server holding the key) and the summary's
   [regulatory check](regulatory-check.md) section. Found the stage key's
   API host (`console-stage.aityx.ai`; production answers 401) and
   verified the check end to end.
8. **Add tooltips to the uncommon form fields.** ⓘ icons with an
   explanation on the less common fields of the
   [proposal request](proposal-request.md), none on plain ones like the
   name.
9. **Have Fill random leave optional fields empty at random.** HOA dues
   are now random too (taxes, insurance and savings already were).
10. **Merge, rebuild and restart.** Before merging, fixed the code
    review's findings: the rules compared a rounded LTV and DTI (97.0002%
    passed a 97% maximum), so the model now compares exact values and the
    API rounds them for display; release Android builds lacked the
    INTERNET permission; the app's HTTP client was never closed; the web
    app couldn't reach the API behind a forwarded port, so the dev server
    now proxies `/api/` on the app's own origin; and nothing tested the
    rules, so `scripts/model-test.sh` runs them on aityx with expected
    verdicts at each boundary. The app's name on Android and iOS is now
    Mortgage Hub.
