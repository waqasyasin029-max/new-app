import 'dart:convert';

import 'package:http/http.dart' as http;

class ElevenVoice {
  ElevenVoice({
    required this.id,
    required this.name,
    this.gender = '',
    this.description = '',
    this.previewUrl = '',
    this.ownerId = '',
    this.language = '',
  });

  final String id;
  final String name;
  final String gender;
  final String description;
  final String previewUrl;

  /// Set for voices from the public library that are not in the account yet.
  final String ownerId;
  final String language;

  bool get isLibrary => ownerId.isNotEmpty;
}

class VoiceApiError implements Exception {
  VoiceApiError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lists and adds voices through the ElevenLabs API.
class ElevenVoicesService {
  static const _base = 'https://api.elevenlabs.io/v1';

  static Map<String, String> _headers(String key) => {
    'xi-api-key': key.trim(),
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
  };

  static Never _fail(http.Response r) {
    final c = r.statusCode;
    if (c == 401 || c == 403) {
      throw VoiceApiError(
        'This key cannot list voices. Create a key with all permissions (at least Voices read and write, and Text to Speech).',
      );
    }
    if (c == 402) {
      throw VoiceApiError(
        'Your ElevenLabs plan does not allow this. Pick one of your own voices.',
      );
    }
    if (c == 429) {
      throw VoiceApiError('Too many requests. Try again in a minute.');
    }
    throw VoiceApiError('ElevenLabs error ($c). Try again.');
  }

  static Future<http.Response> _get(String key, Uri uri) async {
    try {
      return await http
          .get(uri, headers: _headers(key))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw VoiceApiError('No internet or ElevenLabs is slow. Try again.');
    }
  }

  static String _s(Object? v) => v is String ? v : '';

  /// Voices already in the account (includes the ready-made ones).
  static Future<List<ElevenVoice>> mine(String key) async {
    final r = await _get(key, Uri.parse('$_base/voices'));
    if (r.statusCode != 200) _fail(r);
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    final list = data is Map ? data['voices'] : null;
    final out = <ElevenVoice>[];
    if (list is List) {
      for (final v in list) {
        if (v is! Map) continue;
        final id = _s(v['voice_id']);
        if (id.isEmpty) continue;
        final labels = v['labels'] is Map ? v['labels'] as Map : const {};
        final bits = [
          _s(labels['accent']),
          _s(labels['age']),
          _s(labels['descriptive']),
          _s(labels['description']),
          _s(labels['use_case']),
        ].where((e) => e.isNotEmpty).join(', ');
        out.add(
          ElevenVoice(
            id: id,
            name: _s(v['name']).isEmpty ? id : _s(v['name']),
            gender: _s(labels['gender']).toLowerCase(),
            description: bits.isNotEmpty ? bits : _s(v['description']),
            previewUrl: _s(v['preview_url']),
          ),
        );
      }
    }
    return out;
  }

  /// Public library voices for a language, for example Urdu.
  static Future<List<ElevenVoice>> library(
    String key, {
    String language = 'ur',
    String gender = '',
    String search = '',
  }) async {
    final q = <String, String>{
      'page_size': '30',
      'language': language,
      if (gender.isNotEmpty) 'gender': gender,
      if (search.trim().isNotEmpty) 'search': search.trim(),
    };
    final r = await _get(
      key,
      Uri.parse('$_base/shared-voices').replace(queryParameters: q),
    );
    if (r.statusCode != 200) _fail(r);
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    final list = data is Map ? data['voices'] : null;
    final out = <ElevenVoice>[];
    if (list is List) {
      for (final v in list) {
        if (v is! Map) continue;
        final id = _s(v['voice_id']);
        final owner = _s(v['public_owner_id']);
        if (id.isEmpty || owner.isEmpty) continue;
        final bits = [
          _s(v['accent']),
          _s(v['age']),
          _s(v['descriptive']),
          _s(v['use_case']),
        ].where((e) => e.isNotEmpty).join(', ');
        out.add(
          ElevenVoice(
            id: id,
            name: _s(v['name']).isEmpty ? id : _s(v['name']),
            gender: _s(v['gender']).toLowerCase(),
            description: bits.isNotEmpty ? bits : _s(v['description']),
            previewUrl: _s(v['preview_url']),
            ownerId: owner,
            language: _s(v['language']),
          ),
        );
      }
    }
    return out;
  }

  /// Adds a library voice to the account and returns its id there.
  static Future<String> add(String key, ElevenVoice v) async {
    final http.Response r;
    try {
      r = await http
          .post(
            Uri.parse('$_base/voices/add/${v.ownerId}/${v.id}'),
            headers: _headers(key),
            body: utf8.encode(jsonEncode({'new_name': v.name})),
          )
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      throw VoiceApiError('No internet or ElevenLabs is slow. Try again.');
    }
    if (r.statusCode != 200) {
      if (r.statusCode == 400 || r.statusCode == 422) {
        throw VoiceApiError(
          'Could not add this voice. Your voice slots may be full, or this voice is not available on your plan.',
        );
      }
      _fail(r);
    }
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    final id = data is Map ? _s(data['voice_id']) : '';
    return id.isEmpty ? v.id : id;
  }
}
