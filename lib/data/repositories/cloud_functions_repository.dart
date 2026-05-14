import 'package:cloud_functions/cloud_functions.dart';

class CloudFunctionsRepository {
  CloudFunctionsRepository([FirebaseFunctions? functions])
      : _fn = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _fn;

  Future<String> musicAgentKeywords(String prompt) async {

    print('DEBUG functions app: ${_fn.app.name}');
    print('DEBUG callable: ${_fn.httpsCallable('musicAgent')}');

    final callable = _fn.httpsCallable('musicAgent');
    final res = await callable.call<Map<String, dynamic>>({'prompt': prompt});
    final data = res.data;
    final keywords = data['keywords'];
    if (keywords is String) return keywords;
    return '';
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
