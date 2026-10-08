import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/app_user.dart';
import '../../application/admin_providers.dart';
import '../../data/user_admin_service.dart';

/// Admin form to create a new staff account, or edit an existing one.
///
/// All fields are compulsory (AGENTS.md / assignment requirement). On create the
/// username is generated automatically (`role_firstname_seq`). Staff cannot edit
/// their own details — only the admin uses this screen.
class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({super.key, this.userId});

  /// When non-null the form edits an existing user; otherwise it creates one.
  final String? userId;

  bool get isEdit => userId != null;

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _mobile = TextEditingController();
  final _personalMobile = TextEditingController();
  final _nic = TextEditingController();

  UserRole _role = UserRole.ranger;
  String? _parkId;
  Gender? _gender;
  DateTime? _dob;
  Uint8List? _photoBytes;

  bool _loaded = false;
  bool _submitting = false;
  AppUser? _editing; // original record when editing

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _mobile, _personalMobile, _nic]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Populate the form from the cached user list when editing.
  void _hydrateForEdit() {
    if (_loaded || !widget.isEdit) return;
    final users = ref.read(adminUsersProvider).asData?.value;
    final user = users?.where((u) => u.id == widget.userId).firstOrNull;
    if (user == null) return;
    _editing = user;
    _name.text = user.name;
    _email.text = user.email;
    _mobile.text = user.mobileNumber;
    _personalMobile.text = user.personalMobileNumber;
    _nic.text = user.nic;
    _role = user.role;
    _parkId = user.parkId.isEmpty ? null : user.parkId;
    _gender = user.gender;
    _dob = user.dateOfBirth;
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    _hydrateForEdit();
    final parksAsync = ref.watch(parksProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit User' : 'Create User'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Center(child: _PhotoPicker(
                bytes: _photoBytes,
                existingData: _editing?.photoData ?? '',
                existingUrl: _editing?.photoUrl ?? '',
                onPick: _pickPhoto,
              )),
              const SizedBox(height: 20),

              _label('Full name'),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('e.g. Kumar Ravi'),
                validator: _required,
              ),
              const SizedBox(height: 16),

              _label('Email address'),
              TextFormField(
                controller: _email,
                readOnly: widget.isEdit, // email is the account identity
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('name@wildguard.lk').copyWith(
                  helperText: widget.isEdit ? 'Email cannot be changed' : null,
                ),
                validator: _email_,
              ),
              const SizedBox(height: 16),

              if (!widget.isEdit) ...[
                _label('Temporary password'),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: _dec('At least 6 characters'),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Use at least 6 characters.'
                      : null,
                ),
                const SizedBox(height: 16),
              ],

              _label('Role'),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: _dec(''),
                items: [
                  for (final r in UserRoleX.assignableByAdmin)
                    DropdownMenuItem(value: r, child: Text(r.displayLabel)),
                ],
                onChanged: (v) => setState(() => _role = v ?? _role),
              ),
              const SizedBox(height: 16),

              _label('Park'),
              parksAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Could not load parks'),
                data: (parks) => DropdownButtonFormField<String>(
                  initialValue: _parkId ??
                      (parks.isNotEmpty ? parks.first.id : null),
                  decoration: _dec(''),
                  items: [
                    for (final p in parks)
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (v) => setState(() => _parkId = v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Select a park.' : null,
                ),
              ),
              const SizedBox(height: 16),

              _label('Work mobile number'),
              TextFormField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('0771234567'),
                validator: _phone,
              ),
              const SizedBox(height: 16),

              _label('Personal mobile number'),
              TextFormField(
                controller: _personalMobile,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('0770000000'),
                validator: _phone,
              ),
              const SizedBox(height: 16),

              _label('NIC number'),
              TextFormField(
                controller: _nic,
                textCapitalization: TextCapitalization.characters,
                decoration: _dec('200012345678 or 901234567V'),
                validator: _nic_,
              ),
              const SizedBox(height: 16),

              _label('Date of birth'),
              _DobField(
                value: _dob,
                onPick: _pickDob,
              ),
              const SizedBox(height: 16),

              _label('Gender'),
              DropdownButtonFormField<Gender>(
                initialValue: _gender,
                decoration: _dec('Select gender'),
                items: [
                  for (final g in Gender.values)
                    DropdownMenuItem(value: g, child: Text(g.displayLabel)),
                ],
                onChanged: (v) => setState(() => _gender = v),
                validator: (v) => v == null ? 'Select a gender.' : null,
              ),
              const SizedBox(height: 28),

              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(widget.isEdit ? 'Save changes' : 'Create user'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Field helpers ------------------------------------------------------

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required.' : null;

  String? _email_(String? v) {
    final e = v?.trim() ?? '';
    if (e.isEmpty) return 'Email is required.';
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(e)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _phone(String? v) {
    final p = v?.trim() ?? '';
    if (p.isEmpty) return 'Mobile number is required.';
    if (p.length < 9 || p.length > 12) return 'Enter a valid mobile number.';
    return null;
  }

  String? _nic_(String? v) {
    final n = v?.trim().toUpperCase() ?? '';
    if (n.isEmpty) return 'NIC is required.';
    final oldNic = RegExp(r'^\d{9}[VX]$');
    final newNic = RegExp(r'^\d{12}$');
    if (!oldNic.hasMatch(n) && !newNic.hasMatch(n)) {
      return 'Enter a valid NIC (12 digits or 9 digits + V).';
    }
    return null;
  }

  // --- Actions ------------------------------------------------------------

  Future<void> _pickPhoto() async {
    // Keep the image small — it is stored inline (base64) in the Firestore
    // document, which has a 1 MB limit.
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 70,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) setState(() => _photoBytes = bytes);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 16, now.month, now.day),
      helpText: 'Select date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      _toast('Date of birth is required.');
      return;
    }
    if (!widget.isEdit && _photoBytes == null) {
      _toast('A profile picture is required.');
      return;
    }

    final service = ref.read(userAdminServiceProvider);
    if (service == null) {
      _toast('Account management is unavailable (Firebase not configured).');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (widget.isEdit) {
        final updated = _editing!.copyWith(
          name: _name.text.trim(),
          role: _role,
          parkId: _parkId ?? '',
          mobileNumber: _mobile.text.trim(),
          personalMobileNumber: _personalMobile.text.trim(),
          nic: _nic.text.trim().toUpperCase(),
          gender: _gender,
          dateOfBirth: _dob,
        );
        await service.updateUser(updated, newPhotoBytes: _photoBytes);
        _finish('${updated.name} updated.');
      } else {
        final created = await service.createUser(NewUserInput(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          role: _role,
          parkId: _parkId ?? '',
          mobileNumber: _mobile.text.trim(),
          personalMobileNumber: _personalMobile.text.trim(),
          nic: _nic.text.trim().toUpperCase(),
          gender: _gender!,
          dateOfBirth: _dob!,
          photoBytes: _photoBytes,
        ));
        _finish('Created ${created.name} — username: ${created.username}');
      }
    } on UserAdminException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _finish(String message) {
    if (!mounted) return;
    ref.invalidate(adminUsersProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
    Navigator.of(context).pop();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.bytes,
    required this.existingData,
    required this.existingUrl,
    required this.onPick,
  });

  final Uint8List? bytes;
  final String existingData;
  final String existingUrl;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (bytes != null) {
      image = MemoryImage(bytes!);
    } else if (existingData.isNotEmpty) {
      try {
        image = MemoryImage(base64Decode(existingData));
      } catch (_) {
        image = null;
      }
    } else if (existingUrl.isNotEmpty) {
      image = NetworkImage(existingUrl);
    }
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 52,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: image,
              child: image == null
                  ? const Icon(Icons.person, size: 48, color: AppColors.primary)
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: AppColors.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPick,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onPick,
          child: const Text('Choose profile picture'),
        ),
      ],
    );
  }
}

class _DobField extends StatelessWidget {
  const _DobField({required this.value, required this.onPick});

  final DateTime? value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Select date of birth'
        : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}';
    final age = value == null ? null : AppUser(
      id: '', name: '', role: UserRole.ranger, parkId: '', dateOfBirth: value,
    ).age;
    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixIcon: Icon(Icons.calendar_today, size: 18),
        ),
        child: Row(
          children: [
            Text(text,
                style: TextStyle(
                    color: value == null ? Colors.grey : null)),
            const Spacer(),
            if (age != null)
              Text('Age $age',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
