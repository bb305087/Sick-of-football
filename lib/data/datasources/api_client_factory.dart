import 'package:http/http.dart' as http;

import 'api_client_factory_stub.dart'
    if (dart.library.io) 'api_client_factory_io.dart' as platform;

http.Client createApiClient() => platform.createApiClient();
