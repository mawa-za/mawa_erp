import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class ManualReceiptCutoverSettingsScreen extends StatefulWidget {
  const ManualReceiptCutoverSettingsScreen({super.key});
  @override State<ManualReceiptCutoverSettingsScreen> createState() => _State();
}
class _State extends State<ManualReceiptCutoverSettingsScreen> {
  DateTime? _goLive; DateTime? _closeDate; bool _proof = true; bool _legacyEnabled = true; bool _loading = true; bool _saving = false; String? _error;
  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async {
    try { final r=await ApiClient().get('/v2/manual-receipts/configuration');
      if(r.statusCode==200){ final m=jsonDecode(r.body); setState((){ _goLive=DateTime.parse(m['mawaPayGoLiveDate']); _closeDate=m['legacyCaptureCloseDate']==null?null:DateTime.parse(m['legacyCaptureCloseDate']); _proof=m['emergencyReceiptRequiresProof']!=false; _legacyEnabled=m['legacyCaptureEnabled']!=false; _loading=false;}); }
      else { setState((){_loading=false;}); }
    } catch(e){ setState((){_loading=false; _error='Configuration has not been created yet.';}); }
  }
  String _fmt(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  Future<void> _pick(bool goLive) async { final d=await showDatePicker(context: context, initialDate:(goLive?_goLive:_closeDate)??DateTime.now(), firstDate:DateTime(2020), lastDate:DateTime(2035)); if(d!=null)setState((){if(goLive)_goLive=d;else _closeDate=d;}); }
  Future<void> _save() async { if(_goLive==null){setState(()=>_error='MAWAPay go-live date is required');return;} setState((){_saving=true;_error=null;}); try { final p=await SharedPreferences.getInstance(); final r=await ApiClient().put('/v2/manual-receipts/configuration', body:{'mawaPayGoLiveDate':_fmt(_goLive!),'legacyCaptureCloseDate':_closeDate==null?null:_fmt(_closeDate!),'emergencyReceiptRequiresProof':_proof,'legacyCaptureEnabled':_legacyEnabled,'updatedBy':p.getString('userId')??'unknown'}); if(r.statusCode<200||r.statusCode>=300)throw AppException(r.body); if(mounted){setState(()=>_saving=false);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Manual receipt cutover configuration saved')));} }catch(e){if(mounted)setState((){_saving=false;_error=friendlyErrorMessage(e);});} }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Manual Receipt Cutover')),body:_loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(24),children:[const Text('Control how outstanding old-system receipts and post-go-live emergency receipts are captured.',style:TextStyle(fontSize:16)),const SizedBox(height:20),ListTile(title:const Text('MAWAPay go-live date'),subtitle:Text(_goLive==null?'Not configured':_fmt(_goLive!)),trailing:const Icon(Icons.calendar_today),onTap:()=>_pick(true)),ListTile(title:const Text('Legacy capture close date'),subtitle:Text(_closeDate==null?'No closing date':_fmt(_closeDate!)),trailing:Wrap(children:[IconButton(onPressed:()=>_pick(false),icon:const Icon(Icons.calendar_today)),IconButton(onPressed:()=>setState(()=>_closeDate=null),icon:const Icon(Icons.clear))])),SwitchListTile(title:const Text('Legacy catch-up capture enabled'),subtitle:const Text('Allows receipts dated before go-live to update memberships without entering live cashups.'),value:_legacyEnabled,onChanged:(v)=>setState(()=>_legacyEnabled=v)),SwitchListTile(title:const Text('Require proof for emergency receipts'),subtitle:const Text('Post-go-live emergency manual receipts require a carbon-copy attachment.'),value:_proof,onChanged:(v)=>setState(()=>_proof=v)),if(_error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),FilledButton.icon(onPressed:_saving?null:_save,icon:const Icon(Icons.save_outlined),label:Text(_saving?'Saving...':'Save configuration'))]));
}
