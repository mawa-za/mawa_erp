import 'dart:convert';
import '../../../core/api_client.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class FuneralResourcePlanningService {
  final ApiClient _api = ApiClient();
  Future<Map<String,dynamic>> configuration() => _get('/v2/funeral-resource-planning/configuration');
  Future<Map<String,dynamic>> saveConfiguration(Map<String,dynamic> body) => _put('/v2/funeral-resource-planning/configuration',body);
  Future<List<Map<String,dynamic>>> plans({String? status,String? query}) async {
    final response=await _api.get('/v2/funeral-resource-planning/plans',queryParameters:{if(status!=null)'status':status,if(query!=null&&query.isNotEmpty)'query':query});
    if(response.statusCode!=200) throw AppException('Failed to load resource plans: ${response.body}');
    return (jsonDecode(response.body) as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
  Future<Map<String,dynamic>> plan(String id)=>_get('/v2/funeral-resource-planning/plans/$id');
  Future<List<Map<String,dynamic>>> assets(String itemId) async {
    final response=await _api.get('/v2/funeral-resource-planning/items/$itemId/available-assets');
    if(response.statusCode!=200) throw AppException('Failed to load available resources: ${response.body}');
    return (jsonDecode(response.body) as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
  Future<Map<String,dynamic>> allocateAsset(String itemId,String assetId,num quantity)=>_post('/v2/funeral-resource-planning/items/$itemId/internal-allocations',{'assetId':assetId,'quantity':quantity});
  Future<Map<String,dynamic>> allocateEmployee(String itemId,String employeeId,num quantity)=>_post('/v2/funeral-resource-planning/items/$itemId/internal-allocations',{'employeePartnerId':employeeId,'quantity':quantity});
  Future<Map<String,dynamic>> lease(String itemId,String supplierId,String productId,num quantity,num unitCost)=>_post('/v2/funeral-resource-planning/items/$itemId/external-allocations',{'supplierPartnerId':supplierId,'productId':productId,'quantity':quantity,'unitCost':unitCost});
  Future<Map<String,dynamic>> confirmReady(String id)=>_post('/v2/funeral-resource-planning/plans/$id/confirm-ready',{});
  Future<Map<String,dynamic>> _get(String path) async {final r=await _api.get(path);if(r.statusCode!=200)throw AppException(r.body);return Map<String,dynamic>.from(jsonDecode(r.body) as Map);}
  Future<Map<String,dynamic>> _post(String path,Map<String,dynamic> body) async {final r=await _api.post(path,body:body);if(r.statusCode<200||r.statusCode>=300)throw AppException(r.body);return Map<String,dynamic>.from(jsonDecode(r.body) as Map);}
  Future<Map<String,dynamic>> _put(String path,Map<String,dynamic> body) async {final r=await _api.put(path,body:body);if(r.statusCode!=200)throw AppException(r.body);return Map<String,dynamic>.from(jsonDecode(r.body) as Map);}
}
