import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/color.dart';
import '../service/tournament_service.dart';

class ManageGroupsScreen extends StatefulWidget {
  final int tournamentId;
  const ManageGroupsScreen({super.key, required this.tournamentId});

  @override
  State<ManageGroupsScreen> createState() => _ManageGroupsScreenState();
}

class _ManageGroupsScreenState extends State<ManageGroupsScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('api_logged_in_token') ?? '';
    await _fetchGroups();
    setState(() => _loading = false);
  }

  Future<void> _fetchGroups() async {
    final res = await TournamentService.getGroups(
      token: _token!,
      tournamentId: widget.tournamentId,
    );
    setState(() => _groups = res);
  }

  Future<void> _addGroup(String name) async {
    final res = await TournamentService.addGroup(
      token: _token!,
      tournamentId: widget.tournamentId,
      groupName: name,
    );

    if (res['success']) {
      final group = res['data'][0];
      setState(
            () => _groups.add({
          'group_id': int.tryParse(group['group_id'].toString()) ?? 0,
          'group_name': group['group_name'] ?? '',
          'tournament_id': widget.tournamentId,
        }),
      );
      _showFlushbar(res['message']);
    } else {
      _showFlushbar(res['message'], isError: true);
    }
  }

  // ✅ Corrected Update Group method
  Future<void> _updateGroup(int id, String newName) async {
    final res = await TournamentService.updateGroup(
      token: _token!,
      tournamentId: widget.tournamentId,
      groupId: id,
      groupName: newName,
    );

    if (res['success']) {
      final i = _groups.indexWhere((g) => g['group_id'] == id);
      if (i != -1) setState(() => _groups[i]['group_name'] = newName);
      _showFlushbar(res['message']);
    } else {
      _showFlushbar(res['message'], isError: true);
    }
  }

  Future<void> _deleteGroup(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this group?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await TournamentService.deleteGroup(
        token: _token!,
        tournamentId: widget.tournamentId,
        groupId: id,
      );

      if (res['success']) {
        setState(() => _groups.removeWhere((g) => g['group_id'] == id));
        _showFlushbar(res['message']);
      } else {
        _showFlushbar(res['message'], isError: true);
      }
    }
  }

  void _showGroupDialog({int? id, String? initial}) {
    final controller = TextEditingController(text: initial ?? '');
    final isEdit = id != null;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? "Edit Group Name" : "Add Group"),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: "Enter group name (A, B, C...)",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              final exists = _groups.any(
                    (g) =>
                g['group_name'].toString().toLowerCase() ==
                    name.toLowerCase() &&
                    (!isEdit || g['group_id'] != id),
              );

              if (exists) {
                Navigator.pop(context);
                await Future.delayed(const Duration(milliseconds: 100));
                _showFlushbar("Group '$name' already exists", isError: true);
                return;
              }

              Navigator.pop(context);
              isEdit ? await _updateGroup(id!, name) : await _addGroup(name);
            },
            child: Text(isEdit ? "Update" : "Add"),
          ),
        ],
      ),
    );
  }

  Widget _groupCard(Map<String, dynamic> g) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(
          'Group ${g['group_name']?.toString().toUpperCase() ?? 'N/A'}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text("Tap below to add teams to this group"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.orange),
              onPressed: () =>
                  _showGroupDialog(id: g['group_id'], initial: g['group_name']),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteGroup(g['group_id']),
            ),
          ],
        ),
      ),
    );
  }

  void _showFlushbar(String message, {bool isError = false}) {
    Flushbar(
      message: message,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      backgroundColor: isError ? Colors.redAccent : AppColors.primary,
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Manage Groups",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: Theme.of(context).brightness == Brightness.dark
                ? null
                : const LinearGradient(
              colors: [AppColors.primary, Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : null,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: _groups.isEmpty
            ? const Center(child: Text("No groups yet."))
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Total Groups: ${_groups.length}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _groups.length,
                itemBuilder: (_, i) => _groupCard(_groups[i]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.group_add),
        label: const Text("Add Group"),
        onPressed: () => _showGroupDialog(),
      ),
    );
  }
}
