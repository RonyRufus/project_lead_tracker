import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/leads_provider.dart';
import '../models/project_lead.dart';
import '../services/export_service.dart';
import '../theme.dart';
import 'detail_screen.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final _searchCtrl = TextEditingController();
  bool _isExporting = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _export(List<ProjectLead> leads) async {
    if (leads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No leads to export.')),
      );
      return;
    }
    setState(() => _isExporting = true);
    try {
      await ExportService.exportAndShare(leads);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _deleteConfirm(
      BuildContext ctx, LeadsProvider provider, ProjectLead lead) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Delete Lead',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Delete "${lead.title}"?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.recordingRed)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await provider.deleteLead(lead.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LeadsProvider>();
    final leads = provider.filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Leads'),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accent),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.ios_share, color: AppTheme.accent),
              tooltip: 'Export CSV',
              onPressed: () => _export(provider.leads),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            tooltip: 'Refresh',
            onPressed: provider.loadLeads,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: provider.setSearch,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search leads…',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          provider.clearSearch();
                        },
                      )
                    : null,
              ),
            ),
          ),
          // Stats row
          _statsRow(provider),
          // List
          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent))
                : leads.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: leads.length,
                        itemBuilder: (ctx, i) => _leadCard(
                          ctx,
                          leads[i],
                          i,
                          provider,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(LeadsProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _stat('${provider.count}', 'Total'),
          const SizedBox(width: 16),
          _stat(
            '${provider.leads.where((l) => !l.isManual).length}',
            'Voice',
          ),
          const SizedBox(width: 16),
          _stat(
            '${provider.leads.where((l) => l.isManual).length}',
            'Manual',
          ),
          const Spacer(),
          if (provider.searchQuery.isNotEmpty)
            Chip(
              label: Text(
                '${provider.filtered.length} results',
                style: const TextStyle(fontSize: 11),
              ),
              backgroundColor: AppTheme.primary.withOpacity(0.2),
              side: const BorderSide(color: Colors.transparent),
            ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        Text(label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ],
    );
  }

  Widget _leadCard(BuildContext ctx, ProjectLead lead, int index,
      LeadsProvider provider) {
    return Dismissible(
      key: Key(lead.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.recordingRed.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        await _deleteConfirm(ctx, provider, lead);
        return false; // We handle deletion manually
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => DetailScreen(lead: lead)),
            );
            provider.loadLeads();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    lead.isManual ? Icons.push_pin_outlined : Icons.mic_none,
                    color: AppTheme.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lead.title,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      const SizedBox(height: 3),
                      if (lead.subtitle.isNotEmpty)
                        Text(lead.subtitle,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.schedule,
                              size: 11, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(lead.shortDate,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 11)),
                          const SizedBox(width: 8),
                          const Icon(Icons.location_on_outlined,
                              size: 11, color: AppTheme.textSecondary),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              lead.address.isNotEmpty
                                  ? lead.address
                                  : lead.coordsString,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary, size: 18),
              ],
            ),
          ),
        ),
      )
          .animate(delay: Duration(milliseconds: index * 40))
          .fadeIn(duration: 250.ms)
          .slideX(begin: 0.05, end: 0, duration: 250.ms),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined,
              size: 64,
              color: AppTheme.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            context.read<LeadsProvider>().searchQuery.isEmpty
                ? 'No leads yet'
                : 'No results found',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Say "Save Location" to capture a lead\nor tap the button on the map.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
