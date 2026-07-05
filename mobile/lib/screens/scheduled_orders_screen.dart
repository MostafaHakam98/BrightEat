import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recurring_order.dart';
import '../providers/orders_provider.dart';

/// Weekday labels indexed by the backend convention:
/// 0=Mon, 1=Tue, 2=Wed, 3=Thu, 4=Fri, 5=Sat, 6=Sun.
const List<String> _kWeekdayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// Screen listing recurring order schedules that auto-open a daily order.
class ScheduledOrdersScreen extends StatefulWidget {
  const ScheduledOrdersScreen({Key? key}) : super(key: key);

  @override
  State<ScheduledOrdersScreen> createState() => _ScheduledOrdersScreenState();
}

class _ScheduledOrdersScreenState extends State<ScheduledOrdersScreen> {
  bool _isLoading = true;
  List<RecurringOrder> _schedules = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Warm up the restaurant list for the create form, then load schedules.
      Provider.of<OrdersProvider>(context, listen: false).fetchRestaurants();
      _refresh();
    });
  }

  Future<void> _refresh() async {
    final svc = Provider.of<OrdersProvider>(context, listen: false).ordersService;
    if (mounted) setState(() => _isLoading = true);
    final schedules = await svc.fetchRecurringOrders();
    if (!mounted) return;
    setState(() {
      _schedules = schedules;
      _isLoading = false;
    });
  }

  Future<void> _toggleActive(RecurringOrder schedule, bool value) async {
    final svc = Provider.of<OrdersProvider>(context, listen: false).ordersService;
    await svc.updateRecurringOrder(schedule.id, {'is_active': value});
    await _refresh();
  }

  Future<void> _confirmDelete(RecurringOrder schedule) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete schedule?'),
        content: Text(
          'The schedule for ${schedule.restaurantName ?? 'this restaurant'} '
          'will stop opening orders automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final svc = Provider.of<OrdersProvider>(context, listen: false).ordersService;
    final ok = await svc.deleteRecurringOrder(schedule.id);
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Schedule deleted' : 'Could not delete schedule'),
        backgroundColor: ok ? Colors.grey[800] : Colors.red,
      ),
    );
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreateScheduleSheet(),
    );

    if (created == true && mounted) {
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scheduled — it will open automatically'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Orders'),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New schedule', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_schedules.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _schedules.length,
        itemBuilder: (context, index) => _buildScheduleCard(_schedules[index]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alarm, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No schedules yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set one up and the order opens itself.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openCreateSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.add),
              label: const Text('New schedule'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(RecurringOrder schedule) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    schedule.restaurantName ?? 'Restaurant #${schedule.restaurant}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: schedule.isActive,
                  activeColor: Colors.teal,
                  onChanged: (value) => _toggleActive(schedule, value),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(schedule),
                ),
              ],
            ),
            if (schedule.menuName != null && schedule.menuName!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                schedule.menuName!,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '⏰ ${schedule.openAtShort}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text('·', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final day in schedule.weekdayList)
                        _dayChip(
                          (day >= 0 && day < _kWeekdayLabels.length)
                              ? _kWeekdayLabels[day]
                              : '?',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.teal,
        ),
      ),
    );
  }
}

/// Modal bottom-sheet form for creating a new recurring order schedule.
class _CreateScheduleSheet extends StatefulWidget {
  const _CreateScheduleSheet({Key? key}) : super(key: key);

  @override
  State<_CreateScheduleSheet> createState() => _CreateScheduleSheetState();
}

class _CreateScheduleSheetState extends State<_CreateScheduleSheet> {
  int? _restaurantId;
  int? _menuId;
  TimeOfDay _time = const TimeOfDay(hour: 11, minute: 0);

  // Default: Sun–Thu (the Egypt work week) — 6,0,1,2,3.
  final Set<int> _weekdays = {6, 0, 1, 2, 3};
  String _feeSplitRule = 'equal';
  bool _submitting = false;

  // Menus for the currently selected restaurant (fetched on change).
  List<dynamic> _menus = [];
  bool _loadingMenus = false;

  final TextEditingController _cutoffCtrl = TextEditingController(text: '45');
  final TextEditingController _deliveryCtrl = TextEditingController(text: '30');
  final TextEditingController _tipCtrl = TextEditingController(text: '30');
  final TextEditingController _serviceCtrl = TextEditingController(text: '0');

  @override
  void dispose() {
    _cutoffCtrl.dispose();
    _deliveryCtrl.dispose();
    _tipCtrl.dispose();
    _serviceCtrl.dispose();
    super.dispose();
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _onRestaurantChanged(int? id) async {
    setState(() {
      _restaurantId = id;
      _menuId = null;
      _menus = [];
      _loadingMenus = id != null;
    });
    if (id == null) return;
    final provider = Provider.of<OrdersProvider>(context, listen: false);
    await provider.fetchMenus(restaurantId: id);
    if (!mounted) return;
    setState(() {
      _menus = List.of(provider.menus);
      _loadingMenus = false;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null && mounted) {
      setState(() => _time = picked);
    }
  }

  Future<void> _submit() async {
    if (_restaurantId == null) {
      _showError('Please pick a restaurant');
      return;
    }
    if (_weekdays.isEmpty) {
      _showError('Please pick at least one day');
      return;
    }

    final weekdaysCsv = (_weekdays.toList()..sort()).join(',');
    final payload = <String, dynamic>{
      'restaurant': _restaurantId,
      'menu': _menuId,
      'open_at': _fmtTime(_time),
      'weekdays': weekdaysCsv,
      'cutoff_after_minutes': int.tryParse(_cutoffCtrl.text.trim()),
      'delivery_fee': num.tryParse(_deliveryCtrl.text.trim()) ?? 0,
      'tip': num.tryParse(_tipCtrl.text.trim()) ?? 0,
      'service_fee': num.tryParse(_serviceCtrl.text.trim()) ?? 0,
      'fee_split_rule': _feeSplitRule,
    };

    setState(() => _submitting = true);
    final svc = Provider.of<OrdersProvider>(context, listen: false).ordersService;
    final result = await svc.createRecurringOrder(payload);
    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      setState(() => _submitting = false);
      _showError('${result['error'] ?? 'Could not create schedule'}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = Provider.of<OrdersProvider>(context).restaurants;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const Text(
                    'New schedule',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  // Restaurant (required)
                  DropdownButtonFormField<int>(
                    value: _restaurantId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Restaurant',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.restaurant),
                    ),
                    items: [
                      for (final r in restaurants)
                        DropdownMenuItem<int>(
                          value: r.id,
                          child: Text(r.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: _submitting ? null : _onRestaurantChanged,
                  ),
                  const SizedBox(height: 16),

                  // Menu (optional)
                  DropdownButtonFormField<int>(
                    value: _menuId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Menu (optional)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.menu_book),
                      helperText: _restaurantId == null
                          ? 'Pick a restaurant first'
                          : (_loadingMenus ? 'Loading menus…' : null),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Any menu'),
                      ),
                      for (final m in _menus)
                        DropdownMenuItem<int>(
                          value: m.id as int,
                          child: Text(
                            m.name as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (_restaurantId == null || _submitting)
                        ? null
                        : (value) => setState(() => _menuId = value),
                  ),
                  const SizedBox(height: 16),

                  // Time picker
                  InkWell(
                    onTap: _submitting ? null : _pickTime,
                    borderRadius: BorderRadius.circular(4),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Opens at',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(
                        _fmtTime(_time),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Weekday chips
                  const Text(
                    'Repeat on',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (int day = 0; day < _kWeekdayLabels.length; day++)
                        FilterChip(
                          label: Text(_kWeekdayLabels[day]),
                          selected: _weekdays.contains(day),
                          selectedColor: Colors.teal.withOpacity(0.2),
                          checkmarkColor: Colors.teal,
                          onSelected: _submitting
                              ? null
                              : (selected) {
                                  setState(() {
                                    if (selected) {
                                      _weekdays.add(day);
                                    } else {
                                      _weekdays.remove(day);
                                    }
                                  });
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Cutoff after minutes
                  TextField(
                    controller: _cutoffCtrl,
                    keyboardType: TextInputType.number,
                    enabled: !_submitting,
                    decoration: const InputDecoration(
                      labelText: 'Auto-lock after (minutes)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Fee fields
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _deliveryCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          enabled: !_submitting,
                          decoration: const InputDecoration(
                            labelText: 'Delivery',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _tipCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          enabled: !_submitting,
                          decoration: const InputDecoration(
                            labelText: 'Tip',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _serviceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          enabled: !_submitting,
                          decoration: const InputDecoration(
                            labelText: 'Service',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Fee split rule
                  DropdownButtonFormField<String>(
                    value: _feeSplitRule,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Fee split',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.call_split),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'equal', child: Text('Equal')),
                      DropdownMenuItem(
                        value: 'proportional',
                        child: Text('Proportional'),
                      ),
                      DropdownMenuItem(
                        value: 'collector_pays',
                        child: Text('Collector pays'),
                      ),
                    ],
                    onChanged: _submitting
                        ? null
                        : (value) => setState(
                            () => _feeSplitRule = value ?? 'equal'),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create schedule',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
