import 'dart:convert';
import '../../../core/api_client.dart';
import '../../../core/errors/app_error.dart';

class CardTerminal {
  final String id, code, name;
  final String? merchantNumber, locationCode;
  final bool active;
  const CardTerminal({required this.id,required this.code,required this.name,this.merchantNumber,this.locationCode,required this.active});
  factory CardTerminal.fromJson(Map<String,dynamic> j)=>CardTerminal(id:'${j['id']??''}',code:'${j['code']??''}',name:'${j['name']??''}',merchantNumber:j['merchantNumber']?.toString(),locationCode:j['locationCode']?.toString(),active:j['active']!=false);
  Map<String,dynamic> toJson({String? changedBy})=>{'code':code,'name':name,'merchantNumber':merchantNumber,'locationCode':locationCode,'active':active,'changedBy':changedBy};
  String get label => '$name ($code)';
}

class CardTerminalService {
  Future<List<CardTerminal>> list({bool activeOnly=false}) async {
    final r=await ApiClient().get('/v2/card-terminals',queryParameters:{'activeOnly':activeOnly});
    if(r.statusCode!=200) throw AppException('Unable to load card terminals.');
    return (jsonDecode(r.body) as List).map((e)=>CardTerminal.fromJson(Map<String,dynamic>.from(e))).toList();
  }
  Future<void> save(CardTerminal terminal,{String? changedBy}) async {
    final r=terminal.id.isEmpty?await ApiClient().post('/v2/card-terminals',body:terminal.toJson(changedBy:changedBy)):await ApiClient().put('/v2/card-terminals/${terminal.id}',body:terminal.toJson(changedBy:changedBy));
    if(r.statusCode<200||r.statusCode>=300) throw AppException.fromHttp(statusCode:r.statusCode,responseBody:r.body,fallback:'Unable to save card terminal.');
  }
}
