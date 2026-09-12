import 'package:flutter/material.dart';
import '../services/card_terminal_service.dart';
import '../../../core/widgets/searchable_dropdown_form_field.dart';

class CardTerminalDropdown extends StatefulWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const CardTerminalDropdown({super.key,required this.value,required this.onChanged});
  @override State<CardTerminalDropdown> createState()=>_CardTerminalDropdownState();
}
class _CardTerminalDropdownState extends State<CardTerminalDropdown>{
  late final Future<List<CardTerminal>> _future=CardTerminalService().list(activeOnly:true);
  @override Widget build(BuildContext context)=>FutureBuilder<List<CardTerminal>>(
    future:_future,
    builder:(context,snapshot){
      final terminals=snapshot.data??const <CardTerminal>[];
      return SearchableDropdownFormField<String>(
        value:widget.value,
        decoration:InputDecoration(labelText:'Card terminal *',prefixIcon:const Icon(Icons.point_of_sale_outlined),border:const OutlineInputBorder(),helperText:snapshot.connectionState==ConnectionState.waiting?'Loading terminals...':terminals.isEmpty?'No active terminals configured under System Configuration → Card Terminals':null),
        items:terminals.map((t)=>DropdownMenuItem(value:t.id,child:Text(t.label))).toList(),
        onChanged:widget.onChanged,
        validator:(v)=>v==null||v.isEmpty?'Select the card terminal used':null,
      );
    },
  );
}
