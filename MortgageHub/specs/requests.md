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
11. **Add a button to show or hide the aityx request and response at the
    end of the regulatory check.** The API now returns the body it sent to
    aityx and aityx's answer with the check, and the
    [regulatory check](regulatory-check.md) ends with **Show / Hide aityx
    request and response**, showing both as JSON.
12. **Make Fill random a split button: click it, or pick the data to
    generate: Processable, Requires review or Not processable.** Added
    the menu and a generator that builds a request for each verdict
    ([Fill random for a verdict](proposal-request.md#fill-random-for-a-verdict)),
    checked live against aityx. The verdict label "Needs review" is now
    "Requires review" everywhere.

## 2026-10-15

13. **Move the Mortgage Hub dev container to the root of the repository,
    under a folder called Mortgage Hub, so people can see which app they
    are launching on Codespaces; and pass the user's own API key in.**
    GitHub only looks for dev containers at the repository root, so
    `MortgageHub/.devcontainer/` moved to
    [.devcontainer/Mortgage Hub/](../../.devcontainer/Mortgage%20Hub) and
    the configuration is now named **Mortgage Hub**, which is
    what the Codespaces configuration list shows in a repository holding
    several samples. The Containerfile no longer assumes the repository is
    the app (its `WORKDIR` named a path that only existed in a standalone
    repository), the build context is the dev container folder alone since
    nothing is copied in, and `post-create.sh` resolves `MortgageHub/`
    from its own location. `devcontainer.json` declares `AITYX_API_KEY` as a
    Codespaces `secret`, so GitHub asks each person for their own key and
    passes it in as an environment variable, which the scripts already
    prefer over `.env`; the repository ships no key and nothing is written
    to disk in the container. `post-create.sh` reports whether the key arrived, never its
    value. See [Development environment](dev-environment.md) and
    [aityx.ai](aityx.md).

14. **Add a link to launch a codespace with 4 cores, ask only for the API
    key, default to aityx.ai, say before the launch button how to set the
    key up and that it is required, and describe the project in the dev
    container profile.** The [README](../README.md#run-it-in-a-codespace)
    now opens with how to add the `AITYX_API_KEY` Codespaces secret and
    why it is required, then an **Open in GitHub Codespaces** badge that
    pins this configuration and a 4-core machine
    (`machine=standardLinux32gb`). `devcontainer.json` asks for the key
    alone: `AITYX_URL` already defaults to `https://api.aityx.ai` and
    `ASSUMED_RATE` to 6.5 (the annual rate, in percent, behind the
    summary's payment estimate), so neither needs setting, and both stay
    overridable in `.env`. The configuration is named **Mortgage Hub** and
    carries a header describing the project with links to the repository,
    aityx.ai, aletyx.com and nu01.com.

15. **Take a look at the Greptile suggestions and fix.** Both findings on
    [Fill random for a verdict](proposal-request.md#fill-random-for-a-verdict)
    were valid. The processable generator can build a VA loan of up to
    $855,000, above the $832,750 conforming baseline, and that is correct:
    VA has no loan limit with full entitlement, so the model passes any VA
    amount. The test applied the baseline to every program, so a valid VA
    sample failed it — reproduced at seed 27, which builds an $834,000 VA
    loan. The assertion now skips VA, and the generator and this spec say
    why. Nothing checked the ratio `fitIncome` works back from the payment
    either, so four offline tests now recompute it at 6.5% from the
    finished request: that processable drafts land in the 20 to 36% they
    aim for and stay under 45%, that a targeted high ratio really does
    breach Fannie Mae's 50%, and that a targeted review ratio lands
    between the two maximums. Both were checked by mutation.
