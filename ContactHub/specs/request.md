# Request box

Where someone says what they need: typed, or dictated with the
microphone beside the field. It's on the [welcome page](welcome.md).
Nothing processes the request yet; routing comes next.

## The box

[RequestBox](../contacthub_app/lib/request/request_box.dart):

- **Your request**, a text field of three to six lines. Its hint says
  "What do you need? Type it, or tap the mic and say it." where voice
  input works, and "What do you need?" where it doesn't.
- **The microphone**, to the field's right, only where voice input works:
  a mic to start; a red stop button while listening; a spinner while the
  speech model downloads (showing its progress when known), while the
  microphone starts, and while the recording is transcribed.
- A **status line** under the field: "Downloading the speech model, 42%
  (first time only)…", "Preparing speech recognition on this device (first
  time only)…", "Starting the microphone… allow it if your browser asks.",
  "Listening… tap the stop button when you're done.", "Turning your words
  into text…", or why dictation failed (in the error color), such as
  "Microphone access was denied."
- **Send**, enabled when the field has text and no dictation is running.
  It hands the trimmed text on; the welcome page answers with a snack bar,
  "Got your request. Routing it comes next."

Dictated words go after whatever is already typed, separated by a space.
With on-device speech they appear live as you speak; with the model,
when you stop.

## Voice input, on the device only

No audio leaves the device: recognition runs in the browser.
[voice.js](../contacthub_app/web/voice/voice.js), loaded by `index.html`
before the app, exposes `window.contactHubVoice` (`engine()`, `start()`,
`stop()`), which the app reaches through `dart:js_interop`
([voice_input_web.dart](../contacthub_app/lib/request/voice_input_web.dart)).
It uses the first engine the browser has, in English (`en-US`):

1. **On-device speech** (`local-speech`): the Web Speech API with
   `processLocally = true`, in Chrome and Edge. `SpeechRecognition.available()`
   says whether it can run here; when the language pack is only
   downloadable, the first dictation installs it with
   `SpeechRecognition.install()`. Continuous, with interim results, so the
   words show as they're recognized.
2. **Moonshine tiny** (`model`): a speech model built for edge devices,
   run by [transformers.js](https://huggingface.co/docs/transformers.js)
   4.3.1 in a module Web Worker
   ([moonshine-worker.js](../contacthub_app/web/voice/moonshine-worker.js)),
   for browsers without on-device Web Speech (Firefox, Safari). On WebGPU
   it runs the full-precision encoder and a 4-bit decoder (about 76 MB, as
   Hugging Face's Moonshine demo does); otherwise WASM with 8-bit weights
   (about 28 MB). The model downloads on the first dictation, with its
   progress shown, and the browser caches it. The microphone is recorded
   with `MediaRecorder` until you stop, decoded to 16 kHz mono, and
   transcribed in the worker.

The Web Speech API's default mode, which sends audio to a server, is never
used. Add `?voice=model` to the page's URL to force the model. Elsewhere
(Android, iOS, Linux, and tests) there's no voice input
([voice_input_stub.dart](../contacthub_app/lib/request/voice_input_stub.dart)),
so the mic is hidden.

### Verified

In Chrome 155 on macOS, against the running app: the engine is
`local-speech`, and the first dictation installs the English pack, then
asks for the microphone. With `?voice=model`, the model downloads (about
7 s on WebGPU) and the microphone is asked for. Moonshine tiny, through
the worker, transcribed Hugging Face's 11-second JFK sample correctly in
1.8 s on WebGPU. Widget tests cover typing, sending, live dictation after
typed text, the download, start-up and transcription states, and errors.

## Known limitations

- English only; Moonshine is English-only.
- Speaking into either engine hasn't been tested end to end: in the test
  browser, the microphone permission can't be granted.
- The WASM path of the model hasn't been run (the test machine has
  WebGPU).
- The model and the library are fetched from Hugging Face and jsDelivr on
  first use: the audio stays on the device, but those two sites see the
  download.
- No voice input in the Android, iOS and Linux apps yet.
- Nothing is done with a sent request yet.
