# Requests

The requests that shaped Contact Hub, oldest first, each with what changed.
The feature files hold the current specification; see the
[index](README.md).

## 2026-10-21

1. **Start Contact Hub, a new sample in this repository, following
   Mortgage Hub's standards and patterns: an app where someone can ask
   anything and it's routed to the right department or person, with
   validations. For now a static index page and a hello-world page, with
   a dev container and a devbox configuration, so the scaffolding can be
   launched and tested in a codespace and on a local machine.** Added
   `ContactHub/`: the Flutter app (`contacthub_app`, web, Android, iOS and
   Linux) with a [welcome page](welcome.md) and a Hello page
   that shows the API's greeting; a Dart API (`contacthub_api`) with
   `/api/hello` and `/api/health`; devbox, process-compose and the health
   monitor, the Makefile, Docker Compose, and the dev container in
   `.devcontainer/ContactHub/`, all as Mortgage Hub has them (see
   [Development environment](dev-environment.md)). Ports 8890 and 8891,
   so it runs alongside Mortgage Hub. The [theme](theme.md) is the aityx
   palette. No aityx key yet: nothing calls aityx.
2. **Use the same aityx key as Mortgage Hub, copied from our GitHub.**
   GitHub never returns a secret's value, so the key can't be copied, and
   it doesn't need to be: Codespaces secrets belong to a user and are
   granted per repository, and Contact Hub is in the same repository. The
   dev container now declares the same `AITYX_API_KEY` secret, so a key
   already granted to this repository for Mortgage Hub reaches it.
   `post-create.sh` and the start-up log say whether it arrived; the API
   reads `AITYX_API_KEY` and `AITYX_URL` (from the environment, else
   `.env`; see `.env.example`), Docker Compose passes them to the API
   only, and `/api/health` and the health monitor's 🤖 aityx say whether
   the key is set. Nothing calls aityx yet. See
   [Development environment](dev-environment.md).
3. **Generate a cool icon.** An orange speech bubble with a route cut
   into it that branches three ways, the chosen branch lit white, in the
   aityx palette; generated for web, Android and iOS from SVG masters with
   `flutter_launcher_icons`, as Mortgage Hub's. See
   [App icon](app-icon.md).
4. **When the health check starts, print the address to access the app,
   then wait about 5 seconds before checking.** The health monitor now
   prints `http://localhost:8890/app/` and, in a codespace, the forwarded
   URL, then waits `HEALTH_CHECK_DELAY` (5 s) before its first check. See
   [Development environment](dev-environment.md).

## 2026-10-21 (later)

5. **Add a text box where the user types their request, with a recording
   icon beside it to dictate it; run efficient voice recognition in the
   browser, client-side if possible, and process the request later.**
   The welcome page now has the [request box](request.md): **Your
   request**, a microphone button beside it, a status line and **Send**,
   which for now only confirms the request was received. Speech is
   recognized on the device only: the Web Speech API with
   `processLocally = true` where the browser has it (Chrome, Edge),
   installing the language pack on first use, with words appearing live;
   else Moonshine tiny, run by transformers.js 4.3.1 in a Web Worker on
   WebGPU or WASM, transcribing when you stop. The server-based Web Speech
   mode is never used. **Say hello** became a link under the box. No voice
   input in the Android, iOS and Linux apps yet.
6. **Remove the Hello feature, which was only there to get started.**
   Removed the Hello page and its greeter from the app, with the **Say
   hello** link and the `http` package only it used, and `GET /api/hello`
   from the API. The API stays, with `/` and `/api/health` and the aityx
   key, for routing; its spec moved from `hello.md` to [API](api.md).
7. **Add routing: with aityx and Jev, classify the text and route it to
   the appropriate person (orders to Customer Service, product questions
   to Marketing, job applications to HR, and so on), with all the usual
   departments of a large online store. Show the request to aityx and its
   response, as Mortgage Hub does but better: larger, with navigation
   buttons that go exactly to the part of the JSON for each item.**
   **Send** now opens the [routing](routing.md): the API's new
   `POST /api/route` makes one System One call, where Jev answers four
   questions about the message (the topic, as a choice among 13
   departments' topics, and urgency, sensitive data and abuse) and
   `models/routing.json` picks the department, the priority, the hours to
   answer and whether a person reviews it first. Each department has a
   (made-up) person. The screen shows the result, each item with links to
   exactly its JSON (down to the table row that fired), and the aityx
   call in a new viewer: request and response, 14 px Roboto Mono with line
   numbers and colors, three quarters of the window high, full screen on
   demand, and a **Jump to** bar; every jump lands the value's first line
   at the top and marks and explains the value. The key was copied into
   `ContactHub/.env` from Mortgage Hub's (git-ignored), to test against
   the live API.
8. **Add a drop-down of sample complaints to send instead of saying or
   typing them, one for each department.** **Try a sample**, beside
   **Send**, lists one request for each of the 13 departments and two
   for the checks (a card number, an abusive message); picking one fills
   the field. All 15 were routed where expected through the live API. See
   [Request box](request.md#samples).
9. **Fix what the code review found, and never say "Jev" in the app,
   always "aityx".** The app's text, and the routing model's own
   descriptions shown in its JSON, now say aityx; only aityx's own
   identifiers keep the name (`"model": "jev-latest"`, the
   `jev:/answers/...` binding, and `"source": "jev"` in aityx's receipt).
   Fixed: the field is read-only while dictating, and a dictation stopped
   for a sample can no longer overwrite it; a speech model that fails to
   load ends the dictation with an error instead of a spinner that never
   stops; Android release builds get the internet permission; full screen
   opens where the view was scrolled and keeps room for the code on short
   windows; the API's 90 s deadline covers aityx's whole answer and aborts
   the call, and nginx waits 100 s.
10. **Add dates, numbers and figures to the sample requests and to the
    rules, with the usual commerce rules (for example, no automatic refund
    more than a month after the purchase); be creative.** aityx's
    questions can't read numbers, so the API now has an order book of
    made-up orders, dated back from today, and sends the order a message
    names, and today, with each call. A new question asks what the
    customer wants done with their order, and the model applies the
    [store's policy](order-policy.md): refund within 30 days, store
    credit within 60, final sale, damage within 7 days, a 1-year warranty
    on electronics, a 15% restocking fee on electronics after 14 days, a
    person above $500, price drops within 14 days, cancellation before
    shipping, late packages after 10 days, double charges; with the
    amount and the date it's paid by. The routing screen shows **The
    store's policy** with the order's facts and links to the rules that
    fired. **Try a sample** leads with one sample per outcome, and the
    others carry dates and figures. Two topics were sharpened so a broken
    item bought here is a warranty claim, Customer Service's.
11. **Fix what the code review found on the order policy.** The amount
    rule that fired gets its own **Jump to** entry, with its explanation.
    `scripts/model-test.sh` now runs the rules themselves on aityx, with
    fixed facts at each limit of the policy, so a changed window or fee
    fails a test (see [Order policy](order-policy.md#verified)).
