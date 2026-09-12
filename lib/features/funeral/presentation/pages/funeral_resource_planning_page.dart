import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/funeral_resource_planning_service.dart';
import '../../../partners/partner_service.dart';
import '../../data/funeral_api.dart';
import '../../../../core/models/product_lookup.dart';
import '../../../../core/services/product_lookup_service.dart';
import '../../../../core/widgets/searchable_dropdown_form_field.dart';

class FuneralResourcePlanningPage extends StatefulWidget {
  final bool configurationOnly;
  const FuneralResourcePlanningPage({super.key,this.configurationOnly=false});
  @override State<FuneralResourcePlanningPage> createState()=>_State();
}
class _State extends State<FuneralResourcePlanningPage>{
  static const _statuses=['ALL','PLANNING_REQUIRED','IN_PROGRESS','READY','COMPLETED'];
  final _service=FuneralResourcePlanningService();
  final _search=TextEditingController();
  Map<String,dynamic>? _config;
  List<Map<String,dynamic>> _plans=[];
  bool _loading=true;
  String? _error;
  String _status='ALL';

  @override void initState(){super.initState();_load();}
  @override void dispose(){_search.dispose();super.dispose();}

  Future<void> _load()async{
    setState((){_loading=true;_error=null;});
    try{
      final c=await _service.configuration();
      final enabled=c['status']=='ENABLED';
      final p=widget.configurationOnly||!enabled?<Map<String,dynamic>>[]:await _service.plans(status:_status=='ALL'?null:_status,query:_search.text.trim());
      if(mounted)setState((){_config=c;_plans=p;});
    }catch(e){if(mounted)setState(()=>_error='$e');}
    finally{if(mounted)setState(()=>_loading=false);}
  }

  Future<void> _toggle(bool enabled)async{
    final c=_config!;
    await _service.saveConfiguration({'enabled':enabled,'autoCreatePlans':c['autoCreatePlans'],'requireReadiness':c['requireReadiness'],'provisionalExpiryHours':c['provisionalExpiryHours'],'allowThirdPartyLeasing':c['allowThirdPartyLeasing'],'requireApprovedPo':c['requireApprovedPo']});
    await _load();
  }

  Future<void> _openPlanning()async{
    await Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const FuneralResourcePlanningPage()));
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(
      title:Text(widget.configurationOnly?'Funeral Resource Planning Configuration':'Funeral Resource Planning'),
      actions:[if(!widget.configurationOnly)IconButton(tooltip:'Refresh and synchronise plans',onPressed:_loading?null:_load,icon:const Icon(Icons.refresh))],
    ),
    body:_loading?const Center(child:CircularProgressIndicator()):_error!=null?_errorView():_config==null?const Center(child:Text('Configuration unavailable')):widget.configurationOnly?_configurationView():_operationalView(),
  );

  Widget _configurationView()=>ListView(padding:const EdgeInsets.all(24),children:[
    Card(child:SwitchListTile(contentPadding:const EdgeInsets.all(20),secondary:const Icon(Icons.event_available_outlined),title:const Text('Enable Funeral Resource Planning'),subtitle:Text('Tenant status: ${_config!['status']}'),value:_config!['status']=='ENABLED',onChanged:_toggle)),
    Card(child:Column(children:_settings())),
    if(_config!['status']=='ENABLED')Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Resource planning workspace',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:8),const Text('Upcoming funerals are synchronised automatically. Open the independent planner to allocate internal resources or arrange third-party leasing.'),const SizedBox(height:16),FilledButton.icon(onPressed:_openPlanning,icon:const Icon(Icons.open_in_new),label:const Text('Open Resource Planning'))]))),
  ]);

  Widget _operationalView(){
    if(_config!['status']!='ENABLED')return Center(child:Padding(padding:const EdgeInsets.all(32),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.event_busy_outlined,size:64),const SizedBox(height:16),Text('Resource planning is not enabled',style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:8),const Text('A system administrator must enable it under System Configuration → Funeral Resource Planning.',textAlign:TextAlign.center)])));
    final required=_plans.where((p)=>'${p['status']}'=='PLANNING_REQUIRED').length;
    final progress=_plans.where((p)=>'${p['status']}'=='IN_PROGRESS').length;
    final ready=_plans.where((p)=>'${p['status']}'=='READY').length;
    return RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(24),children:[
      Text('Upcoming funeral resource plans',style:Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height:6),
      const Text('Allocate employees, vehicles, equipment and externally leased resources before the funeral date.'),
      const SizedBox(height:20),
      Wrap(spacing:12,runSpacing:12,children:[_summary('Planning required',required,Icons.assignment_late_outlined),_summary('In progress',progress,Icons.pending_actions_outlined),_summary('Ready',ready,Icons.task_alt_outlined),_summary('Plans shown',_plans.length,Icons.event_note_outlined)]),
      const SizedBox(height:20),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Wrap(spacing:12,runSpacing:12,crossAxisAlignment:WrapCrossAlignment.center,children:[SizedBox(width:360,child:TextField(controller:_search,onSubmitted:(_)=>_load(),decoration:InputDecoration(labelText:'Search service request or deceased',prefixIcon:const Icon(Icons.search),suffixIcon:IconButton(tooltip:'Search',onPressed:_load,icon:const Icon(Icons.arrow_forward)),border:const OutlineInputBorder()))),DropdownButton<String>(value:_status,items:_statuses.map((s)=>DropdownMenuItem(value:s,child:Text(_label(s)))).toList(),onChanged:(v){if(v==null)return;setState(()=>_status=v);_load();}),OutlinedButton.icon(onPressed:_load,icon:const Icon(Icons.sync),label:const Text('Synchronise'))]))),
      const SizedBox(height:12),
      if(_plans.isEmpty)_emptyState() else ..._plans.map(_planCard),
    ]));
  }

  Widget _summary(String label,int value,IconData icon)=>SizedBox(width:210,child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[CircleAvatar(child:Icon(icon)),const SizedBox(width:12),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$value',style:Theme.of(context).textTheme.headlineSmall),Text(label)])]))));

  Widget _planCard(Map<String,dynamic> p){
    final raw='${p['funeral_date']??''}';
    final parsed=DateTime.tryParse(raw);
    final date=parsed==null?raw:DateFormat('EEE, dd MMM yyyy').format(parsed);
    final unresolved=int.tryParse('${p['unresolved_count']??0}')??0;
    return Card(child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:20,vertical:12),leading:CircleAvatar(child:Text(date.isEmpty?'?':date.substring(0,1))),title:Text('${p['service_request_no']??'Unnumbered request'} · ${p['deceased_name']??'Deceased not captured'}'),subtitle:Text('$date · ${p['funeral_area']??'Location not captured'}\n${p['item_count']??0} requirements · $unresolved mandatory outstanding'),isThreeLine:true,trailing:Chip(label:Text(_label('${p['status']}'))),onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>_PlanPage(id:'${p['id']}'))).then((_)=>_load())));
  }

  Widget _emptyState()=>Card(child:Padding(padding:const EdgeInsets.all(36),child:Column(children:[const Icon(Icons.event_note_outlined,size:56),const SizedBox(height:16),Text('No matching resource plans',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),const Text('Upcoming funeral requests with a funeral date are synchronised automatically. Make sure Automatically create plans is enabled and resource requirements are maintained on the funeral package.',textAlign:TextAlign.center),const SizedBox(height:20),FilledButton.icon(onPressed:_load,icon:const Icon(Icons.sync),label:const Text('Synchronise Upcoming Funerals'))])));

  Widget _errorView()=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.error_outline,size:56),const SizedBox(height:12),Text(_error!,textAlign:TextAlign.center),const SizedBox(height:16),FilledButton.icon(onPressed:_load,icon:const Icon(Icons.refresh),label:const Text('Retry'))])));

  String _label(String value)=>value.toLowerCase().split('_').map((word)=>word.isEmpty?'':word[0].toUpperCase()+word.substring(1)).join(' ');
  List<Widget> _settings()=>[
    CheckboxListTile(title:const Text('Automatically create plans'),subtitle:const Text('Create and synchronise a plan for every upcoming funeral request.'),value:_config!['autoCreatePlans']==true,onChanged:(v)=>_saveOption('autoCreatePlans',v)),
    CheckboxListTile(title:const Text('Require resource readiness'),value:_config!['requireReadiness']==true,onChanged:(v)=>_saveOption('requireReadiness',v)),
    CheckboxListTile(title:const Text('Allow third-party leasing'),value:_config!['allowThirdPartyLeasing']==true,onChanged:(v)=>_saveOption('allowThirdPartyLeasing',v)),
    CheckboxListTile(title:const Text('Require approved PO before readiness'),value:_config!['requireApprovedPo']==true,onChanged:(v)=>_saveOption('requireApprovedPo',v)),
  ];
  Future<void> _saveOption(String key,bool? value)async{final body=Map<String,dynamic>.from(_config!);body[key]=value;body['enabled']=body['status']=='ENABLED';setState(()=>_loading=true);try{_config=await _service.saveConfiguration(body);}finally{if(mounted)setState(()=>_loading=false);}}
}

class _PlanPage extends StatefulWidget{final String id;const _PlanPage({required this.id});@override State<_PlanPage> createState()=>_PlanState();}
class _PlanState extends State<_PlanPage>{final s=FuneralResourcePlanningService();Map<String,dynamic>? plan;bool loading=true;@override void initState(){super.initState();load();}Future<void>load()async{setState(()=>loading=true);try{plan=await s.plan(widget.id);}finally{if(mounted)setState(()=>loading=false);}}
@override Widget build(BuildContext context){final items=plan==null?<dynamic>[]:(plan!['items'] as List);return Scaffold(appBar:AppBar(title:Text(plan?['service_request_no']??'Resource Plan'),actions:[IconButton(tooltip:'Refresh',onPressed:loading?null:load,icon:const Icon(Icons.refresh))]),floatingActionButton:plan!=null&&items.isNotEmpty?FloatingActionButton.extended(onPressed:_ready,label:const Text('Confirm Ready'),icon:const Icon(Icons.task_alt)):null,body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(24),children:[Card(child:Padding(padding:const EdgeInsets.all(20),child:Row(children:[const CircleAvatar(child:Icon(Icons.person_outline)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${plan!['deceased_name']}',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:4),Text('${plan!['funeral_date']} · ${plan!['funeral_area']??'Location not captured'}')])),Chip(label:Text('${plan!['status']}'.replaceAll('_',' ')))]))),const SizedBox(height:12),if(items.isEmpty)Card(child:Padding(padding:const EdgeInsets.all(36),child:Column(children:[const Icon(Icons.playlist_remove_outlined,size:56),const SizedBox(height:16),Text('No resource requirements on this plan',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),const Text('Configure resource requirements against this funeral package under System Configuration → Funeral Packages, then synchronise the planner. An empty plan cannot be confirmed ready.',textAlign:TextAlign.center),const SizedBox(height:20),OutlinedButton.icon(onPressed:load,icon:const Icon(Icons.refresh),label:const Text('Reload Plan'))])))else...items.map((raw){final i=Map<String,dynamic>.from(raw as Map);final allocations=(i['allocations'] as List?)??const[];return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(child:Icon(i['resource_type']=='EMPLOYEE'?Icons.groups_outlined:i['resource_type']=='VEHICLE'?Icons.local_shipping_outlined:Icons.handyman_outlined)),title:Text('${i['name']} · ${i['required_quantity']} ${i['uom']}'),subtitle:Text('${i['resource_type']} · ${i['start_at']} – ${i['end_at']}\nAllocated ${i['allocated_quantity']??0} · ${i['status']}'),isThreeLine:true,trailing:PopupMenuButton<String>(tooltip:'Allocate resource',onSelected:(v)=>v=='internal'?_internal(i):_external(i),itemBuilder:(_)=>[const PopupMenuItem(value:'internal',child:Text('Use own resource')),if(_canExternal(i))const PopupMenuItem(value:'external',child:Text('Lease from third party'))])),if(allocations.isNotEmpty)...[const Divider(),Text('Allocations',style:Theme.of(context).textTheme.labelLarge),...allocations.map((rawAllocation){final a=Map<String,dynamic>.from(rawAllocation as Map);return ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:const Icon(Icons.check_circle_outline),title:Text('${a['asset_name']??a['partner_name']??a['purchase_order_no']??'Allocated resource'}'),subtitle:Text('${a['allocation_type']} · ${a['quantity']} · ${a['status']}'));})]])));}),if(items.isNotEmpty)const SizedBox(height:80)]));}
bool _canExternal(Map<String,dynamic>i)=>i['sourcing_mode']!='INTERNAL_ONLY';
Future<void>_internal(Map<String,dynamic>i)async{if(i['resource_type']=='EMPLOYEE'){final people=await FuneralApi().getEmployees();if(!mounted)return;final selected=await showDialog<String>(context:context,builder:(c)=>SimpleDialog(title:const Text('Select employee'),children:people.map((p)=>SimpleDialogOption(onPressed:()=>Navigator.pop(c,p.id),child:Text(p.fullName))).toList()));if(selected!=null){await s.allocateEmployee('${i['id']}',selected,1);await load();}}else{final assets=await s.assets('${i['id']}');if(!mounted)return;final selected=await showDialog<String>(context:context,builder:(c)=>SimpleDialog(title:const Text('Select available resource'),children:assets.map((a)=>SimpleDialogOption(onPressed:()=>Navigator.pop(c,'${a['id']}'),child:Text('${a['asset_no']} · ${a['name']}'))).toList()));if(selected!=null){await s.allocateAsset('${i['id']}',selected,1);await load();}}}
Future<void>_external(Map<String,dynamic> i) async {
  final suppliers = await PartnerService().getPartnersByRole('SUPPLIER');
  suppliers.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
  final products = await ProductLookupService().getProducts();
  products.sort((a, b) {
    final byDescription = a.description.toLowerCase().compareTo(b.description.toLowerCase());
    return byDescription != 0 ? byDescription : a.code.toLowerCase().compareTo(b.code.toLowerCase());
  });
  if (!mounted) return;

  if (suppliers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No approved suppliers are available. Add or approve a supplier before creating a lease.')),
    );
    return;
  }
  if (products.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No procurement products or services are available.')),
    );
    return;
  }

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ThirdPartyLeaseDialog(
      requirement: i,
      suppliers: suppliers,
      products: products,
    ),
  );
  if (result == null) return;

  await s.lease(
    '${i['id']}',
    '${result['supplierId']}',
    '${result['productId']}',
    result['quantity'] as num,
    result['unitCost'] as num,
  );
  await load();
}
Future<void>_ready()async{try{plan=await s.confirmReady(widget.id);if(mounted)setState((){});}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}
}

class _ThirdPartyLeaseDialog extends StatefulWidget {
  const _ThirdPartyLeaseDialog({
    required this.requirement,
    required this.suppliers,
    required this.products,
  });

  final Map<String, dynamic> requirement;
  final List<dynamic> suppliers;
  final List<ProductLookup> products;

  @override
  State<_ThirdPartyLeaseDialog> createState() => _ThirdPartyLeaseDialogState();
}

class _ThirdPartyLeaseDialogState extends State<_ThirdPartyLeaseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantity;
  late final TextEditingController _unitCost;
  String? _supplierId;
  String? _productId;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(text: '${widget.requirement['required_quantity'] ?? 1}');
    _unitCost = TextEditingController();
    final configuredProduct = '${widget.requirement['product_id'] ?? ''}';
    if (widget.products.any((product) => product.id == configuredProduct)) {
      _productId = configuredProduct;
      _setProductPrice(configuredProduct);
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    _unitCost.dispose();
    super.dispose();
  }

  void _setProductPrice(String? productId) {
    if (productId == null) return;
    final product = widget.products.firstWhere((item) => item.id == productId);
    if (product.priceCents > 0) {
      _unitCost.text = (product.priceCents / 100).toStringAsFixed(2);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, <String, dynamic>{
      'supplierId': _supplierId,
      'productId': _productId,
      'quantity': num.parse(_quantity.text.trim()),
      'unitCost': num.parse(_unitCost.text.trim()),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedProduct = _productId == null
        ? null
        : widget.products.firstWhere((item) => item.id == _productId);
    final quantity = num.tryParse(_quantity.text.trim()) ?? 0;
    final unitCost = num.tryParse(_unitCost.text.trim()) ?? 0;
    final total = quantity * unitCost;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.local_shipping_outlined, color: theme.colorScheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Arrange third-party lease', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 3),
                      Text('${widget.requirement['name']} · ${widget.requirement['required_quantity']} ${widget.requirement['uom']}', style: theme.textTheme.bodyMedium),
                    ])),
                    IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 10),
                      Expanded(child: Text('Choose an approved supplier and the product or service that must appear on the purchase order.')),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  Text('Supplier', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  SearchableDropdownFormField<String>(
                    value: _supplierId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Approved lease supplier',
                      hintText: 'Search by supplier name or number',
                      prefixIcon: Icon(Icons.business_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: widget.suppliers.map<DropdownMenuItem<String>>((supplier) => DropdownMenuItem(
                      value: supplier.id as String,
                      child: Text(
                        supplier.number.toString().isEmpty ? supplier.fullName.toString() : '${supplier.fullName} · ${supplier.number}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    validator: (value) => value == null ? 'Select a supplier' : null,
                    onChanged: (value) => setState(() => _supplierId = value),
                  ),
                  const SizedBox(height: 22),
                  Text('Purchase order item', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  SearchableDropdownFormField<String>(
                    value: _productId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Third-party lease product or service',
                      hintText: 'Search by product code or description',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: widget.products.map((product) => DropdownMenuItem(
                      value: product.id,
                      child: Text('${product.description} · ${product.code}', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    validator: (value) => value == null ? 'Select a product or service' : null,
                    onChanged: (value) => setState(() {
                      _productId = value;
                      _setProductPrice(value);
                    }),
                  ),
                  if (selectedProduct != null && selectedProduct.priceCents > 0) ...[
                    const SizedBox(height: 8),
                    Text('Catalogue price: R ${(selectedProduct.priceCents / 100).toStringAsFixed(2)}', style: theme.textTheme.bodySmall),
                  ],
                  const SizedBox(height: 16),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: TextFormField(
                      controller: _quantity,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Quantity (${widget.requirement['uom']})', border: const OutlineInputBorder()),
                      validator: (value) => (num.tryParse(value?.trim() ?? '') ?? 0) <= 0 ? 'Enter a valid quantity' : null,
                      onChanged: (_) => setState(() {}),
                    )),
                    const SizedBox(width: 14),
                    Expanded(child: TextFormField(
                      controller: _unitCost,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Unit cost', prefixText: 'R ', border: OutlineInputBorder()),
                      validator: (value) => (num.tryParse(value?.trim() ?? '') ?? -1) < 0 ? 'Enter a valid cost' : null,
                      onChanged: (_) => setState(() {}),
                    )),
                  ]),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Estimated PO total'),
                      Text('R ${total.toStringAsFixed(2)}', style: theme.textTheme.titleLarge),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 10),
                    FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.description_outlined), label: const Text('Create Draft PO')),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
