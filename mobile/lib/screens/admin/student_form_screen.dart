import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/states.dart';

/// Create or edit a student. Pops `true` when something changed.
class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({super.key, this.student, this.batches = const []});

  final Student? student;
  final List<Batch> batches;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _f;

  String? _batchId;
  DateTime _admissionDate = DateTime.now();
  bool _saving = false;
  List<Batch> _batches = const [];

  bool get _isEdit => widget.student != null;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _f = {
      'name': TextEditingController(text: s?.name),
      'phone': TextEditingController(text: s?.phone),
      'email': TextEditingController(text: s?.email),
      'parentName': TextEditingController(text: s?.parentName),
      'parentPhone': TextEditingController(text: s?.parentPhone),
      'address': TextEditingController(text: s?.address),
      'course': TextEditingController(text: s?.course),
      'password': TextEditingController(),
      'notes': TextEditingController(text: s?.notes),
    };
    _batchId = s?.batchId ?? s?.batch?.id;
    _admissionDate = s?.admissionDate ?? DateTime.now();
    _batches = widget.batches;
    if (_batches.isEmpty) _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final b = await context.read<ApiService>().batches(isActive: true);
      if (mounted) setState(() => _batches = b);
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _admissionDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _admissionDate = picked);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final api = context.read<ApiService>();
    final body = <String, dynamic>{
      'name': _f['name']!.text.trim(),
      'phone': _f['phone']!.text.trim(),
      'email': _f['email']!.text.trim(),
      'parentName': _f['parentName']!.text.trim(),
      'parentPhone': _f['parentPhone']!.text.trim(),
      'address': _f['address']!.text.trim(),
      'course': _f['course']!.text.trim(),
      'batchId': _batchId,
      'admissionDate': Fmt.iso(_admissionDate),
      if (_f['notes']!.text.trim().isNotEmpty) 'notes': _f['notes']!.text.trim(),
      if (!_isEdit && _f['password']!.text.isNotEmpty)
        'password': _f['password']!.text,
    };
    // The API treats an explicit null as "unassign"; omit rather than send ''.
    if (_batchId == null) body.remove('batchId');

    try {
      if (_isEdit) {
        await api.updateStudent(widget.student!.id, body);
      } else {
        await api.createStudent(body);
      }
      if (!mounted) return;
      showSnack(context, _isEdit ? 'Student updated' : 'Student added');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  String? _phone(String? v, String label) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return '$label is required';
    if (value.replaceAll(RegExp(r'\D'), '').length < 6) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit student' : 'New student')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(Gap.lg),
          children: [
            _label('Student details'),
            TextFormField(
              controller: _f['name'],
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) => _required(v, 'Name'),
            ),
            const SizedBox(height: Gap.lg),
            if (_isEdit)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.lg),
                child: TextFormField(
                  enabled: false,
                  initialValue: widget.student!.studentCode,
                  decoration: const InputDecoration(
                    labelText: 'Student ID',
                    helperText: 'Auto-generated, cannot be changed',
                  ),
                ),
              ),
            TextFormField(
              controller: _f['phone'],
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
              ],
              decoration: const InputDecoration(labelText: 'Phone'),
              validator: (v) => _phone(v, 'Phone'),
            ),
            const SizedBox(height: Gap.lg),
            TextFormField(
              controller: _f['email'],
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                helperText: 'Also used as the login for this student',
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Email is required';
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            if (!_isEdit) ...[
              const SizedBox(height: Gap.lg),
              TextFormField(
                controller: _f['password'],
                decoration: const InputDecoration(
                  labelText: 'Password (optional)',
                  helperText: 'Leave blank to use the default: Student@123',
                ),
                validator: (v) => (v == null || v.isEmpty || v.length >= 6)
                    ? null
                    : 'Password must be at least 6 characters',
              ),
            ],

            _label('Parent / guardian'),
            TextFormField(
              controller: _f['parentName'],
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Parent name'),
              validator: (v) => _required(v, 'Parent name'),
            ),
            const SizedBox(height: Gap.lg),
            TextFormField(
              controller: _f['parentPhone'],
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
              ],
              decoration: const InputDecoration(labelText: 'Parent phone'),
              validator: (v) => _phone(v, 'Parent phone'),
            ),
            const SizedBox(height: Gap.lg),
            TextFormField(
              controller: _f['address'],
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Address'),
              validator: (v) => _required(v, 'Address'),
            ),

            _label('Enrolment'),
            TextFormField(
              controller: _f['course'],
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Course',
                hintText: 'e.g. JEE Main 2027',
              ),
              validator: (v) => _required(v, 'Course'),
            ),
            const SizedBox(height: Gap.lg),
            DropdownButtonFormField<String?>(
              initialValue: _batchId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Batch'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Not assigned yet'),
                ),
                ..._batches.map(
                  (b) => DropdownMenuItem(
                    value: b.id,
                    child: Text(
                      '${b.name} · ${b.timing}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _batchId = v),
            ),
            const SizedBox(height: Gap.lg),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(kRadiusSm),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Admission date',
                  suffixIcon: Icon(Icons.calendar_today_rounded, size: 19),
                ),
                child: Text(Fmt.date(_admissionDate)),
              ),
            ),
            const SizedBox(height: Gap.lg),
            TextFormField(
              controller: _f['notes'],
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
              ),
            ),
            const SizedBox(height: Gap.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Add student'),
            ),
            const SizedBox(height: Gap.xxl),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: Gap.xl, bottom: Gap.md),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
        ),
      );
}
