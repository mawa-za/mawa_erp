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
      if(r.statusCode==200){ final m=jsonDecode(r.body); if(!mounted)return; setState((){ _goLive=m['mawaPayGoLiveDate'] == null ? null : DateTime.tryParse(m['mawaPayGoLiveDate'].toString()); _closeDate=m['legacyCaptureCloseDate']==null?null:DateTime.tryParse(m['legacyCaptureCloseDate'].toString()); _proof=m['emergencyReceiptRequiresProof']==true; _legacyEnabled=m['legacyCaptureEnabled']!=false; _loading=false; _error=_goLive==null?'No saved MAWAPay go-live date was returned by the server for this tenant. Verify the tenant configuration before capturing receipts.':null;}); }
      else { if(mounted)setState((){_loading=false;_error='Unable to load cutover configuration (HTTP ${r.statusCode}).';}); }
    } catch(e){ if(mounted)setState((){_loading=false; _error=friendlyErrorMessage(e);}); }
  }
  String _fmt(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  Future<void> _pick(bool goLive) async { final d=await showDatePicker(context: context, initialDate:(goLive?_goLive:_closeDate)??DateTime.now(), firstDate:DateTime(2020), lastDate:DateTime(2035)); if(d!=null)setState((){if(goLive)_goLive=d;else _closeDate=d;}); }
  Future<void> _save() async { if(_goLive==null){setState(()=>_error='MAWAPay go-live date is required');return;} setState((){_saving=true;_error=null;}); try { final p=await SharedPreferences.getInstance(); final r=await ApiClient().put('/v2/manual-receipts/configuration', body:{'mawaPayGoLiveDate':_fmt(_goLive!),'legacyCaptureCloseDate':_closeDate==null?null:_fmt(_closeDate!),'emergencyReceiptRequiresProof':_proof,'legacyCaptureEnabled':_legacyEnabled,'updatedBy':p.getString('userId')??'unknown'}); if(r.statusCode<200||r.statusCode>=300)throw AppException(r.body); if(!mounted)return;
      // Read the persisted configuration independently; the PUT response alone
      // cannot establish whether this tenant's settings will survive a reload.
      final expectedDate = _fmt(_goLive!);
      final verify = await ApiClient().get('/v2/manual-receipts/configuration');
      if (verify.statusCode != 200) {
        throw StateError('Configuration was submitted but could not be verified (HTTP ${verify.statusCode}). Reload before attempting another save.');
      }
      final persisted = jsonDecode(verify.body);
      final persistedDate = persisted is Map ? persisted['mawaPayGoLiveDate']?.toString() : null;
      if (persistedDate != expectedDate) {
        throw StateError('Configuration verification failed: expected $expectedDate but the server returned ${persistedDate ?? "no go-live date"}. Check tenant selection and backend deployment.');
      }
      if (!mounted) return;
      setState(() {
        _goLive = DateTime.tryParse(persistedDate!);
        _closeDate = persisted['legacyCaptureCloseDate'] == null ? null : DateTime.tryParse(persisted['legacyCaptureCloseDate'].toString());
        _proof = persisted['emergencyReceiptRequiresProof'] == true;
        _legacyEnabled = persisted['legacyCaptureEnabled'] != false;
        _saving = false;
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Manual receipt cutover configuration saved'))); }catch(e){if(mounted)setState((){_saving=false;_error=friendlyErrorMessage(e);});} }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Manual Receipt Cutover')),body:_loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(24),children:[const Text('Control how outstanding old-system receipts and post-go-live emergency receipts are captured.',style:TextStyle(fontSize:16)),const SizedBox(height:20),ListTile(title:const Text('MAWAPay go-live date'),subtitle:Text(_goLive==null?'Not configured':_fmt(_goLive!)),trailing:const Icon(Icons.calendar_today),onTap:()=>_pick(true)),ListTile(title:const Text('Legacy capture close date'),subtitle:Text(_closeDate==null?'No closing date':_fmt(_closeDate!)),trailing:Wrap(children:[IconButton(onPressed:()=>_pick(false),icon:const Icon(Icons.calendar_today)),IconButton(onPressed:()=>setState(()=>_closeDate=null),icon:const Icon(Icons.clear))])),SwitchListTile(title:const Text('Legacy catch-up capture enabled'),subtitle:const Text('Allows receipts dated before go-live to update memberships without entering live cashups.'),value:_legacyEnabled,onChanged:(v)=>setState(()=>_legacyEnabled=v)),SwitchListTile(title:const Text('Request proof for emergency receipts (optional)'),subtitle:const Text('Proof can be provided when available; it is never mandatory.'),value:_proof,onChanged:(v)=>setState(()=>_proof=v)),if(_error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),FilledButton.icon(onPressed:_saving?null:_save,icon:const Icon(Icons.save_outlined),label:Text(_saving?'Saving...':'Save configuration'))]));
}
