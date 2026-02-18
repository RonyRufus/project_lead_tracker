import 'package:flutter/foundation.dart';
import '../models/project_lead.dart';
import '../services/database_service.dart';

class LeadsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<ProjectLead> _leads = [];
  List<ProjectLead> _filtered = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _lastError;

  List<ProjectLead> get leads => _leads;
  List<ProjectLead> get filtered => _filtered;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  int get count => _leads.length;

  Future<void> loadLeads() async {
    _isLoading = true;
    notifyListeners();
    try {
      _leads = await _db.getAllLeads();
      _applyFilter();
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> addLead(ProjectLead lead) async {
    final id = await _db.insertLead(lead);
    await loadLeads();
    return id;
  }

  Future<void> updateLead(ProjectLead lead) async {
    await _db.updateLead(lead);
    await loadLeads();
  }

  Future<void> deleteLead(String id) async {
    await _db.deleteLead(id);
    await loadLeads();
  }

  void setSearch(String query) {
    _searchQuery = query;
    _applyFilter();
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _filtered = List.from(_leads);
    notifyListeners();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_leads);
    } else {
      final q = _searchQuery.toLowerCase();
      _filtered = _leads.where((l) {
        return l.buildingType.toLowerCase().contains(q) ||
            l.architectName.toLowerCase().contains(q) ||
            l.phoneNumber.toLowerCase().contains(q) ||
            l.companyName.toLowerCase().contains(q) ||
            l.notes.toLowerCase().contains(q) ||
            l.address.toLowerCase().contains(q) ||
            l.rawTranscript.toLowerCase().contains(q) ||
            l.formattedDate.toLowerCase().contains(q);
      }).toList();
    }
  }

  /// Called from background service when a new lead is saved.
  void onLeadSavedFromBackground(Map<String, dynamic> data) {
    try {
      final lead = ProjectLead.fromMap(data);
      _leads.insert(0, lead);
      _applyFilter();
      notifyListeners();
    } catch (e) {
      loadLeads();
    }
  }
}
