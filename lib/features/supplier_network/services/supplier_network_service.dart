import 'dart:convert';
import '../../../core/api_client.dart';
import '../../../core/errors/app_error.dart';

class SupplierNetworkService {
  final ApiClient _api=ApiClient();
  Future<Map<String,dynamic>> configuration() => _get('/v2/supplier-network/configuration');
  Future<Map<String,dynamic>> saveConfiguration(bool enabled) => _put('/v2/supplier-network/configuration',{'enabled':enabled});
  Future<List<Map<String,dynamic>>> tenants() => _list('/v2/supplier-network/tenants');
  Future<List<Map<String,dynamic>>> resources({String type='ASSET',String query=''}) => _list('/v2/supplier-network/resources?type=$type&query=${Uri.encodeQueryComponent(query)}');
  Future<List<Map<String,dynamic>>> orders() => _list('/v2/supplier-network/orders');
  Future<Map<String,dynamic>> order(String id) => _get('/v2/supplier-network/orders/$id');
  Future<List<Map<String,dynamic>>> connections() => _list('/v2/supplier-network/connections');
  Future<Map<String,dynamic>> saveConnection(Map<String,dynamic> body) => _post('/v2/supplier-network/connections',body);
  Future<Map<String,dynamic>> respond(String id,String status,{String? note}) => _post('/v2/supplier-network/orders/$id/response',{'status':status,'note':note});
  Future<Map<String,dynamic>> complete(String id) => _post('/v2/supplier-network/orders/$id/complete',{});
  Future<Map<String,dynamic>> invoice(String id) => _post('/v2/supplier-network/orders/$id/invoice',{});
  Future<Map<String,dynamic>> reserve(String id,Map<String,dynamic> body) => _post('/v2/supplier-network/orders/$id/reservations',body);
  Future<Map<String,dynamic>> _get(String p)async{final r=await _api.get(p);if(r.statusCode!=200)throw AppException(r.body);return Map<String,dynamic>.from(jsonDecode(r.body) as Map);}
  Future<List<Map<String,dynamic>>> _list(String p)async{final r=await _api.get(p);if(r.statusCode!=200)throw AppException(r.body);return (jsonDecode(r.body) as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();}
  Future<Map<String,dynamic>> _post(String p,Map<String,dynamic>b)async{final r=await _api.post(p,body:b);if(r.statusCode<200||r.statusCode>=300)throw AppException(r.body);return Map<String,dynamic>.from(jsonDecode(r.body) as Map);}
  Future<Map<String,dynamic>> _put(String p,Map<String,dynamic>b)async{final r=await _api.put(p,body:b);if(r.statusCode<200||r.statusCode>=300)throw AppException(r.body);return Map<String,dynamic>.from(jsonDecode(r.body) as Map);}
}
