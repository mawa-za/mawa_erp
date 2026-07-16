import 'package:flutter/material.dart';
import '../../../core/models/user.dart';
import '../../../core/services/user_service.dart';
import '../models/role.dart';
import '../services/role_service.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});
  @override State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final _users = UserService();
  final _roles = RoleService();
  bool _loading = true;
  String? _error;
  User? _user;
  List<Map<String,dynamic>> _assigned = [];
  List<Role> _available = [];

  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    setState(() {_loading=true;_error=null;});
    try {
      final values=await Future.wait([_users.getUser(widget.userId),_users.getUserRoles(widget.userId),_roles.getRoles()]);
      if(mounted)setState((){_user=values[0] as User;_assigned=List<Map<String,dynamic>>.from(values[1] as List);_available=values[2] as List<Role>;_loading=false;});
    } catch(e){if(mounted)setState((){_error=e.toString();_loading=false;});}
  }

  Future<void> _action(String action) async {
    try {
      if(action=='lock'){
        final reason=await _textDialog('Lock user','Reason');if(reason==null||reason.trim().isEmpty)return;
        await _users.lockUser(widget.userId,reason:reason.trim());
      }else if(action=='unlock'){await _users.unlockUser(widget.userId);}
      else if(action=='reset'){await _users.resetUser(widget.userId);}
      else if(action=='delete'){
        if(_user!.protectedUser||_user!.systemManaged)return;
        if(!await _confirm('Delete ${_user!.username}?'))return;
        await _users.deleteUser(widget.userId);if(mounted)Navigator.pop(context,true);return;
      }else if(action=='policy'){await _editPolicy();return;}
      await _load();
    }catch(e){_showError(e);}
  }

  Future<void> _manageRoles() async {
    final selected=_assigned.map((r)=>(r['id']??'').toString()).toSet();
    final result=await showDialog<Set<String>>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setLocal)=>AlertDialog(
      title:const Text('Roles from Role Maintenance'),content:SizedBox(width:560,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:_available.map((r)=>CheckboxListTile(value:selected.contains(r.id),title:Text(r.id),subtitle:Text(r.description),secondary:r.protectedRole?const Icon(Icons.shield_rounded):null,onChanged:(v)=>setLocal(()=>v==true?selected.add(r.id):selected.remove(r.id)))).toList()))),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(dialogContext,selected),child:const Text('Save'))])));
    if(result==null)return;
    try{await _users.updateUserRoles(widget.userId,result.toList());await _load();}catch(e){_showError(e);}
  }

  Future<void> _editPolicy() async {
    final u=_user!;final email=TextEditingController(text:u.email??'');final cellphone=TextEditingController(text:u.cellphone??'');final env=TextEditingController(text:u.environmentScope);final expiry=TextEditingController(text:u.expiresAt?.toIso8601String().split('T').first??'');final reason=TextEditingController(text:u.protectedReason);
    String account=u.accountType,status=u.status;bool test=u.testUser,blocked=u.externalTransactionsBlocked,mfa=u.mfaRequired;
    final save=await showDialog<bool>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setLocal)=>AlertDialog(title:Text('Access policy — ${u.username}'),content:SizedBox(width:650,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:email,decoration:const InputDecoration(labelText:'Email')),const SizedBox(height:8),TextField(controller:cellphone,decoration:const InputDecoration(labelText:'Cellphone')),const SizedBox(height:8),
      Row(children:[Expanded(child:DropdownButtonFormField<String>(value:account,decoration:const InputDecoration(labelText:'Account type'),items:['STANDARD','QA_TESTER','AUTOMATION_TEST','DEMO_USER','SUPPORT_VERIFICATION'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>setLocal(()=>account=v!))),const SizedBox(width:8),Expanded(child:InputDecorator(decoration:const InputDecoration(labelText:'Access scope',helperText:'Derived from assigned roles'),child:Text(u.accessScope))),const SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'Status'),items:['ACTIVE','LOCKED'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>setLocal(()=>status=v!)))]),
      SwitchListTile(value:test,title:const Text('Testing user'),onChanged:(v)=>setLocal((){test=v;if(v){blocked=true;if(env.text.isEmpty)env.text='DEV,ALPHA,BETA';}})),
      SwitchListTile(value:u.protectedUser,title:const Text('Protected — cannot be deleted'),subtitle:const Text('Derived from protected roles in Role Maintenance'),onChanged:null),
      SwitchListTile(value:blocked,title:const Text('Block external transactions'),onChanged:(v)=>setLocal(()=>blocked=v)),SwitchListTile(value:mfa,title:const Text('MFA required'),onChanged:(v)=>setLocal(()=>mfa=v)),
      TextField(controller:env,decoration:const InputDecoration(labelText:'Environment scope')),const SizedBox(height:8),TextField(controller:expiry,decoration:const InputDecoration(labelText:'Expiry date (YYYY-MM-DD)')),const SizedBox(height:8),TextField(controller:reason,decoration:const InputDecoration(labelText:'Protection/access reason')),
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),child:const Text('Save'))])));
    if(save!=true)return;
    try{await _users.updateUser(widget.userId,{'email':email.text.trim(),'cellphone':cellphone.text.trim(),'userType':u.type,'status':status,'accountType':account,'testUser':test,'environmentScope':env.text.trim(),'externalTransactionsBlocked':blocked,'expiresAt':expiry.text.trim().isEmpty?null:'${expiry.text.trim()}T23:59:59','protectedReason':reason.text.trim(),'mfaRequired':mfa});await _load();}catch(e){_showError(e);}
  }

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('User Details'),actions:[if(_user!=null)PopupMenuButton<String>(onSelected:_action,itemBuilder:(_)=>[
    const PopupMenuItem(value:'policy',child:ListTile(leading:Icon(Icons.policy_outlined),title:Text('Access policy'),contentPadding:EdgeInsets.zero)),
    if(_user!.status.toUpperCase()=='ACTIVE')const PopupMenuItem(value:'lock',child:ListTile(leading:Icon(Icons.lock_outline),title:Text('Lock'),contentPadding:EdgeInsets.zero))else const PopupMenuItem(value:'unlock',child:ListTile(leading:Icon(Icons.lock_open),title:Text('Unlock'),contentPadding:EdgeInsets.zero)),
    const PopupMenuItem(value:'reset',child:ListTile(leading:Icon(Icons.password),title:Text('Reset password'),contentPadding:EdgeInsets.zero)),
    PopupMenuItem(value:'delete',enabled:!_user!.protectedUser&&!_user!.systemManaged,child:const ListTile(leading:Icon(Icons.delete_outline,color:Colors.red),title:Text('Delete'),contentPadding:EdgeInsets.zero)),
  ]),IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),body:_loading?const Center(child:CircularProgressIndicator()):_error!=null?Center(child:Text(_error!)):ListView(padding:const EdgeInsets.all(20),children:[
    _header(_user!),const SizedBox(height:16),_section('Assigned roles',[if(_assigned.isEmpty)const Text('No roles assigned') else Wrap(spacing:8,runSpacing:8,children:_assigned.map((r)=>Chip(avatar:(r['protectedRole']==true)?const Icon(Icons.shield,size:16):null,label:Text((r['id']??'').toString()))).toList()),const SizedBox(height:8),OutlinedButton.icon(onPressed:_manageRoles,icon:const Icon(Icons.manage_accounts),label:const Text('Manage roles'))]),
    _section('Account policy',[_row('Account type',_user!.accountType),_row('Access scope',_user!.accessScope),_row('Environment',_user!.environmentScope.isEmpty?'All permitted environments':_user!.environmentScope),_row('External transactions',_user!.externalTransactionsBlocked?'Blocked':'Allowed'),_row('Expiry',_user!.expiresAt?.toLocal().toString()??'None'),_row('MFA',_user!.mfaRequired?'Required':'Not required'),if(_user!.protectedReason.isNotEmpty)_row('Reason',_user!.protectedReason)]),
    _section('User information',[_row('Username',_user!.username),_row('Email',_user!.email??''),_row('Cellphone',_user!.cellphone??''),_row('User type',_user!.type),_row('Status',_user!.status)]),
  ]));

  Widget _header(User u)=>Card(child:Padding(padding:const EdgeInsets.all(20),child:Row(children:[CircleAvatar(radius:28,child:Icon(u.testUser?Icons.science:u.protectedUser?Icons.shield:Icons.person)),const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(u.displayName?.isNotEmpty==true?u.displayName!:u.username,style:Theme.of(context).textTheme.titleLarge),Text(u.username),Wrap(spacing:6,children:[if(u.protectedUser)const Chip(label:Text('PROTECTED')),if(u.testUser)const Chip(label:Text('TEST USER')),if(u.systemManaged)const Chip(label:Text('SYSTEM MANAGED'))])]))])));
  Widget _section(String title,List<Widget> children)=>Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:12),...children])));
  Widget _row(String label,String value)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:170,child:Text(label,style:const TextStyle(fontWeight:FontWeight.w600))),Expanded(child:Text(value))]));
  Future<String?> _textDialog(String title,String label) async{final c=TextEditingController();return showDialog<String>(context:context,builder:(d)=>AlertDialog(title:Text(title),content:TextField(controller:c,decoration:InputDecoration(labelText:label)),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,c.text),child:const Text('Continue'))]));}
  Future<bool> _confirm(String message) async=>(await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('Confirm'),content:Text(message),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Continue'))])))??false;
  void _showError(Object e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e'),backgroundColor:Colors.red));}
}
