import 'package:flutter/material.dart';
import '../services/stock_service.dart';

class InventoryReservationsScreen extends StatefulWidget {
  const InventoryReservationsScreen({super.key});
  @override
  State<InventoryReservationsScreen> createState() => _InventoryReservationsScreenState();
}

class _InventoryReservationsScreenState extends State<InventoryReservationsScreen> {
  final StockService _service = StockService();
  List<Map<String,dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;

  @override void initState(){super.initState();_load();}
  Future<void> _load() async {setState((){_loading=true;_error=null;});try{final rows=await _service.inventoryReservations();if(mounted)setState(()=>_rows=rows);}catch(e){if(mounted)setState(()=>_error=e.toString());}finally{if(mounted)setState(()=>_loading=false);}}

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Stock Reservations')),
    floatingActionButton:FloatingActionButton.extended(onPressed:_create,icon:const Icon(Icons.add),label:const Text('Reserve')),
    body:RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('Allocate available inventory to sales, funeral services, service orders, tombstone orders or other demand without reducing physical on-hand stock.'),
      const SizedBox(height:16),
      if(_loading)const Center(child:Padding(padding:EdgeInsets.all(40),child:CircularProgressIndicator()))
      else if(_error!=null)Card(child:Padding(padding:const EdgeInsets.all(20),child:Text(_error!)))
      else if(_rows.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(24),child:Text('No reservations found.')))
      else ..._rows.map((r)=>Card(child:ListTile(
        leading:const Icon(Icons.bookmark_outline),
        title:Text('${r['reservation_no']} • ${r['product_code'] ?? r['product_id']}'),
        subtitle:Text('${r['source_type']} ${r['source_id']}\n${r['warehouse_code'] ?? ''} / ${r['location_code'] ?? ''} • ${r['quantity']} ${r['uom']}'),
        isThreeLine:true,
        trailing:Row(mainAxisSize:MainAxisSize.min,children:[Chip(label:Text('${r['status']}')),if('${r['status']}'=='ACTIVE')IconButton(tooltip:'Release',icon:const Icon(Icons.lock_open_outlined),onPressed:()async{await _service.releaseInventoryReservation('${r['id']}');await _load();})]),
      ))),
    ])),
  );

  Future<void> _create() async {
    final warehouses=await _service.inventoryReferenceWarehouses('stock-reservation');
    final products=await _service.inventoryReferenceProducts('stock-reservation');
    if(!mounted)return;
    String? warehouseId=warehouses.isEmpty?null:'${warehouses.first['id']}';
    String? productId;
    final sourceType=TextEditingController(text:'SALES_ORDER');
    final sourceId=TextEditingController();
    final qty=TextEditingController(text:'1');
    final uom=TextEditingController(text:'EA');
    final ok=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(builder:(context,setLocal)=>AlertDialog(
      title:const Text('Reserve stock'),content:SizedBox(width:520,child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(value:warehouseId,decoration:const InputDecoration(labelText:'Warehouse'),items:warehouses.map((w)=>DropdownMenuItem(value:'${w['id']}',child:Text('${w['warehouse_code']} - ${w['name']}'))).toList(),onChanged:(v)=>setLocal(()=>warehouseId=v)),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(value:productId,decoration:const InputDecoration(labelText:'Product'),items:products.map((p)=>DropdownMenuItem(value:'${p['id']}',child:Text('${p['code']} - ${p['description']}'))).toList(),onChanged:(v)=>setLocal((){productId=v;final p=products.firstWhere((e)=>'${e['id']}'==v,orElse:()=> <String,dynamic>{});uom.text='${p['uom'] ?? 'EA'}';})),
        const SizedBox(height:12),TextField(controller:sourceType,decoration:const InputDecoration(labelText:'Demand source type')),
        const SizedBox(height:12),TextField(controller:sourceId,decoration:const InputDecoration(labelText:'Demand reference ID')),
        const SizedBox(height:12),Row(children:[Expanded(child:TextField(controller:qty,decoration:const InputDecoration(labelText:'Quantity'),keyboardType:const TextInputType.numberWithOptions(decimal:true))),const SizedBox(width:12),SizedBox(width:120,child:TextField(controller:uom,decoration:const InputDecoration(labelText:'UOM')))]),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Reserve'))],
    )));
    if(ok!=true||warehouseId==null||productId==null||sourceId.text.trim().isEmpty)return;
    try{await _service.createInventoryReservation({'sourceType':sourceType.text.trim(),'sourceId':sourceId.text.trim(),'productId':productId,'warehouseId':warehouseId,'quantity':double.tryParse(qty.text)??0,'uom':uom.text.trim().toUpperCase(),'stockStatus':'UNRESTRICTED'});await _load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
  }
}
