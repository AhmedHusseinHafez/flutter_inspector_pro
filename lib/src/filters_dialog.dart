import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:requests_inspector/src/enums/item_type_filter_enum.dart';
import 'package:requests_inspector/src/enums/requests_methods.dart';
import 'package:requests_inspector/src/inspector_controller.dart';
import 'package:requests_inspector/src/shared_widgets/inspector_theme.dart';

class FiltersDialog extends StatefulWidget {
  const FiltersDialog({super.key, required this.isDarkMode});

  final bool isDarkMode;

  @override
  State<FiltersDialog> createState() => _FiltersDialogState();
}

class _FiltersDialogState extends State<FiltersDialog> {
  final TextEditingController _statusCodeController = TextEditingController();
  RequestMethod? _selectedMethod;
  ItemTypeFilter _itemType = ItemTypeFilter.all;

  bool get _httpFiltersEnabled =>
      _itemType == ItemTypeFilter.all || _itemType == ItemTypeFilter.http;

  @override
  void initState() {
    super.initState();
    final controller = InspectorController();
    _selectedMethod = controller.filterRequestMethod;
    _itemType = controller.filterItemType;
    _statusCodeController.text = controller.filterStatusCode?.toString() ?? '';
  }

  @override
  void dispose() {
    _statusCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black54;

    return Dialog(
      backgroundColor: InspectorTheme.surface(isDarkMode),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: InspectorTheme.primary),
                const SizedBox(width: 8.0),
                Text(
                  'Filter requests',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20.0),
            _sectionLabel('Type', subtitleColor),
            const SizedBox(height: 8.0),
            Row(
              children: [
                _typeChip(ItemTypeFilter.all, 'All', isDarkMode),
                const SizedBox(width: 8.0),
                _typeChip(ItemTypeFilter.http, 'HTTP', isDarkMode),
                const SizedBox(width: 8.0),
                _typeChip(ItemTypeFilter.sse, 'SSE', isDarkMode),
                const SizedBox(width: 8.0),
                _typeChip(
                  ItemTypeFilter.firebaseMessaging,
                  'Firebase',
                  isDarkMode,
                ),
              ],
            ),
            const SizedBox(height: 20.0),
            _sectionLabel('Method', subtitleColor),
            const SizedBox(height: 8.0),
            Opacity(
              opacity: _httpFiltersEnabled ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !_httpFiltersEnabled,
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    _methodChip(null, 'Any', isDarkMode),
                    ...RequestMethod.values.map(
                      (m) => _methodChip(m, m.name, isDarkMode),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20.0),
            _sectionLabel('Status code', subtitleColor),
            const SizedBox(height: 8.0),
            Opacity(
              opacity: _httpFiltersEnabled ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !_httpFiltersEnabled,
                child: TextField(
                  controller: _statusCodeController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'e.g. 200',
                    hintStyle: TextStyle(color: subtitleColor),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 10.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(InspectorTheme.radius),
                      borderSide: BorderSide(
                        color: InspectorTheme.border(isDarkMode),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(InspectorTheme.radius),
                      borderSide: BorderSide(
                        color: InspectorTheme.border(isDarkMode),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(InspectorTheme.radius),
                      borderSide: const BorderSide(
                        color: InspectorTheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  keyboardType: TextInputType.number,
                ),
              ),
            ),
            const SizedBox(height: 24.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side:
                          BorderSide(color: InspectorTheme.border(isDarkMode)),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(InspectorTheme.radius),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedMethod = null;
                        _itemType = ItemTypeFilter.all;
                        _statusCodeController.clear();
                      });
                      InspectorController().clearFilters();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: InspectorTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(InspectorTheme.radius),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    onPressed: () {
                      final c = InspectorController();
                      c.setItemTypeFilter(_itemType);
                      c.setRequestMethodFilter(
                        _httpFiltersEnabled ? _selectedMethod : null,
                      );
                      int? status;
                      if (_httpFiltersEnabled &&
                          _statusCodeController.text.trim().isNotEmpty) {
                        status =
                            int.tryParse(_statusCodeController.text.trim());
                      }
                      c.setStatusCodeFilter(status);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _typeChip(ItemTypeFilter type, String label, bool isDarkMode) {
    final isSelected = _itemType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _itemType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? InspectorTheme.primary
                : InspectorTheme.surface(isDarkMode),
            borderRadius: BorderRadius.circular(InspectorTheme.radius),
            border: Border.all(
              color: isSelected
                  ? InspectorTheme.primary
                  : InspectorTheme.border(isDarkMode),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDarkMode ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  Widget _methodChip(RequestMethod? method, String label, bool isDarkMode) {
    final isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected
              ? InspectorTheme.primary
              : InspectorTheme.surface(isDarkMode),
          borderRadius: BorderRadius.circular(InspectorTheme.radius),
          border: Border.all(
            color: isSelected
                ? InspectorTheme.primary
                : InspectorTheme.border(isDarkMode),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.0,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDarkMode ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
