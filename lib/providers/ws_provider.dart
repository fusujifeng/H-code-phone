import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ws_client.dart';

final wsClientProvider = ChangeNotifierProvider<WsClient>((ref) {
  return WsClient();
});
