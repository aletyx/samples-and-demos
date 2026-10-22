/// Reading a request with the local model: the chat request sent to Ollama,
/// built from the questions in models/routing.json, and the facts read back
/// from the model's answer, apart from the HTTP plumbing in bin/server.dart
/// so it can be tested without a server or a model.
///
/// The local model reads; it never decides. Its answers become the state of
/// the routing model, which aityx runs (lib/routing.dart).
library;

import 'dart:convert';

/// Where Ollama answers, and which model reads, unless the environment
/// says otherwise (OLLAMA_URL, OLLAMA_MODEL).
const defaultOllamaUrl = 'http://127.0.0.1:11434';
const defaultLocalModel = 'qwen3:1.7b';

/// The facts the local model reads, in the order it answers them: the
/// routing model's inputs of the same names. The topic first: with it
/// settled, a small model keeps the yes/no questions apart better (the
/// order was tried both ways on the samples).
const factNames = [
  'topic',
  'topic_confidence',
  'urgent_probability',
  'sensitive_data_probability',
  'abusive_probability',
  'request_kind',
];

/// The local model answered, but not with a reading.
class ReadingFailed implements Exception {
  ReadingFailed(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The body sent to Ollama's /api/chat: the prompt built from the
/// `questions` of [model] (models/routing.json), the [message], and the
/// JSON schema the answer must follow, so the model can only pick a topic
/// and a request kind from the lists, and probabilities between 0 and 1.
/// Temperature 0, so the same message reads the same way every time;
/// thinking off, so a reasoning model such as qwen3 answers directly.
Map<String, Object?> readingRequest(
  Map<String, Object?> model,
  String message, {
  String localModel = defaultLocalModel,
}) {
  final questions = (model['questions'] as Map).cast<String, Object?>();
  return {
    'model': localModel,
    'messages': [
      {'role': 'system', 'content': readingPrompt(questions)},
      {'role': 'user', 'content': message},
    ],
    'format': readingSchema(questions),
    'options': {'temperature': 0},
    'think': false,
    'stream': false,
    'keep_alive': '30m',
  };
}

/// The system prompt: each question's instructions and criteria, in plain
/// words, under the name of the fact it answers.
String readingPrompt(Map<String, Object?> questions) {
  String criteria(String name) {
    final question = questions[name] as Map;
    final criteria = (question['criteria'] as Map).entries;
    return criteria.map((c) => '- ${c.key}: ${c.value}').join('\n');
  }

  String ask(String name) => (questions[name] as Map)['instructions'] as String;

  String probability(String name) =>
      '$name: ${ask(name)} The probability, from 0 to 1.\n${criteria(name)}';

  return [
    "You read messages sent to a large online store's contact desk and "
        'answer questions about each one. Answer with a JSON object only, '
        'no explanation.',
    'topic: ${ask('topic')} One of:\n${criteria('topic')}',
    'topic_confidence: how sure you are of the topic, in percent: 100 when '
        'the message plainly belongs to that department, 50 when another '
        'could handle it, 0 when it is a guess.',
    probability('urgent_probability'),
    probability('sensitive_data_probability'),
    probability('abusive_probability'),
    'request_kind: ${ask('request_kind')} One of:\n${criteria('request_kind')}',
  ].join('\n\n');
}

/// The JSON schema of the answer, which Ollama enforces while the model
/// writes: the choices are the questions' criteria, the numbers 0 to 1.
Map<String, Object?> readingSchema(Map<String, Object?> questions) {
  List<String> choices(String name) => [
    for (final key in ((questions[name] as Map)['criteria'] as Map).keys)
      '$key',
  ];
  const unit = {'type': 'number', 'minimum': 0, 'maximum': 1};
  return {
    'type': 'object',
    'properties': {
      'topic': {'type': 'string', 'enum': choices('topic')},
      'topic_confidence': {'type': 'integer', 'minimum': 0, 'maximum': 100},
      'urgent_probability': unit,
      'sensitive_data_probability': unit,
      'abusive_probability': unit,
      'request_kind': {'type': 'string', 'enum': choices('request_kind')},
    },
    'required': factNames,
  };
}

/// The facts in Ollama's [answer] to [sent]: its message's content, parsed
/// and checked against the schema that was sent (a choice must be one of
/// the list; a probability is a number, clamped to 0..1). Throws
/// [ReadingFailed] otherwise.
Map<String, Object?> factsFrom(
  Map<String, Object?> sent,
  Map<String, Object?> answer,
) {
  final content = (answer['message'] as Map?)?['content'];
  if (content is! String || content.trim().isEmpty) {
    throw ReadingFailed('the local model gave no answer');
  }
  final Object? parsed;
  try {
    parsed = jsonDecode(content);
  } on FormatException {
    throw ReadingFailed('the local model did not answer in JSON');
  }
  if (parsed is! Map) throw ReadingFailed('the local model answered no object');
  final facts = parsed.cast<String, Object?>();
  final properties = ((sent['format'] as Map)['properties'] as Map);

  String choice(String name) {
    final value = facts[name];
    final allowed = (properties[name] as Map)['enum'] as List;
    if (value is! String || !allowed.contains(value)) {
      throw ReadingFailed('$name is not one of ${allowed.join(', ')}: $value');
    }
    return value;
  }

  double unit(String name) {
    final value = facts[name];
    if (value is! num) throw ReadingFailed('$name is not a number: $value');
    return value.clamp(0, 1).toDouble();
  }

  double percent(String name) {
    final value = facts[name];
    if (value is! num) throw ReadingFailed('$name is not a number: $value');
    return (value.clamp(0, 100) / 100).toDouble();
  }

  return {
    'topic': choice('topic'),
    'topic_confidence': percent('topic_confidence'),
    'urgent_probability': unit('urgent_probability'),
    'sensitive_data_probability': unit('sensitive_data_probability'),
    'abusive_probability': unit('abusive_probability'),
    'request_kind': choice('request_kind'),
  };
}

/// Whether [tags], Ollama's /api/tags answer, lists [localModel]; a name
/// without a tag means `:latest`, as Ollama's does.
bool listsModel(Object? tags, String localModel) {
  final wanted = localModel.contains(':') ? localModel : '$localModel:latest';
  final models = tags is Map ? tags['models'] : null;
  if (models is! List) return false;
  return models.any((m) => m is Map && m['name'] == wanted);
}
