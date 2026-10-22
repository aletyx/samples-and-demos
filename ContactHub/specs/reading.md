# Reading with a local model

Before anything is decided, the request is read on the machine that runs
the API, by a small open model through [Ollama](https://ollama.com):
qwen3:1.7b by default. It answers the routing model's questions about
the message; nothing else of the message is interpreted anywhere. aityx
then decides from its answers (see [Routing](routing.md)).

## The call

[lib/reading.dart](../contacthub_api/lib/reading.dart) builds one call
to Ollama's `POST /api/chat`:

- `model`: `OLLAMA_MODEL` (default `qwen3:1.7b`).
- `messages`: a system prompt, then the message as the user's turn. The
  prompt is written out from the `questions` of
  [models/routing.json](../contacthub_api/models/routing.json): under
  the name of each fact, the question's `instructions` and its
  `criteria`, one `- key: ...` line each, in plain words; the
  confidence is asked in percent. It opens with "You read messages sent
  to a large online store's contact desk..." and asks for a JSON object
  only.
- `format`: a JSON schema that Ollama enforces as the model writes, so
  the answer can only be `topic` (one of the topic question's criteria,
  `other` included), `topic_confidence` (an integer, 0 to 100),
  `urgent_probability`, `sensitive_data_probability` and
  `abusive_probability` (numbers, 0 to 1) and `request_kind` (one of its
  criteria), all required. No free text is parsed.
- `options.temperature` 0, so the same message reads the same way every
  time; `think` false, so a reasoning model such as qwen3 answers
  directly; `stream` false; `keep_alive` 30 minutes, so the model stays
  in memory between requests.

The API reads `message.content` back as JSON and checks it against the
schema it sent (`factsFrom`): a choice must be in its list, a number is
clamped to 0..1, the confidence is divided by 100. Anything else is a
`ReadingFailed`, answered 502. These six facts, with the message, today
and the order, become the state of the routing model.

The first call after Ollama starts loads the model into memory (a second
or two for qwen3:1.7b); later ones read a message in well under a second
on a laptop (about 0.7 s on an M-series Mac, 900 prompt tokens, 50
answer tokens). The API waits up to 120 s for Ollama.

## Which model

Any model Ollama runs and that follows a JSON schema works; set
`OLLAMA_MODEL` (see [Development environment](dev-environment.md)). On
the 27 samples (see [Request box](request.md#samples)), with the prompt
as it is:

| Model | Size | Routed as the sample says | Reading time |
|---|---|---|---|
| qwen3:1.7b (default) | 1.4 GB | 22 of 27 | 0.7 s |
| qwen3:4b | 2.5 GB | 25 of 27 | 1.7 s |

qwen3:1.7b reads every order sample and both check samples right (the
card number and the abuse are flagged, the request kinds match the
policy outcomes); what it misses are the rarer departments: a
pre-purchase product question (Customer Service), a would-be supplier
(Seller Services), a shareholder (Business Sales), a price-drop refund
(Billing & Payments) and a vague "hello?" (Customer Service, where the
rules want General Inquiries). Its topic confidence is coarse, 100 or 50
or 0, and its probabilities are mostly 0 or 1. qwen3:4b gets the
departments but mistakes the double charge for Customer Service. The
order of the questions matters to a model this small: the topic first,
then the yes/no questions, then the request kind read best; asking the
confidence in percent rather than 0..1 stopped it answering 0 for topics
it had right.

## On the routing screen

**Read on this machine**, the first card after the message: the model's
name and how long it took (with the loading time when the model wasn't
in memory), what it read (the topic and how sure, in percent; what the
customer wants; the flags raised, or none), each with links to its row in
the local call's answer and to its input in the aityx request, and links
to the prompt, the schema, the whole answer and the facts sent to aityx.
The call itself is the first pane under **Behind the routing** (see
[Routing](routing.md#the-calls)).

## Verified

The 27 samples were routed through the running API with qwen3:1.7b and
qwen3:4b (`dart run tool/route_samples.dart` in `contacthub_app/`, which
routes every sample through a running API and compares the department
with the sample's label; the table above is its output). Tests use the
real answers of the API for the tablet, the jacket, the late lamp, the
abusive message and the card number, read by qwen3:1.7b and decided by
aityx, as fixtures.

## Known limitations

- A 1.7B-parameter model misreads some messages, see the table: a larger
  model reads better and slower. The rules never vary.
- English only, as the questions are.
- The prompt is regenerated on every call; Ollama caches the prompt's
  prefix only while the model is loaded.
- No GPU in the Docker Compose and codespace setups: Ollama runs on the
  CPU there, and a reading takes a few seconds.
