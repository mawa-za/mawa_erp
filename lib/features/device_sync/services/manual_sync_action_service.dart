import 'dart:convert';
import '../../../core/api_client.dart';
import '../../../core/errors/app_error.dart';
import '../models/manual_sync_action.dart';

class ManualSyncActionService {
  final ApiClient _api=ApiClient();
  Future<List<ManualSyncAction>> list({String status='ATTENTION_REQUIRED',String search=''}) async {
    final r=await _api.get('/v2/pay-app/manual-actions',queryParameters:{'status':status,if(search.trim().isNotEmpty)'search':search.trim()});
    if(r.statusCode!=200) throw AppException(r.body);
    return (jsonDecode(r.body) as List).map((e)=>ManualSyncAction.fromJson(Map<String,dynamic>.from(e))).toList();
  }
  Future<ManualSyncAction> get(String id) async { final r=await _api.get('/v2/pay-app/manual-actions/$id'); if(r.statusCode!=200)throw AppException(r.body); return ManualSyncAction.fromJson(Map<String,dynamic>.from(jsonDecode(r.body))); }
  Future<ManualSyncAction> correct(String id,dynamic payload,String notes) async { final r=await _api.put('/v2/pay-app/manual-actions/$id/payload',body:{'payload':payload,'notes':notes}); if(r.statusCode!=200)throw AppException(r.body); return ManualSyncAction.fromJson(Map<String,dynamic>.from(jsonDecode(r.body))); }
  Future<ManualSyncAction> process(String id) async { final r=await _api.post('/v2/pay-app/manual-actions/$id/process'); if(r.statusCode!=200)throw AppException(r.body); return ManualSyncAction.fromJson(Map<String,dynamic>.from(jsonDecode(r.body))); }
  Future<ManualSyncAction> reject(String id,String notes) async { final r=await _api.post('/v2/pay-app/manual-actions/$id/reject',body:{'notes':notes}); if(r.statusCode!=200)throw AppException(r.body); return ManualSyncAction.fromJson(Map<String,dynamic>.from(jsonDecode(r.body))); }
}
