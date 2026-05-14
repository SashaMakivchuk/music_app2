import 'package:cloud_functions/cloud_functions.dart';

class CloudFunctionsRepository {
  CloudFunctionsRepository([FirebaseFunctions? functions])
      : _fn = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _fn;

  Future<({String reply, List<String> keywords})> musicAgentKeywords(
      String prompt) async {
    final callable = _fn.httpsCallable('musicAgent');
    final res = await callable.call<Map<String, dynamic>>({'prompt': prompt});
    final data = res.data;
    final reply = data['reply'] is String ? data['reply'] as String : '';
    final kwRaw = data['keywords'];
    final keywords = kwRaw is List
        ? kwRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    return (reply: reply, keywords: keywords);
  }

  Future<List<String>> getRecommendationQueries() async {
    final callable = _fn.httpsCallable('getRecommendations');
    final res = await callable.call<Map<String, dynamic>>();
    final data = res.data;
    final q = data['queries'];
    if (q is List) {
      return q.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }
}
