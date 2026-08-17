import 'package:flutter/material.dart';

/// Drop-in searchable replacement for [DropdownButtonFormField].
///
/// It deliberately supports the constructor options used throughout MAWA ERP
/// so existing forms retain their validation and decoration while every option
/// list gets an in-dialog search box.
class SearchableDropdownFormField<T> extends FormField<T> {
  SearchableDropdownFormField({
    super.key,
    T? value,
    T? initialValue,
    required List<DropdownMenuItem<T>>? items,
    ValueChanged<T?>? onChanged,
    FormFieldValidator<T>? validator,
    InputDecoration decoration = const InputDecoration(),
    Widget? hint,
    Widget? icon,
    bool isExpanded = false,
    Color? dropdownColor,
    BorderRadius? borderRadius,
    double? itemHeight = kMinInteractiveDimension,
    DropdownButtonBuilder? selectedItemBuilder,
  })  : assert(value == null || initialValue == null,
            'Provide either value or initialValue, not both.'),
        super(
          initialValue: initialValue ?? value,
          validator: validator,
          builder: (state) {
            final enabled = onChanged != null && items != null && items.isNotEmpty;
            final selectedIndex = items?.indexWhere((item) => item.value == state.value) ?? -1;
            final selectedWidgets = selectedItemBuilder?.call(state.context);
            final selectedChild = selectedIndex >= 0
                ? (selectedWidgets != null && selectedIndex < selectedWidgets.length
                    ? selectedWidgets[selectedIndex]
                    : items![selectedIndex].child)
                : null;
            final effectiveDecoration = decoration.copyWith(
              errorText: state.errorText,
              enabled: enabled,
              suffixIcon: icon ?? const Icon(Icons.arrow_drop_down),
              floatingLabelBehavior: decoration.floatingLabelBehavior ??
                  FloatingLabelBehavior.always,
            );

            return InkWell(
              borderRadius: borderRadius ?? BorderRadius.circular(4),
              onTap: enabled
                  ? () async {
                      final result = await showDialog<_DropdownSelection<T>>(
                        context: state.context,
                        builder: (context) => _SearchableDropdownDialog<T>(
                          items: items!,
                          selectedValue: state.value,
                          title: _labelText(decoration) ?? 'Select option',
                          dropdownColor: dropdownColor,
                          itemHeight: itemHeight,
                        ),
                      );
                      if (result == null) return;
                      state.didChange(result.value);
                      onChanged(result.value);
                    }
                  : null,
              child: InputDecorator(
                isEmpty: selectedChild == null,
                isFocused: false,
                decoration: effectiveDecoration,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: itemHeight == null ? 0 : (itemHeight - 16).clamp(0.0, double.infinity).toDouble(),
                  ),
                  child: Row(
                    children: [
                      if (isExpanded)
                        Expanded(child: selectedChild ?? hint ?? const SizedBox.shrink())
                      else
                        Flexible(child: selectedChild ?? hint ?? const SizedBox.shrink()),
                    ],
                  ),
                ),
              ),
            );
          },
        );

  @override
  FormFieldState<T> createState() => _SearchableDropdownFormFieldState<T>();

  static String? _labelText(InputDecoration decoration) {
    final label = decoration.label;
    if (label is Text) return label.data;
    return decoration.labelText;
  }
}

class _SearchableDropdownFormFieldState<T> extends FormFieldState<T> {
  @override
  SearchableDropdownFormField<T> get widget =>
      super.widget as SearchableDropdownFormField<T>;

  @override
  void didUpdateWidget(covariant SearchableDropdownFormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && value != widget.initialValue) {
      didChange(widget.initialValue);
    }
  }
}

class _DropdownSelection<T> {
  const _DropdownSelection(this.value);
  final T? value;
}

class _SearchableDropdownDialog<T> extends StatefulWidget {
  const _SearchableDropdownDialog({
    required this.items,
    required this.selectedValue,
    required this.title,
    this.dropdownColor,
    this.itemHeight,
  });

  final List<DropdownMenuItem<T>> items;
  final T? selectedValue;
  final String title;
  final Color? dropdownColor;
  final double? itemHeight;

  @override
  State<_SearchableDropdownDialog<T>> createState() => _SearchableDropdownDialogState<T>();
}

class _SearchableDropdownDialogState<T> extends State<_SearchableDropdownDialog<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = widget.items.where((item) {
      if (query.isEmpty) return true;
      final label = _widgetText(item.child).toLowerCase();
      final value = item.value?.toString().toLowerCase() ?? '';
      return label.contains(query) || value.contains(query);
    }).toList(growable: false);

    return Dialog(
      backgroundColor: widget.dropdownColor,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search options',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: filtered.isEmpty
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No matching options'),
                      ))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final selected = item.value == widget.selectedValue;
                          return ListTile(
                            selected: selected,
                            minVerticalPadding: 8,
                            title: item.child,
                            trailing: selected ? const Icon(Icons.check) : null,
                            onTap: item.enabled
                                ? () => Navigator.of(context).pop(_DropdownSelection<T>(item.value))
                                : null,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _widgetText(Widget widget) {
  if (widget is Text) return widget.data ?? widget.textSpan?.toPlainText() ?? '';
  if (widget is RichText) return widget.text.toPlainText();
  if (widget is Row) return widget.children.map(_widgetText).join(' ');
  if (widget is Column) return widget.children.map(_widgetText).join(' ');
  if (widget is Wrap) return widget.children.map(_widgetText).join(' ');
  if (widget is Expanded) return _widgetText(widget.child);
  if (widget is Flexible) return _widgetText(widget.child);
  if (widget is Padding) return widget.child == null ? '' : _widgetText(widget.child!);
  if (widget is Align) return widget.child == null ? '' : _widgetText(widget.child!);
  if (widget is Center) return widget.child == null ? '' : _widgetText(widget.child!);
  if (widget is SizedBox) return widget.child == null ? '' : _widgetText(widget.child!);
  if (widget is Container) return widget.child == null ? '' : _widgetText(widget.child!);
  return '';
}
