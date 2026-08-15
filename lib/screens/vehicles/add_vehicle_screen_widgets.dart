part of 'add_vehicle_screen.dart';

// Bu dosya, add_vehicle_screen.dart'tan çıkarılan bağımsız (paylaşılan
// state'e bağımlı olmayan) yardımcı widget'ları içerir. 'part of' ile
// aynı kütüphaneye bağlı olduğundan private (_) sınıflar davranış
// değişmeden burada tanımlanabilir.

class _VehicleCategoryButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _VehicleCategoryButton({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 34,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionField extends FormField<String> {
  _SelectionField({
    required String label,
    required String value,
    required String emptyText,
    required IconData icon,
    required VoidCallback onTap,
    required String? Function(String?) validator,
  }) : super(
         initialValue: value,
         validator: (_) => validator(value),
         builder: (state) {
           return InkWell(
             onTap: onTap,
             borderRadius: BorderRadius.circular(14),
             child: InputDecorator(
               decoration: InputDecoration(
                 labelText: label,
                 prefixIcon: Icon(icon),
                 suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                 errorText: state.errorText,
               ),
               child: Text(
                 value.trim().isEmpty ? emptyText : value,
                 style: TextStyle(
                   color: value.trim().isEmpty
                       ? Theme.of(state.context).colorScheme.onSurfaceVariant
                       : null,
                 ),
               ),
             ),
           );
         },
       );
}

class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool showDivider;

  const _ReviewRow({
    required this.icon,
    required this.title,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

class _SearchSelectionSheet extends StatefulWidget {
  static const String customValue = '__CUSTOM_VALUE__';

  final String title;
  final String searchHint;
  final List<String> items;
  final String customOptionText;

  const _SearchSelectionSheet({
    required this.title,
    required this.searchHint,
    required this.items,
    required this.customOptionText,
  });

  @override
  State<_SearchSelectionSheet> createState() => _SearchSelectionSheetState();
}

class _SearchSelectionSheetState extends State<_SearchSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  List<String> get _filteredItems {
    if (_searchText.trim().isEmpty) {
      return widget.items;
    }

    final normalizedSearch = _searchText.toLowerCase();

    return widget.items
        .where((item) => item.toLowerCase().contains(normalizedSearch))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchText.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();

                              setState(() {
                                _searchText = '';
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Text(
                      'Eşleşen kayıt bulunamadı.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];

                      return ListTile(
                        title: Text(item),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(context, item);
                        },
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, _SearchSelectionSheet.customValue);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(widget.customOptionText),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
